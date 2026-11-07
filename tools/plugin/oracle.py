"""Independent fixture/event/copy oracle. Production framing remains in Bend."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess
from integrity import ROOT,inputs,digest
from fixtures import all_fixtures,reference,limit_fixtures
from checks import verify_fixture

SPLITS=(1,2,3,5,6,7,23,24,25,65535,65536)

def cases():
    result=[]
    for fixture in all_fixtures():
        # The bounded native generator covers large fixtures without argv-size lists.
        if len(fixture.data)>16384:continue
        for chunk in SPLITS:
            output={1:1,2:3,3:2,5:7,6:5,7:23,23:24,24:25,25:65535,65535:65536,65536:1}[chunk]
            args=[fixture.data.hex() or '-',str(chunk),str(output)]
            result.append((fixture.name+':'+str(chunk)+':'+str(output),fixture,args))
    for fixture,limits in limit_fixtures():
        for chunk in [1,25]:
            args=[fixture.data.hex() or '-',str(chunk),'3',*map(str,limits),'1073741824','268435456']
            result.append((fixture.name+':'+str(chunk)+':3',fixture,args))
    return result


def profile(local):
    if local:return {'development_only':True,'uid':os.getuid()}
    m={'uid':os.getuid(),'cgroup':Path('/proc/self/cgroup').read_text(),
       'memory.max':Path('/sys/fs/cgroup/memory.max').read_text().strip(),
       'memory.swap.max':Path('/sys/fs/cgroup/memory.swap.max').read_text().strip(),
       'packages_sha256':digest('/opt/packages.lock')}
    lock=json.loads((ROOT/'sources.lock').read_text())
    if m['uid']==0 or m['memory.max']!='1073741824' or m['memory.swap.max']!='0' or m['packages_sha256']!=lock['probe_image']['packages_sha256']:
        raise RuntimeError('locked bounded oracle profile not established')
    return m


def main():
    parser=argparse.ArgumentParser();parser.add_argument('--local',action='store_true')
    args=parser.parse_args()
    out=Path(os.environ.get('PLUGIN_REPORT_DIR',str(ROOT/'build/plugin')));out.mkdir(parents=True,exist_ok=True)
    binary=ROOT/'build/plugin/driver';snapshot=inputs(ROOT)
    result={'complete':False,'acceptance_complete':False,'inputs':snapshot,'metadata':profile(args.local),
            'binary_sha256':digest(binary),'cases':[]}
    target=out/'oracle-suite.json'
    target.write_text(json.dumps(result,indent=2)+'\n')
    for key,fixture,argv in cases():
        p=subprocess.run([str(binary),'+RTS','--threads','1','--gpu','off','-RTS',*argv],capture_output=True,text=True,timeout=30)
        if len(p.stdout)+len(p.stderr)>262144:raise RuntimeError('native oracle output limit')
        row={'key':key,'args':argv,'fixture_sha256':hashlib.sha256(fixture.data).hexdigest(),
             'exit':p.returncode,'stdout':p.stdout,'stderr':p.stderr,'pass':False}
        if p.returncode or p.stderr:raise RuntimeError(key+': '+p.stdout+p.stderr)
        verify_fixture(fixture,p.stdout);row['pass']=True;result['cases'].append(row)
        if len(result['cases'])%100==0:print(len(result['cases']),'oracle cases passed',flush=True)
    if inputs(ROOT)!=snapshot:raise RuntimeError('oracle inputs changed')
    result.update(complete=True,acceptance_complete=not args.local)
    target.write_text(json.dumps(result,indent=2)+'\n')
    print(len(result['cases']),'parser/copy oracle cases passed'+(' (development only)' if args.local else ''))
if __name__=='__main__':main()
