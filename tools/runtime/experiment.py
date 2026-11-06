"""Host-side supervisor. Never place this supervisor in the probe's cgroup."""
import base64
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import tempfile
import time
import platform
from integrity import inputs

ROOT = Path(__file__).resolve().parents[2]
IMAGE = 'bend-xt-probe:issue1'
RTS = ['+RTS', '--threads', '1', '--gpu', 'off', '-RTS']


def docker_env():
    env = os.environ.copy()
    for name in ['DOCKER_HOST', 'DOCKER_CONTEXT', 'DOCKER_TLS', 'DOCKER_TLS_VERIFY', 'DOCKER_CERT_PATH']:
        env.pop(name, None)
    return env


def docker(*args, **kwargs):
    return subprocess.run(['docker', '--host=unix:///var/run/docker.sock', *args],
                          env=docker_env(), check=True, capture_output=True, timeout=kwargs.pop('timeout', 90), **kwargs)


def cgroup_path(cid, pid):
    relative = Path('/proc', str(pid), 'cgroup').read_text().split('0::', 1)[1].strip()
    paths = []
    if '..' not in Path(relative).parts:
        paths.append(Path('/sys/fs/cgroup') / relative.lstrip('/'))
    paths += [Path('/sys/fs/cgroup/docker') / cid,
              Path('/sys/fs/cgroup/system.slice') / ('docker-' + cid + '.scope')]
    for candidate in paths:
        try:
            if str(pid) in (candidate / 'cgroup.procs').read_text().split():
                return candidate
        except OSError:
            pass
    raise RuntimeError('cannot establish the probe cgroup identity')


def counters(value):
    return {k: int(v) for k, v in (line.split() for line in value.splitlines())}


def verified_build():
    manifest = json.loads((ROOT/'build/build.json').read_text())
    current = inputs(ROOT)
    if not manifest.get('complete') or manifest.get('inputs') != current:
        raise RuntimeError('missing, partial, or stale build: rebuild every probe before running')
    binaries = {p['probe']: p['binary_sha256'] for p in manifest['probes']}
    binaries['exclusive_race'] = manifest['race_sha256']
    binaries['fault_inject.so'] = manifest['interposer_sha256']
    for name, digest in binaries.items():
        if hashlib.sha256((ROOT/'build'/name).read_bytes()).hexdigest()!=digest:
            raise RuntimeError('binary digest mismatch: '+name)
    return binaries


