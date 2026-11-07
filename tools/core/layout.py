"""Check the pinned emitted representation; keep excerpts for independent review."""
import json
from integrity import ROOT, digest
from experiment import verified_build

SHAPES = {
    'roundtrip': {
        'core_scalars_created': ['o[21] = blk_new(e, 0, ((u64)(_depth_0)), 0, 1, _fv_0);', 'o[29] = blk_new(e, 0, ((u64)(_depth_0)), 0, 1, _fv_1);'],
        'core_scalars_drop': ['term_sink(e, _owner_8);', 'spin_______core_storage_drop(e,'],
        'core_storage_drop': ['term_sink(e, _storage_0);'],
    },
    'sha': {'hash_sha256_initialized': ['o[21] = 1779033703ull;', 'o[28] = 1541459225ull;', 'o[29] = blk_new(e, 0, 6ull, 0, 1, _fv_0);']},
    'cursors': {'core_cursor_bind_valid': ['Term _bytes_0 = r6;', 'u32 _base_0 = r14;', 'o[7] = _bytes_0;', 'o[15] = _base_0;']},
    'budget': {'core_budget_reserve_commit': ['u32 _run_0 = r0;', 'u32 _next_0 = r1;']},
}


def extract(text, name):
    marker='INLINE Term spin_______'+name+'('
    starts=[]
    start=0
    while (start:=text.find(marker,start))>=0:
        end=text.find('\n',start)
        if text[start:end].endswith(' {'): starts.append(start)
        start=end
    if len(starts)!=1: raise ValueError('missing/ambiguous emitted function '+name)
    start=starts[0]; end=text.find('\n}\n',start)
    if end<0: raise ValueError('unterminated emitted function '+name)
    return text[:start].count('\n')+1,text[start:end+3]


def inspect():
    records=[]
    for probe,shapes in SHAPES.items():
        path=ROOT/'build/core'/(probe+'.c')
        text=path.read_text()
        if 'return (u64)*blk_ptr(H, loc, i);' not in text or 'return ((u32)i & (u32)((1ull << (blk_cls(a) - lgs)) - 1)) << lgs;' not in text:
            raise ValueError('pinned U32 block access representation changed')
        for name,needles in shapes.items():
            line,body=extract(text,name)
            if not all(s in body for s in needles): raise ValueError('emitted representation changed: '+name)
            records.append({'probe':probe,'c_sha256':digest(path),'function':name,'line':line,'excerpt':body})
    return records


def main():
    verified_build()
    result={'complete':True,'build_sha256':digest(ROOT/'build/core/build.json'),'inspection':inspect()}
    (ROOT/'build/core/layout.json').write_text(json.dumps(result,indent=2)+'\n')
    print('6 emitted representation checks passed')

if __name__=='__main__': main()
