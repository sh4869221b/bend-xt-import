"""Source and artifact identity for the independent Issue #2 build/evidence."""
import hashlib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
DIRECTORIES = ['core', 'hash', 'tests/core', 'tools/core', 'docs/core']
FILES = ['sources.lock', 'tools/runtime/fetch_toolchain.py', 'tools/runtime/Dockerfile', 'tools/runtime/verify_lock.py',
         'tools/runtime/packages.lock', 'tools/runtime/probe-packages.lock',
         '.github/workflows/core.yml']


def digest(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def inputs(root=ROOT):
    paths = []
    for name in DIRECTORIES + FILES:
        path = root / name
        if not path.exists() or path.is_symlink():
            raise RuntimeError('missing or symlinked mandatory source: ' + name)
        if any(parent.is_symlink() for parent in path.parents if parent != root and parent.is_relative_to(root)):
            raise RuntimeError('symlinked source ancestor: ' + name)
    for directory in DIRECTORIES:
        paths += [p for p in (root / directory).rglob('*') if p.is_file() and '__pycache__' not in p.parts]
    paths += [root / p for p in FILES]
    if any(p.is_symlink() for p in paths):
        raise RuntimeError('source symlink is unsupported')
    return {str(p.relative_to(root)): digest(p) for p in sorted(set(paths))}


def invalidate_summary(root=ROOT):
    target = root / 'build/core/summary.json'
    if target.exists():
        target.write_text('{"complete":false,"reason":"validation must finish again"}\n')
