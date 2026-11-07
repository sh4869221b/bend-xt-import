"""Enforce the supported core boundary; Bend module privacy is not a security boundary."""
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
TRUSTED = {
    'core/budget.bend', 'core/storage.bend', 'core/bytes.bend', 'core/scalars.bend',
    'core/cursor.bend', 'core/codec.bend', 'core/utf8.bend', 'core/cp1252.bend', 'hash/sha256.bend', 'hash/hex.bend',
}
PUBLIC = {
    'core/error.bend': set(),
    'core/checked.bend': {'add','sub','mul','byte','ceil_capacity'},
    'core/budget.bend': {'reserve_many','settle','cancel','consume','release','finish','inspect',
                         'zero','live','work','Six'},
    'core/bytes.bend': {'new','get','put','append','clear','drop','metadata','copy_range'},
    'core/scalars.bend': {'new','get','put','append','clear','drop','metadata'},
    'core/cursor.bend': {'source_range','cursor','subrange','take','skip','remaining','begin',
                        'continued','read_u8','read_u16_le','read_u16_be','read_u32_le','read_u32_be'},
    'core/codec.bend': {'decode','encode','encoder_init'},
    'core/utf8.bend': {'init','finish'},
    'hash/sha256.bend': {'init','update','finalize','drop'},
    'hash/hex.bend': {'format'},
}
PUBLIC_TYPES = {
    'core/error.bend': {'Error'},
    'core/budget.bend': {'Budget','Reservation','Allocation','Six'},
    'core/bytes.bend': {'OwnedBytes','CopyResult'},
    'core/scalars.bend': {'ScalarChunk'},
    'core/cursor.bend': {'SourceOwner','ByteWindow','Range','Cursor','ReadState','ReadResult'},
    'core/codec.bend': {'Progress','EncodeState','EncodeProgress'},
    'core/utf8.bend': {'State'},
    'hash/sha256.bend': {'ShaState','FinalResult'},
}
PUBLIC_PATTERNS = {
    'core/bytes.bend': {'Copied','CopyFailed'},
    'core/cursor.bend': {'Range','Cursor','ReadDone','NeedMore','ReadFail'},
    'core/codec.bend': {'Progress','EncodeProgress','EncodeReady','Pending','EncodeBroken'},
    'core/utf8.bend': {'State','Broken'},
    'hash/sha256.bend': {'HashDone','HashFailed','ReleaseFailed'},
}
ADAPTERS = {'host/snapshot.bend'}
ENTRYPOINTS = {'cli/main.bend'}


def problems(path, text):
    relative = str(path.relative_to(ROOT))
    if relative.startswith('tests/'):
        return []
    # Comments are not declarations. String text remains conservatively inspected.
    text = '\n'.join(line.split('#',1)[0] for line in text.splitlines())
    errors = []
    if re.search(r'\bArray\.(?:clone|fork|to_list)\b',text):
        errors.append('unbudgeted array clone/list conversion')
    if relative.startswith(('core/','hash/')) and re.search(r'\b(?:String|List)\b',text):
        errors.append('unbounded linked representation in pure core')
    if relative not in TRUSTED:
        if re.search(r'\bArray\s*(?:\.|<)|\b(?:ALeaf|ANode)\s*\{', text):
            errors.append('raw Array outside trusted representation modules')
    if re.search(r'\bIO\.(?:die|exit)\s*\(',text) and relative not in ENTRYPOINTS:
        errors.append('library process termination')
    for line in text.splitlines():
        if line.startswith('import ') and line != 'import Base' and ' as ' not in line:
            errors.append('explicit import alias required outside Base')
    aliases = re.findall(r'^import\s+([^\s]+)\s+as\s+(\w+)\s*$',text,re.M)
    for module, alias in aliases:
        if not module.endswith('.bend'):
            errors.append('explicit .bend import extension required')
            continue
        target = (path.parent / module).resolve()
        try: target_name = str(target.relative_to(ROOT))
        except ValueError:
            errors.append('import outside repository')
            continue
        if target_name in PUBLIC and relative not in TRUSTED:
            allowed = set(PUBLIC[target_name])
            if relative in ENTRYPOINTS and target_name == 'core/budget.bend': allowed.add('start')
            if relative in ADAPTERS and target_name == 'core/cursor.bend':
                allowed.update({'source','bind','unbind','drop_source'})
            for line in text.splitlines():
                pattern_end = line.find(':') if line.lstrip().startswith('case ') else -1
                for match in re.finditer(r'\b'+re.escape(alias)+r'\.(\w+)',line):
                    name = match[1]
                    if target_name == 'core/error.bend': continue
                    is_constructor = bool(re.match(r'\s*\{',line[match.end():]))
                    is_pattern = is_constructor and 0 <= match.start() < pattern_end
                    permitted = name in allowed
                    if is_pattern and name in PUBLIC_PATTERNS.get(target_name,set()): permitted = True
                    if not is_constructor and name in PUBLIC_TYPES.get(target_name,set()): permitted = True
                    if not permitted: errors.append(f'private core API {target_name}:{name}')
        if target_name == 'core/storage.bend' and relative not in TRUSTED:
            errors.append('private storage import')
    return errors


def main():
    failures = []
    for path in sorted(ROOT.rglob('*.bend')):
        if '.cache' in path.parts or 'build' in path.parts or 'runs' in path.parts: continue
        failures.extend(f'{path.relative_to(ROOT)}: {error}' for error in problems(path,path.read_text()))
    # Positive and negative policy controls are actual distinct violations.
    fake = ROOT / 'parser/fixture.bend'
    controls = [
        ('import Base\ndef x() -> Array<U32>:\n  Array.new(U32,0n,0)', True),
        ('import ../core/budget.bend as B\ndef x() -> U32:\n  B.start(1, B.zero())', True),
        ('import ../core/cursor.bend as C\ndef x() -> U32:\n  C.bind(a,b,0)', True),
        ('import ../core/budget.bend as B\ndef x() -> U32:\n  +f = B.allocate', True),
        ('import ../core/bytes.bend as X\ndef x() -> U32:\n  X.get(b,a,0)', False),
    ]
    for text, rejected in controls:
        if bool(problems(fake,text)) != rejected: failures.append('lint policy control failed')
    if failures:
        raise SystemExit('\n'.join(failures))
    print('core API boundary lint passed (including policy controls)')

if __name__ == '__main__': main()
