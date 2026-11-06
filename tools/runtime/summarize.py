"""Create a small, auditable summary from completed suites; no success inference."""
import hashlib
import json
from pathlib import Path
import statistics
from experiment import ROOT, verified_build
from integrity import inputs
from case_spec import validate


def digest(path): return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    verified_build()
    snapshot=inputs(ROOT)
    files=[ROOT/'runs/suite-all.json',ROOT/'runs/measure-all.json']
    summary={'schema':1,'description':'Linux x86_64 experiments; not WSL or production importer certification',
             'inputs':{},'suites':[],'shape_metrics':{},'stream_metrics':{}}
    for directory in ['tools/runtime','tests/runtime']:
        for p in sorted((ROOT/directory).rglob('*')):
            if p.is_file() and '__pycache__' not in p.parts:
                summary['inputs'][str(p.relative_to(ROOT))]=digest(p)
    for name in ['sources.lock','.github/workflows/runtime-probes.yml']:
        summary['inputs'][name]=digest(ROOT/name)
    build=json.loads((ROOT/'build/build.json').read_text())
    summary['build_sha256']=digest(ROOT/'build/build.json')
    summary['compiler_source']=build['compiler_source']
    summary['provenance']=build['provenance']
    summary['ownership_checks']=build['ownership_checks']
    groups={}
    for file in files:
        data=json.loads(file.read_text())
        validate(data,'api' if file.name.startswith('suite') else 'resource','all',snapshot)
        cases=[]
        if not data['cases'] or any(c['result']!='pass' for c in data['cases']):
            raise SystemExit('incomplete or failed suite: '+str(file))
        for c in data['cases']:
            p=ROOT/c['observation']
            r=json.loads(p.read_text())
            item={'case':c['case'],'result':c['result'],'observation_sha256':digest(p),
                  'exit':r['exit'],'oom_killed':r['oom_killed'],'timed_out':r['timed_out'],
                  'external_kill':r['external_kill'],'limits':r['limits']}
            if r['build_sha256']!=summary['build_sha256'] or r['lock_sha256']!=digest(ROOT/'sources.lock'): raise SystemExit('mixed build evidence')
            if r['runner_sha256']!=digest(ROOT/'tools/runtime/experiment.py') or r['entry_sha256']!=digest(ROOT/'tools/runtime/native_entry.py'):
                raise SystemExit('runner changed after execution')
            if 'verified_gap' in c:item['verified_gap']=c['verified_gap']
            if 'metrics' in c:item['metrics']=c['metrics']
            cases.append(item)
            if c['case'].startswith(('M-shape-','M-stream-')):
                key=c['case'].rsplit('-',1)[0]
                groups.setdefault(key,[]).append(c['metrics'])
        summary['suites'].append({'file':file.name,'sha256':digest(file),'count':len(cases),'cases':cases})
    for key,rows in groups.items():
        stats={}
        for metric in rows[0]:
            values=[r[metric] for r in rows if r[metric] is not None]
            stats[metric]={'n':len(values),'min':min(values) if values else None,
                           'median':statistics.median(values) if values else None,'max':max(values) if values else None}
        summary['shape_metrics' if key.startswith('M-shape') else 'stream_metrics'][key]=stats
    out=ROOT/'docs/runtime/evidence'
    out.mkdir(parents=True,exist_ok=True)
    (out/'linux-summary.json').write_text(json.dumps(summary,indent=2)+'\n')
    (out/'linux-build.json').write_bytes((ROOT/'build/build.json').read_bytes())
    (out/'linux-environment.json').write_bytes((ROOT/'build/environment.json').read_bytes())
    print('wrote',sum(s['count'] for s in summary['suites']),'cases with observation digests')

if __name__=='__main__':main()
