"""Incremental locked builds. This is not a completed acceptance manifest."""
import hashlib
import json
from pathlib import Path
import subprocess
import sys

ROOT = Path('/work')
sys.path.append(str(ROOT / 'tools/runtime'))
from verify_lock import verify
from integrity import inputs


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    provenance = verify()
    out = ROOT / 'build/core'
    out.mkdir(parents=True, exist_ok=True)
    files = [ROOT / 'tests/core' / (name + '.bend') for name in sys.argv[1:]]
    for path in files:
        record = {'acceptance_complete': False, 'provenance': provenance,
                  'inputs': inputs(ROOT),
                  'source': str(path.relative_to(ROOT)), 'steps': []}
        for flags in [['--check-only'], ['-o', str(out / (path.stem + '.c'))],
                      ['-o', str(out / path.stem)]]:
            cmd = ['/opt/bun/bun-linux-x64-baseline/bun', '--no-env-file',
                   '/opt/bend/bend2/main.ts', str(path), *flags]
            p = subprocess.run(cmd, cwd='/opt/bend', capture_output=True, timeout=240)
            record['steps'].append({'argv': cmd, 'exit': p.returncode,
                                    'stdout': p.stdout.decode(), 'stderr': p.stderr.decode()})
            (out / (path.stem + '.build.json')).write_text(json.dumps(record, indent=2) + '\n')
            if p.returncode:
                print(p.stdout.decode(), p.stderr.decode(), flush=True)
                return 1
        record['inputs_stable'] = inputs(ROOT) == record['inputs']
        if not record['inputs_stable']:
            (out / (path.stem + '.build.json')).write_text(json.dumps(record, indent=2) + '\n')
            raise RuntimeError('source changed during development build')
        record['c_sha256'] = sha(out / (path.stem + '.c'))
        record['binary_sha256'] = sha(out / path.stem)
        (out / (path.stem + '.build.json')).write_text(json.dumps(record, indent=2) + '\n')
        print(path.stem, 'built (acceptance incomplete)', flush=True)
    return 0

if __name__ == '__main__':
    raise SystemExit(main())
