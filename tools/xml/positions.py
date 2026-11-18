"""Literal original-byte span and EOF-reference regression inventory.

The Bend probe asserts every exposed entry/field/Fuz/Params span and SourceKey
against constants. This runner supplies synthetic bytes and checks the native
result. It never derives expected coordinates from the production parser.
"""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[2]
MANIFEST = ROOT / 'tests/xml/positions-golden.json'
CHUNKS = (1, 2, 3, 7, 31, 65536)
RTS = ('+RTS', '--threads', '1', '--gpu', 'off', '-RTS')


def sha256(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def inventory(all_boundaries=False):
    manifest = json.loads(MANIFEST.read_text())
    if manifest['schema'] != 1 or [x['id'] for x in manifest['cases']] != [1, 2]:
        raise RuntimeError('position golden inventory differs')
    cases = []
    for case in manifest['cases']:
        count = sum(key.count('/') == 1 and key.startswith('Content1/String')
                    for key in case['spans'])
        cases.append((f"metadata-{case['id']}", case['id'], case['xml'].encode(),
                      {'kind': 'ok', 'count': count}))
    for case in manifest['reference_eof']:
        cases.append((case['name'], 0, case['xml'].encode(),
                      {'kind': 'error', 'diagnostic': case['diagnostic']}))
    if len(cases) != 14 or len({x[0] for x in cases}) != len(cases):
        raise RuntimeError('position golden count/names differ')
    rows = []
    for name, fixture, raw, expected in cases:
        chunks = [*CHUNKS]
        if all_boundaries:
            chunks.extend(65536 + cut for cut in range(1, len(raw)))
        for chunk in chunks:
            rows.append({'name': name, 'fixture': fixture, 'raw': raw,
                         'fixture_sha256': hashlib.sha256(raw).hexdigest(),
                         'chunk': chunk, 'override': [], 'expected': expected})
    for case in manifest['neighbors']:
        raw = case['xml'].encode()
        rows.append({'name': case['name'], 'fixture': case['fixture'], 'raw': raw,
                     'fixture_sha256': hashlib.sha256(raw).hexdigest(),
                     'chunk': case['chunk'], 'override': case['override'],
                     'expected': case['expected']})
    if len(manifest['neighbors']) != 7 or len({r['name'] for r in rows}) != 21:
        raise RuntimeError('live/source neighbor inventory differs')
    return rows


def parse(stdout):
    words = stdout.decode('ascii').strip().split()
    if not words or words[-1] != 'balanced':
        raise ValueError('missing balanced result')
    if words[0] == 'ok' and len(words) == 6:
        digest, count, logical, work = map(int, words[1:-1])
        return {'kind': 'ok', 'digest': digest, 'count': count,
                'logical': logical, 'work': work, 'balanced': True}
    if words[0] == 'error' and len(words) == 10:
        values = list(map(int, words[1:-1]))
        return {'kind': 'error', 'diagnostic': values[:6],
                'logical': values[6], 'work': values[7], 'balanced': True}
    raise ValueError('unexpected native position result')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--binary', type=Path, default=ROOT / 'build/xml/positions')
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--all-boundaries', action='store_true')
    args = parser.parse_args()
    binary = args.binary.resolve()
    report = {'schema': 1, 'complete': False,
              'binary_sha256': sha256(binary), 'manifest_sha256': sha256(MANIFEST),
              'probe_sha256': sha256(ROOT / 'tests/xml/positions.bend'),
              'runner_sha256': sha256(Path(__file__)),
              'all_boundaries': args.all_boundaries, 'rows': []}
    args.output.parent.mkdir(parents=True, exist_ok=True)
    baselines = {}
    try:
        for row in inventory(args.all_boundaries):
            raw = row.pop('raw')
            cmd = [str(binary), *RTS, str(row['fixture']), raw.hex(), str(row['chunk']),
                   *map(str, row['override'])]
            result = subprocess.run(cmd, capture_output=True, timeout=15)
            row.update(exit=result.returncode, stderr=result.stderr.decode(errors='replace'))
            report['rows'].append(row)
            if result.returncode or result.stderr:
                row['stdout'] = result.stdout.decode(errors='replace')
                raise RuntimeError(f"{row['name']} chunk {row['chunk']}: exit {result.returncode}")
            actual = parse(result.stdout)
            row['actual'] = actual
            expected = row['expected']
            if any(actual.get(key) != value for key, value in expected.items()):
                raise RuntimeError(f"{row['name']} chunk {row['chunk']}: expected {expected}, actual {actual}")
            # The adapter's work cost may depend on partitioning. Preserve the
            # measured value, but require semantic/diagnostic/logical equality.
            semantic = {k: v for k, v in actual.items() if k != 'work'}
            previous = baselines.setdefault(row['name'], semantic)
            if semantic != previous:
                raise RuntimeError(f"{row['name']} chunk {row['chunk']}: partition-dependent result")
        if sha256(binary) != report['binary_sha256'] or sha256(MANIFEST) != report['manifest_sha256']:
            raise RuntimeError('position binary or manifest changed during the run')
        report['complete'] = True
    finally:
        args.output.write_text(json.dumps(report, indent=2) + '\n')
    print(f"positions: {len(baselines)} fixtures, {len(report['rows'])} native runs passed")


if __name__ == '__main__':
    main()
