"""Fail-closed validation. Synthetic technical success never clears provenance."""
from pathlib import Path
import hashlib
import json
import re
from integrity import digest


def require_inventory(actual, expected):
    if len(actual) != len(set(actual)) or set(actual) != set(expected):
        raise ValueError('missing, duplicate, or unexpected case')


def validate_identity(suite, current, build_hash, environment_hash):
    if suite.get('complete') is not True or suite.get('inputs') != current or suite.get('build_sha256') != build_hash or suite.get('environment_sha256') != environment_hash:
        raise ValueError('partial, stale, or mixed evidence')


def validate_binary(row, binaries):
    if row.get('probe') not in binaries or row.get('binary_sha256') != binaries[row['probe']]:
        raise ValueError('binary identity differs')


def check_observation(row):
    if row['exit'] != 0 or row['docker_client_exit'] != 0 or row['timed_out'] or row['external_kill'] or row['oom_killed'] or row['stderr']:
        raise ValueError('native program failed')
    if row['limits'] != {'memory.max': '1073741824', 'memory.swap.max': '0'}:
        raise ValueError('external resource ceiling not proven')
    if not re.fullmatch(r'[0-9a-f]{64}', row.get('container_id', '')) or type(row.get('native_host_pid')) is not int or row['native_host_pid'] <= 0:
        raise ValueError('missing container/native process identity')
    if not row.get('cgroup_path', '').startswith('/sys/fs/cgroup/') or '..' in Path(row['cgroup_path']).parts:
        raise ValueError('missing/invalid observed cgroup identity')
    if row['ready']['uid'] == 0 or row['ready']['pid'] <= 0 or row['native_result'] is None or row['final_cgroup'] is None:
        raise ValueError('native identity/final observation missing')
    if row['native_result']['exit'] != 0 or row['native_result']['signal'] is not None:
        raise ValueError('native exit failed')
    if type(row['native_result']['maxrss_bytes']) is not int or not 0 < row['native_result']['maxrss_bytes'] < 1073741824:
        raise ValueError('missing/excessive native RSS')
    if any(row['final_cgroup']['events'][k] != row['events_before'][k] for k in ('oom', 'oom_kill', 'max')):
        raise ValueError('resource ceiling hit')
    if type(row['final_cgroup']['memory_peak']) is not int or not 0 < row['final_cgroup']['memory_peak'] < 1073741824:
        raise ValueError('missing/excessive cgroup peak')
    if row['ready']['memory.max'].strip() != '1073741824' or row['ready']['memory.swap.max'].strip() != '0':
        raise ValueError('pre-exec ceiling differs')


def contained(root, path):
    original = root / path
    resolved = original.resolve()
    if not resolved.is_relative_to((root / 'runs/xml').resolve()) or original.is_symlink() or any(p.is_symlink() for p in original.parents if p.is_relative_to(root)):
        raise ValueError('evidence path outside XML runs')
    return resolved


def claim_run(root, path, row, seen):
    canonical = contained(root, path)
    scratch = row.get('scratch')
    if canonical.name != 'observation.json' or scratch != canonical.parent.name:
        raise ValueError('observation scratch identity differs')
    container = row.get('container_id', '')
    if not re.fullmatch(r'[0-9a-f]{64}', container):
        raise ValueError('missing independent container identity')
    identity = (str(canonical), scratch, container)
    if any(identity[0] == p or identity[1] == r or identity[2] == c for p, r, c in seen):
        raise ValueError('observation reused across independent runs')
    seen.add(identity)


