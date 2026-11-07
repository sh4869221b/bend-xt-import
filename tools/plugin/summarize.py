"""Require complete fresh parser evidence; no local smoke or core reuse pass."""
import base64
import hashlib
import json
import math
from integrity import ROOT,inputs,digest,invalidate_summary
from experiment import verified_build
from validation import require_inventory,validate_identity,validate_binary,validate_oracle,check_observation,contained,validate_build,claim_run
from checks import verify_output,verify_fixture
from oracle import cases as oracle_cases
from case_spec import ENTRYPOINTS,OWNERS,functional_cases,resource_cases,key,live_charge
from layout import inspect


def observation(item,build_hash,environment,binaries,seen):
    path=contained(ROOT,item['observation'])
    if digest(path)!=item['sha256']:raise ValueError('observation digest changed')
    row=json.loads(path.read_text())
    claim_run(ROOT,item['observation'],row,seen)
    if row['build_sha256']!=build_hash or row['image_id']!=environment['images'][1]['id'] or row['lock_sha256']!=digest(ROOT/'sources.lock'):
        raise ValueError('observation build/image/lock differs')
    if row['runner_sha256']!=digest(ROOT/'tools/plugin/experiment.py') or row['entry_sha256']!=digest(ROOT/'tools/plugin/native_entry.py'):
        raise ValueError('observation harness differs')
    validate_binary(row,binaries);check_observation(row)
    args=[base64.b64decode(x,validate=True).decode() for x in row['args_base64']]
    verify_output(row['probe'],args,row['stdout'])
    return row,args


def resource_summary(cases,rows,profile):
    baselines=[r for c,r in zip(cases,rows) if c['group'].startswith('baseline-')]
    if len(baselines)!=6:raise ValueError('baseline inventory incomplete')
    mib=1048576
    rss_base=max(r['native_result']['maxrss_bytes'] for r in baselines)
    cg_base=max(r['final_cgroup']['memory_peak'] for r in baselines)
    rss_allowance=math.ceil(rss_base/mib)*mib*profile['baseline_margin_multiplier']
    cg_allowance=math.ceil(cg_base/mib)*mib*profile['baseline_margin_multiplier']
    groups={}
    for case,row in zip(cases,rows):
        charge=live_charge(case);rss=row['native_result']['maxrss_bytes'];cg=row['final_cgroup']['memory_peak']
        if rss>rss_allowance+charge or cg>cg_allowance+charge:
            raise ValueError('parser representation exceeds measured allowance: '+case['group'])
        groups.setdefault(case['group'],[]).append({'rss_with_launcher':rss,'cgroup_peak':cg,'live_charge':charge,'seconds':row['seconds']})
    for prefix in ['scan-stream-','copy-stream-']:
        selected=[r for group,items in groups.items() if group.startswith(prefix) for r in items]
        if len(selected)!=9:raise ValueError('stream matrix incomplete')
        for field in ['rss_with_launcher','cgroup_peak']:
            if max(r[field] for r in selected)-min(r[field] for r in selected)>profile['maximum_stream_peak_growth']:
                raise ValueError('unbounded or uncalibrated stream memory: '+prefix)
    return {'baseline_rss_with_launcher':rss_base,'baseline_cgroup':cg_base,
            'rss_fixed_allowance':rss_allowance,'cgroup_fixed_allowance':cg_allowance,'groups':groups}


