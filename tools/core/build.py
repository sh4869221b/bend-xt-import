"""Build every independent core entry point with the unmodified locked compiler."""
import json
from pathlib import Path
import subprocess
import sys
from integrity import inputs, digest
from case_spec import ENTRYPOINTS, OWNERS

ROOT = Path('/work')
sys.path.append(str(ROOT / 'tools/runtime'))
from verify_lock import verify


def main():
    out = ROOT / 'build/core'
    out.mkdir(parents=True, exist_ok=True)
    (out / 'build.json').unlink(missing_ok=True)
    snapshot = inputs(ROOT)
    provenance = verify()
    records, negatives = [], []
    paths = sorted((ROOT / 'tests/core').glob('*.bend'))
    if {p.stem for p in paths} != ENTRYPOINTS:
        raise RuntimeError('entry-point inventory differs; no partial acceptance build')
    negative_paths = sorted((ROOT / 'tests/core/negative').glob('*.bend'))
    if {p.stem for p in negative_paths} != OWNERS | {n+'_control' for n in OWNERS}:
        raise RuntimeError('ownership inventory differs')
    for path in paths:
        item = {'probe': path.stem, 'source_sha256': digest(path), 'steps': []}
        for flags in [['--check-only'], ['-o', str(out / (path.stem + '.c'))], ['-o', str(out / path.stem)]]:
            argv = ['/opt/bun/bun-linux-x64-baseline/bun', '--no-env-file', '/opt/bend/bend2/main.ts', str(path), *flags]
            run = subprocess.run(argv, cwd='/opt/bend', capture_output=True, text=True, timeout=240)
            item['steps'].append({'argv': argv, 'exit': run.returncode, 'stdout': run.stdout, 'stderr': run.stderr})
            if run.returncode:
                (out / 'build-failure.json').write_text(json.dumps(item, indent=2) + '\n')
                print(run.stdout, run.stderr, flush=True)
                return 1
        item['binary_sha256'] = digest(out / path.stem)
        item['c_sha256'] = digest(out / (path.stem + '.c'))
        records.append(item)
        print(path.stem, 'built', flush=True)
    for path in negative_paths:
        argv = ['/opt/bun/bun-linux-x64-baseline/bun', '--no-env-file', '/opt/bend/bend2/main.ts', str(path), '--check-only']
        run = subprocess.run(argv, cwd='/opt/bend', capture_output=True, text=True, timeout=240)
        control = path.stem.endswith('_control')
        text = run.stdout + run.stderr
        if (control and run.returncode) or (not control and (run.returncode == 0 or 'consumed more than once' not in text)):
            raise RuntimeError(path.name + '\n' + text)
        negatives.append({'file': path.name, 'control': control, 'sha256': digest(path), 'exit': run.returncode, 'diagnostic': text})
    if inputs(ROOT) != snapshot:
        raise RuntimeError('inputs changed during build')
    record = {'schema': 1, 'build_complete': True, 'acceptance_complete': False,
              'provenance': provenance, 'inputs': snapshot, 'probes': records, 'ownership_checks': negatives,
              'base_sha256': digest('/opt/bend/bend2/base.bend')}
    temporary = out / 'build.json.tmp'
    temporary.write_text(json.dumps(record, indent=2) + '\n')
    temporary.replace(out / 'build.json')
    return 0

if __name__ == '__main__':
    raise SystemExit(main())
