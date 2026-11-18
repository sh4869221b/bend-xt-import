"""Local locked-compiler smoke builds; never an acceptance manifest."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess
from integrity import ROOT,digest,inputs


def tree_digest(root):
    h=hashlib.sha256()
    for p in sorted(root.rglob('*')):
        if p.is_symlink():raise RuntimeError('symlinked compiler tree')
        if p.is_file():h.update(p.relative_to(root).as_posix().encode()+b'\0');h.update(hashlib.sha256(p.read_bytes()).digest())
    return h.hexdigest()


def main():
    p=argparse.ArgumentParser();p.add_argument('names',nargs='*')
    p.add_argument('--bun',type=Path,default=ROOT/'.cache/bun/bun-linux-x64-baseline/bun')
    p.add_argument('--compiler',type=Path,default=ROOT/'.cache/bend/bend2/main.ts')
    p.add_argument('--cc',type=Path,default=ROOT/'.cache/clang/usr/bin/clang-19')
    p.add_argument('--library-path',type=Path,default=ROOT/'.cache/clang/usr/lib/x86_64-linux-gnu')
    args=p.parse_args();lock=json.loads((ROOT/'sources.lock').read_text())
    if digest(args.bun)!=lock['bun_binary_sha256'] or tree_digest(args.compiler.parent)!=lock['compiler_tree_sha256']:
        raise RuntimeError('local Bend/Bun differs from sources.lock')
    from case_spec import ENTRYPOINTS,OWNERS
    snapshot=inputs(ROOT)
    names=args.names or sorted(ENTRYPOINTS)
    if not set(names)<=ENTRYPOINTS:raise RuntimeError('unknown native entrypoint')
    env=dict(os.environ,BEND_NO_TELEMETRY='1',CC=str(args.cc.resolve()),LD_LIBRARY_PATH=str(args.library_path.resolve()))
    out=ROOT/'build/xml';out.mkdir(parents=True,exist_ok=True)
    cmd=[str(args.bun.resolve()),'--smol','--no-env-file',str(args.compiler.resolve())]
    records=[]
    for name in names:
        path=ROOT/'tests/xml'/(name+'.bend')
        record={'probe':name,'source_sha256':digest(path),'acceptance_complete':False,'steps':[]}
        commands=[cmd+[str(path),'--check-only'],cmd+[str(path),'-o',str(out/(name+'.c'))],
                  [str(args.cc.resolve()),'-std=c11','-O3',str(out/(name+'.c')),'-lpthread','-lm','-o',str(out/name)]]
        for command in commands:
            run=subprocess.run(command,env=env,cwd=ROOT,capture_output=True,text=True,timeout=300)
            record['steps'].append({'argv':command,'exit':run.returncode,'stdout':run.stdout,'stderr':run.stderr})
            if run.returncode:
                (out/'development-failure.json').write_text(json.dumps(record,indent=2)+'\n')
                raise RuntimeError(name+': exit='+str(run.returncode)+' argv='+str(command)+'\n'+run.stdout+run.stderr)
        record.update(c_sha256=digest(out/(name+'.c')),binary_sha256=digest(out/name));records.append(record)
        print(name,'local build passed',flush=True)
    for name in sorted(OWNERS|{n+'_control' for n in OWNERS}):
        path=ROOT/'tests/xml/negative'/(name+'.bend')
        run=subprocess.run(cmd+[str(path),'--check-only'],env=env,cwd=ROOT,capture_output=True,text=True,timeout=120)
        control=name.endswith('_control');diagnostic=run.stdout+run.stderr
        if (control and run.returncode) or (not control and (run.returncode==0 or 'consumed more than once' not in diagnostic)):
            raise RuntimeError(name+': '+diagnostic)
    if inputs(ROOT)!=snapshot:raise RuntimeError('inputs changed during local build')
    (out/'development.json').write_text(json.dumps({'acceptance_complete':False,'inputs':snapshot,'probes':records},indent=2)+'\n')
    print('Development checks only; locked Docker/cgroup acceptance is still required.')
if __name__=='__main__':main()
