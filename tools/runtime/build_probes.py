"""Compile only the issue-1 experiments, inside the locked, offline image."""
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys

from verify_lock import verify
from integrity import inputs

ROOT = Path('/work')
BUN = '/opt/bun/bun-linux-x64-baseline/bun'
CLI = '/opt/bend/bend2/main.ts'


def digest(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def main():
    out = ROOT / 'build'
    out.mkdir(exist_ok=True)
    (out/'build.json').unlink(missing_ok=True)
    provenance = verify()
    snapshot = inputs(ROOT)
    records = []
    paths = sorted((ROOT / 'tests/runtime/probes').glob('*.bend'))
    if len(sys.argv) > 1:
        unknown = set(sys.argv[1:]) - {p.stem for p in paths if p.stem != 'Support'}
        if unknown: raise SystemExit('unknown probe selection: ' + repr(sorted(unknown)))
        paths = [p for p in paths if p.stem in sys.argv[1:]]
    for path in paths:
        if path.stem == 'Support':
            continue
        record = {'probe': path.stem, 'source_sha256': digest(path), 'steps': []}
        for options in [['--check-only'], ['-o', str(out / path.stem)],
                        ['-o', str(out / (path.stem + '.c'))]]:
            command = [BUN, '--no-env-file', CLI, str(path), *options]
            run = subprocess.run(command, cwd='/opt/bend', capture_output=True,
                                 timeout=180, check=False)
            step = {'argv': command, 'exit': run.returncode,
                    'stdout': run.stdout.decode('utf-8', 'backslashreplace'),
                    'stderr': run.stderr.decode('utf-8', 'backslashreplace')}
            record['steps'].append(step)
            if run.returncode:
                (out / 'build-failure.json').write_text(json.dumps(record, indent=2))
                print(path.stem, 'FAILED', step['stdout'], step['stderr'], flush=True)
                return 1
        record['binary_sha256'] = digest(out / path.stem)
        record['c_sha256'] = digest(out / (path.stem + '.c'))
        records.append(record)
        print(path.stem, 'built', flush=True)
    negative = []
    for path in sorted((ROOT / 'tests/runtime/negative').glob('*.bend')):
        command = [BUN, '--no-env-file', CLI, str(path), '--check-only']
        run = subprocess.run(command, cwd='/opt/bend', capture_output=True, timeout=180)
        control = path.stem.endswith('_control')
        message = (run.stdout + run.stderr).decode('utf-8', 'backslashreplace')
        if (control and run.returncode) or (not control and (run.returncode == 0 or 'consumed more than once' not in message)):
            raise RuntimeError('ownership control failed: ' + path.name + '\n' + message)
        negative.append({'source': path.name, 'control': control, 'exit': run.returncode,
                         'source_sha256': digest(path), 'diagnostic': message})
        print(path.stem, 'expected typecheck result', flush=True)
    command = ['/usr/bin/clang-19', '-shared', '-fPIC', '-O2', '-Wall', '-Wextra', '-Werror',
               str(ROOT / 'tests/runtime/native/fault_inject.c'), '-o', str(out / 'fault_inject.so')]
    subprocess.run(command, check=True, timeout=60)
    race = ['/usr/bin/clang-19', '-O2', '-Wall', '-Wextra', '-Werror',
            str(ROOT / 'tests/runtime/native/exclusive_race.c'), '-o', str(out / 'exclusive_race')]
    subprocess.run(race, check=True, timeout=60)
    result = {'schema': 1, 'provenance': provenance,
              'compiler_source': '266b02ee40a2ad0c42608db32c08c5c7b6a8f5ae',
              'base_sha256': digest('/opt/bend/bend2/base.bend'),
              'packages_sha256': digest('/opt/packages.lock'), 'probes': records,
              'ownership_checks': negative, 'interposer_argv': command,
              'interposer_sha256': digest(out / 'fault_inject.so'),
              'race_sha256': digest(out / 'exclusive_race'),
              'complete': len(sys.argv) == 1,
              'inputs': snapshot}
    if inputs(ROOT)!=snapshot: raise RuntimeError('inputs changed during build')
    temporary=out/'build.json.tmp'
    temporary.write_text(json.dumps(result, indent=2) + '\n')
    temporary.replace(out/'build.json')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
