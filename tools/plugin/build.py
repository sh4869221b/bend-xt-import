"""Build exact parser test inventory using the unmodified locked compiler."""
import json
from pathlib import Path
import subprocess
import sys
from integrity import inputs,digest
from case_spec import ENTRYPOINTS,OWNERS
ROOT=Path('/work')
sys.path.append(str(ROOT/'tools/runtime'))
from verify_lock import verify

def main():
    out=ROOT/'build/plugin';out.mkdir(parents=True,exist_ok=True)
    (out/'build.json').unlink(missing_ok=True)
    snapshot=inputs(ROOT);provenance=verify()
    paths=[ROOT/'tests/plugin'/(n+'.bend') for n in sorted(ENTRYPOINTS)]
    # Helpers are explicitly named in a separate inventory rather than compiled as mains.
    from case_spec import HELPERS
    if {p.stem for p in (ROOT/'tests/plugin').glob('*.bend')} != ENTRYPOINTS|HELPERS:
        raise RuntimeError('parser test source inventory differs')
    neg=sorted((ROOT/'tests/plugin/negative').glob('*.bend'))
    if {p.stem for p in neg} != OWNERS|{n+'_control' for n in OWNERS}:
        raise RuntimeError('parser ownership inventory differs')
    compiler=['/opt/bun/bun-linux-x64-baseline/bun','--no-env-file','/opt/bend/bend2/main.ts']
    records=[];negatives=[]
    for path in paths:
        record={'probe':path.stem,'source_sha256':digest(path),'steps':[]}
        for flags in [['--check-only'],['-o',str(out/(path.stem+'.c'))],['-o',str(out/path.stem)]]:
            cmd=compiler+[str(path)]+flags
            p=subprocess.run(cmd,cwd='/opt/bend',capture_output=True,text=True,timeout=300)
            record['steps'].append({'argv':cmd,'exit':p.returncode,'stdout':p.stdout,'stderr':p.stderr})
            if p.returncode:
                (out/'build-failure.json').write_text(json.dumps(record,indent=2)+'\n')
                raise RuntimeError(p.stdout+p.stderr)
        record.update(binary_sha256=digest(out/path.stem),c_sha256=digest(out/(path.stem+'.c')))
        records.append(record);print(path.stem,'built',flush=True)
    for path in neg:
        p=subprocess.run(compiler+[str(path),'--check-only'],cwd='/opt/bend',capture_output=True,text=True,timeout=120)
        control=path.stem.endswith('_control');diagnostic=p.stdout+p.stderr
        if (control and p.returncode) or (not control and (p.returncode==0 or 'consumed more than once' not in diagnostic)):
            raise RuntimeError(path.name+'\n'+diagnostic)
        negatives.append({'file':path.name,'control':control,'sha256':digest(path),'exit':p.returncode,'diagnostic':diagnostic})
    if inputs(ROOT)!=snapshot:raise RuntimeError('inputs changed during build')
    manifest={'schema':1,'build_complete':True,'acceptance_complete':False,'provenance':provenance,
              'inputs':snapshot,'probes':records,'ownership_checks':negatives,'base_sha256':digest('/opt/bend/bend2/base.bend')}
    tmp=out/'build.json.tmp';tmp.write_text(json.dumps(manifest,indent=2)+'\n');tmp.replace(out/'build.json')
if __name__=='__main__':main()
