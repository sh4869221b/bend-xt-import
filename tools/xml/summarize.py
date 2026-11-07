"""Fail-closed locked technical gate, with a distinct blocked producer gate."""
import base64
import json
import math
import subprocess
from case_spec import ENTRYPOINTS, OWNERS
from checks import functional_cases, key, verify_output, stream_expected
from experiment import verified_build
from integrity import ROOT, inputs, digest, invalidate_summary
from layout import inspect
from resources import cases as resource_cases, live_charge
from validation import (require_inventory, validate_identity, validate_binary, check_observation,
                        contained, claim_run, validate_build, validate_oracle, validate_limits,
                        validate_positions, producer_status, validate_producer)


def observation(item, build_hash, environment, binaries, seen):
    path = contained(ROOT, item['observation'])
    if digest(path) != item['sha256']:
        raise ValueError('changed observation')
    row = json.loads(path.read_text())
    claim_run(ROOT, item['observation'], row, seen)
    if row['build_sha256'] != build_hash or row['image_id'] != environment['images'][1]['id'] or row['lock_sha256'] != digest(ROOT / 'sources.lock'):
        raise ValueError('observation build/image/lock differs')
    if row['runner_sha256'] != digest(ROOT / 'tools/xml/experiment.py') or row['entry_sha256'] != digest(ROOT / 'tools/xml/native_entry.py'):
        raise ValueError('observation harness differs')
    lock = json.loads((ROOT / 'sources.lock').read_text())
    if row['ready']['packages_sha256'] != lock['probe_image']['packages_sha256'] or row['kernel'] != environment['kernel']:
        raise ValueError('observation runtime identity differs')
    validate_binary(row, binaries)
    check_observation(row)
    args = [base64.b64decode(a, validate=True).decode() for a in row['args_base64']]
    verify_output(row['probe'], args, row['stdout'])
    return row, args


def resource_summary(cases, rows, profile):
    baselines = [r for c, r in zip(cases, rows, strict=True) if c['group'].startswith('baseline-')]
    if len(baselines) != 6 or profile['resource_repeats'] != 3:
        raise ValueError('resource baseline/repetition inventory incomplete')
    mib = 1048576
    rss_base = max(r['native_result']['maxrss_bytes'] for r in baselines)
    cg_base = max(r['final_cgroup']['memory_peak'] for r in baselines)
    rss_fixed = math.ceil(rss_base / mib) * mib * profile['baseline_margin_multiplier']
    cg_fixed = math.ceil(cg_base / mib) * mib * profile['baseline_margin_multiplier']
    groups = {}
    for c, row in zip(cases, rows, strict=True):
        charge = live_charge(c)
        rss = row['native_result']['maxrss_bytes']
        cg = row['final_cgroup']['memory_peak']
        if rss > rss_fixed + charge or cg > cg_fixed + charge:
            raise ValueError('XML representation exceeds measured fixed+charged allowance: ' + c['group'])
        groups.setdefault(c['group'], []).append({'repeat': c['repeat'], 'rss_with_launcher': rss,
                                                'cgroup_peak': cg, 'live_charge': charge, 'seconds': row['seconds']})
    selected = [r for group, rs in groups.items() if group.startswith('stream-ascii-') for r in rs]
    if len(selected) != 9:
        raise ValueError('missing 1/16/64 MiB three-repeat stream matrix')
    for field in ('rss_with_launcher', 'cgroup_peak'):
        if max(r[field] for r in selected) - min(r[field] for r in selected) > profile['maximum_stream_peak_growth']:
            raise ValueError('unbounded/uncalibrated streaming memory')
    return {'baseline_rss_with_launcher': rss_base, 'baseline_cgroup_peak': cg_base,
            'rss_fixed_allowance': rss_fixed, 'cgroup_fixed_allowance': cg_fixed, 'groups': groups}


def validate_container(proof, image_id):
    expected = {'image_id': image_id, 'exit': 0, 'oom_killed': False, 'network': 'none',
                'read_only': True, 'memory': 1073741824, 'memory_swap': 1073741824}
    if any(proof.get(k) != v for k, v in expected.items()) or not proof.get('container_id'):
        raise ValueError('oracle container identity/isolation differs')
    if [x.upper() for x in proof['cap_drop']] != ['ALL'] or proof['security_opt'] != ['no-new-privileges']:
        raise ValueError('oracle container security profile differs')


