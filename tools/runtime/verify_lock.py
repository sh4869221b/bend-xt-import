"""Verify the actual tools inside the pinned experiment image."""
import hashlib
import json
from pathlib import Path

ROOT = Path('/work')


def tree_digest(root):
    h = hashlib.sha256()
    for path in sorted(root.rglob('*')):
        if path.is_symlink():
            raise ValueError('compiler tree contains a symlink')
        if path.is_file():
            h.update(path.relative_to(root).as_posix().encode() + b'\0')
            h.update(hashlib.sha256(path.read_bytes()).digest())
    return h.hexdigest()


def verify():
    lock = json.loads((ROOT / 'sources.lock').read_text())
    actual = hashlib.sha256(Path('/opt/packages.lock').read_bytes()).hexdigest()
    expected_file = ROOT / lock['build_image']['packages_file']
    if actual != lock['build_image']['packages_sha256'] or Path('/opt/packages.lock').read_bytes() != expected_file.read_bytes():
        raise ValueError('host package lock differs')
    actual_tree = tree_digest(Path('/opt/bend/bend2'))
    if actual_tree != lock['compiler_tree_sha256']:
        raise ValueError('compiler/Base/effects tree differs')
    actual_bun = hashlib.sha256(Path('/opt/bun/bun-linux-x64-baseline/bun').read_bytes()).hexdigest()
    if actual_bun != lock['bun_binary_sha256']:
        raise ValueError('Bun binary differs')
    return {'packages_sha256': actual, 'compiler_tree_sha256': actual_tree,
            'bun_binary_sha256': actual_bun}


if __name__ == '__main__':
    print(json.dumps(verify(), sort_keys=True))
