"""Three independently observed native processes per finite XML resource case."""
import json
from checks import verify_output, stream_expected
from experiment import ROOT, run_probe, verified_build
from integrity import invalidate_summary, inputs, digest
from resources import cases
from validation import check_observation, producer_status


def main():
    invalidate_summary()
    verified_build()
    snapshot = inputs(ROOT)
    data = {'schema': 1, 'complete': False, 'acceptance_complete': False, 'producer_export': producer_status(),
            'inputs': snapshot, 'build_sha256': digest(ROOT / 'build/xml/build.json'),
            'environment_sha256': digest(ROOT / 'build/xml/environment.json'), 'cases': []}
    target = ROOT / 'build/xml/resource.json'
    target.write_text(json.dumps(data, indent=2) + '\n')
    inventory = cases()
    for index, case in enumerate(inventory):
        row, directory = run_probe(case['probe'], case['args'], timeout=900)
        check_observation(row)
        verify_output(case['probe'], case['args'], row['stdout'])
        record = {**case, 'observation': str((directory / 'observation.json').relative_to(ROOT)),
                  'sha256': digest(directory / 'observation.json')}
        if case['probe'] == 'stream':
            record['generated_source'] = stream_expected(*map(int, case['args']))
        data['cases'].append(record)
        target.write_text(json.dumps(data, indent=2) + '\n')
        print(f"{index + 1}/{len(inventory)} {case['group']} repeat={case['repeat']} passed", flush=True)
    verified_build()
    if inputs(ROOT) != snapshot:
        raise RuntimeError('resource inputs changed')
    data['complete'] = True
    target.write_text(json.dumps(data, indent=2) + '\n')


if __name__ == '__main__':
    main()
