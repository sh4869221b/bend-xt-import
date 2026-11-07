"""Native contracts and independent oracles; exact complete inventory only."""
import json
import os
from pathlib import Path
import tempfile
from experiment import ROOT, docker, run_probe, verified_build
from integrity import invalidate_summary, inputs, digest
from case_spec import functional_cases, key
from checks import check_observation, verify_output


def oracle_container():
    directory = Path(tempfile.mkdtemp(prefix='oracles-',dir=ROOT/'runs/core'))
    name = 'bend-core-'+directory.name
    cid = None
    try:
        cid = docker('create','--name',name,'--network','none','--read-only','--cap-drop','ALL',
                     '--security-opt','no-new-privileges','--user',f'{os.getuid()}:{os.getgid()}',
                     '--memory','1073741824','--memory-swap','1073741824','--cpus','1','--pids-limit','64',
                     '--mount',f'type=bind,src={ROOT},dst=/work,readonly',
                     '--mount',f'type=bind,src={directory},dst=/reports',
                     'bend-xt-probe:issue1','python3','/work/tools/core/oracles.py').stdout.decode().strip()
        info = json.loads(docker('inspect',cid).stdout)[0]
        environment = json.loads((ROOT/'build/core/environment.json').read_text())
        if info['Image']!=environment['images'][1]['id']: raise RuntimeError('oracle image differs')
        run = docker('start','-a',cid,timeout=600)
        info = json.loads(docker('inspect',cid).stdout)[0]
        (directory/'stdout.log').write_bytes(run.stdout)
        (directory/'stderr.log').write_bytes(run.stderr)
        if info['State']['ExitCode']!=0 or info['State']['OOMKilled']:
            raise RuntimeError('oracle container failed')
        data=json.loads((directory/'oracle-suite.json').read_text())
        if not data['complete']: raise RuntimeError('partial oracle suite')
        return {'directory':str(directory.relative_to(ROOT)), 'sha256':digest(directory/'oracle-suite.json'),
                'image_id':info['Image'], 'count':736}
    finally:
        if cid is not None: docker('rm','-f',cid)
        else:
            import subprocess
            try: docker('rm','-f',name)
            except subprocess.CalledProcessError as error:
                if b'No such container' not in error.stderr: raise


def main():
    invalidate_summary()
    verified_build()
    (ROOT/'runs/core').mkdir(parents=True,exist_ok=True)
    snapshot=inputs(ROOT)
    result={'schema':1,'complete':False,'inputs':snapshot,
            'build_sha256':digest(ROOT/'build/core/build.json'),
            'environment_sha256':digest(ROOT/'build/core/environment.json'), 'cases':[]}
    target=ROOT/'build/core/functional.json'
    target.write_text(json.dumps(result,indent=2)+'\n')
    for name,args in functional_cases():
        row,directory=run_probe(name,args,timeout=90)
        check_observation(row)
        verify_output(name,args,row['stdout'])
        result['cases'].append({'key':key(name,args),'observation':str((directory/'observation.json').relative_to(ROOT)),
                                'sha256':digest(directory/'observation.json')})
        target.write_text(json.dumps(result,indent=2)+'\n')
        print(name,'passed',flush=True)
    result['oracles']=oracle_container()
    verified_build()
    if inputs(ROOT)!=snapshot: raise RuntimeError('functional inputs changed')
    result['complete']=True
    target.write_text(json.dumps(result,indent=2)+'\n')

if __name__ == '__main__': main()
