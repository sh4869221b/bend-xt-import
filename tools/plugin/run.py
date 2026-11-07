"""Complete parser native contracts plus the independent fixture oracle."""
import json
import os
from pathlib import Path
import tempfile
from experiment import ROOT,docker,run_probe,verified_build
from integrity import invalidate_summary,inputs,digest
from case_spec import functional_cases,key
from checks import verify_output
from validation import check_observation

def oracle_container():
    directory=Path(tempfile.mkdtemp(prefix='oracle-',dir=ROOT/'runs/plugin'))
    name='bend-plugin-'+directory.name;cid=None
    try:
        cid=docker('create','--name',name,'--network','none','--read-only','--cap-drop','ALL',
                   '--security-opt','no-new-privileges','--user',f'{os.getuid()}:{os.getgid()}',
                   '--memory','1073741824','--memory-swap','1073741824','--cpus','1','--pids-limit','64',
                   '--mount',f'type=bind,src={ROOT},dst=/work,readonly',
                   '--mount',f'type=bind,src={directory},dst=/reports',
                   '--env','PLUGIN_REPORT_DIR=/reports',
                   'bend-xt-probe:issue1','python3','/work/tools/plugin/oracle.py').stdout.decode().strip()
        info=json.loads(docker('inspect',cid).stdout)[0]
        environment=json.loads((ROOT/'build/plugin/environment.json').read_text())
        if info['Image']!=environment['images'][1]['id']:raise RuntimeError('oracle image identity differs')
        p=docker('start','-a',cid,timeout=900)
        info=json.loads(docker('inspect',cid).stdout)[0]
        (directory/'stdout.log').write_bytes(p.stdout);(directory/'stderr.log').write_bytes(p.stderr)
        if info['State']['ExitCode']!=0 or info['State']['OOMKilled'] or p.stderr:raise RuntimeError('oracle container failed')
        data=json.loads((directory/'oracle-suite.json').read_text())
        if not data['complete'] or not data['acceptance_complete']:raise RuntimeError('partial/development oracle')
        return {'directory':str(directory.relative_to(ROOT)),'sha256':digest(directory/'oracle-suite.json'),'image_id':info['Image']}
    finally:
        if cid is not None:docker('rm','-f',cid)
        else:
            import subprocess
            try:docker('rm','-f',name)
            except subprocess.CalledProcessError as e:
                if b'No such container' not in e.stderr:raise

def main():
    invalidate_summary();verified_build();(ROOT/'runs/plugin').mkdir(parents=True,exist_ok=True)
    snapshot=inputs(ROOT)
    result={'schema':1,'complete':False,'inputs':snapshot,'build_sha256':digest(ROOT/'build/plugin/build.json'),
            'environment_sha256':digest(ROOT/'build/plugin/environment.json'),'cases':[]}
    target=ROOT/'build/plugin/functional.json';target.write_text(json.dumps(result,indent=2)+'\n')
    for name,args in functional_cases():
        row,directory=run_probe(name,args,timeout=120);check_observation(row);verify_output(name,args,row['stdout'])
        result['cases'].append({'key':key(name,args),'observation':str((directory/'observation.json').relative_to(ROOT)),
                                'sha256':digest(directory/'observation.json')})
        target.write_text(json.dumps(result,indent=2)+'\n');print(name,'passed',flush=True)
    result['oracles']=oracle_container();verified_build()
    if inputs(ROOT)!=snapshot:raise RuntimeError('functional inputs changed')
    result['complete']=True;target.write_text(json.dumps(result,indent=2)+'\n')
if __name__=='__main__':main()
