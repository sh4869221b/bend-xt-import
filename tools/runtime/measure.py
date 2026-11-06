"""Bounded native resource experiments; an expected OOM is never a capability pass."""
import argparse
import json
import platform
import statistics
import time
from experiment import ROOT, run_probe
from integrity import inputs, record
from case_spec import expected
from run_probes import assert_equal


def summarize(r):
    native = [s for s in r['samples'] if s['native_process']]
    def peak(key):
        return max((s.get(key, 0) for s in native), default=None)
    result = {key: peak(key) for key in ['VmRSS_bytes', 'VmHWM_bytes', 'VmSize_bytes', 'memory_current', 'memory_peak']}
    result['ru_maxrss_bytes'] = (r.get('native_result') or {}).get('maxrss_bytes')
    return result


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--group', choices=['all','budget','shapes','stress','stream'], default='all')
    args = parser.parse_args()
    records=[]
    complete=False
    snapshot=inputs(ROOT)
    output_path=ROOT/'runs'/('measure-'+args.group+'.json')
    record(output_path, {'schema':1,'group':args.group,'complete':False,'execution_inputs':snapshot,'cases':[]})
    def case(label, probe, arguments=(), expected=0, output=None, check=None, **kwargs):
        try:
            r,p=run_probe(probe, arguments, **kwargs)
            assert_equal(r['exit'], expected)
            if output is not None: assert_equal(r['stdout'], output)
            if check: check(r,p)
            elif r['timed_out'] or r['oom_killed'] or r['external_kill']: raise AssertionError('unexpected termination')
            records.append({'case':label,'result':'pass','metrics':summarize(r),
                            'observation':str(p.relative_to(ROOT)/'observation.json')})
            print(label,'PASS',summarize(r),flush=True)
            return r,p
        except Exception as error:
            records.append({'case':label,'result':'fail','error':str(error)})
            raise
    try:
        if args.group in ['all','budget']:
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
        if args.group in ['all','shapes']:
            markers={1:'array-u32',2:'list-u32',3:'index-array',4:'string',5:'string',6:'string',7:'input-list+array+output-list'}
            for mode in range(8):
                for depth in ([8] if mode==0 else [8,16,20]):
                    n=2**depth; values=32640*(n//256)
                    checksum=0 if mode==0 else (values if mode in [1,2] else (n*(n-1)//2+values+n if mode==3 else (3*values if mode==7 else n)))
                    expected_stdout=(('live='+markers[mode]+'\n') if mode else '')+'released-checksum='+str(checksum&0xffffffff)+'\n'
                    for rep in range(3):
                        case(f'M-shape-{mode}-{depth}-{rep}','memory_shapes',[mode,depth,3,100],output=expected_stdout*3+'complete\n',timeout=120)
        if args.group in ['all','stress']:
            n=2**24;checksum=(32640*(n//256))&0xffffffff
            case('M-charge-256MiB','charged_array',[24,268435456,3],timeout=120,
                 output=f'reserved=268435456\nlive=array-u32\nchecksum={checksum}\nreleased=0\n'*3+'complete\n')
            case('M-charge-one-over','charged_array',[24,268435455,1],expected=5,output='')
            def oom(r,p):
                assert_equal(r['oom_killed'],True)
                assert_equal(r['external_kill'],False)
                assert_equal('complete' in r['stdout'],False)
                observed=max((s['events'].get('oom_kill',0) for s in r['samples']),default=0)
                observed=max(observed,(r.get('final_cgroup') or {}).get('events',{}).get('oom_kill',0))
                if observed <= r['events_before'].get('oom_kill',0):
                    raise AssertionError('OOM kill counter was not captured; cannot certify this run')
            case('M-oom-small','memory_pressure',[512,20,0],memory=134217728,expected=137,check=oom,timeout=120)
            case('M-oom-1GiB','memory_pressure',[512,22,0],expected=137,check=oom,timeout=240)
            for signal,code in [('SIGTERM',143),('SIGKILL',137)]:
                def killed(r,p):
                    assert_equal(r['external_kill'],True);assert_equal(r['oom_killed'],False)
                    assert_equal(r['timed_out'],False);assert_equal('complete' in r['stdout'],False)
                case('M-'+signal,'memory_pressure',[100,18,100],expected=code,kill_after=.5,kill_signal=signal,check=killed)
            def timeout_check(r,p):
                assert_equal(r['timed_out'],True);assert_equal(r['oom_killed'],False)
            case('M-timeout','memory_pressure',[100,18,100],expected=137,timeout=.5,check=timeout_check)
            def as_failed(r,p):
                assert_equal(r['oom_killed'],False)
                if not r['stderr']: raise AssertionError('missing mapping failure diagnostic')
            case('M-AS-is-not-RSS','memory_shapes',[0,8,1,100],expected=1,rlimit_as=1073741824,check=as_failed)
            for op,signal,code,deadline in [('read','SIGTERM',143,False),('write','SIGKILL',137,False),('write','SIGKILL',137,True)]:
                def stopped_io(r,p):
                    assert_equal(r['external_kill'],True);assert_equal(r['oom_killed'],False)
                    assert_equal(r['timed_out'],deadline)
                    assert_equal('stall' in r['fault_trace'],True)
                    assert_equal('complete' in r['stdout'],False)
                    if op=='write': assert_equal((p/'output.bin').read_bytes(),bytes([0,1,2,3,4,255,0]))
                    else: assert_equal((p/'input.bin').read_bytes(),bytes(range(64)))
                case('M-IO-'+op+'-'+('timeout' if deadline else signal),'short_io',[op],expected=code,
                     prepare=(lambda p:(p/'input.bin').write_bytes(bytes(range(64)))) if op=='read' else None,
                     fault={'OP':op,'MODE':'stall'},kill_signal=signal,kill_after=None if deadline else .5,
                     timeout=.5 if deadline else 45,check=stopped_io)
            # Raw 256MiB index payload; this deliberately bypasses a live guard to measure feasibility.
            n=2**24;checksum=(n*(n-1)//2+32640*(n//256)+n)&0xffffffff
            case('M-index-256MiB-raw','memory_shapes',[3,24,1,250],timeout=240,
                 output=f'live=index-array\nreleased-checksum={checksum}\ncomplete\n')
        if args.group in ['all','stream']:
            for size in [1048576,16777216,67108864]:
                for rep in range(3):
                    def prepare(p):
                        with (p/'input.bin').open('wb') as f:
                            block=bytes(range(256))*256
                            for _ in range(size//len(block)): f.write(block)
                    def inspect(r,p):
                        import hashlib
                        def digest(path):
                            h=hashlib.sha256()
                            with path.open('rb') as f:
                                while chunk:=f.read(65536):h.update(chunk)
                            return h.digest()
                        assert_equal(digest(p/'input.bin'),digest(p/'output.bin'))
                    case(f'M-stream-{size}-{rep}','chunk_stream',prepare=prepare,output=str(size)+'\n',check=inspect,timeout=240)
        if [c['case'] for c in records]!=expected('resource',args.group) or inputs(ROOT)!=snapshot:
            raise RuntimeError('suite identity or source snapshot changed')
        complete=True
    finally:
        (ROOT/'runs').mkdir(exist_ok=True)
        record(output_path,{'schema':1,'group':args.group,'complete':complete,'execution_inputs':snapshot,'kernel':platform.release(),
            'machine':platform.machine(),'cases':records})
    print(len(records),'resource cases passed',flush=True)

if __name__=='__main__': main()