def validate_build(build, lock, entrypoints, owners, root):
    provenance = {'packages_sha256': lock['build_image']['packages_sha256'],
                  'compiler_tree_sha256': lock['compiler_tree_sha256'], 'bun_binary_sha256': lock['bun_binary_sha256']}
    if build.get('build_complete') is not True or build.get('provenance') != provenance:
        raise ValueError('unverified compiler or build package identity')
    require_inventory([p['probe'] for p in build['probes']], entrypoints)
    compiler = ['/opt/bun/bun-linux-x64-baseline/bun', '--smol', '--no-env-file', '/opt/bend/bend2/main.ts']
    for probe in build['probes']:
        name = probe['probe']
        if probe['source_sha256'] != digest(root / 'tests/xml' / (name + '.bend')):
            raise ValueError('test source identity differs')
        expected = [compiler + ['/work/tests/xml/' + name + '.bend', '--check-only'],
                    compiler + ['/work/tests/xml/' + name + '.bend', '-o', '/work/build/xml/' + name + '.c'],
                    ['/usr/bin/clang-19', '-std=c11', '-O3', '/work/build/xml/' + name + '.c', '-lpthread', '-lm', '-o', '/work/build/xml/' + name]]
        if len(probe['steps']) != 3 or any(s['argv'] != argv or s['exit'] != 0 for s, argv in zip(probe['steps'], expected)):
            raise ValueError('incomplete/failed compiler step')
    names = owners | {n + '_control' for n in owners}
    require_inventory([p['file'] for p in build['ownership_checks']], {n + '.bend' for n in names})
    for c in build['ownership_checks']:
        control = c['file'].endswith('_control.bend')
        if c['control'] != control or c['sha256'] != digest(root / 'tests/xml/negative' / c['file']):
            raise ValueError('affine control identity differs')
        if (control and c['exit'] != 0) or (not control and (c['exit'] == 0 or 'consumed more than once' not in c['diagnostic'])):
            raise ValueError('affine compiler result differs')


def producer_status():
    return {'status': 'blocked_missing_fixture', 'acceptance_complete': False,
            'pinned_revision': '9aa38d60860273401f8bb0dd1557c82a295c41b3',
            'verified_fixtures': [],
            'reason': 'No intact pinned-producer export with verified build identity is available for permitted verification.'}


def validate_producer(value):
    # There is intentionally no flag-only path to certify an unprovided fixture.
    # Adding real acceptance requires a reviewed manifest/capture validator.
    if value != producer_status():
        raise ValueError('unsupported/falsified pinned-producer acceptance')


def validate_oracle(suite, current, packages, binaries):
    from cases import corpus
    from checks import schedules, verify_fixture, RTS, partition_key
    from oracle import result
    if suite.get('complete') is not True or suite.get('locked_technical_validation') is not True or suite.get('inputs') != current:
        raise ValueError('partial/local/stale oracle evidence')
    if suite.get('acceptance_complete') is not False:
        raise ValueError('oracle cannot certify producer acceptance')
    validate_producer(suite['producer_export'])
    if suite.get('seed') != 5005 or suite.get('real_files') != []:
        raise ValueError('unknown seed or unconfigured real-file fixture')
    m = suite['metadata']
    if m['uid'] == 0 or m['memory.max'] != '1073741824' or m['memory.swap.max'] != '0' or m['packages_sha256'] != packages or m['runtime_args'] != RTS:
        raise ValueError('oracle execution profile differs')
    if not m['python_version'] or not m['expat_version'] or m['machine'] != 'x86_64' or m['system'] != 'Linux':
        raise ValueError('missing oracle implementation/platform identity')
    if suite['binaries'] != {k: binaries[k] for k in ('driver', 'positions')}:
        raise ValueError('oracle native binaries differ')
    expected = {c['name']: c for c in corpus()}
    require_inventory([c['name'] for c in suite['cases']], expected)
    for c in suite['cases']:
        spec = expected[c['name']]
        raw = spec['raw']
        if c['sha256'] != hashlib.sha256(raw).hexdigest() or c['raw_hex'] != raw.hex() or c['group'] != spec['group']:
            raise ValueError('oracle fixture/replay identity differs')
        independent = result(raw)
        comparable = ('accepted', 'value') if spec['accepted'] else ('accepted', 'category')
        if any(c['oracle'].get(k) != independent.get(k) for k in comparable) or c['oracle']['accepted'] is not spec['accepted']:
            raise ValueError('oracle result differs from explicit expectation')
        require_inventory([r['chunk'] for r in c['runs']], schedules(raw))
        first = None
        for row in c['runs']:
            if row['exit'] != 0 or row['stderr']:
                raise ValueError('native differential run failed')
            actual = verify_fixture(raw, row['stdout'], spec['accepted'])
            if row.get('actual') != actual or c.get('first_difference') is not None:
                raise ValueError('oracle actual/result mismatch or recorded difference')
            # Remove the independently computed input-capacity initialization.
            # Invalid input may stop before later chunks are allocated.
            semantic = partition_key(actual, len(raw), row['chunk'])
            if first is not None and semantic != first:
                raise ValueError('partition-dependent content, diagnostics, or successful work')
            first = semantic


