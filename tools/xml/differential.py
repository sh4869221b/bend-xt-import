"""Native/independent-oracle comparison, including raw-byte chunk boundaries.

This runner never downloads data and never copies third-party text to reports.
A local binary is useful development evidence, not locked resource certification.
"""
from __future__ import annotations
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import time

from cases import corpus
from digest import digest
from oracle import result, tree

ROOT = Path(__file__).resolve().parents[2]
RTS = ['+RTS','--threads','1','--gpu','off','-RTS']


def sha(raw):
    return hashlib.sha256(raw).hexdigest()


def logical_bytes(raw):
    def entry(node):
        own = sum(len(v.encode('utf-8')) for v in node.attributes.values())
        # Containers have structural whitespace only, which is not logical text.
        if node.name not in {'SSTXMLRessources','Params','Content','String','FuzInfo'}:
            own += len(node.text.encode('utf-8'))
        return own + sum(entry(child) for child in node.children)
    root = tree(raw)
    return sum(entry(node) for node in root.children)

def native(binary, raw, chunk, override=None):
    # Large resource tests use a streaming generator, not a giant OS argument.
    if len(raw) > 60000:
        raise ValueError('hex argument would exceed conservative OS argument limit')
    extra = [] if override is None else list(map(str,override))
    proc = subprocess.run([str(binary),raw.hex(),str(chunk),*extra,*RTS],capture_output=True,text=True,timeout=60)
    if proc.returncode or proc.stderr:
        raise AssertionError(f'native failure exit={proc.returncode}, stderr={proc.stderr[:2000]}')
    parts = proc.stdout.split()
    if len(parts) == 6 and parts[0] == 'ok' and parts[5] == 'balanced':
        return {'accepted':True,'digest':int(parts[1]),'count':int(parts[2]),'logical':int(parts[3]),'work':int(parts[4])}
    if len(parts) == 10 and parts[0] == 'error' and parts[-1] == 'balanced':
        return {'accepted':False,**dict(zip(('phase','reason','entry','byte','line','column','logical','work'),map(int,parts[1:9])))}
    raise AssertionError('unexpected native framing: '+proc.stdout[:2000])


def compare(binary, case, chunks):
    raw = case['raw']
    oracle = result(raw)
    if oracle['accepted'] != case['accepted']:
        raise AssertionError('project-authored expectation disagrees with independent oracle: '+case['name'])
    expected = digest(raw) if oracle['accepted'] else None
    logical = logical_bytes(raw) if oracle['accepted'] else None
    first_error = None
    for chunk in chunks:
        actual = native(binary,raw,chunk)
        if actual['accepted'] != oracle['accepted']:
            raise AssertionError(f'{case["name"]} chunk={chunk}: acceptance differs ({actual})')
        if expected and actual['logical'] != logical:
            raise AssertionError(f'{case["name"]} chunk={chunk}: decoded logical bytes differ ({actual["logical"]}, {logical})')
        if expected and (actual['digest'],actual['count']) != expected:
            raise AssertionError(f'{case["name"]} chunk={chunk}: typed value differs ({actual}, {expected})')
        if not actual['accepted']:
            current = tuple(actual[x] for x in ('phase','reason','entry','byte','line','column'))
            if first_error is None:
                first_error = current
            elif current != first_error:
                raise AssertionError(f'{case["name"]}: diagnostics depend on chunk size')
    return {'name':case['name'],'sha256':sha(raw),'bytes':len(raw),'chunks':chunks,
            'accepted':oracle['accepted'],'digest':expected[0] if expected else None,
            'count':expected[1] if expected else None,'logical':logical,'error':first_error}


def main():
    p = argparse.ArgumentParser()
    p.add_argument('--binary',type=Path,default=ROOT/'build/xml/driver')
    p.add_argument('--output',type=Path,default=ROOT/'runs/xml/differential-local.json')
    p.add_argument('--all-boundaries',action='store_true')
    p.add_argument('--real-file',type=Path,action='append',default=[])
    args = p.parse_args()
    binary = args.binary.resolve()
    binary_sha = sha(binary.read_bytes())
    records = {'schema':1,'complete':False,'locked_resource_acceptance':False,
               'binary_sha256':binary_sha,'cases':[],'real_files':[]}
    args.output.parent.mkdir(parents=True,exist_ok=True)
    args.output.write_text(json.dumps(records,indent=2)+'\n')
    # Every short vector includes malformed syntax and generated text, not
    # only happy-path smoke fixtures. Encoded sizes select exactly two chunks.
    selected = {case['name'] for case in corpus() if len(case['raw']) <= 4096}
    start = time.monotonic()
    for case in corpus():
        chunks = sorted(set([1,2,3,7,31,65536]))
        if args.all_boundaries and case['name'] in selected:
            chunks = sorted(set(chunks + [65536+cut for cut in range(1,len(case['raw']))]))
        records['cases'].append(compare(binary,case,chunks))
    for path in args.real_file:
        raw = path.read_bytes()
        accepted = result(raw)['accepted']
        case = {'name':path.name,'raw':raw,'accepted':accepted}
        row = compare(binary,case,[1,2,3,7,31,65536])
        row['producer_version_verified'] = False
        records['real_files'].append(row)
    if sha(binary.read_bytes()) != binary_sha:
        raise AssertionError('binary changed during comparison')
    records['seconds'] = time.monotonic()-start
    records['complete'] = True
    args.output.write_text(json.dumps(records,indent=2)+'\n')
    print(f"{len(records['cases'])} synthetic vectors and {len(records['real_files'])} real files matched")

if __name__ == '__main__':
    main()
