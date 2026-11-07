"""An exec barrier: the native probe replaces this process in its limited cgroup."""
import base64
import hashlib
import json
import os
from pathlib import Path
import re
import resource
import signal
import sys
import time

name = sys.argv[1]
if not re.fullmatch(r'[a-z_]+', name):
    raise SystemExit('invalid probe name')
scratch = Path('/scratch')
def record(name, value):
    temporary = scratch / (name + '.tmp')
    temporary.write_text(json.dumps(value))
    temporary.replace(scratch / name)

child = os.fork()
if child:
    # This small pinned helper reaps the native child and preserves final rusage.
    # It is charged to the same cgroup; the real supervisor remains outside.
    def forward(number, frame):
        try: os.kill(child, number)
        except ProcessLookupError: pass
    signal.signal(signal.SIGTERM, forward)
    _, status, usage = os.wait4(child, 0)
    result = {'wait_status': status, 'maxrss_bytes': int(usage.ru_maxrss) * 1024,
              'signal': os.WTERMSIG(status) if os.WIFSIGNALED(status) else None,
              'exit': os.WEXITSTATUS(status) if os.WIFEXITED(status) else 128 + os.WTERMSIG(status)}
    record('native-result.json', result)
    deadline = time.monotonic() + 60
    while not (scratch / '.release').exists():
        if time.monotonic() >= deadline: raise SystemExit(79)
        time.sleep(.01)
    raise SystemExit(result['exit'])
metadata = {'pid': os.getpid(), 'uid': os.getuid(), 'cgroup': Path('/proc/self/cgroup').read_text()}
metadata['packages_sha256'] = hashlib.sha256(Path('/opt/packages.lock').read_bytes()).hexdigest()
for key in ['memory.max', 'memory.swap.max', 'memory.events']:
    metadata[key] = (Path('/sys/fs/cgroup') / key).read_text()
if metadata['memory.max'].strip() != sys.argv[3] or metadata['memory.swap.max'].strip() != '0':
    raise SystemExit('resource limits were not applied before exec')
record('ready.json', metadata)
deadline = time.monotonic() + 60
while not (scratch / '.go').exists():
    if time.monotonic() >= deadline:
        raise SystemExit('launch barrier timed out')
    time.sleep(.01)
argv = [('/probes/' + name).encode(), b'+RTS', b'--threads', b'1', b'--gpu', b'off', b'-RTS']
argv.extend(base64.b64decode(x, validate=True) for x in json.loads(sys.argv[2]))
preload = os.environ.pop('BEND_PROBE_PRELOAD', None)
if preload is not None:
    if preload != '/probes/fault_inject.so':
        raise SystemExit('unexpected interposer')
    os.environ['LD_PRELOAD'] = preload
as_limit = os.environ.pop('BEND_PROBE_AS_LIMIT', None)
if as_limit is not None:
    resource.setrlimit(resource.RLIMIT_AS, (int(as_limit), int(as_limit)))
os.execv(argv[0], argv)
