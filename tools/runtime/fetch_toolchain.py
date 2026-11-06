"""Fetch checksum-locked experiment inputs; never execute downloaded installers."""
import argparse
import hashlib
import json
from pathlib import Path
import tempfile
import urllib.request

ROOT = Path(__file__).resolve().parents[2]


def sha(path):
    h = hashlib.sha256()
    with path.open('rb') as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b''):
            h.update(block)
    return h.hexdigest()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--cache', type=Path, default=ROOT / '.cache/downloads')
    args = parser.parse_args()
    lock = json.loads((ROOT / 'sources.lock').read_text())
    if lock['schema'] != 1:
        raise SystemExit('unsupported lock schema')
    args.cache.mkdir(parents=True, exist_ok=True)
    for item in lock['artifacts']:
        name = item['name']
        if Path(name).name != name or not item['url'].startswith('https://'):
            raise SystemExit('unsafe artifact entry')
        destination = args.cache / name
        if destination.exists():
            if not destination.is_file() or destination.is_symlink() or sha(destination) != item['sha256']:
                raise SystemExit('cached artifact failed verification: ' + name)
            print(name, 'verified cache')
            continue
        temporary = None
        try:
            with tempfile.NamedTemporaryFile(dir=args.cache, delete=False) as output:
                temporary = Path(output.name)
                with urllib.request.urlopen(item['url'], timeout=60) as response:
                    count = 0
                    while block := response.read(1024 * 1024):
                        count += len(block)
                        if count > 128 * 1024 * 1024:
                            raise ValueError('artifact exceeds download limit')
                        output.write(block)
            if sha(temporary) != item['sha256']:
                raise ValueError('download checksum mismatch: ' + name)
            temporary.replace(destination)
            temporary = None
            print(name, 'downloaded and verified')
        finally:
            if temporary is not None:
                temporary.unlink()


if __name__ == '__main__':
    main()