def main():
    invalidate_summary()
    binaries = verified_build()
    current = inputs(ROOT)
    build_hash = digest(ROOT / 'build/xml/build.json')
    environment_hash = digest(ROOT / 'build/xml/environment.json')
    build = json.loads((ROOT / 'build/xml/build.json').read_text())
    environment = json.loads((ROOT / 'build/xml/environment.json').read_text())
    lock = json.loads((ROOT / 'sources.lock').read_text())
    validate_build(build, lock, ENTRYPOINTS, OWNERS, ROOT)
    head = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip()
    dirty = bool(subprocess.check_output(['git', 'status', '--porcelain'], cwd=ROOT))
    if environment['git_head'] != head or environment['dirty_worktree'] != dirty or environment['machine'] != 'x86_64':
        raise ValueError('git or host identity differs')
    if len(environment['images']) != 2 or any(x['architecture'] != 'amd64' or x['os'] != 'linux' or not x['id'].startswith('sha256:') for x in environment['images']):
        raise ValueError('missing/nonlocked container image identities')
    layout = json.loads((ROOT / 'build/xml/layout.json').read_text())
    if layout.get('complete') is not True or layout['build_sha256'] != build_hash or layout['inspection'] != inspect():
        raise ValueError('missing/changed generated-C shape evidence')
    functional = json.loads((ROOT / 'build/xml/functional.json').read_text())
    resources = json.loads((ROOT / 'build/xml/resource.json').read_text())
    for suite in (functional, resources):
        validate_identity(suite, current, build_hash, environment_hash)
        validate_producer(suite['producer_export'])
        if suite.get('acceptance_complete') is not False:
            raise ValueError('technical suite misrepresents producer acceptance')
    require_inventory([c['key'] for c in functional['cases']], [key(n, a) for n, a in functional_cases()])
    seen = set()
    for c in functional['cases']:
        row, args = observation(c, build_hash, environment, binaries, seen)
        if c['key'] != key(row['probe'], args):
            raise ValueError('functional invocation identity differs')
    ref = functional['oracle']
    directory = contained(ROOT, ref['directory'])
    if digest(directory / 'oracle-suite.json') != ref['sha256'] or digest(directory / 'container.json') != ref['container_sha256']:
        raise ValueError('oracle evidence changed')
    validate_container(json.loads((directory / 'container.json').read_text()), environment['images'][1]['id'])
    if ref['image_id'] != environment['images'][1]['id']:
        raise ValueError('oracle reference image differs')
    oracle = json.loads((directory / 'oracle-suite.json').read_text())
    validate_oracle(oracle, current, lock['probe_image']['packages_sha256'], binaries)
    for name, validator, binary in [('limits', validate_limits, 'driver'), ('positions', validate_positions, 'positions')]:
        if oracle[name]['file'] != name + '.json' or digest(directory / (name + '.json')) != oracle[name]['sha256']:
            raise ValueError('oracle subsuite changed')
        validator(json.loads((directory / (name + '.json')).read_text()), ROOT, binaries[binary])
    expected = {c['key']: c for c in resource_cases()}
    require_inventory([c['key'] for c in resources['cases']], expected)
    rows, ordered = [], []
    for c in resources['cases']:
        spec = expected[c['key']]
        if any(c[k] != v for k, v in spec.items()):
            raise ValueError('resource label/repetition differs')
        row, args = observation(c, build_hash, environment, binaries, seen)
        if row['probe'] != c['probe'] or args != c['args']:
            raise ValueError('resource invocation differs')
        if c['probe'] == 'stream' and c['generated_source'] != stream_expected(*map(int, args)):
            raise ValueError('generated source identity differs')
        rows.append(row)
        ordered.append(c)
    profile = json.loads((ROOT / 'docs/xml/profile.json').read_text())
    if profile['producer_export'] != 'blocked_missing_fixture':
        raise ValueError('profile silently overrides producer gate')
    measurements = resource_summary(ordered, rows, profile)
    data = {'schema': 1, 'report_complete': True, 'complete': False, 'technical_validation_complete': True,
            'acceptance_complete': False, 'issue5_complete': False, 'producer_export': producer_status(),
            'profile': profile['profile'], 'git_head': head, 'dirty_worktree': dirty, 'inputs': current,
            'build_sha256': build_hash, 'environment_sha256': environment_hash,
            'layout_sha256': digest(ROOT / 'build/xml/layout.json'),
            'functional_sha256': digest(ROOT / 'build/xml/functional.json'),
            'resource_sha256': digest(ROOT / 'build/xml/resource.json'),
            'functional_cases': len(functional['cases']), 'oracle_cases': len(oracle['cases']),
            'oracle_native_runs': sum(len(c['runs']) for c in oracle['cases']),
            'resource_cases': len(rows), 'ownership_controls': len(build['ownership_checks']), 'measurements': measurements}
    # Fail closed if sources change during the final validation itself.
    if current != inputs(ROOT):
        raise ValueError('inputs changed during summary')
    (ROOT / 'build/xml/summary.json').write_text(json.dumps(data, indent=2) + '\n')
    print(json.dumps({k: data[k] for k in ('technical_validation_complete', 'acceptance_complete', 'issue5_complete', 'producer_export', 'git_head', 'oracle_native_runs', 'resource_cases')}))


if __name__ == '__main__':
    main()
