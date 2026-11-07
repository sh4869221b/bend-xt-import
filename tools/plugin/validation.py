"""Fail-closed identities and observations used by parser evidence gates."""
import base64
from pathlib import Path

def require_inventory(actual,expected):
    if len(actual)!=len(set(actual)) or set(actual)!=set(expected):
        raise ValueError('missing, duplicate or unexpected case')

def validate_identity(suite,current,build_hash,environment_hash):
    if suite.get('complete') is not True or suite.get('inputs')!=current or suite.get('build_sha256')!=build_hash or suite.get('environment_sha256')!=environment_hash:
        raise ValueError('partial, stale or mixed evidence')

def validate_binary(row,binaries):
    if row.get('probe') not in binaries or row.get('binary_sha256')!=binaries[row['probe']]:
        raise ValueError('binary identity differs')

def check_observation(row):
    if row['exit']!=0 or row['docker_client_exit']!=0 or row['timed_out'] or row['external_kill'] or row['oom_killed'] or row['stderr']:
        raise AssertionError('native program failed')
    if row['limits']!={'memory.max':'1073741824','memory.swap.max':'0'}:
        raise AssertionError('resource ceiling not proven')
    if row['ready']['uid']==0 or row['native_result'] is None or row['final_cgroup'] is None:
        raise AssertionError('native identity/final observation missing')
    if row['native_result']['exit']!=0 or row['native_result']['signal'] is not None:
        raise AssertionError('native exit not successful')
    if any(row['final_cgroup']['events'][k]!=row['events_before'][k] for k in ['oom','oom_kill','max']):
        raise AssertionError('memory ceiling hit')
    if not 0<row['final_cgroup']['memory_peak']<1073741824:
        raise AssertionError('invalid or excessive memory peak')

def validate_oracle(suite,current,packages):
    if suite.get('complete') is not True or suite['inputs']!=current:
        raise ValueError('partial or stale oracle')
    m=suite['metadata']
    if m['uid']==0 or m['memory.max']!='1073741824' or m['memory.swap.max']!='0' or m['packages_sha256']!=packages:
        raise ValueError('oracle execution profile differs')

def contained(root,path):
    original=root/path;resolved=original.resolve()
    if not resolved.is_relative_to((root/'runs/plugin').resolve()) or original.is_symlink() or any(p.is_symlink() for p in original.parents if p.is_relative_to(root)):
        raise ValueError('evidence path outside parser runs')
    return resolved


def validate_build(build,lock,entrypoints,owners,root):
    expected_provenance={'packages_sha256':lock['build_image']['packages_sha256'],
                         'compiler_tree_sha256':lock['compiler_tree_sha256'],'bun_binary_sha256':lock['bun_binary_sha256']}
    if build.get('build_complete') is not True or build.get('provenance')!=expected_provenance:
        raise ValueError('unverified compiler/package provenance')
    require_inventory([p['probe'] for p in build['probes']],entrypoints)
    compiler=['/opt/bun/bun-linux-x64-baseline/bun','--no-env-file','/opt/bend/bend2/main.ts']
    from integrity import digest
    for probe in build['probes']:
        name=probe['probe'];path=root/'tests/plugin'/(name+'.bend')
        if probe['source_sha256']!=digest(path):raise ValueError('test source identity differs')
        expected=[compiler+['/work/tests/plugin/'+name+'.bend',*flags] for flags in
                  [['--check-only'],['-o','/work/build/plugin/'+name+'.c'],['-o','/work/build/plugin/'+name]]]
        if len(probe['steps'])!=3 or any(step['argv']!=argv or step['exit']!=0 for step,argv in zip(probe['steps'],expected)):
            raise ValueError('incomplete or failed compiler step')
    names=owners|{n+'_control' for n in owners}
    require_inventory([p['file'] for p in build['ownership_checks']],{n+'.bend' for n in names})
    for check in build['ownership_checks']:
        control=check['file'].endswith('_control.bend')
        if check['control']!=control or check['sha256']!=digest(root/'tests/plugin/negative'/check['file']):
            raise ValueError('affine control identity differs')
        if (control and check['exit']!=0) or (not control and (check['exit']==0 or 'consumed more than once' not in check['diagnostic'])):
            raise ValueError('affine compile evidence differs')


def claim_run(root,path,row,seen):
    """Each accepted observation must represent a separate captured process."""
    canonical=contained(root,path)
    scratch=row.get('scratch')
    if canonical.name!='observation.json' or scratch!=canonical.parent.name:
        raise ValueError('observation scratch identity differs')
    identity=(str(canonical),scratch)
    if any(identity[0]==p or identity[1]==r for p,r in seen):
        raise ValueError('observation reused across independent runs')
    seen.add(identity)
