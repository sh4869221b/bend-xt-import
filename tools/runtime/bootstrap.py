"""Fetch locked sources, build fixed userlands, and compile offline probes."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import platform
import subprocess
import sys
from experiment import ROOT, docker, docker_env


def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('--cache',type=Path,default=ROOT/'.cache/downloads')
    parser.add_argument('--ca',type=Path,default=Path('/etc/ssl/certs/ca-certificates.crt'))
    parser.add_argument('--no-cache',action='store_true')
    args=parser.parse_args()
    if platform.system()!='Linux' or platform.machine()!='x86_64':
        raise SystemExit('only Linux x86_64 has an experimental profile')
    if os.getuid()==0: raise SystemExit('run as a non-root user with access to the local Docker socket')
    (ROOT/'build/build.json').unlink(missing_ok=True)
    subprocess.run([sys.executable,str(ROOT/'tools/runtime/fetch_toolchain.py'),'--cache',str(args.cache)],check=True)
    env=docker_env()
    env['BUILDX_CONFIG']=str(ROOT/'.cache/buildx')
    for target,tag in [('build','bend-xt-runtime:issue1'),('probe','bend-xt-probe:issue1')]:
        cmd=['docker','--host=unix:///var/run/docker.sock','build','--target',target,
             '--secret',f'id=proxy_ca,src={args.ca.resolve()}',
             '-f',str(ROOT/'tools/runtime/Dockerfile'),'-t',tag]
        if args.no_cache: cmd+=['--no-cache']
        subprocess.run([*cmd,str(args.cache.resolve())],env=env,check=True,timeout=1200)
    subprocess.run(['docker','--host=unix:///var/run/docker.sock','run','--rm','--network','none',
        '--user',f'{os.getuid()}:{os.getgid()}','--cap-drop','ALL',
        '--mount',f'type=bind,src={ROOT},dst=/work','--workdir','/opt/bend',
        'bend-xt-runtime:issue1','python3','/work/tools/runtime/build_probes.py'],
        env=env,check=True,timeout=1800)
    # Native libc/userland is verified independently of the compiler image.
    packages=docker('run','--rm','--network','none','bend-xt-probe:issue1','cat','/opt/packages.lock').stdout
    lock=json.loads((ROOT/'sources.lock').read_text())
    if hashlib.sha256(packages).hexdigest()!=lock['probe_image']['packages_sha256']:
        raise SystemExit('probe image package mismatch')
    metadata={'kernel':platform.release(),'machine':platform.machine(),
        'host_python':platform.python_version(),'docker_version':docker('version','--format','{{json .}}').stdout.decode(),
        'images':json.loads(docker('image','inspect','bend-xt-runtime:issue1','bend-xt-probe:issue1').stdout)}
    # Keep only immutable IDs, not complete image configuration/environment.
    metadata['images']=[{'id':x['Id'],'architecture':x['Architecture'],'os':x['Os']} for x in metadata['images']]
    (ROOT/'build/environment.json').write_text(json.dumps(metadata,indent=2)+'\n')

if __name__=='__main__': main()
