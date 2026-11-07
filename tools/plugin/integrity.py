"""Exact input identities for Issue #4; never reuse core or host acceptance."""
import hashlib
from pathlib import Path
ROOT = Path(__file__).resolve().parents[2]
DIRECTORIES = ['core','hash','plugin','tests/plugin','tools/plugin','docs/plugin']
FILES = ['sources.lock','.github/workflows/plugin.yml','tools/core/lint.py',
         'tools/runtime/fetch_toolchain.py','tools/runtime/Dockerfile',
         'tools/runtime/verify_lock.py','tools/runtime/packages.lock',
         'tools/runtime/probe-packages.lock']

def digest(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()

def inputs(root=ROOT):
    paths = []
    for name in DIRECTORIES + FILES:
        p = root/name
        if not p.exists() or p.is_symlink():
            raise RuntimeError('missing or symlinked mandatory input: '+name)
        if any(a.is_symlink() for a in p.parents if a != root and a.is_relative_to(root)):
            raise RuntimeError('symlinked input ancestor: '+name)
    for name in DIRECTORIES:
        for p in (root/name).rglob('*'):
            if p.is_symlink():raise RuntimeError('symlinked source: '+str(p.relative_to(root)))
            if p.is_file() and '__pycache__' not in p.parts:paths.append(p)
    paths.extend(root/name for name in FILES)
    if any(p.is_symlink() for p in paths):
        raise RuntimeError('symlinked source')
    return {str(p.relative_to(root)):digest(p) for p in sorted(set(paths))}

def invalidate_summary(root=ROOT):
    p=root/'build/plugin/summary.json'
    if p.exists():p.write_text('{"complete":false,"reason":"validation must finish again"}\n')
