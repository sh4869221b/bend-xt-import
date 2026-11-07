"""Supported parser API visibility; this is a source contract, not a sandbox."""
from pathlib import Path
import re
ROOT=Path(__file__).resolve().parents[2]
FUNCTIONS={
 'plugin/frame.bend':{'start','next','input_ended'},
 'plugin/state.bend':{'drop','charge'},
 'plugin/copy.bend':{'start','pump','resume','input_ended','drop'},
 'plugin/subrecords.bend':set(),
}
TYPES={'plugin/state.bend':{'Scanner','Status'},'plugin/frame.bend':{'StartResult'},
       'plugin/copy.bend':{'CopyState','CopyResult'}}
TRUSTED={'plugin/types.bend','plugin/error.bend','plugin/state.bend','plugin/frame.bend',
         'plugin/subrecords.bend','plugin/copy.bend'}
PATTERNS={'plugin/frame.bend':{'Started','StartFailed'},
          'plugin/state.bend':{'Yield','NeedWindow','Complete','Failed'},
          'plugin/copy.bend':{'CopyNeedWindow','ChunkReady','CopyFailed','CopyDone'}}

def problems(path,text):
    relative=str(path.relative_to(ROOT))
    if relative.startswith('tests/'):return []
    text='\n'.join(line.split('#',1)[0] for line in text.splitlines())
    errors=[]
    for module,alias in re.findall(r'^import\s+(\S+)\s+as\s+(\w+)\s*$',text,re.M):
        try:target=str((path.parent/module).resolve().relative_to(ROOT))
        except ValueError:continue
        if target not in FUNCTIONS:continue
        if relative in TRUSTED:
            raw={'plugin/state.bend':'Scanner','plugin/copy.bend':'CopyState'}.get(target)
            if raw and target!=relative and re.search(r'\b'+re.escape(alias)+r'\.'+raw+r'\s*\{',text):
                errors.append('raw parser owner outside its defining module')
            continue
        for line in text.splitlines():
            boundary=line.find(':') if line.lstrip().startswith('case ') else -1
            for match in re.finditer(r'\b'+re.escape(alias)+r'\.(\w+)',line):
                name=match[1];constructor=bool(re.match(r'\s*\{',line[match.end():]))
                pattern=constructor and 0<=match.start()<boundary
                allowed=name in FUNCTIONS[target]
                if not constructor and name in TYPES.get(target,set()):allowed=True
                if pattern and name in PATTERNS.get(target,set()):allowed=True
                if not allowed:errors.append('private parser API '+target+':'+name)
    return errors

def main():
    failures=[]
    for path in ROOT.rglob('*.bend'):
        if any(x in path.parts for x in ['.cache','build','runs']):continue
        failures.extend(str(path.relative_to(ROOT))+': '+e for e in problems(path,path.read_text()))
    fake=ROOT/'consumer/main.bend'
    controls=[
      ('import ../plugin/state.bend as S\ndef x() -> S.Scanner:\n  S.Scanner{a}',True),
      ('import ../plugin/state.bend as S\ndef x() -> U32:\n  S.create(a)',True),
      ('import ../plugin/frame.bend as F\ndef x() -> U32:\n  F.next(a,b,c)',False),
      ('import ../plugin/copy.bend as C\ndef x() -> C.CopyState:\n  C.CopyState{a}',True),
      ('import ../plugin/subrecords.bend as S\ndef x() -> U32:\n  S.step(a)',True),
      ('import ../plugin/copy.bend as C\ndef x() -> U32:\n  C.pump(a,b,c)',False),
      ('import ../plugin/copy.bend as C\ndef x() -> C.CopyState:\n  C.input_ended(a)',False),
    ]
    for text,rejected in controls:
        if bool(problems(fake,text))!=rejected:failures.append('parser boundary control failed')
    untrusted=ROOT/'plugin/consumer.bend'
    forged='import state.bend as S\ndef forge(scanner, machine, summary):\n  S.replace(scanner, S.with_phase(machine, S.Finished{summary}))'
    if not problems(untrusted,forged):failures.append('unlisted parser module bypassed private API boundary')
    if failures:raise SystemExit('\n'.join(failures))
    print('parser API boundary controls passed')
if __name__=='__main__':main()
