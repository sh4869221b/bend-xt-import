"""Run complete native functional inventory and isolated Expat comparison."""
import json
import os
from pathlib import Path
import subprocess
import tempfile
from checks import functional_cases, key, verify_output
from experiment import ROOT, docker, run_probe, verified_build
from integrity import digest, inputs, invalidate_summary
from validation import check_observation, producer_status, validate_oracle, validate_limits, validate_positions


def oracle_container(binaries):
    directory = Path(tempfile.mkdtemp(prefix='oracle-', dir=ROOT / 'runs/xml'))
    name = 'bend-xml-' + directory.name
    cid = None
    try:
        cid = docker('create', '--name', name, '--network', 'none', '--read-only', '--cap-drop', 'ALL',
                     '--security-opt', 'no-new-privileges', '--user', f'{os.getuid()}:{os.getgid()}',
                     '--memory', '1073741824', '--memory-swap', '1073741824', '--cpus', '1', '--pids-limit', '64',
                     '--mount', f'type=bind,src={ROOT},dst=/work,readonly',
                     '--mount', f'type=bind,src={directory},dst=/reports',
                     'bend-xt-probe:issue1', 'python3', '/work/tools/xml/functional_runner.py').stdout.decode().strip()
        info = json.loads(docker('inspect', cid).stdout)[0]
        environment = json.loads((ROOT / 'build/xml/environment.json').read_text())
        if info['Image'] != environment['images'][1]['id']:
            raise RuntimeError('oracle runtime image changed')
        p = docker('start', '-a', cid, timeout=1800)
        info = json.loads(docker('inspect', cid).stdout)[0]
        (directory / 'stdout.log').write_bytes(p.stdout)
        (directory / 'stderr.log').write_bytes(p.stderr)
        if info['State']['ExitCode'] != 0 or info['State']['OOMKilled'] or p.stderr:
            raise RuntimeError('oracle container failed')
        host = info['HostConfig']
        proof = {'image_id': info['Image'], 'container_id': cid, 'exit': info['State']['ExitCode'],
                 'oom_killed': info['State']['OOMKilled'], 'network': host['NetworkMode'],
                 'read_only': host['ReadonlyRootfs'], 'memory': host['Memory'],
                 'memory_swap': host['MemorySwap'], 'cap_drop': host['CapDrop'], 'security_opt': host['SecurityOpt']}
        (directory / 'container.json').write_text(json.dumps(proof, indent=2) + '\n')
        data = json.loads((directory / 'oracle-suite.json').read_text())
        lock = json.loads((ROOT / 'sources.lock').read_text())
        validate_oracle(data, inputs(ROOT), lock['probe_image']['packages_sha256'], binaries)
        validate_limits(json.loads((directory / 'limits.json').read_text()), ROOT, binaries['driver'])
        validate_positions(json.loads((directory / 'positions.json').read_text()), ROOT, binaries['positions'])
        return {'directory': str(directory.relative_to(ROOT)), 'sha256': digest(directory / 'oracle-suite.json'),
                'container_sha256': digest(directory / 'container.json'), 'image_id': info['Image']}
    finally:
        if cid is not None:
            docker('rm', '-f', cid)
        else:
            try:
                docker('rm', '-f', name)
            except subprocess.CalledProcessError as error:
                if b'No such container' not in error.stderr:
                    raise


def main():
    invalidate_summary()
    binaries = verified_build()
    (ROOT / 'runs/xml').mkdir(parents=True, exist_ok=True)
    snapshot = inputs(ROOT)
    data = {'schema': 1, 'complete': False, 'acceptance_complete': False, 'producer_export': producer_status(),
            'inputs': snapshot, 'build_sha256': digest(ROOT / 'build/xml/build.json'),
            'environment_sha256': digest(ROOT / 'build/xml/environment.json'), 'cases': []}
    target = ROOT / 'build/xml/functional.json'
    target.write_text(json.dumps(data, indent=2) + '\n')
    for name, args in functional_cases():
        row, directory = run_probe(name, args, timeout=300)
        check_observation(row)
        verify_output(name, args, row['stdout'])
        data['cases'].append({'key': key(name, args), 'observation': str((directory / 'observation.json').relative_to(ROOT)),
                              'sha256': digest(directory / 'observation.json')})
        target.write_text(json.dumps(data, indent=2) + '\n')
        print(name, 'passed', flush=True)
    data['oracle'] = oracle_container(binaries)
    verified_build()
    if inputs(ROOT) != snapshot:
        raise RuntimeError('functional inputs changed')
    data['complete'] = True
    target.write_text(json.dumps(data, indent=2) + '\n')


if __name__ == '__main__':
    main()
