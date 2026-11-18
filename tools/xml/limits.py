"""Explicit limit neighbors plus replayed exact measured-work boundaries.

Phase 5 belongs only to the test adapter (input construction/consumer iteration),
not to the production parser. Every expected refusal must still finish balanced.
"""
import argparse
import json
from pathlib import Path
from differential import ROOT, native, logical_bytes, sha
from digest import digest


def main():
    p=argparse.ArgumentParser()
    p.add_argument('--binary',type=Path,default=ROOT/'build/xml/driver')
    p.add_argument('--output',type=Path,default=ROOT/'runs/xml/limits-local.json')
    args=p.parse_args();binary=args.binary.resolve()
    manifest_path=ROOT/'tests/xml/limit-cases.json'
    manifest=json.loads(manifest_path.read_text())
    result={'schema':1,'complete':False,'locked_resource_acceptance':False,
            'binary_sha256':sha(binary.read_bytes()),'manifest_sha256':sha(manifest_path.read_bytes()),
            'cases':[],'work_neighbors':[],'live_neighbors':[]}
    args.output.parent.mkdir(parents=True,exist_ok=True)
    args.output.write_text(json.dumps(result,indent=2)+'\n')
    for case in manifest['cases']:
        raw=manifest['fixtures'][case['fixture']]['xml'].encode()
        for chunk in manifest['defaultChunkModes']:
            actual=native(binary,raw,chunk,(case['field'],case['value']))
            if actual['accepted'] != case['accepted']:
                raise AssertionError((case['name'],chunk,actual))
            if actual['accepted']:
                if (actual['digest'],actual['count'])!=digest(raw) or actual['logical']!=logical_bytes(raw):
                    raise AssertionError('typed/logical mismatch: '+case['name'])
            result['cases'].append({'name':case['name'],'chunk':chunk,'actual':actual})
    # Same exact bytes, same input-buffer schedule, only cumulative work changes.
    for fixture in ('base','reference','fuz'):
        raw=manifest['fixtures'][fixture]['xml'].encode()
        for chunk in (1,7,65536):
            baseline=native(binary,raw,chunk)
            if not baseline['accepted'] or baseline['work']<=0:
                raise AssertionError('invalid work baseline')
            exact=native(binary,raw,chunk,(10,baseline['work']))
            under=native(binary,raw,chunk,(10,baseline['work']-1))
            if exact!=baseline or under['accepted'] or under['work']>baseline['work']-1:
                raise AssertionError(('work neighbor mismatch',fixture,chunk,baseline,exact,under))
            result['work_neighbors'].append({'fixture':fixture,'chunk':chunk,'baseline':baseline,'exact':exact,'under':under})
    # Independently binary-search the smallest successful *configured live cap*.
    # This tests budget refusal/cleanup, not an assertion about physical RSS.
    raw=manifest['fixtures']['base']['xml'].encode()
    low,high=65536,268435456
    if native(binary,raw,7,(11,low))['accepted']:
        raise AssertionError('expected reader live charge at floor')
    if not native(binary,raw,7,(11,high))['accepted']:
        raise AssertionError('live upper bound fails')
    while high-low>1:
        middle=(low+high)//2
        if native(binary,raw,7,(11,middle))['accepted']:high=middle
        else:low=middle
    exact=native(binary,raw,7,(11,high));under=native(binary,raw,7,(11,low))
    if not exact['accepted'] or under['accepted']:
        raise AssertionError('live neighbor replay failed')
    result['live_neighbors']=[{'exact_limit':high,'under_limit':low,'exact':exact,'under':under}]
    if sha(binary.read_bytes())!=result['binary_sha256'] or sha(manifest_path.read_bytes())!=result['manifest_sha256']:
        raise AssertionError('test input changed')
    result['complete']=True
    args.output.write_text(json.dumps(result,indent=2)+'\n')
    print(len(result['cases']),'limit checks and exact work/live neighbors passed')

if __name__=='__main__':main()
