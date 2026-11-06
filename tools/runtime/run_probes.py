"""Independent expected outcomes for Issue #1's small native experiments."""
import argparse
import errno
import hashlib
import json
from pathlib import Path
import random
import re
import sys

from experiment import ROOT, run_probe
from integrity import inputs, record
from case_spec import expected


def assert_equal(actual, expected):
    if actual != expected:
        raise AssertionError(f'expected {expected!r}, observed {actual!r}')


def byte_line(data):
    return ''.join(str(x) + ',' for x in data) + '\n'


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--group', choices=['all', 'io', 'faults', 'arithmetic'], default='all')
    args = parser.parse_args()
    records = []
    complete = False
    snapshot = inputs(ROOT)
    output_path=ROOT/'runs'/('suite-'+args.group+'.json')
    record(output_path, {'schema':1,'group':args.group,'complete':False,'execution_inputs':snapshot,'cases':[]})

    def case(label, probe, arguments=(), prepare=None, expected=0, output=None,
             inspect=None, fault=None, gap=None, **kwargs):
        directory = None
        try:
            r, directory = run_probe(probe, arguments, prepare, fault=fault, **kwargs)
            assert_equal(r['exit'], expected)
            assert_equal(r['docker_client_exit'], expected)
            assert_equal(r['timed_out'], False)
            assert_equal(r['oom_killed'], False)
            if output is not None:
                assert_equal(r['stdout'], output)
            if fault:
                if len(r['fault_trace'].splitlines()) < 2:
                    raise AssertionError('interposer armed but no injection reached')
                if fault['MODE']=='short':
                    split=int(fault['SPLIT'])
                    first=re.search(r'request call=1 bytes=(\d+)',r['fault_trace'])
                    if not first or int(first[1])<=split or f'short call=1 bytes={split}' not in r['fault_trace'] or 'call=2 ' not in r['fault_trace']:
                        raise AssertionError('requested short IO was not applied and retried')
            if inspect:
                inspect(r, directory)
            record = {'case': label, 'result': 'pass', 'observation': str(directory.relative_to(ROOT) / 'observation.json')}
            if gap:
                record['verified_gap'] = gap
            records.append(record)
            print(label, 'PASS' + (' (capability blocked)' if gap else ''), flush=True)
        except Exception as error:
            records.append({'case': label, 'result': 'fail', 'error': str(error), 'scratch': directory.name if directory else None})
            raise

    try:
        if args.group in ['all', 'io']:
            raw = [b'', b'with space', '日本語'.encode(), b'bad\xff', b'--', b'--threads']
            case('P01-raw-argv', 'argv_exit', raw,
                 output=''.join(byte_line(x) for x in [b'/probes/argv_exit', *raw]))
            for code in [0, 2, 3, 4, 5, 6, 7]:
                case(f'P01-exit-{code}', 'argv_exit', ['exit', code], expected=code, output='')
            case('P01-die', 'argv_exit', ['die'], expected=7)
            for count in [0, 1, 65535, 65536, 65537, 131073]:
                data = bytes(range(256)) * (count // 256) + bytes(range(count % 256))
                def prepare(p, data=data):
                    (p / 'input.bin').write_bytes(data)
                def inspect(r, p, data=data):
                    assert_equal((p / 'output.bin').read_bytes(), data)
                    assert_equal((p / 'input.bin').read_bytes(), data)
                case(f'P02-roundtrip-{count}', 'binary_roundtrip', prepare=prepare,
                     output=str(count) + '\n', inspect=inspect)
                if count in [0, 1, 65536, 65537, 131073]:
                    case(f'P08-chunk-{count}', 'chunk_stream', prepare=prepare,
                         output=str(count) + '\n', inspect=inspect)
            case('P04-exclusive-new', 'exclusive_create', output='created\n',
                 inspect=lambda r,p: assert_equal((p/'output.bin').read_bytes(), bytes([0,17,255,0])))
            case('P04-concurrent-exclusive-create','exclusive_race',output='created\none-created-one-EEXIST\n',
                 inspect=lambda r,p:assert_equal((p/'output.bin').read_bytes(),bytes([0,17,255,0])))
            case('P04-existing-file', 'exclusive_create',
                 prepare=lambda p: (p/'output.bin').write_bytes(b'existing'), expected=errno.EEXIST,
                 inspect=lambda r,p: assert_equal((p/'output.bin').read_bytes(), b'existing'))
            case('P04-existing-dir', 'exclusive_create', prepare=lambda p: (p/'output.bin').mkdir(), expected=errno.EEXIST)
            case('P04-symlink', 'exclusive_create', prepare=lambda p: (p/'output.bin').symlink_to('sentinel.bin'), expected=errno.EEXIST)
            def denied(p):
                (p/'denied.bin').write_bytes(b'private')
                (p/'denied.bin').chmod(0)
            for mode, code, prep in [('missing',errno.ENOENT,None),('denied',errno.EACCES,denied),
                                     ('mode',errno.EINVAL,None),('invalid-byte',errno.EINVAL,None),
                                     ('readonly',errno.EBADF,lambda p:(p/'input.bin').write_bytes(b'input')),
                                     ('full',errno.ENOSPC,None)]:
                case('P05-'+mode,'io_errors',[mode],prepare=prep,expected=code,
                     inspect=(lambda r,p:assert_equal((p/'output.bin').read_bytes(),b'')) if mode=='invalid-byte' else None)
            case('P03-position', 'offsets', ['basic'], prepare=lambda p:(p/'input.bin').write_bytes(b'ABCDEFGH'),
                 output='65,\n0,255,\n66,\n\n',
                 inspect=lambda r,p:assert_equal((p/'input.bin').read_bytes(),b'ABC\x00\xffFGH'))
            def sparse(p, size):
                with (p/'input.bin').open('wb') as f:
                    f.truncate(size)
                    f.seek(size-1)
                    f.write(b'Z')
            case('P03-u32-max-size','offsets',['size'],prepare=lambda p:sparse(p,2**32-1),output=str(2**32-1)+'\n')
            case('P03-u32-last-byte','offsets',['last'],prepare=lambda p:sparse(p,2**32-1),output='90,\n')
            case('P03-over-u32-size','offsets',['size'],prepare=lambda p:sparse(p,2**32),expected=errno.EOVERFLOW)
        if args.group in ['all', 'arithmetic']:
            for index, (arguments, code, output) in enumerate([
                (['range',0,0,0],0,'accepted\n'),(['range',9,1,10],0,'accepted\n'),
                (['range',10,1,10],5,''),(['range',11,0,10],5,''),
                (['range',4294967294,1,4294967295],0,'accepted\n'),
                (['range',4294967295,1,4294967295],5,''),
                (['index',65535,65536,65536],0,'123\n'),(['index',65536,65536,65536],5,''),
                (['index',3,3,65536],5,''),(['index',0,0,65536],5,''),
                (['index',1,65537,65536],5,'')]):
                case(f'P03-P07-guard-{index}','range_guard',arguments,expected=code,output=output)
            values = [x ^ 21930 for x in range(65536)]
            old = values[12]
            values[12] = 99
            case('P07-affine-array','affine_arrays',output=f'{old}\n{21930}\n{sum(values) & 0xffffffff}\n')
            rng = random.Random(12026)
            vectors = [(0,0,0),(0xffffffff,1,31),(0x80000000,0xffffffff,32),(0x12345678,0xabcdef01,1)]
            vectors += [(rng.randrange(2**32),rng.randrange(2**32),rng.choice([0,1,7,16,31,32])) for _ in range(8)]
            for i,(a,b,n) in enumerate(vectors):
                mask=2**32-1; lo=(a+b)&mask
                rotate=((a>>n)|(a<<(32-n)))&mask
                fields=[lo,a^b,a&b,a|b,(~a)&mask,a>>n,(a<<n)&mask,rotate,
                        a>>24,(a>>16)&255,(a>>8)&255,a&255,a,int(lo<a),(b<<3)&mask,b>>29]
                output=byte_line(fields)+str(sum(a^(j*j) for j in range(16))&mask)+'\n'+str(sum(b^(j*j) for j in range(64))&mask)+'\n'
                case(f'P09-sha-primitives-{i}','sha_primitives',[a,b,n],output=output)
        if args.group in ['all', 'faults']:
            source=bytes(range(64))
            for op in ['read','pread','write','pwrite']:
                is_read=op in ['read','pread']
                prepare=(lambda p:(p/'input.bin').write_bytes(source)) if is_read else None
                expected_output=byte_line(source) if is_read else 'complete\n'
                modes=[('eintr',0),('error',errno.EIO),('partial-error',0 if is_read else errno.EIO),('zero',0 if is_read else errno.EIO)]
                for split in [1,7,4095]:
                    large = split == 4095
                    data = bytes(range(256))*32 if large else source
                    command = op + '-long' if large and not is_read else op
                    written = bytes(8192) if large else bytes([0,1,2,3,4,255,0,33])
                    case(f'P06-{op}-short-{split}','short_io',[command],
                         prepare=(lambda p,data=data:(p/'input.bin').write_bytes(data)) if is_read else None,
                         output=byte_line(data) if is_read else 'complete\n',
                         fault={'OP':op,'MODE':'short','SPLIT':split},
                         inspect=None if is_read else lambda r,p,written=written:assert_equal((p/'output.bin').read_bytes(),written))
                for mode,code in modes:
                    output=None
                    gap=None
                    if is_read and mode=='partial-error':
                        output=byte_line(source[:7]);gap='partial-read-error-is-not-propagated'
                    elif is_read and mode=='zero':output='\n'
                    elif mode=='eintr':output=expected_output
                    case(f'P06-{op}-{mode}','short_io',[op],prepare=prepare,expected=code,output=output,
                         fault={'OP':op,'MODE':mode},gap=gap,
                         inspect=(lambda r,p:assert_equal((p/'output.bin').read_bytes(),bytes([0,1,2,3,4,255,0,33]))) if not is_read and mode=='eintr' else None)
                if not is_read:
                    case(f'P06-{op}-enospc','short_io',[op],expected=errno.ENOSPC,
                         fault={'OP':op,'MODE':'enospc'},
                         inspect=lambda r,p:assert_equal((p/'output.bin').read_bytes(),bytes([0,1,2,3,4,255,0])))
            case('P06-transient-error-followed-by-success','short_io',['read-twice'],
                 prepare=lambda p:(p/'input.bin').write_bytes(source),
                 output=byte_line(source[:7])+byte_line(source[7:]),
                 fault={'OP':'read','MODE':'transient-error'},gap='transient-read-error-lost-even-when-final-bytes-complete')
            case('P06-realloc-failure','short_io',['write-long'],expected=1,
                 fault={'OP':'realloc','MODE':'error'},
                 inspect=lambda r,p:assert_equal('host allocation failed' in r['stderr'],True))
            case('P06-close-error','short_io',['write'],output='complete\n',
                 fault={'OP':'close','MODE':'error'},gap='checked-close-unavailable')
            case('P06-malloc-failure','short_io',['read'],prepare=lambda p:(p/'input.bin').write_bytes(source),
                 expected=1,fault={'OP':'malloc','MODE':'error'},
                 inspect=lambda r,p:assert_equal('host allocation failed' in r['stderr'],True))
        if [c['case'] for c in records]!=expected('api',args.group) or inputs(ROOT)!=snapshot:
            raise RuntimeError('suite identity or source snapshot changed')
        complete=True
    finally:
        (ROOT/'runs').mkdir(exist_ok=True)
        record(output_path,{'schema':1,'group':args.group,'complete':complete,'execution_inputs':snapshot,'cases':records})
    print(f'{len(records)} cases passed; known gaps are not capability passes',flush=True)


if __name__ == '__main__':
    main()
