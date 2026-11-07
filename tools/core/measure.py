"""Measure real core representations; unavailable cgroup data is a failure."""
import json
from experiment import ROOT, run_probe, verified_build
from integrity import invalidate_summary, inputs, digest
from case_spec import resource_cases, key
from checks import check_observation, verify_output


def main():
    invalidate_summary()
    verified_build()
    snapshot=inputs(ROOT)
    result={'schema':1,'complete':False,'inputs':snapshot,
            'build_sha256':digest(ROOT/'build/core/build.json'),
            'environment_sha256':digest(ROOT/'build/core/environment.json'), 'cases':[]}
    target=ROOT/'build/core/resource.json'
    target.write_text(json.dumps(result,indent=2)+'\n')
    cases=resource_cases()
    for index,case in enumerate(cases):
        row,directory=run_probe(case['probe'],case['args'],timeout=120)
        check_observation(row)
        verify_output(case['probe'],case['args'],row['stdout'])
        result['cases'].append({**case,'key':key(case['probe'],case['args'],case['repeat']),
                                'observation':str((directory/'observation.json').relative_to(ROOT)),
                                'sha256':digest(directory/'observation.json')})
        target.write_text(json.dumps(result,indent=2)+'\n')
        print(f'{index+1}/{len(cases)} {case["group"]} repeat={case["repeat"]} passed',flush=True)
    verified_build()
    if inputs(ROOT)!=snapshot: raise RuntimeError('resource inputs changed')
    result['complete']=True
    target.write_text(json.dumps(result,indent=2)+'\n')

if __name__ == '__main__': main()
