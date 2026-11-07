"""Reject partial/stale evidence and certify only the measured core profile."""
import json
import math
from pathlib import Path
from integrity import invalidate_summary, ROOT, inputs, digest
from experiment import verified_build
from layout import inspect
from case_spec import ENTRYPOINTS, OWNERS, functional_cases, resource_cases, key
from checks import check_observation, verify_output, capacity, memory_expectation


def require_inventory(actual, expected):
    if len(actual)!=len(set(actual)) or set(actual)!=set(expected):
        raise ValueError('missing, duplicate or unexpected evidence case')


def validate_identity(suite, current, build_hash, environment_hash):
    if suite.get('complete') is not True or suite.get('inputs')!=current or suite.get('build_sha256')!=build_hash or suite.get('environment_sha256')!=environment_hash:
        raise ValueError('partial, stale or mixed evidence')


def validate_binary(row, binaries):
    if row.get('binary_sha256') != binaries.get(row.get('probe')) or row.get('probe') not in binaries:
        raise ValueError('observation binary identity differs')


def validate_oracle(oracle, current, packages):
    metadata = oracle['metadata']
    if oracle.get('complete') is not True or oracle['inputs'] != current:
        raise ValueError('stale/incomplete oracles')
    if metadata['uid'] == 0 or metadata['memory.max'] != '1073741824' or metadata['memory.swap.max'] != '0' or metadata['packages_sha256'] != packages:
        raise ValueError('oracle execution profile differs')
    require_inventory([Path(c['argv'][-1]).name for c in oracle['commands']], ['codec_oracle.py','sha_oracle.py'])
    if any(c['exit'] != 0 or c['stderr'] for c in oracle['commands']):
        raise ValueError('oracle subprocess failed')


def observation(item, build_hash, environment, binaries):
    original=ROOT/item['observation']
    path=original.resolve()
    if not path.is_relative_to((ROOT/'runs/core').resolve()) or original.is_symlink() or any(p.is_symlink() for p in original.parents if p.is_relative_to(ROOT)):
        raise ValueError('observation outside independent core runs')
    if digest(path)!=item['sha256']: raise ValueError('observation digest changed')
    row=json.loads(path.read_text())
    if row['build_sha256']!=build_hash or row['image_id']!=environment['images'][1]['id'] or row['lock_sha256']!=digest(ROOT/'sources.lock'):
        raise ValueError('observation build/image/lock identity differs')
    if row['runner_sha256']!=digest(ROOT/'tools/core/experiment.py') or row['entry_sha256']!=digest(ROOT/'tools/core/native_entry.py'):
        raise ValueError('observation harness identity differs')
    validate_binary(row, binaries)
    check_observation(row)
    import base64
    args=[base64.b64decode(x,validate=True).decode() for x in row['args_base64']]
    verify_output(row['probe'],args,row['stdout'])
    return row,args


def live_charge(case):
    name,args=case['probe'],list(map(int,case['args']))
    if name=='memory': return memory_expectation(*args)[1]
    if name=='sha':
        byte,total,chunk=args
        # Input+SHA overlap, or SHA+new digest overlap at finalization.
        return 65536+max(max(65536,16*capacity(chunk))+4096+65536+4096,2*(65536+4096))
    if name=='roundtrip':
        length,cycles=args
        return 65536+2*(max(65536,16*capacity(length))+4096)+(max(65536,32*capacity(length))+4096)
    # Small bounded contract/error cases are all below this declared test cap.
    return 1048576


def resource_summary(cases, rows, profile):
    baselines=[row for case,row in zip(cases,rows) if case['group'].startswith('baseline-')]
    if len(baselines)!=9: raise ValueError('baseline inventory incomplete')
    mib=1048576
    rss_base=max(row['native_result']['maxrss_bytes'] for row in baselines)
    cg_base=max(row['final_cgroup']['memory_peak'] for row in baselines)
    rss_allowance=math.ceil(rss_base/mib)*mib*profile['baseline_margin_multiplier']
    cg_allowance=math.ceil(cg_base/mib)*mib*profile['baseline_margin_multiplier']
    groups={}
    for case,row in zip(cases,rows):
        charge=live_charge(case)
        rss=row['native_result']['maxrss_bytes']
        cg=row['final_cgroup']['memory_peak']
        if rss>rss_allowance+charge or cg>cg_allowance+charge:
            raise ValueError('measured representation exceeds profile allowance: '+case['group'])
        groups.setdefault(case['group'],[]).append({'rss_with_launcher':rss,'cgroup_peak':cg,'charge':charge})
    for prefix in ['sha-stream-','codec-stream-']:
        selected=[x for group,items in groups.items() if group.startswith(prefix) for x in items]
        if len(selected)!=9: raise ValueError('stream matrix incomplete')
        for field in ['rss_with_launcher','cgroup_peak']:
            if max(x[field] for x in selected)-min(x[field] for x in selected)>profile['maximum_stream_peak_growth']:
                raise ValueError('unbounded/uncalibrated stream growth: '+prefix+field)
    return {'baseline_rss_with_launcher':rss_base,'baseline_cgroup':cg_base,
            'rss_fixed_allowance':rss_allowance,'cgroup_fixed_allowance':cg_allowance,'groups':groups,
            'note':'wait4 RSS includes the pre-exec Python high-water mark. Cgroup accounting is distinct; neither metric is the logical live charge.'}