def run_probe(name, args=(), prepare=None, fault=None, timeout=45, memory=1073741824,
              kill_after=None, rlimit_as=None, kill_signal='SIGKILL'):
    binaries = verified_build()
    if name not in binaries or name.endswith('.so'): raise ValueError('unbuilt probe')
    (ROOT / 'runs').mkdir(exist_ok=True)
    directory = Path(tempfile.mkdtemp(prefix=name + '-', dir=ROOT / 'runs'))
    published = directory / 'published'
    published.mkdir()
    sentinel = directory / 'sentinel.bin'
    sentinel.write_bytes(b'unchanged-existing-destination')
    if prepare:
        prepare(directory)
    before = hashlib.sha256(sentinel.read_bytes()).hexdigest()
    uid = os.getuid()
    if uid == 0:
        raise RuntimeError('run the harness as an unprivileged user for permission probes')
    if kill_signal not in {'SIGTERM', 'SIGKILL'}:
        raise ValueError('unsupported test signal')
    encoded = json.dumps([base64.b64encode(x if isinstance(x, bytes) else str(x).encode()).decode() for x in args])
    container_name='bend-xt-'+directory.name
    command = ['create', '--name', container_name, '--label', 'bend-xt-experiment=issue1', '--network', 'none', '--read-only', '--cap-drop', 'ALL',
               '--security-opt', 'no-new-privileges', '--user', f'{uid}:{os.getgid()}',
               '--memory', str(memory), '--memory-swap', str(memory), '--cpus', '1', '--pids-limit', '64',
               '--mount', f'type=bind,src={ROOT / "build"},dst=/probes,readonly',
               '--mount', f'type=bind,src={ROOT / "tools/runtime/native_entry.py"},dst=/entry.py,readonly',
               '--mount', f'type=bind,src={directory},dst=/scratch', '--workdir', '/scratch']
    if fault:
        command += ['--env', 'BEND_PROBE_PRELOAD=/probes/fault_inject.so']
        for key, value in fault.items():
            if key not in {'OP', 'MODE', 'SPLIT'}:
                raise ValueError('unknown fault option')
            command += ['--env', f'BEND_PROBE_FAULT_{key}={value}']
    if rlimit_as is not None:
        command += ['--env', f'BEND_PROBE_AS_LIMIT={int(rlimit_as)}']
    # Set LD_PRELOAD only at native exec: Python's launch barrier must not be instrumented.
    command += [IMAGE, 'python3', '/entry.py', name, encoded, str(memory)]
    cid = None
    started = time.monotonic()
    attached = None
    samples = []
    timed_out = False
    killed = False
    log_out = (directory / 'stdout.log').open('wb')
    log_err = (directory / 'stderr.log').open('wb')
    try:
        cid = docker(*command).stdout.decode().strip()
        attached = subprocess.Popen(['docker', '--host=unix:///var/run/docker.sock', 'start', '-a', cid],
                                    stdout=log_out, stderr=log_err, env=docker_env())
        while not (directory / 'ready.json').exists():
            if attached.poll() is not None or time.monotonic() - started > 60:
                raise RuntimeError('container failed before the native launch barrier: ' + docker('logs', cid).stderr.decode(errors='replace'))
            time.sleep(.02)
        info = json.loads(docker('inspect', cid).stdout)[0]
        ready = json.loads((directory / 'ready.json').read_text())
        lock = json.loads((ROOT / 'sources.lock').read_text())
        if ready['packages_sha256'] != lock['probe_image']['packages_sha256']:
            raise RuntimeError('probe userland differs from the lock')
        cg = cgroup_path(cid, info['State']['Pid'])
        candidates = []
        for member in (cg / 'cgroup.procs').read_text().split():
            status = Path('/proc', member, 'status').read_text()
            ns = re.search(r'^NSpid:\s+(.+)$', status, re.M)
            if ns and ns[1].split()[-1] == str(ready['pid']): candidates.append(int(member))
        if len(candidates) != 1: raise RuntimeError('cannot identify native child at the pre-exec barrier')
        pid = candidates[0]
        limits = {k: (cg / k).read_text().strip() for k in ['memory.max', 'memory.swap.max']}
        if limits != {'memory.max': str(memory), 'memory.swap.max': '0'}:
            raise RuntimeError('external limit readback mismatch')
        events_before = counters((cg / 'memory.events').read_text())
        (directory / '.go').touch(exist_ok=False)
        native_start = time.monotonic()
        final = None
        final_cgroup = None
        while attached.poll() is None:
            try:
                proc = Path('/proc', str(pid), 'status').read_text()
                item = {'elapsed': time.monotonic() - native_start,
                        'memory_current': int((cg / 'memory.current').read_text()),
                        'memory_peak': int((cg / 'memory.peak').read_text()),
                        'events': counters((cg / 'memory.events').read_text())}
                for key in ['VmRSS', 'VmHWM', 'VmSize']:
                    match = re.search(r'^' + key + r':\s+(\d+) kB$', proc, re.M)
                    if match:
                        item[key + '_bytes'] = int(match[1]) * 1024
                process_name = re.search(r'^Name:\s+(.+)$', proc, re.M)
                item['output_lines'] = (directory / 'stdout.log').read_bytes().count(b'\n')
                item['native_process'] = bool(process_name and process_name[1] == name[:15])
                samples.append(item)
            except OSError:
                pass  # The finite lifetime of the cgroup is reflected by missing final samples.
            if final is None and (directory / 'native-result.json').exists():
                final = json.loads((directory / 'native-result.json').read_text())
                final_cgroup = {'events': counters((cg / 'memory.events').read_text()),
                                'memory_peak': int((cg / 'memory.peak').read_text())}
                (directory / '.release').touch(exist_ok=False)
            elapsed = time.monotonic() - native_start
            if (directory / 'stdout.log').stat().st_size + (directory / 'stderr.log').stat().st_size > 256 * 1024:
                docker('kill', '--signal', 'SIGKILL', cid)
                raise RuntimeError('probe output exceeded the experiment limit')
            if final is None and not killed and ((kill_after is not None and elapsed >= kill_after) or elapsed > timeout):
                timed_out = elapsed > timeout
                docker('kill', '--signal', kill_signal if not timed_out else 'SIGKILL', cid)
                killed = True
            if elapsed > timeout + 20:
                raise RuntimeError('container attach did not terminate after kill')
            time.sleep(.02)
        attached.wait(timeout=10)
        log_out.close()
        log_err.close()
        stdout = (directory / 'stdout.log').read_bytes()
        stderr = (directory / 'stderr.log').read_bytes()
        state = json.loads(docker('inspect', cid).stdout)[0]['State']
        if len(stdout) + len(stderr) > 256 * 1024:
            raise RuntimeError('probe output exceeded the experiment limit')
        if hashlib.sha256(sentinel.read_bytes()).hexdigest() != before or list(published.iterdir()):
            raise AssertionError('sentinel changed or a publish artifact appeared')
        result = {'probe': name, 'binary_sha256': binaries[name],
                  'build_sha256': hashlib.sha256((ROOT/'build/build.json').read_bytes()).hexdigest(),
                  'lock_sha256': hashlib.sha256((ROOT/'sources.lock').read_bytes()).hexdigest(),
                  'runner_sha256': hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
                  'entry_sha256': hashlib.sha256((ROOT/'tools/runtime/native_entry.py').read_bytes()).hexdigest(),
                  'kernel': platform.release(), 'args_base64': json.loads(encoded), 'exit': state['ExitCode'],
                  'docker_client_exit': attached.returncode, 'oom_killed': state['OOMKilled'],
                  'timed_out': timed_out, 'external_kill': killed, 'limits': limits,
                  'events_before': events_before, 'samples': samples,
                  'native_result': final, 'final_cgroup': final_cgroup,
                  'image_id': info['Image'], 'ready': ready,
                  'kill_signal': kill_signal if killed and not timed_out else ('SIGKILL' if timed_out else None),
                  'stdout': stdout.decode('utf-8', 'backslashreplace'),
                  'stderr': stderr.decode('utf-8', 'backslashreplace'),
                  'scratch': directory.name, 'seconds': time.monotonic() - native_start}
        trace = directory / 'fault.trace'
        if fault:
            if not trace.is_file():
                raise AssertionError('fault injection trace missing')
            result['fault_trace'] = trace.read_text()
        (directory / 'observation.json').write_text(json.dumps(result, indent=2) + '\n')
        return result, directory
    finally:
        if cid is not None:
            docker('rm', '-f', cid)
        else:
            # Named before create: recover only our own interrupted create attempt.
            try: docker('rm', '-f', container_name)
            except subprocess.CalledProcessError as error:
                if b'No such container' not in error.stderr: raise
        if attached is not None and attached.poll() is None:
            attached.kill()
            attached.communicate()
        log_out.close()
        log_err.close()
