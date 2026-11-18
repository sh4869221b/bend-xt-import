"""Bounded native resource experiments; an expected OOM is never a capability pass."""
import argparse
import hashlib
import platform
from experiment import ROOT, run_probe
from fault_trace import check_fault_trace
from integrity import digest, inputs, observation_reference, record
from case_spec import expected
from termination import assert_equal, check_termination


def summarize(r):
    native = [s for s in r['samples'] if s['native_process']]
    def peak(key):
        return max((value for s in native if (value := s.get(key)) is not None), default=None)
    result = {key: peak(key) for key in ['VmRSS_bytes', 'VmHWM_bytes', 'VmSize_bytes', 'memory_current', 'memory_peak']}
    result['ru_maxrss_bytes'] = (r.get('native_result') or {}).get('maxrss_bytes')
    return result


def check_result(row, directory, expected, output, check, *, termination='exit', fault=None):
    check_termination(row, expected, termination)
    if output is not None:
        assert_equal(row['stdout'], output)
    if fault:
        check_fault_trace(row['fault_trace'], fault)
    if check:
        check(row, directory)


STREAM_BLOCK = bytes(range(256)) * 256


def stream_digest(size):
    digest = hashlib.sha256()
    for _ in range(size // len(STREAM_BLOCK)):
        digest.update(STREAM_BLOCK)
    return digest.hexdigest()


def check_stream(directory, size, expected_digest):
    for name in ('input.bin', 'output.bin'):
        path = directory / name
        if path.stat().st_size != size:
            raise AssertionError(f'{name}: expected stream size {size}')
        if digest(path) != expected_digest:
            raise AssertionError(f'{name}: stream digest differs from recipe')


def run_cases(group, case):
    if group in ['all','budget']:
        names=['reserve-exact','reserve-over','reserve-invalid-used','reserve-wrap','reserve-max-exact',
               'release-exact','release-underflow','multiply-exact','multiply-over','multiply-wrap',
               'multiply-zero','work-exact-synthetic','work-over-synthetic']
        case('P10-selftest','budget_work',['selftest'],output=''.join(n+'\n' for n in names))
        for label,arguments,code,output in [
            ('reserve',['reserve',268435456,268435455,1],0,'268435456\n'),
            ('over',['reserve',268435456,268435456,1],5,''),
            ('multiply-wrap',['multiply',4294967295,65536,65536],5,''),
            ('release-underflow',['release',0,1],5,''),
            ('allocation',['allocation',4,4,2],0,'reserved=4\nallocated-checksum=4096\n0\n'*2+'complete\n'),
            ('allocation-reject',['allocation',3,4,2],5,''),
            ('work',['work',3,4,12],0,'remaining=0\nchecksum=18\n'),
            ('work-exhausted',['work',3,4,11],5,''),
            ('work-many',['work',17,65536,17*65536],0,'remaining=0\nchecksum='+str(17*sum(range(256))*256)+'\n'),
            ('work-many-exhausted',['work',17,65536,17*65536-1],5,'')]:
            case('P10-'+label,'budget_work',arguments,expected=code,output=output)
    if group in ['all','shapes']:
        markers={1:'array-u32',2:'list-u32',3:'index-array',4:'string',5:'string',6:'string',7:'input-list+array+output-list'}
        for mode in range(8):
            for depth in ([8] if mode==0 else [8,16,20]):
                n=2**depth; values=32640*(n//256)
                checksum=0 if mode==0 else (values if mode in [1,2] else (n*(n-1)//2+values+n if mode==3 else (3*values if mode==7 else n)))
                expected_stdout=(('live='+markers[mode]+'\n') if mode else '')+'released-checksum='+str(checksum&0xffffffff)+'\n'
                for rep in range(3):
                    case(f'M-shape-{mode}-{depth}-{rep}','memory_shapes',[mode,depth,3,100],output=expected_stdout*3+'complete\n',timeout=120)
    if group in ['all','stress']:
        n=2**24;checksum=(32640*(n//256))&0xffffffff
        case('M-charge-256MiB','charged_array',[24,268435456,3],timeout=120,
             output=f'reserved=268435456\nlive=array-u32\nchecksum={checksum}\nreleased=0\n'*3+'complete\n')
        case('M-charge-one-over','charged_array',[24,268435455,1],expected=5,output='')
        def incomplete(r,p):
            assert_equal('complete' in r['stdout'],False)
        case('M-oom-small','memory_pressure',[512,20,0],memory=134217728,expected=137,termination='oom',check=incomplete,timeout=120)
        case('M-oom-1GiB','memory_pressure',[512,22,0],expected=137,termination='oom',check=incomplete,timeout=240)
        for signal_name,code in [('SIGTERM',143),('SIGKILL',137)]:
            case('M-'+signal_name,'memory_pressure',[100,18,100],expected=code,kill_after=.5,
                 kill_signal=signal_name,termination=signal_name,check=incomplete)
        case('M-timeout','memory_pressure',[100,18,100],expected=137,timeout=.5,termination='timeout',check=incomplete)
        def as_failed(r,p):
            if not r['stderr']: raise AssertionError('missing mapping failure diagnostic')
        case('M-AS-is-not-RSS','memory_shapes',[0,8,1,100],expected=1,rlimit_as=1073741824,check=as_failed)
        for op,signal_name,code,deadline in [('read','SIGTERM',143,False),('write','SIGKILL',137,False),('write','SIGKILL',137,True)]:
            def stopped_io(r,p):
                incomplete(r,p)
                if op=='write': assert_equal((p/'output.bin').read_bytes(),bytes([0,1,2,3,4,255,0]))
                else: assert_equal((p/'input.bin').read_bytes(),bytes(range(64)))
            termination='timeout' if deadline else signal_name
            case('M-IO-'+op+'-'+termination,'short_io',[op],expected=code,termination=termination,
                 prepare=(lambda p:(p/'input.bin').write_bytes(bytes(range(64)))) if op=='read' else None,
                 fault={'OP':op,'MODE':'stall'},kill_signal=signal_name,kill_after=None if deadline else .5,
                 timeout=.5 if deadline else 45,check=stopped_io)
        # Raw 256MiB index payload; this deliberately bypasses a live guard to measure feasibility.
        n=2**24;checksum=(n*(n-1)//2+32640*(n//256)+n)&0xffffffff
        case('M-index-256MiB-raw','memory_shapes',[3,24,1,250],timeout=240,
             output=f'live=index-array\nreleased-checksum={checksum}\ncomplete\n')
    if group in ['all','stream']:
        for size in [1048576,16777216,67108864]:
            expected_digest = stream_digest(size)
            def prepare(p):
                with (p/'input.bin').open('wb') as f:
                    for _ in range(size // len(STREAM_BLOCK)):
                        f.write(STREAM_BLOCK)
            def inspect(r,p):
                check_stream(p, size, expected_digest)
            for rep in range(3):
                case(f'M-stream-{size}-{rep}','chunk_stream',prepare=prepare,output=str(size)+'\n',check=inspect,timeout=240)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--group', choices=['all','budget','shapes','stress','stream'], default='all')
    args = parser.parse_args()
    records=[]
    complete=False
    snapshot=inputs(ROOT)
    output_path=ROOT/'runs'/('measure-'+args.group+'.json')
    record(output_path, {'schema':1,'group':args.group,'complete':False,'execution_inputs':snapshot,'cases':[]})
    def case(label, probe, arguments=(), prepare=None, expected=0, output=None, check=None,
             termination='exit', fault=None, **kwargs):
        try:
            row, directory = run_probe(probe, arguments, prepare, case=label, fault=fault, **kwargs)
            check_result(row, directory, expected, output, check, termination=termination, fault=fault)
            metrics = summarize(row)
            records.append({'case': label, 'result': 'pass', 'metrics': metrics,
                            **observation_reference(ROOT, directory)})
            print(label, 'PASS', metrics, flush=True)
        except Exception as error:
            records.append({'case':label,'result':'fail','error':str(error)})
            raise
    try:
        run_cases(args.group, case)
        if [c['case'] for c in records]!=expected('resource',args.group) or inputs(ROOT)!=snapshot:
            raise RuntimeError('suite identity or source snapshot changed')
        complete=True
    finally:
        (ROOT/'runs').mkdir(exist_ok=True)
        record(output_path,{'schema':1,'group':args.group,'complete':complete,'execution_inputs':snapshot,'kernel':platform.release(),
            'machine':platform.machine(),'cases':records})
    print(len(records),'resource cases passed',flush=True)

if __name__=='__main__': main()
