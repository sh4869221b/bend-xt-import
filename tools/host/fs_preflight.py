"""Capability availability only; not host acceptance or transaction qualification."""
import argparse
import ctypes
import errno
import hashlib
import json
import os
from pathlib import Path
import platform
import stat
import struct
import subprocess
import sys


def require(condition, message):
    if not condition:
        raise RuntimeError(message)


def metadata(path):
    value = path.lstat()
    return {name: getattr(value, 'st_' + name) for name in
            ('dev', 'ino', 'mode', 'uid', 'gid', 'nlink', 'size', 'atime_ns', 'mtime_ns', 'ctime_ns')}


def identity(value):
    return {key: value[key] for key in ('dev', 'ino', 'mode', 'uid', 'gid', 'nlink')}


def snapshot(path):
    data = (path/'marker').read_bytes()
    return {'directory': metadata(path), 'file': metadata(path/'marker'),
            'bytes_hex': data.hex(), 'sha256': hashlib.sha256(data).hexdigest()}


def unchanged(before, after):
    # Reading our markers may update atime; record it but do not mistake our read
    # for namespace or content mutation.
    for key in ('directory', 'file'):
        require({k:v for k,v in before[key].items() if k != 'atime_ns'} ==
                {k:v for k,v in after[key].items() if k != 'atime_ns'}, key + ' metadata changed')
    require(before['bytes_hex'] == after['bytes_hex'], 'foreign bytes changed')


def mount(path):
    command = ['findmnt', '--json', '--target', str(path), '--output', 'FSTYPE,SOURCE,TARGET,OPTIONS']
    run = subprocess.run(command, text=True, capture_output=True, timeout=10)
    require(run.returncode == 0, 'findmnt failed: ' + run.stderr)
    rows = json.loads(run.stdout).get('filesystems', [])
    require(len(rows) == 1, 'ambiguous mount identity')
    return {'argv': command, 'exit': run.returncode, 'filesystem': rows[0]}


def absent_acl(path, key):
    try:
        os.getxattr(path, key)
    except OSError as error:
        require(error.errno == errno.ENODATA, key + ' absence did not report ENODATA')
        return error.errno
    raise RuntimeError(key + ' unexpectedly present')


