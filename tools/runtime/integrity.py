"""Bind build and execution evidence to every experiment input."""
import hashlib
import json


def digest(path):
    sha256 = hashlib.sha256()
    with path.open('rb') as stream:
        while chunk := stream.read(65536):
            sha256.update(chunk)
    return sha256.hexdigest()


def observation_reference(root, directory):
    path = directory / 'observation.json'
    return {'observation': str(path.relative_to(root)), 'sha256': digest(path)}


def inputs(root):
    paths=[]
    for directory in ['tools/runtime','tests/runtime']:
        paths.extend(p for p in (root/directory).rglob('*') if p.is_file() and '__pycache__' not in p.parts)
    paths.extend(root/name for name in ['sources.lock','.github/workflows/runtime-probes.yml'])
    return {str(p.relative_to(root)):digest(p) for p in sorted(paths)}


def record(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary=path.with_name(path.name+'.tmp')
    temporary.write_text(json.dumps(value,indent=2)+'\n')
    temporary.replace(path)