def main():
    invalidate_summary();binaries=verified_build();current=inputs(ROOT)
    build_hash=digest(ROOT/'build/plugin/build.json');environment_hash=digest(ROOT/'build/plugin/environment.json')
    build=json.loads((ROOT/'build/plugin/build.json').read_text());environment=json.loads((ROOT/'build/plugin/environment.json').read_text())
    layout=json.loads((ROOT/'build/plugin/layout.json').read_text())
    if layout.get('complete') is not True or layout['build_sha256']!=build_hash or layout['inspection']!=inspect():
        raise ValueError('missing or changed generated representation evidence')
    lock=json.loads((ROOT/'sources.lock').read_text())
    validate_build(build,lock,ENTRYPOINTS,OWNERS,ROOT)
    import subprocess
    if environment['git_head']!=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip():raise ValueError('git head differs from build')
    require_inventory([p['probe'] for p in build['probes']],ENTRYPOINTS)
    require_inventory([p['file'] for p in build['ownership_checks']],{n+'.bend' for n in OWNERS|{n+'_control' for n in OWNERS}})
    functional=json.loads((ROOT/'build/plugin/functional.json').read_text());resources=json.loads((ROOT/'build/plugin/resource.json').read_text())
    for suite in [functional,resources]:validate_identity(suite,current,build_hash,environment_hash)
    require_inventory([x['key'] for x in functional['cases']],[key(n,a) for n,a in functional_cases()])
    seen=set()
    for item in functional['cases']:
        row,args=observation(item,build_hash,environment,binaries,seen)
        if item['key']!=key(row['probe'],args):raise ValueError('functional invocation mismatch')
    oracle_ref=functional['oracles'];oracle_path=contained(ROOT,oracle_ref['directory']+'/oracle-suite.json')
    if digest(oracle_path)!=oracle_ref['sha256']:raise ValueError('oracle digest changed')
    oracle=json.loads(oracle_path.read_text());lock=json.loads((ROOT/'sources.lock').read_text())
    validate_oracle(oracle,current,lock['probe_image']['packages_sha256'])
    if oracle.get('acceptance_complete') is not True or oracle_ref['image_id']!=environment['images'][1]['id'] or oracle['binary_sha256']!=binaries['driver']:
        raise ValueError('oracle build/profile identity mismatch')
    expected={k:(f,a) for k,f,a in oracle_cases()}
    require_inventory([x['key'] for x in oracle['cases']],expected)
    for row in oracle['cases']:
        fixture,args=expected[row['key']]
        if row['args']!=args or row['fixture_sha256']!=hashlib.sha256(fixture.data).hexdigest() or row['exit']!=0 or row['stderr'] or row.get('pass') is not True:
            raise ValueError('oracle result/fixture mismatch')
        verify_fixture(fixture,row['stdout'])
    expected_resources={key(c['probe'],c['args'],c['repeat']):c for c in resource_cases()}
    require_inventory([x['key'] for x in resources['cases']],expected_resources)
    rows=[];ordered=[]
    for item in resources['cases']:
        case=expected_resources[item['key']]
        if any(item[k]!=case[k] for k in ['probe','args','group','repeat']):raise ValueError('resource label mismatch')
        row,args=observation(item,build_hash,environment,binaries,seen)
        if row['probe']!=case['probe'] or args!=case['args']:raise ValueError('resource invocation mismatch')
        rows.append(row);ordered.append(case)
    profile=json.loads((ROOT/'docs/plugin/profile.json').read_text());summary=resource_summary(ordered,rows,profile)
    result={'schema':1,'complete':True,'profile':profile['profile'],'git_head':environment['git_head'],
            'dirty_worktree':environment['dirty_worktree'],'inputs':current,'build_sha256':build_hash,
            'layout_sha256':digest(ROOT/'build/plugin/layout.json'),'functional_sha256':digest(ROOT/'build/plugin/functional.json'),
            'resource_sha256':digest(ROOT/'build/plugin/resource.json'),'functional_cases':len(functional['cases']),
            'oracle_cases':len(expected),'resource_cases':len(rows),'ownership_controls':len(build['ownership_checks']),
            'measurements':summary}
    (ROOT/'build/plugin/summary.json').write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps({k:result[k] for k in ['profile','git_head','dirty_worktree','functional_cases','oracle_cases','resource_cases','ownership_controls']}))
if __name__=='__main__':main()
