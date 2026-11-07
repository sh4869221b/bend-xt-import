"""Build the parser with the existing locked userlands, separately from Issue #1 and #2."""
import argparse
import json
import os
from pathlib import Path
import platform
import subprocess
import sys
from experiment import docker, docker_env
from integrity import invalidate_summary, ROOT, inputs, digest


def main():
    invalidate_summary()
    parser = argparse.ArgumentParser()
    parser.add_argument('--cache', type=Path, default=ROOT / '.cache/downloads')
    parser.add_argument('--ca', type=Path, default=Path('/etc/ssl/certs/ca-certificates.crt'))
    parser.add_argument('--reuse-images', action='store_true', help='verify and reuse locally built locked images')
    args = parser.parse_args()
    if platform.system() != 'Linux' or platform.machine() != 'x86_64' or os.getuid() == 0:
        raise SystemExit('requires non-root Linux x86_64 with local Docker access')
    env = docker_env()
    env['BUILDX_CONFIG'] = str(ROOT / '.cache/plugin-buildx')
    if not args.reuse_images:
        subprocess.run([sys.executable, str(ROOT / 'tools/runtime/fetch_toolchain.py'),
                        '--cache', str(args.cache)], check=True)
        for target, tag in [('build','bend-xt-runtime:issue1'), ('probe','bend-xt-probe:issue1')]:
            subprocess.run(['docker','--host=unix:///var/run/docker.sock','build','--target',target,
                            '--secret',f'id=proxy_ca,src={args.ca.resolve()}',
                            '-f',str(ROOT / 'tools/runtime/Dockerfile'),'-t',tag,str(args.cache.resolve())],
                           env=env,check=True,timeout=1200)
    before = inputs(ROOT)
    head = subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip()
    dirty = bool(subprocess.check_output(['git','status','--porcelain'],cwd=ROOT))
    subprocess.run(['docker','--host=unix:///var/run/docker.sock','run','--rm','--network','none',
                    '--user',f'{os.getuid()}:{os.getgid()}','--cap-drop','ALL',
                    '--mount',f'type=bind,src={ROOT},dst=/work','--workdir','/opt/bend',
                    'bend-xt-runtime:issue1','python3','/work/tools/plugin/build.py'],
                   env=env,check=True,timeout=2400)
    if inputs(ROOT) != before or subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip() != head:
        raise RuntimeError('sources or git head changed during build')
    packages = docker('run','--rm','--network','none','bend-xt-probe:issue1','cat','/opt/packages.lock').stdout
    import hashlib
    lock = json.loads((ROOT / 'sources.lock').read_text())
    if hashlib.sha256(packages).hexdigest() != lock['probe_image']['packages_sha256']:
        raise RuntimeError('probe userland differs from lock')
    images = json.loads(docker('image','inspect','bend-xt-runtime:issue1','bend-xt-probe:issue1').stdout)
    environment = {'git_head':head,'dirty_worktree':dirty,'inputs':before,
                   'kernel':platform.release(),'machine':platform.machine(),'host_python':platform.python_version(),
                   'images':[{'id':x['Id'],'architecture':x['Architecture'],'os':x['Os']} for x in images],
                   'build_sha256':digest(ROOT / 'build/plugin/build.json')}
    (ROOT / 'build/plugin/environment.json').write_text(json.dumps(environment,indent=2)+'\n')

if __name__ == '__main__': main()