def main():
    invalidate_summary()
    binaries=verified_build()
    current=inputs(ROOT)
    build_hash=digest(ROOT/'build/core/build.json')
    environment_hash=digest(ROOT/'build/core/environment.json')
    build=json.loads((ROOT/'build/core/build.json').read_text())
    environment=json.loads((ROOT/'build/core/environment.json').read_text())
    layout=json.loads((ROOT/'build/core/layout.json').read_text())
    if layout.get('complete') is not True or layout['build_sha256']!=build_hash or layout['inspection']!=inspect():
        raise ValueError('missing, stale or changed generated representation evidence')
    require_inventory([p['probe'] for p in build['probes']],ENTRYPOINTS)
    require_inventory([p['file'] for p in build['ownership_checks']],{x+'.bend' for x in OWNERS|{n+'_control' for n in OWNERS}})
    functional=json.loads((ROOT/'build/core/functional.json').read_text())
    resources=json.loads((ROOT/'build/core/resource.json').read_text())
    for suite in [functional,resources]: validate_identity(suite,current,build_hash,environment_hash)
    require_inventory([x['key'] for x in functional['cases']],[key(n,a) for n,a in functional_cases()])
    for item in functional['cases']:
        row,args=observation(item,build_hash,environment,binaries)
        if item['key']!=key(row['probe'],args): raise ValueError('functional case identity differs')
    oracle_dir=(ROOT/functional['oracles']['directory']).resolve()
    if not oracle_dir.is_relative_to((ROOT/'runs/core').resolve()): raise ValueError('oracle path escaped')
    if digest(oracle_dir/'oracle-suite.json')!=functional['oracles']['sha256']: raise ValueError('oracle record changed')
    oracle=json.loads((oracle_dir/'oracle-suite.json').read_text())
    lock=json.loads((ROOT/'sources.lock').read_text())
    validate_oracle(oracle,current,lock['probe_image']['packages_sha256'])
    if functional['oracles']['image_id']!=environment['images'][1]['id']: raise ValueError('oracle image differs')
    for filename,count,field,binary in [('codec-vectors.json',705,'cases','codecs'),('sha-vectors.json',31,'vectors','sha')]:
        path=oracle_dir/filename
        if digest(path)!=oracle['reports'][filename]: raise ValueError('oracle vectors changed')
        data=json.loads(path.read_text())
        if len(data[field])!=count or not all(x['pass'] for x in data[field]) or data['binary_sha256']!=digest(ROOT/'build/core'/binary):
            raise ValueError('oracle inventory/results mismatch')
    cases=resource_cases()
    expected={key(c['probe'],c['args'],c['repeat']):c for c in cases}
    require_inventory([x['key'] for x in resources['cases']],expected)
    rows=[]
    ordered=[]
    for item in resources['cases']:
        case=expected[item['key']]
        if any(item[k]!=case[k] for k in ['probe','args','group','repeat']): raise ValueError('resource label differs')
        row,args=observation(item,build_hash,environment,binaries)
        if row['probe']!=case['probe'] or args!=case['args']: raise ValueError('resource invocation differs')
        rows.append(row); ordered.append(case)
    profile=json.loads((ROOT/'docs/core/profile.json').read_text())
    summary=resource_summary(ordered,rows,profile)
    result={'schema':1,'complete':True,'profile':profile['profile'],'git_head':environment['git_head'],
            'dirty_worktree':environment['dirty_worktree'],'inputs':current,'build_sha256':build_hash,
            'layout_sha256':digest(ROOT/'build/core/layout.json'),
            'functional_sha256':digest(ROOT/'build/core/functional.json'),
            'resource_sha256':digest(ROOT/'build/core/resource.json'),
            'functional_cases':len(functional['cases']),'oracle_cases':736,
            'resource_cases':len(resources['cases']),'ownership_controls':len(build['ownership_checks']),
            'measurements':summary}
    (ROOT/'build/core/summary.json').write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps({k:result[k] for k in ['profile','git_head','dirty_worktree','functional_cases','oracle_cases','resource_cases','ownership_controls']}))

if __name__ == '__main__': main()
