"""Locked no-network container driver. Not a resource measurement supervisor."""
import json
import os
from pathlib import Path
import platform
import subprocess
import sys
import time
import xml.parsers.expat as expat
from cases import corpus
from checks import RTS, schedules, verify_fixture, partition_key
from integrity import ROOT, inputs, digest
from oracle import result
from validation import producer_status, validate_limits


def main():
    out = Path('/reports')
    target = out / 'oracle-suite.json'
    snapshot = inputs(ROOT)
    binaries = {name: digest(ROOT / 'build/xml' / name) for name in ('driver', 'positions')}
    metadata = {'uid': os.getuid(), 'python_version': platform.python_version(), 'expat_version': expat.EXPAT_VERSION,
                'machine': platform.machine(), 'system': platform.system(), 'runtime_args': RTS,
                'packages_sha256': digest('/opt/packages.lock')}
    for k in ('memory.max', 'memory.swap.max'):
        metadata[k] = (Path('/sys/fs/cgroup') / k).read_text().strip()
    if metadata['uid'] == 0 or metadata['memory.max'] != '1073741824' or metadata['memory.swap.max'] != '0':
        raise RuntimeError('unlocked oracle execution profile')
    data = {'schema': 1, 'complete': False, 'acceptance_complete': False,
            'locked_technical_validation': True, 'producer_export': producer_status(),
            'metadata': metadata, 'inputs': snapshot, 'binaries': binaries,
            'seed': 5005, 'cases': [], 'real_files': []}
    target.write_text(json.dumps(data, indent=2) + '\n')
    for case in corpus():
        raw = case['raw']
        expected = result(raw)
        if expected['accepted'] is not case['accepted']:
            raise ValueError('explicit expectation disagrees with Expat/schema oracle: ' + case['name'])
        row = {'name': case['name'], 'group': case['group'], 'sha256': __import__('hashlib').sha256(raw).hexdigest(),
               'raw_hex': raw.hex(), 'oracle': expected, 'runs': []}
        data['cases'].append(row)
        target.write_text(json.dumps(data, indent=2) + '\n')
        first = None
        for chunk in schedules(raw):
            start = time.monotonic()
            try:
                p = subprocess.run([str(ROOT / 'build/xml/driver'), raw.hex(), str(chunk), *RTS],
                                   capture_output=True, text=True, timeout=60)
            except subprocess.TimeoutExpired:
                row['first_difference'] = {'chunk': chunk, 'error': 'native comparison timed out after 60 seconds'}
                target.write_text(json.dumps(data, indent=2) + '\n')
                raise
            record = {'chunk': chunk, 'exit': p.returncode, 'stdout': p.stdout, 'stderr': p.stderr,
                      'seconds': time.monotonic() - start}
            row['runs'].append(record)
            try:
                if p.returncode or p.stderr:
                    raise ValueError('native comparison process failed: ' + case['name'])
                actual = verify_fixture(raw, p.stdout, case['accepted'])
                record['actual'] = actual
                semantic = partition_key(actual, len(raw), chunk)
                if first is not None and semantic != first:
                    raise ValueError('partition changes content/diagnostics/work: ' + case['name'])
                first = semantic
            except (ValueError, AssertionError) as error:
                row['first_difference'] = {'chunk': chunk, 'error': str(error)}
                target.write_text(json.dumps(data, indent=2) + '\n')
                raise
        target.write_text(json.dumps(data, indent=2) + '\n')
        print(case['name'], len(row['runs']), 'passed', flush=True)
    for tool, binary in [('limits', 'driver'), ('positions', 'positions')]:
        command = [sys.executable, str(ROOT / 'tools/xml' / (tool + '.py')), '--binary',
                   str(ROOT / 'build/xml' / binary), '--output', str(out / (tool + '.json'))]
        if tool == 'positions':
            command.append('--all-boundaries')
        p = subprocess.run(command, capture_output=True, text=True, timeout=900)
        (out / (tool + '-stdout.log')).write_text(p.stdout)
        (out / (tool + '-stderr.log')).write_text(p.stderr)
        if p.returncode or p.stderr:
            raise ValueError(tool + ' failed: ' + p.stdout + p.stderr)
        data[tool] = {'file': tool + '.json', 'sha256': digest(out / (tool + '.json'))}
    validate_limits(json.loads((out / 'limits.json').read_text()), ROOT, binaries['driver'])
    if inputs(ROOT) != snapshot or binaries != {n: digest(ROOT / 'build/xml' / n) for n in binaries}:
        raise ValueError('oracle source or binary changed during execution')
    data['complete'] = True
    target.write_text(json.dumps(data, indent=2) + '\n')


if __name__ == '__main__':
    main()
