"""Mutation regressions for incomplete, stale, duplicate and false acceptance."""
import copy
import hashlib
import json
from pathlib import Path
import tempfile
from unittest.mock import patch
from checks import RTS, parse, schedules, stream_expected, input_initialization_work
from integrity import DIRECTORIES, FILES, digest, inputs, invalidate_summary
from validation import (require_inventory, validate_identity, validate_binary, check_observation,
                        contained, claim_run, validate_build, validate_oracle, validate_limits,
                        validate_positions, producer_status, validate_producer)
from summarize import validate_container, resource_summary

count = 0


def rejected(fn):
    global count
    count += 1
    try:
        fn()
    except (ValueError, AssertionError, RuntimeError, KeyError, TypeError, FileNotFoundError):
        return
    raise AssertionError('corrupt/incomplete evidence accepted')


def mutations(value, changes, validator):
    validator(value)
    for change in changes:
        changed = copy.deepcopy(value)
        change(changed)
        rejected(lambda: validator(changed))


def main():
    valid = {'complete': True, 'inputs': {'a': 'b'}, 'build_sha256': 'c', 'environment_sha256': 'd'}
    mutations(valid, [lambda v: v.update(complete=False), lambda v: v.update(inputs={}),
                     lambda v: v.update(build_sha256='old'), lambda v: v.update(environment_sha256='old')],
              lambda v: validate_identity(v, {'a': 'b'}, 'c', 'd'))
    require_inventory(['a', 'b'], ['a', 'b'])
    for wrong in (['a'], ['a', 'a'], ['a', 'b', 'c']):
        rejected(lambda: require_inventory(wrong, ['a', 'b']))
    validate_binary({'probe': 'driver', 'binary_sha256': 'fresh'}, {'driver': 'fresh'})
    rejected(lambda: validate_binary({'probe': 'driver', 'binary_sha256': 'old'}, {'driver': 'fresh'}))
    rejected(lambda: validate_binary({'probe': 'missing', 'binary_sha256': None}, {'driver': 'fresh'}))
    mutations(producer_status(), [lambda v: v.update(status='passed'), lambda v: v.update(acceptance_complete=True),
                                 lambda v: v.update(verified_fixtures=['synthetic']), lambda v: v.update(pinned_revision='later')],
              validate_producer)
    row = {'exit': 0, 'docker_client_exit': 0, 'timed_out': False, 'external_kill': False, 'oom_killed': False, 'stderr': '',
           'container_id': 'a' * 64, 'native_host_pid': 42, 'cgroup_path': '/sys/fs/cgroup/test',
           'limits': {'memory.max': '1073741824', 'memory.swap.max': '0'},
           'ready': {'uid': 1000, 'pid': 23, 'memory.max': '1073741824\n', 'memory.swap.max': '0\n'},
           'native_result': {'exit': 0, 'signal': None, 'maxrss_bytes': 1000000},
           'events_before': {'oom': 0, 'oom_kill': 0, 'max': 0},
           'final_cgroup': {'events': {'oom': 0, 'oom_kill': 0, 'max': 0}, 'memory_peak': 8000000}}
    changes = [lambda v, k=k, x=x: v.update({k: x}) for k, x in
               [('exit', 1), ('docker_client_exit', 1), ('timed_out', True), ('external_kill', True),
                ('oom_killed', True), ('stderr', 'bad'), ('native_result', None), ('final_cgroup', None)]]
    changes += [lambda v, k=k, x=x: v['limits'].update({k: x}) for k, x in [('memory.max', 'max'), ('memory.swap.max', '1')]]
    changes += [lambda v: v.update(container_id=''), lambda v: v.update(native_host_pid=0),
                lambda v: v.update(cgroup_path=''), lambda v: v['ready'].update(uid=0), lambda v: v['ready'].update(pid=0),
                lambda v: v['ready'].update({'memory.swap.max': '1'}),
                lambda v: v['native_result'].update(maxrss_bytes=0), lambda v: v['native_result'].update(signal=9),
                lambda v: v['final_cgroup'].update(memory_peak=0), lambda v: v['final_cgroup'].update(memory_peak=1073741824),
                lambda v: v['final_cgroup']['events'].update(max=1)]
    mutations(row, changes, check_observation)
    proof = {'image_id': 'image', 'container_id': 'native-container', 'exit': 0, 'oom_killed': False,
             'network': 'none', 'read_only': True, 'memory': 1073741824, 'memory_swap': 1073741824,
             'cap_drop': ['ALL'], 'security_opt': ['no-new-privileges']}
    mutations(proof, [lambda v: v.update(image_id='changed'), lambda v: v.update(network='bridge'),
                      lambda v: v.update(read_only=False), lambda v: v.update(memory_swap=2147483648),
                      lambda v: v.update(container_id=None), lambda v: v.update(cap_drop=[]),
                      lambda v: v.update(security_opt=[])], lambda v: validate_container(v, 'image'))
    with tempfile.TemporaryDirectory() as temporary:
        root = Path(temporary)
        for d in DIRECTORIES:
            (root / d).mkdir(parents=True, exist_ok=True)
        for name in FILES:
            p = root / name
            p.parent.mkdir(parents=True, exist_ok=True)
            p.write_text('fixture')
        assert inputs(root)
        (root / FILES[0]).unlink()
        rejected(lambda: inputs(root))
        (root / FILES[0]).write_text('fixture')
        (root / 'xml/linked').symlink_to(root / 'hash', target_is_directory=True)
        rejected(lambda: inputs(root))
        (root / 'xml/linked').unlink()
        (root / 'core').rmdir()
        (root / 'core').symlink_to(root / 'hash', target_is_directory=True)
        rejected(lambda: inputs(root))
        rejected(lambda: contained(root, '../escape.json'))
        seen = set()
        claim_run(root, 'runs/xml/first/observation.json', {'scratch': 'first', 'container_id': 'a' * 64}, seen)
        claim_run(root, 'runs/xml/second/observation.json', {'scratch': 'second', 'container_id': 'b' * 64}, seen)
        for path, scratch in [('runs/xml/first/observation.json', 'first'),
                              ('runs/xml/second/../first/observation.json', 'first'),
                              ('runs/xml/third/observation.json', 'first'),
                              ('runs/xml/copy/first/observation.json', 'first'),
                              ('runs/xml/first/renamed.json', 'first')]:
            rejected(lambda: claim_run(root, path, {'scratch': scratch, 'container_id': 'c' * 64}, seen))
        rejected(lambda: claim_run(root, 'runs/xml/new/observation.json', {'scratch': 'new', 'container_id': 'a' * 64}, seen))
        source = root / 'tests/xml/probe.bend'
        source.write_text('def main() -> U32: 0')
        negative = root / 'tests/xml/negative'
        negative.mkdir()
        for name in ('owner', 'owner_control'):
            (negative / (name + '.bend')).write_text('test')
        lock = {'build_image': {'packages_sha256': 'packages'}, 'compiler_tree_sha256': 'compiler', 'bun_binary_sha256': 'bun'}
        compiler = ['/opt/bun/bun-linux-x64-baseline/bun', '--smol', '--no-env-file', '/opt/bend/bend2/main.ts']
        argv = [compiler + ['/work/tests/xml/probe.bend', '--check-only'],
                compiler + ['/work/tests/xml/probe.bend', '-o', '/work/build/xml/probe.c'],
                ['/usr/bin/clang-19', '-std=c11', '-O3', '/work/build/xml/probe.c', '-lpthread', '-lm', '-o', '/work/build/xml/probe']]
        probe = {'probe': 'probe', 'source_sha256': digest(source), 'steps': [{'argv': c, 'exit': 0} for c in argv]}
        controls = [{'file': n + '.bend', 'control': n.endswith('_control'), 'sha256': digest(negative / (n + '.bend')),
                     'exit': 0 if n.endswith('_control') else 1, 'diagnostic': 'consumed more than once'} for n in ('owner', 'owner_control')]
        build = {'build_complete': True, 'provenance': {'packages_sha256': 'packages', 'compiler_tree_sha256': 'compiler', 'bun_binary_sha256': 'bun'},
                 'probes': [probe], 'ownership_checks': controls}
        mutations(build, [lambda v: v.update(build_complete=False), lambda v: v['provenance'].update(compiler_tree_sha256='old'),
                          lambda v: v['probes'][0].update(source_sha256='old'), lambda v: v['probes'][0]['steps'].pop(),
                          lambda v: v['probes'][0]['steps'][0].update(exit=1), lambda v: v['probes'][0]['steps'][2].update(argv=['clang']),
                          lambda v: v['ownership_checks'].pop(), lambda v: v['ownership_checks'][0].update(exit=0),
                          lambda v: v['ownership_checks'][0].update(diagnostic='compiler crashed'),
                          lambda v: v['ownership_checks'][0].update(sha256='old'), lambda v: v['ownership_checks'][1].update(exit=1)],
                  lambda v: validate_build(v, lock, {'probe'}, {'owner'}, root))
        (root / 'build/xml').mkdir(parents=True)
        p = root / 'build/xml/summary.json'
        p.write_text('{"complete":true}')
        invalidate_summary(root)
        assert json.loads(p.read_text())['complete'] is False
    # Verify the actual freshness reader, including emitted C and executable
    # contents, without invoking Docker or a compiler.
    import experiment
    with tempfile.TemporaryDirectory() as temporary:
        root = Path(temporary)
        for d in DIRECTORIES:
            (root / d).mkdir(parents=True, exist_ok=True)
        for name in FILES:
            p = root / name
            p.parent.mkdir(parents=True, exist_ok=True)
            p.write_text('fixture')
        out = root / 'build/xml'
        out.mkdir(parents=True)
        (out / 'probe.c').write_text('generated C')
        (out / 'probe').write_text('native binary')
        snapshot = inputs(root)
        build = {'build_complete': True, 'inputs': snapshot, 'probes': [{'probe': 'probe',
                 'c_sha256': digest(out / 'probe.c'), 'binary_sha256': digest(out / 'probe')}]}
        (out / 'build.json').write_text(json.dumps(build))
        environment = {'inputs': snapshot, 'build_sha256': digest(out / 'build.json')}
        (out / 'environment.json').write_text(json.dumps(environment))
        with patch.object(experiment, 'ROOT', root):
            assert experiment.verified_build() == {'probe': digest(out / 'probe')}
            (out / 'probe.c').write_text('stale C')
            rejected(experiment.verified_build)
            (out / 'probe.c').write_text('generated C')
            (out / 'probe').write_text('stale binary')
            rejected(experiment.verified_build)
            (out / 'probe').write_text('native binary')
            (root / 'xml/new.bend').write_text('new source')
            rejected(experiment.verified_build)
            (root / 'xml/new.bend').unlink()
            (out / 'environment.json').write_text('{}')
            rejected(experiment.verified_build)
            (out / 'environment.json').write_text(json.dumps(environment))
            changed = {**build, 'build_complete': False}
            (out / 'build.json').write_text(json.dumps(changed))
            rejected(experiment.verified_build)
    # Real parser/oracle semantics, tiny finite mocked inventory: no native or
    # Docker execution is fabricated as actual acceptance evidence by this test.
    from cases import document
    from oracle import result
    from digest import digest as typed_digest
    from differential import logical_bytes
    raw = document('').encode()
    case = {'name': 'unit', 'raw': raw, 'accepted': True, 'group': 'fixed'}
    checksum, n = typed_digest(raw)
    stdout = f'ok {checksum} {n} {logical_bytes(raw)} 1000 balanced\n'
    oracle = {'complete': True, 'locked_technical_validation': True, 'acceptance_complete': False,
              'producer_export': producer_status(), 'seed': 5005, 'real_files': [], 'inputs': {'a': 'b'},
              'binaries': {'driver': 'd', 'positions': 'p'},
              'metadata': {'uid': 1000, 'memory.max': '1073741824', 'memory.swap.max': '0', 'packages_sha256': 'packages',
                           'runtime_args': RTS, 'python_version': '3.test', 'expat_version': 'test', 'machine': 'x86_64', 'system': 'Linux'},
              'cases': [{'name': 'unit', 'group': 'fixed', 'sha256': hashlib.sha256(raw).hexdigest(), 'raw_hex': raw.hex(),
                         'oracle': result(raw), 'runs': [{'chunk': c, 'exit': 0, 'stderr': '', 'stdout': f'ok {checksum} {n} {logical_bytes(raw)} {1000 + input_initialization_work(len(raw), c)} balanced\n',
                                   'actual': {'accepted': True, 'digest': checksum, 'count': n, 'logical': logical_bytes(raw),
                                              'work': 1000 + input_initialization_work(len(raw), c)}} for c in schedules(raw)]}]}
    with patch('cases.corpus', return_value=[case]):
        mutations(oracle, [lambda v: v.update(complete=False), lambda v: v.update(locked_technical_validation=False),
                           lambda v: v.update(acceptance_complete=True), lambda v: v.update(inputs={}),
                           lambda v: v.update(seed=4), lambda v: v['binaries'].update(driver='stale'),
                           lambda v: v['metadata'].update({'memory.swap.max': '1'}), lambda v: v['metadata'].update(packages_sha256='stale'),
                           lambda v: v['metadata'].update(runtime_args=[]), lambda v: v['cases'].clear(),
                           lambda v: v['cases'].append(copy.deepcopy(v['cases'][0])),
                           lambda v: v['cases'][0].update(sha256='stale'), lambda v: v['cases'][0].update(raw_hex='00'),
                           lambda v: v['cases'][0]['runs'].pop(), lambda v: v['cases'][0]['runs'].append(v['cases'][0]['runs'][0]),
                           lambda v: v['cases'][0]['runs'][0].update(stdout='ok 0 0 0 0 balanced\n'),
                           lambda v: v['cases'][0]['runs'][0].update(exit=1), lambda v: v['cases'][0]['runs'][0].update(stderr='oops'),
                           lambda v: v['producer_export'].update(status='passed')],
                  lambda v: validate_oracle(v, {'a': 'b'}, 'packages', {'driver': 'd', 'positions': 'p'}))
    # Finite limits and position reports use current authored manifests, not
    # sampled native output. They exercise validators without claiming runs.
    from integrity import ROOT
    manifest_path = ROOT / 'tests/xml/limit-cases.json'
    manifest = json.loads(manifest_path.read_text())
    def actual(raw, accepted):
        if accepted:
            h, count = typed_digest(raw)
            return {'accepted': True, 'digest': h, 'count': count, 'logical': logical_bytes(raw), 'work': 1000}
        return {'accepted': False, 'phase': 4, 'reason': 1, 'entry': 0, 'byte': 0, 'line': 1, 'column': 1, 'logical': 0, 'work': 999}
    limits = {'complete': True, 'binary_sha256': 'driver', 'manifest_sha256': digest(manifest_path),
              'cases': [], 'work_neighbors': [], 'live_neighbors': []}
    for c in manifest['cases']:
        raw_case = manifest['fixtures'][c['fixture']]['xml'].encode()
        for chunk in manifest['defaultChunkModes']:
            limits['cases'].append({'name': c['name'], 'chunk': chunk, 'actual': actual(raw_case, c['accepted'])})
    for fixture in ('base', 'reference', 'fuz'):
        raw_case = manifest['fixtures'][fixture]['xml'].encode()
        for chunk in (1, 7, 65536):
            baseline = actual(raw_case, True)
            limits['work_neighbors'].append({'fixture': fixture, 'chunk': chunk, 'baseline': baseline,
                                            'exact': baseline, 'under': actual(raw_case, False)})
    raw_case = manifest['fixtures']['base']['xml'].encode()
    limits['live_neighbors'].append({'exact_limit': 65537, 'under_limit': 65536,
                                    'exact': actual(raw_case, True), 'under': actual(raw_case, False)})
    mutations(limits, [lambda v: v.update(complete=False), lambda v: v.update(binary_sha256='old'),
                       lambda v: v.update(manifest_sha256='old'), lambda v: v['cases'].pop(),
                       lambda v: v['cases'].append(v['cases'][0]), lambda v: v['cases'][0]['actual'].update(accepted=True),
                       lambda v: v['work_neighbors'].pop(), lambda v: v['work_neighbors'][0].update(exact={}),
                       lambda v: v['work_neighbors'][0]['under'].update(accepted=True),
                       lambda v: v['live_neighbors'].clear(), lambda v: v['live_neighbors'][0].update(exact_limit=65538)],
              lambda v: validate_limits(v, ROOT, 'driver'))
    from positions import inventory
    position = {'complete': True, 'all_boundaries': True, 'binary_sha256': 'positions',
                'manifest_sha256': digest(ROOT / 'tests/xml/positions-golden.json'),
                'probe_sha256': digest(ROOT / 'tests/xml/positions.bend'),
                'runner_sha256': digest(ROOT / 'tools/xml/positions.py'), 'rows': []}
    for spec in inventory(True):
        item = {k: v for k, v in spec.items() if k != 'raw'}
        value = {'balanced': True, 'logical': 0, 'work': 1000, **spec['expected']}
        if value['kind'] == 'ok':
            h, entry_count = typed_digest(spec['raw'])
            value.update(digest=h, count=entry_count, logical=logical_bytes(spec['raw']))
        item.update(exit=0, stderr='', actual=value)
        position['rows'].append(item)
    mutations(position, [lambda v: v.update(all_boundaries=False), lambda v: v.update(binary_sha256='old'),
                         lambda v: v.update(manifest_sha256='old'), lambda v: v.update(probe_sha256='old'),
                         lambda v: v.update(runner_sha256='old'), lambda v: v['rows'].pop(),
                         lambda v: v['rows'].append(v['rows'][0]), lambda v: v['rows'][0].update(fixture_sha256='old'),
                         lambda v: v['rows'][0].update(override=[10, 1]),
                         lambda v: v['rows'][0].update(exit=1), lambda v: v['rows'][0].update(stderr='failure'),
                         lambda v: v['rows'][0]['actual'].update(count=999),
                         lambda v: v['rows'][0]['actual'].update(balanced=False)],
              lambda v: validate_positions(v, ROOT, 'positions'))
    from resources import cases as resource_cases
    resource_inventory = resource_cases()
    observations = [copy.deepcopy(row) for _ in resource_inventory]
    for r in observations:
        r['seconds'] = 1
    profile = json.loads((ROOT / 'docs/xml/profile.json').read_text())
    resource_summary(resource_inventory, observations, profile)
    changed = copy.deepcopy(observations)
    changed[-1]['final_cgroup']['memory_peak'] = 1000000000
    rejected(lambda: resource_summary(resource_inventory, changed, profile))
    rejected(lambda: resource_summary(resource_inventory[1:], observations[1:], profile))
    rejected(lambda: resource_summary(resource_inventory, observations, {**profile, 'resource_repeats': 2}))
    for stdout in ('ok 0 0 0 0\n', 'ok 0 0 0 -1 balanced\n', 'ok 0 0 0 0 balanced\nextra\n'):
        rejected(lambda: parse(stdout))
    # Independent hand-checked streaming identities.
    assert stream_expected(147, 0, 1)['digest'] == 1777605405
    assert stream_expected(232, 1, 1)['digest'] == 944216725
    assert stream_expected(234, 3, 3)['digest'] == 3564119243
    assert stream_expected(235, 4, 4)['digest'] == 693955409
    print(count, 'XML evidence rejection regressions passed; no runtime acceptance claimed')


if __name__ == '__main__':
    main()
