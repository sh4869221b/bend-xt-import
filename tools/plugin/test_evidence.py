"""Reject corrupt evidence independently of Docker availability."""
import copy
import tempfile
from pathlib import Path
from integrity import digest,inputs,DIRECTORIES,FILES,invalidate_summary
from validation import require_inventory,validate_identity,validate_binary,check_observation,validate_oracle,contained,claim_run,validate_build

count=0
def rejected(fn):
    global count
    count+=1
    try:fn()
    except (ValueError,AssertionError,RuntimeError,KeyError):return
    raise AssertionError('bad evidence accepted')

def main():
    valid={'complete':True,'inputs':{'a':'b'},'build_sha256':'c','environment_sha256':'d'}
    validate_identity(valid,{'a':'b'},'c','d')
    require_inventory(['a','b'],['a','b'])
    for wrong in [['a'],['a','a'],['a','b','c']]:rejected(lambda:require_inventory(wrong,['a','b']))
    for key,value in [('complete',False),('inputs',{}),('build_sha256','old'),('environment_sha256','old')]:
        changed={**valid,key:value};rejected(lambda:validate_identity(changed,{'a':'b'},'c','d'))
    row={'exit':0,'docker_client_exit':0,'timed_out':False,'external_kill':False,'oom_killed':False,'stderr':'',
         'limits':{'memory.max':'1073741824','memory.swap.max':'0'},'ready':{'uid':1000},
         'native_result':{'exit':0,'signal':None},'events_before':{'oom':0,'oom_kill':0,'max':0},
         'final_cgroup':{'events':{'oom':0,'oom_kill':0,'max':0},'memory_peak':8000000}}
    check_observation(row)
    for key,value in [('exit',1),('docker_client_exit',1),('timed_out',True),('external_kill',True),('oom_killed',True),('stderr','bad'),('native_result',None),('final_cgroup',None)]:
        changed=copy.deepcopy(row);changed[key]=value;rejected(lambda:check_observation(changed))
    for key,value in [('memory.max','max'),('memory.swap.max','1')]:
        changed=copy.deepcopy(row);changed['limits'][key]=value;rejected(lambda:check_observation(changed))
    for value in [0,1073741824]:
        changed=copy.deepcopy(row);changed['final_cgroup']['memory_peak']=value;rejected(lambda:check_observation(changed))
    changed=copy.deepcopy(row);changed['final_cgroup']['events']['max']=1;rejected(lambda:check_observation(changed))
    validate_binary({'probe':'driver','binary_sha256':'fresh'},{'driver':'fresh'})
    rejected(lambda:validate_binary({'probe':'driver','binary_sha256':'old'},{'driver':'fresh'}))
    rejected(lambda:validate_binary({'probe':'missing','binary_sha256':None},{'driver':'fresh'}))
    oracle={'complete':True,'inputs':{'a':'b'},'metadata':{'uid':1000,'memory.max':'1073741824','memory.swap.max':'0','packages_sha256':'p'}}
    validate_oracle(oracle,{'a':'b'},'p')
    for key,value in [('uid',0),('memory.max','max'),('memory.swap.max','1'),('packages_sha256','old')]:
        changed=copy.deepcopy(oracle);changed['metadata'][key]=value;rejected(lambda:validate_oracle(changed,{'a':'b'},'p'))
    with tempfile.TemporaryDirectory() as temporary:
        root=Path(temporary)
        for directory in DIRECTORIES:(root/directory).mkdir(parents=True,exist_ok=True)
        for name in FILES:
            p=root/name;p.parent.mkdir(parents=True,exist_ok=True);p.write_text('fixture')
        assert inputs(root)
        (root/FILES[0]).unlink();rejected(lambda:inputs(root));(root/FILES[0]).write_text('fixture')
        (root/'plugin/linked').symlink_to(root/'hash',target_is_directory=True);rejected(lambda:inputs(root));(root/'plugin/linked').unlink()
        (root/'core').rmdir();(root/'core').symlink_to(root/'hash',target_is_directory=True);rejected(lambda:inputs(root))
        rejected(lambda:contained(root,'../escape.json'))
        seen=set();claim_run(root,'runs/plugin/resource-first/observation.json',{'scratch':'resource-first'},seen)
        claim_run(root,'runs/plugin/resource-second/observation.json',{'scratch':'resource-second'},seen)
        rejected(lambda:claim_run(root,'runs/plugin/resource-first/observation.json',{'scratch':'resource-first'},seen))
        rejected(lambda:claim_run(root,'runs/plugin/resource-second/../resource-first/observation.json',{'scratch':'resource-first'},seen))
        rejected(lambda:claim_run(root,'runs/plugin/resource-third/observation.json',{'scratch':'resource-first'},seen))
        rejected(lambda:claim_run(root,'runs/plugin/resource-first/renamed.json',{'scratch':'resource-first'},set()))
        # A renamed copy of an existing observation cannot prove another run.
        rejected(lambda:claim_run(root,'runs/plugin/duplicate/resource-first/observation.json',{'scratch':'resource-first'},seen))
        source=root/'tests/plugin/probe.bend';source.write_text('def main() -> U32: 0')
        negative=root/'tests/plugin/negative';negative.mkdir()
        for name in ['owner','owner_control']:(negative/(name+'.bend')).write_text('test')
        lock={'build_image':{'packages_sha256':'packages'},'compiler_tree_sha256':'compiler','bun_binary_sha256':'bun'}
        compiler=['/opt/bun/bun-linux-x64-baseline/bun','--no-env-file','/opt/bend/bend2/main.ts']
        probe={'probe':'probe','source_sha256':digest(source),'steps':[{'argv':compiler+['/work/tests/plugin/probe.bend']+flags,'exit':0} for flags in [['--check-only'],['-o','/work/build/plugin/probe.c'],['-o','/work/build/plugin/probe']]]}
        controls=[{'file':name+'.bend','control':name.endswith('_control'),'sha256':digest(negative/(name+'.bend')),'exit':0 if name.endswith('_control') else 1,'diagnostic':'consumed more than once'} for name in ['owner','owner_control']]
        build={'build_complete':True,'provenance':{'packages_sha256':'packages','compiler_tree_sha256':'compiler','bun_binary_sha256':'bun'},'probes':[probe],'ownership_checks':controls}
        validate_build(build,lock,{'probe'},{'owner'},root)
        mutations=[lambda b:b.update(build_complete=False),lambda b:b['provenance'].update(compiler_tree_sha256='old'),
          lambda b:b['probes'][0].update(source_sha256='old'),lambda b:b['probes'][0]['steps'].pop(),
          lambda b:b['probes'][0]['steps'][0].update(exit=1),lambda b:b['probes'][0]['steps'][1].update(argv=compiler+['wrong']),
          lambda b:b['ownership_checks'].pop(),lambda b:b['ownership_checks'][0].update(exit=0),
          lambda b:b['ownership_checks'][0].update(diagnostic='unrelated compiler crash'),lambda b:b['ownership_checks'][0].update(sha256='old'),
          lambda b:b['ownership_checks'][1].update(exit=1)]
        for mutate in mutations:
            changed=copy.deepcopy(build);mutate(changed);rejected(lambda:validate_build(changed,lock,{'probe'},{'owner'},root))
        (root/'build/plugin').mkdir(parents=True);p=root/'build/plugin/summary.json';p.write_text('{"complete":true}')
        invalidate_summary(root);assert 'false' in p.read_text()
    print(count,'parser evidence rejection regressions passed')
if __name__=='__main__':main()
