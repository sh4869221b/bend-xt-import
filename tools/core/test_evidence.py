"""Regression checks for evidence rejection; these do not emulate OS acceptance."""
import copy
import tempfile
from pathlib import Path
from integrity import inputs, FILES, DIRECTORIES, invalidate_summary
from summarize import require_inventory, validate_identity, validate_binary, validate_oracle
from checks import check_observation, memory_expectation, verify_output


COUNT = 0

def rejected(fn):
    global COUNT
    COUNT += 1
    try: fn()
    except (ValueError,AssertionError,KeyError,RuntimeError): return
    raise AssertionError('invalid evidence accepted')


def main():
    valid={'complete':True,'inputs':{'x':'a'},'build_sha256':'b','environment_sha256':'e'}
    validate_identity(valid,{'x':'a'},'b','e')
    require_inventory(['a','b'],['a','b'])
    rejected(lambda:require_inventory(['a'],['a','b']))
    rejected(lambda:require_inventory(['a','a'],['a','b']))
    rejected(lambda:require_inventory(['a','b','c'],['a','b']))
    for field,value in [('complete',False),('inputs',{'x':'changed'}),('build_sha256','old'),('environment_sha256','old')]:
        changed=copy.deepcopy(valid);changed[field]=value
        rejected(lambda:validate_identity(changed,{'x':'a'},'b','e'))
    row={'exit':0,'docker_client_exit':0,'timed_out':False,'external_kill':False,'oom_killed':False,'stderr':'',
         'limits':{'memory.max':'1073741824','memory.swap.max':'0'},'ready':{'uid':1000},
         'native_result':{'exit':0,'signal':None},'events_before':{'oom':0,'oom_kill':0,'max':0},
         'final_cgroup':{'events':{'oom':0,'oom_kill':0,'max':0},'memory_peak':8000000}}
    check_observation(row)
    for field,value in [('exit',1),('docker_client_exit',1),('timed_out',True),('external_kill',True),('oom_killed',True),('stderr','bad'),('native_result',None),('final_cgroup',None)]:
        changed=copy.deepcopy(row);changed[field]=value
        rejected(lambda:check_observation(changed))
    for limits in [{'memory.max':'max','memory.swap.max':'0'},{'memory.max':'1073741824','memory.swap.max':'1073741824'}]:
        changed=copy.deepcopy(row);changed['limits']=limits
        rejected(lambda:check_observation(changed))
    changed=copy.deepcopy(row);changed['final_cgroup']['events']['oom_kill']=1
    rejected(lambda:check_observation(changed))
    changed=copy.deepcopy(row);changed['final_cgroup']['memory_peak']=1073741824
    rejected(lambda:check_observation(changed))
    verify_output('memory',['3','3','3'],memory_expectation(3,3,3)[0])
    rejected(lambda:verify_output('memory',['3','3','3'],'balanced\n'))
    rejected(lambda:verify_output('sha',['97','1','1'],'done\n'))
    validate_binary({'probe':'sha','binary_sha256':'fresh'},{'sha':'fresh'})
    rejected(lambda:validate_binary({'probe':'sha','binary_sha256':'stale'},{'sha':'fresh'}))
    rejected(lambda:validate_binary({'probe':'absent','binary_sha256':None},{'sha':'fresh'}))
    oracle={'complete':True,'inputs':{'x':'a'},'metadata':{'uid':1000,'memory.max':'1073741824','memory.swap.max':'0','packages_sha256':'p'},'commands':[{'argv':['codec_oracle.py'],'exit':0,'stderr':''},{'argv':['sha_oracle.py'],'exit':0,'stderr':''}]}
    validate_oracle(oracle,{'x':'a'},'p')
    for field,value in [('uid',0),('memory.max','max'),('memory.swap.max','1'),('packages_sha256','old')]:
        changed=copy.deepcopy(oracle);changed['metadata'][field]=value
        rejected(lambda:validate_oracle(changed,{'x':'a'},'p'))
    changed=copy.deepcopy(oracle);changed['commands'][1]['exit']=1
    rejected(lambda:validate_oracle(changed,{'x':'a'},'p'))
    changed=copy.deepcopy(oracle);changed['commands'].pop()
    rejected(lambda:validate_oracle(changed,{'x':'a'},'p'))
    with tempfile.TemporaryDirectory() as temporary:
        root=Path(temporary)
        for directory in DIRECTORIES: (root/directory).mkdir(parents=True,exist_ok=True)
        for name in FILES:
            path=root/name;path.parent.mkdir(parents=True,exist_ok=True);path.write_text('fixture')
        snapshot=inputs(root)
        path=root/FILES[0];path.unlink()
        rejected(lambda:inputs(root))
        path.write_text('fixture')
        path=root/'core';path.rmdir();path.symlink_to(root/'hash',target_is_directory=True)
        rejected(lambda:inputs(root))
        path.unlink();path.mkdir()
        assert inputs(root)==snapshot
        target=root/'build/core/summary.json';target.parent.mkdir(parents=True);target.write_text('{"complete":true}')
        invalidate_summary(root)
        assert '"complete":false' in target.read_text()
    print(f'{COUNT} evidence rejection regressions and 8 positive controls passed')

if __name__ == '__main__': main()