def check(args, record):
    require(platform.system() == 'Linux' and platform.machine() == 'x86_64', 'requires Linux x86_64')
    require(os.geteuid() == 1000 and os.getegid() == 1000 and os.getgroups() == [], 'runtime credentials were not reduced')
    fields = dict(line.split(':', 1) for line in Path('/proc/self/status').read_text().splitlines() if ':' in line)
    record['runtime'] = {'uid': os.geteuid(), 'gid': os.getegid(), 'groups': os.getgroups(),
        'status': {key: fields[key].strip() for key in ('Uid','Gid','Groups','CapEff','CapPrm','CapInh','CapAmb','CapBnd','NoNewPrivs')},
        'kernel': platform.release(), 'machine': platform.machine(), 'python': platform.python_version()}
    require(all(int(fields[key].strip(), 16) == 0 for key in ('CapEff','CapPrm','CapInh','CapAmb')) and
            fields['NoNewPrivs'].strip() == '1', 'capabilities or no_new_privs differ')
    fixture = args.fixture.absolute()
    require(fixture.parent == Path('/var/lib') and fixture.name.startswith('bend-host-capability-') and
            fixture.resolve(strict=True) == fixture, 'unexpected fixture path')
    require(args.report.absolute().parent == fixture and not args.report.exists(), 'report must be a new fixture file')
    for ancestor in (Path('/'), Path('/var'), Path('/var/lib')):
        value = metadata(ancestor)
        record.setdefault('ancestors', {})[str(ancestor)] = value
        require(stat.S_ISDIR(value['mode']) and value['uid'] == 0 and value['mode'] & 0o022 == 0,
                'fixture ancestor is not root-owned and protected: ' + str(ancestor))
    record['fixture_before'] = metadata(fixture)
    require(stat.S_ISDIR(record['fixture_before']['mode']) and
            record['fixture_before']['uid'] == record['fixture_before']['gid'] == 1000 and
            stat.S_IMODE(record['fixture_before']['mode']) == 0o700 and not list(fixture.iterdir()),
            'fixture is not a fresh private directory owned by the reduced runtime')
    record['fixture_validated'] = True
    checkout = args.checkout.resolve(strict=True)
    record['checkout'] = {'path': str(checkout), 'metadata': metadata(checkout), 'mount': mount(checkout)}
    record['fixture_mount'] = mount(fixture)
    record['same_checkout_filesystem'] = checkout.stat().st_dev == fixture.stat().st_dev
    require(record['same_checkout_filesystem'], 'checkout and planned fixture binds are on different filesystems')
    for observation in (record['checkout']['mount'], record['fixture_mount']):
        require(observation['filesystem']['fstype'] == 'ext4', 'actual mount FSTYPE is not ext4')
    git = subprocess.run(['git','-c','safe.directory='+str(checkout),'-C',str(checkout),'rev-parse','HEAD'],
                         capture_output=True, text=True, timeout=10)
    require(git.returncode == 0 and git.stdout.strip() == args.expected_head, 'checkout head differs from workflow head')
    record['git_head'] = git.stdout.strip()

    acl_dir = fixture/'acl'
    acl_dir.mkdir(mode=0o700)
    acl = struct.pack('<I', 2) + b''.join(struct.pack('<HHI', *item) for item in
        [(1,7,0xffffffff),(2,0,1002),(4,0,0xffffffff),(16,0,0xffffffff),(32,0,0xffffffff)])
    record['acl'] = {}
    for kind in ('access','default'):
        key = 'system.posix_acl_' + kind
        row = {'before':metadata(acl_dir), 'initial_absence_errno':absent_acl(acl_dir, key),
               'written_hex':acl.hex()}
        record['acl'][kind] = row
        os.setxattr(acl_dir, key, acl, flags=os.XATTR_CREATE)
        row['read_hex'] = os.getxattr(acl_dir, key).hex()
        require(row['read_hex'] == row['written_hex'], 'ACL round trip mismatch')
        os.removexattr(acl_dir, key)
        row['removed_absence_errno'] = absent_acl(acl_dir, key)
        row['after'] = metadata(acl_dir)
        row['passed'] = True

    left, right = fixture/'left', fixture/'right'
    left.mkdir(mode=0o700); right.mkdir(mode=0o700)
    source, winner = left/'source', right/'destination'
    for path, data in ((source,b'owned source directory bytes'),(winner,b'foreign winner directory bytes')):
        path.mkdir(mode=0o700)
        with (path/'marker').open('xb') as stream:
            stream.write(data); stream.flush(); os.fsync(stream.fileno())
        (path/'marker').chmod(0o600)
    flags = os.O_RDONLY | os.O_DIRECTORY | os.O_CLOEXEC | os.O_NOFOLLOW
    fds = []
    try:
        for path in (fixture,left,right):
            fd = os.open(path, flags); fds.append(fd)
            require(os.fstat(fd).st_dev == fixture.stat().st_dev, 'held parent filesystem differs')
            os.fsync(fd)
        record['held_directory_fsync_before'] = True
        record['source_before'] = snapshot(source)
        record['winner_before'] = snapshot(winner)
        libc = ctypes.CDLL(None, use_errno=True)
        rename = libc.renameat2
        rename.argtypes = [ctypes.c_int,ctypes.c_char_p,ctypes.c_int,ctypes.c_char_p,ctypes.c_uint]
        rename.restype = ctypes.c_int
        ctypes.set_errno(0)
        status = rename(fds[1],b'source',fds[2],b'destination',1)
        record['collision'] = {'return':status, 'errno':ctypes.get_errno()}
        require(status == -1 and record['collision']['errno'] == errno.EEXIST, 'directory no-replace collision failed')
        record['source_after_collision'] = snapshot(source)
        record['winner_after_collision'] = snapshot(winner)
        unchanged(record['source_before'],record['source_after_collision'])
        unchanged(record['winner_before'],record['winner_after_collision'])
        ctypes.set_errno(0)
        status = rename(fds[1],b'source',fds[2],b'moved',1)
        record['success'] = {'return':status, 'errno':ctypes.get_errno()}
        require(status == 0, 'directory no-replace transfer failed')
        try:
            os.stat('source',dir_fd=fds[1],follow_symlinks=False)
        except FileNotFoundError as error:
            record['old_name_absence_errno'] = error.errno
        else: raise RuntimeError('old directory name remains after rename')
        record['moved'] = snapshot(right/'moved')
        require(identity(record['moved']['directory']) == identity(record['source_before']['directory']) and
                identity(record['moved']['file']) == identity(record['source_before']['file']) and
                record['moved']['bytes_hex'] == record['source_before']['bytes_hex'], 'moved directory identity/bytes differ')
        record['winner_after_success'] = snapshot(winner)
        unchanged(record['winner_before'],record['winner_after_success'])
        for fd in fds: os.fsync(fd)
        record['held_directory_fsync_after'] = True
    finally:
        for fd in reversed(fds): os.close(fd)
    record['fixture_after'] = metadata(fixture)
    record['capability_available'] = True


def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('--fixture',type=Path,required=True)
    parser.add_argument('--checkout',type=Path,required=True)
    parser.add_argument('--report',type=Path,required=True)
    parser.add_argument('--expected-head',required=True)
    args=parser.parse_args()
    record={'schema':1,'purpose':'standalone filesystem capability availability only',
        'capability_available':False,'full_host_qualification':False,'transactional_apply_enabled':False,
        'script_sha256':hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),'expected_head':args.expected_head}
    code=1
    try:
        check(args,record); code=0
    except Exception as error:
        record['error']={'type':type(error).__name__,'message':str(error),'errno':getattr(error,'errno',None)}
    finally:
        payload=json.dumps(record,indent=2)+'\n'
        print(payload,flush=True)
        # The only writable report destination is inside the explicitly owned fixture.
        if record.get('fixture_validated') is True and args.report.absolute().parent == args.fixture.absolute() and not args.report.exists():
            try:
                with args.report.open('x') as stream: stream.write(payload)
            except OSError as error:
                print('report write failed: '+str(error),file=sys.stderr); code=1
    raise SystemExit(code)


if __name__=='__main__': main()
