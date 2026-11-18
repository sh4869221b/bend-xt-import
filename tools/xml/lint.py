"""Supported XML API boundary. Bend module names are not a privacy mechanism."""
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[2]
READER_CALLS = {'begin','resume','finish','drop','entry_next','entry_metadata','drop_entry',
                'document_next','document_metadata','drop_document'}
READER_TYPES = {'Reader','ProvisionalEntry','ValidatedDocument','BeginResult','ReadResult','FinishResult'}
READER_PATTERNS = {'ReaderReady','ReaderInitFailed','ReadMore','EntryReady','ReadFailed',
                   'Finished','FinishEntry','FinishFailed'}


def problems(path: Path, text: str) -> list[str]:
    relative = path.relative_to(ROOT).as_posix()
    if relative.startswith('tests/'):
        return []
    text = '\n'.join(line.split('#',1)[0] for line in text.splitlines())
    errors = []
    internal = relative.startswith('xml/')
    if internal and re.search(r'\b(?:IO|String|List)\b',text):
        errors.append('external IO or unbounded string/list in pure XML implementation')
    for module, alias in re.findall(r'^import\s+(\S+)\s+as\s+(\w+)\s*$',text,re.M):
        target = (path.parent / module).resolve()
        try:
            name = target.relative_to(ROOT).as_posix()
        except ValueError:
            errors.append('outside repository import')
            continue
        if not name.startswith('xml/') or internal:
            continue
        if name not in {'xml/reader.bend','xml/types.bend'}:
            errors.append('private XML module import: '+name)
            continue
        if name == 'xml/types.bend':
            continue  # Fixed metadata is intentionally public and duplicable.
        for line in text.splitlines():
            pattern_end = line.find(':') if line.lstrip().startswith('case ') else -1
            for match in re.finditer(r'\b'+re.escape(alias)+r'\.(\w+)',line):
                symbol = match[1]
                constructor = bool(re.match(r'\s*\{',line[match.end():]))
                pattern = constructor and 0 <= match.start() < pattern_end
                allowed = symbol in READER_CALLS
                allowed |= not constructor and symbol in READER_TYPES
                allowed |= pattern and symbol in READER_PATTERNS
                if not allowed:
                    errors.append('private XML API: '+symbol)
    return errors


def main():
    failures = []
    for path in sorted(ROOT.rglob('*.bend')):
        if any(part in {'.cache','build','runs'} for part in path.parts):
            continue
        failures += [f'{path.relative_to(ROOT)}: {e}' for e in problems(path,path.read_text())]
    fake = ROOT/'planner/control.bend'
    controls = [
        ('import ../xml/reader.bend as X\ndef f() -> X.ValidatedDocument:\n  X.ValidatedDocument{a,b,c,d}',True),
        ('import ../xml/reader.bend as X\ndef f() -> U32:\n  X.Reader{a,b,c,d,e}',True),
        ('import ../xml/input.bend as I\ndef f() -> U32:\n  I.index(a)',True),
        ('import ../xml/reader.bend as X\ndef f() -> X.FinishResult:\n  X.finish(b,r)',False),
        ('import ../xml/reader.bend as X\ndef f(x: X.FinishResult) -> U32:\n  match x:\n    case X.Finished{doc}: 1',False),
        ('import ../xml/types.bend as X\ndef f() -> X.Position:\n  X.Position{0,1,1}',False),
    ]
    for text, expected in controls:
        if bool(problems(fake,text)) != expected:
            failures.append('XML boundary control failed')
    if failures:
        raise SystemExit('\n'.join(failures))
    print('XML pure and ownership API boundary passed (including controls)')

if __name__ == '__main__':
    main()
