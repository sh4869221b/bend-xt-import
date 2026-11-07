"""Run independent Python oracles inside the locked, bounded native userland."""
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
from integrity import inputs, digest

ROOT = Path('/work')
OUT = Path('/reports')


def main():
    metadata = {'uid':os.getuid(), 'cgroup':Path('/proc/self/cgroup').read_text(),
                'memory.max':Path('/sys/fs/cgroup/memory.max').read_text().strip(),
                'memory.swap.max':Path('/sys/fs/cgroup/memory.swap.max').read_text().strip(),
                'packages_sha256':digest('/opt/packages.lock')}
    lock = json.loads((ROOT / 'sources.lock').read_text())
    if metadata['uid']==0 or metadata['memory.max']!='1073741824' or metadata['memory.swap.max']!='0' or metadata['packages_sha256']!=lock['probe_image']['packages_sha256']:
        raise RuntimeError('oracle execution profile not established before native exec')
    snapshot = inputs(ROOT)
    result = {'complete':False, 'metadata':metadata, 'inputs':snapshot, 'reports':{}, 'commands':[]}
    target = OUT / 'oracle-suite.json'
    target.write_text(json.dumps(result,indent=2)+'\n')
    env = os.environ.copy()
    env['CORE_REPORT_DIR'] = str(OUT)
    for name,report,count,field in [('codec_oracle.py','codec-vectors.json',705,'cases'),('sha_oracle.py','sha-vectors.json',31,'vectors')]:
        cmd = [sys.executable, str(ROOT / 'tools/core' / name)]
        run = subprocess.run(cmd,env=env,capture_output=True,text=True,timeout=300)
        result['commands'].append({'argv':cmd,'exit':run.returncode,'stdout':run.stdout,'stderr':run.stderr})
        target.write_text(json.dumps(result,indent=2)+'\n')
        if run.returncode: raise RuntimeError(name+' failed: '+run.stdout+run.stderr)
        data = json.loads((OUT / report).read_text())
        if len(data[field])!=count or not all(r['pass'] for r in data[field]):
            raise RuntimeError('oracle inventory/result incomplete')
        binary = ROOT / 'build/core' / ('codecs' if field=='cases' else 'sha')
        if data['binary_sha256']!=digest(binary): raise RuntimeError('oracle binary identity differs')
        result['reports'][report] = digest(OUT / report)
    if inputs(ROOT)!=snapshot: raise RuntimeError('oracle source inputs changed')
    result['complete'] = True
    target.write_text(json.dumps(result,indent=2)+'\n')
    print('736 independent oracle cases passed')

if __name__ == '__main__': main()