def validate_limits(data, root, binary_hash):
    from checks import verify_fixture
    from digest import digest as typed_digest
    from differential import logical_bytes
    path = root / 'tests/xml/limit-cases.json'
    manifest = json.loads(path.read_text())
    if data.get('complete') is not True or data['binary_sha256'] != binary_hash or data['manifest_sha256'] != digest(path):
        raise ValueError('partial/stale limits')
    specs = {(c['name'], chunk): c for c in manifest['cases'] for chunk in manifest['defaultChunkModes']}
    require_inventory([(c['name'], c['chunk']) for c in data['cases']], specs)
    def checked(actual, raw, accepted):
        fields = ('digest', 'count', 'logical', 'work') if accepted else ('phase', 'reason', 'entry', 'byte', 'line', 'column', 'logical', 'work')
        if set(actual) != {'accepted', *fields} or any(type(actual[k]) is not int or not 0 <= actual[k] <= 0xffffffff for k in fields):
            raise ValueError('invalid limit result fields')
        if actual['accepted'] is not accepted:
            raise ValueError('limit acceptance differs')
        if accepted and (actual['digest'], actual['count'], actual['logical']) != (*typed_digest(raw), logical_bytes(raw)):
            raise ValueError('limit typed result differs')
        if not accepted and not 0 <= actual['byte'] <= len(raw):
            raise ValueError('limit error outside source')
    for c in data['cases']:
        spec = specs[c['name'], c['chunk']]
        checked(c['actual'], manifest['fixtures'][spec['fixture']]['xml'].encode(), spec['accepted'])
    require_inventory([(c['fixture'], c['chunk']) for c in data['work_neighbors']],
                      [(f, chunk) for f in ('base', 'reference', 'fuz') for chunk in (1, 7, 65536)])
    for c in data['work_neighbors']:
        raw = manifest['fixtures'][c['fixture']]['xml'].encode()
        checked(c['baseline'], raw, True)
        checked(c['under'], raw, False)
        if c['exact'] != c['baseline'] or c['under']['accepted'] or c['under']['work'] > c['baseline']['work'] - 1:
            raise ValueError('incomplete exact-work neighbors')
    if len(data['live_neighbors']) != 1:
        raise ValueError('missing/duplicate live neighbor')
    c = data['live_neighbors'][0]
    raw = manifest['fixtures']['base']['xml'].encode()
    checked(c['exact'], raw, True)
    checked(c['under'], raw, False)
    if c['exact_limit'] != c['under_limit'] + 1 or not 65536 < c['exact_limit'] <= 268435456 or not c['exact']['accepted'] or c['under']['accepted']:
        raise ValueError('invalid exact-live neighbors')


def validate_positions(data, root, binary_hash):
    from positions import inventory
    for field, path in [('manifest_sha256', 'tests/xml/positions-golden.json'),
                        ('probe_sha256', 'tests/xml/positions.bend'), ('runner_sha256', 'tools/xml/positions.py')]:
        if data[field] != digest(root / path):
            raise ValueError('stale position fixture/probe/runner')
    if data.get('complete') is not True or data.get('all_boundaries') is not True or data['binary_sha256'] != binary_hash:
        raise ValueError('partial/stale position suite')
    expected = {(c['name'], c['chunk']): c for c in inventory(True)}
    require_inventory([(c['name'], c['chunk']) for c in data['rows']], expected)
    baselines = {}
    for c in data['rows']:
        spec = expected[c['name'], c['chunk']]
        if any(c[k] != v for k, v in spec.items() if k != 'raw') or c['exit'] != 0 or c['stderr']:
            raise ValueError('position result/fixture differs')
        actual = c['actual']
        if actual.get('balanced') is not True or any(actual.get(k) != v for k, v in spec['expected'].items()):
            raise ValueError('position golden mismatch')
        if actual['kind'] == 'ok':
            from digest import digest as typed_digest
            from differential import logical_bytes
            if (actual['digest'], actual['count'], actual['logical']) != (*typed_digest(spec['raw']), logical_bytes(spec['raw'])):
                raise ValueError('position typed content differs')
        stable = {k: v for k, v in actual.items() if k != 'work'}
        if stable != baselines.setdefault(c['name'], stable):
            raise ValueError('position partition-dependent result')
