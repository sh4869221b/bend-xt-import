"""Verify each recorded runtime case before sealing the completed suites."""
import argparse
import hashlib
import json
from pathlib import Path
import statistics
from experiment import ROOT, encoded_arguments, execution_options, verified_build
from integrity import digest, inputs
from case_spec import validate
import measure
import run_probes


def load_observation(entry, label, probe, arguments, options, identity, binaries, seen):
    original = ROOT / entry['observation']
    path = original.resolve()
    if path != original or path.parent.parent != ROOT / 'runs' or path.name != 'observation.json':
        raise ValueError(f'{label}: invalid observation path')
    if path in seen:
        raise ValueError(f'{label}: observation was already used')
    raw = path.read_bytes()
    if hashlib.sha256(raw).hexdigest() != entry['sha256']:
        raise ValueError(f'{label}: observation digest differs')
    row = json.loads(raw)
    if row['scratch'] != path.parent.name or row['case'] != label:
        raise ValueError(f'{label}: observation case or scratch differs')
    if row['probe'] != probe or row['args_base64'] != encoded_arguments(arguments) or row['options'] != options:
        raise ValueError(f'{label}: observation invocation differs')
    if probe not in binaries or row['binary_sha256'] != binaries[probe] or any(row[k] != v for k,v in identity.items()):
        raise ValueError(f'{label}: observation build or runner identity differs')
    if row['limits'] != {'memory.max': str(options['memory']), 'memory.swap.max': '0'}:
        raise ValueError(f'{label}: observed limits differ')
    seen.add(path)
    return row, path.parent


def summarize_suite(data, kind, group, snapshot, identity, binaries, seen):
    validate(data, kind, group, snapshot)
    entries = iter(data['cases'])
    results = []

    def case(label, probe, arguments=(), prepare=None, expected=0, output=None,
             inspect=None, check=None, fault=None, gap=None, termination='exit', **kwargs):
        entry = next(entries)
        if entry['case'] != label or entry.get('verified_gap') != gap:
            raise ValueError(f'{label}: case label or verified gap differs')
        options = execution_options(fault=fault, **kwargs)
        row, directory = load_observation(entry, label, probe, arguments, options, identity, binaries, seen)
        item = {'case': label, 'result': 'pass', 'observation_sha256': entry['sha256'],
                **{key: row[key] for key in ('exit', 'oom_killed', 'timed_out', 'external_kill', 'limits')}}
        try:
            if kind == 'api':
                run_probes.check_result(row, directory, expected, output, inspect, fault)
                if gap is not None:
                    item['verified_gap'] = gap
            else:
                measure.check_result(row, directory, expected, output, check, termination=termination, fault=fault)
                item['metrics'] = measure.summarize(row)
                if entry['metrics'] != item['metrics']:
                    raise AssertionError('resource metrics differ from observation')
        except AssertionError as error:
            raise ValueError(f'{label}: {error}') from error
        results.append(item)

    recipes = run_probes if kind == 'api' else measure
    recipes.run_cases(group, case)
    if len(results) != len(data['cases']):
        raise ValueError('case definitions and recorded inventory differ')
    return results


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--output-dir', type=Path, default=ROOT/'docs/runtime/evidence')
    out = parser.parse_args().output_dir
    binaries=verified_build()
    snapshot=inputs(ROOT)
    files=[ROOT/'runs/suite-all.json',ROOT/'runs/measure-all.json']
    summary={'schema':1,'description':'Linux x86_64 experiments; not WSL or production importer certification',
             'inputs':snapshot,'suites':[],'shape_metrics':{},'stream_metrics':{}}
    build=json.loads((ROOT/'build/build.json').read_text())
    environment_path=ROOT/'build/environment.json'
    environment=json.loads(environment_path.read_text())
    summary['build_sha256']=digest(ROOT/'build/build.json')
    summary['compiler_source']=build['compiler_source']
    summary['provenance']=build['provenance']
    summary['ownership_checks']=build['ownership_checks']
    identity={'build_sha256':summary['build_sha256'],'lock_sha256':digest(ROOT/'sources.lock'),
              'runner_sha256':digest(ROOT/'tools/runtime/experiment.py'),
              'entry_sha256':digest(ROOT/'tools/runtime/native_entry.py'),'image_id':environment['images'][1]['id']}
    groups={}
    seen=set()
    for file in files:
        data=json.loads(file.read_text())
        kind='api' if file.name.startswith('suite') else 'resource'
        cases=summarize_suite(data,kind,'all',snapshot,identity,binaries,seen)
        for item in cases:
            if item['case'].startswith(('M-shape-','M-stream-')):
                key=item['case'].rsplit('-',1)[0]
                groups.setdefault(key,[]).append(item['metrics'])
        summary['suites'].append({'file':file.name,'sha256':digest(file),'count':len(cases),'cases':cases})
    for key,rows in groups.items():
        stats={}
        for metric in rows[0]:
            values=[r[metric] for r in rows if r[metric] is not None]
            stats[metric]={'n':len(values),'min':min(values) if values else None,
                           'median':statistics.median(values) if values else None,'max':max(values) if values else None}
        summary['shape_metrics' if key.startswith('M-shape') else 'stream_metrics'][key]=stats
    out.mkdir(parents=True,exist_ok=True)
    (out/'linux-summary.json').write_text(json.dumps(summary,indent=2)+'\n')
    (out/'linux-build.json').write_bytes((ROOT/'build/build.json').read_bytes())
    (out/'linux-environment.json').write_bytes(environment_path.read_bytes())
    print('wrote',sum(s['count'] for s in summary['suites']),'cases with observation digests')

if __name__=='__main__':main()
