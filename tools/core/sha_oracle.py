"""Development differential checks; resource acceptance is a separate harness."""
import hashlib
import json
import os
from pathlib import Path
import subprocess

ROOT = Path('/work')
OUT = Path(os.environ.get('CORE_REPORT_DIR', str(ROOT / 'build/core')))
results = []
for length in [0, 1, 55, 56, 63, 64, 65, 65535, 65536, 65537, 1000000]:
    for chunk in ([1, 63, 65536] if length < 1000000 else [65536]):
        p = subprocess.run([str(ROOT / 'build/core/sha'), '+RTS', '--threads', '1',
                            '--gpu', 'off', '-RTS', '97', str(length), str(chunk)],
                           capture_output=True, text=True, timeout=90)
        lines = p.stdout.splitlines()
        actual = bytes(map(int, lines[:-1])).hex() if p.returncode == 0 and lines[-1:] == ['done'] else ''
        expected = hashlib.sha256(b'a' * length).hexdigest()
        result = {'length': length, 'chunk': chunk, 'exit': p.returncode,
                  'digest': actual, 'expected': expected, 'stderr': p.stderr,
                  'pass': actual == expected and not p.stderr}
        results.append(result)
        print(length, chunk, result['pass'], flush=True)
        if not result['pass']:
            print(p.stdout, p.stderr)
            break
out = {'acceptance_complete': False,
       'binary_sha256': hashlib.sha256((ROOT / 'build/core/sha').read_bytes()).hexdigest(),
       'oracle_sha256': hashlib.sha256(Path(__file__).read_bytes()).hexdigest(), 'vectors': results}
(OUT / 'sha-vectors.json').write_text(json.dumps(out, indent=2) + '\n')
if len(results) != 31 or not all(r['pass'] for r in results):
    raise SystemExit(1)
