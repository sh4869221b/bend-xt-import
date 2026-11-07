"""Strict independent Python codec oracle; not resource calibration."""
import hashlib
import json
import os
from pathlib import Path
import subprocess

ROOT = Path('/work')
OUT = Path(os.environ.get('CORE_REPORT_DIR', str(ROOT / 'build/core')))
BIN = ROOT / 'build/core/codecs'
records = []

def run(mode, kind, value):
    p = subprocess.run([str(BIN), '+RTS', '--threads', '1', '--gpu', 'off', '-RTS',
                        mode, str(kind), str(value)], capture_output=True, text=True, timeout=10)
    return p

def decode(kind, data):
    encoding = ['utf-8', 'cp1252'][kind]
    try:
        expected = [ord(c) for c in data.decode(encoding, 'strict')]
        valid = True
    except UnicodeDecodeError:
        expected, valid = None, False
    p = run('decode', kind, data.hex())
    actual = [int(x) for x in p.stdout.splitlines()[:-1]] if p.returncode == 0 else None
    ok = (p.returncode == 0 and p.stdout.splitlines()[-1:] == ['done'] and actual == expected and not p.stderr) if valid else p.returncode == 3
    records.append({'mode': 'decode', 'kind': kind, 'hex': data.hex(), 'valid': valid,
                    'exit': p.returncode, 'stdout': p.stdout, 'stderr': p.stderr, 'pass': ok})

def encode(kind, scalar):
    encoding = ['utf-8', 'cp1252'][kind]
    try:
        expected = chr(scalar).encode(encoding, 'strict')
        valid = True
    except (ValueError, UnicodeEncodeError):
        expected, valid = None, False
    p = run('encode', kind, scalar)
    values = [int(x) for x in p.stdout.splitlines()] if p.returncode == 0 else []
    actual = bytes(values[1:1+values[0]]) if values else None
    ok = (p.returncode == 0 and actual == expected and not p.stderr) if valid else p.returncode == 3
    records.append({'mode': 'encode', 'kind': kind, 'scalar': scalar, 'valid': valid,
                    'exit': p.returncode, 'stdout': p.stdout, 'stderr': p.stderr, 'pass': ok})

# Every byte, including all five undefined slots; reverse-map all 251 definitions.
for b in range(256):
    decode(1, bytes([b]))
    if b not in [0x81, 0x8d, 0x8f, 0x90, 0x9d]:
        encode(1, ord(bytes([b]).decode('cp1252')))
for scalar in [0x81, 0x8d, 0x8f, 0x90, 0x9d, 0x80, 0x100, 0x65e5, 0x1f600, 0xd800, 0x110000, 0xffffffff]:
    encode(1, scalar)
for scalar in [0,1,0x7f,0x80,0x7ff,0x800,0xd7ff,0xd800,0xdfff,0xe000,0xfeff,
               0xffff,0x10000,0x1f600,0x10ffff,0x110000,0xffffffff]:
    encode(0,scalar)
    if scalar <= 0x10ffff and not 0xd800 <= scalar <= 0xdfff:
        decode(0,chr(scalar).encode('utf-8'))
for data in [b'', b'abc\0xyz', '日本語\ufeff😀'.encode(), bytes(range(128))]:
    decode(0,data)
for leading in range(128,256):
    decode(0,bytes([leading]))
for hx in ['c080','c180','c2','c220','e08080','e09f80','eda080','edbfbf','e280',
           'e228a1','f0808080','f08fbfbf','f4908080','f5808080','f080','f09f98','f09f41a9',
           '808080','ff','fe','e0a080','ed9fbf','f0908080','f48fbfbf']:
    decode(0,bytes.fromhex(hx))
report = {'acceptance_complete': False,
          'binary_sha256': hashlib.sha256(BIN.read_bytes()).hexdigest(),
          'oracle_sha256': hashlib.sha256(Path(__file__).read_bytes()).hexdigest(), 'cases': records}
(OUT / 'codec-vectors.json').write_text(json.dumps(report,indent=2)+'\n')
failures = [r for r in records if not r['pass']]
print(f'{len(records)} codec oracle cases; {len(failures)} failures')
for r in failures: print(r)
if failures: raise SystemExit(1)
