"""Inspect fixed parser stack and affine ownership in the pinned emitted C."""
import json
import re
from integrity import ROOT,digest
from experiment import verified_build

SHAPES={
 'plugin_state_allocated':['o[24] = blk_new(e, 0, 6ull, 0, 1, _fv_0);','o[25] = blk_new(e, 0, 6ull, 0, 1, _fv_1);'],
 'plugin_state_drop':['term_sink(e, _scanner_3);','term_sink(e, _scanner_4);','spin_______core_budget_release(e,'],
 'plugin_state_push':['U32_BIN(_depth_0, <, 64ull)'],
 'plugin_copy_drop':['spin_______plugin_state_drop(e,','spin_______plugin_copy_dropped(e, _o_1, _copy_83, _copy_84'],
}

def extract(text,name):
    matches=list(re.finditer(r'INLINE Term spin_\w*'+re.escape(name)+r'\([^\n]*\) \{',text))
    if len(matches)!=1:raise ValueError('missing/ambiguous emitted function: '+name)
    start=matches[0].start();end=text.find('\n}\n',start)
    if end<0:raise ValueError('unterminated emitted function')
    return text[:start].count('\n')+1,text[start:end+3]

def inspect():
    result=[]
    for probe in ['driver','resource']:
        path=ROOT/'build/plugin'/(probe+'.c');text=path.read_text()
        if 'return (u64)*blk_ptr(H, loc, i);' not in text:raise ValueError('pinned block representation changed')
        for name,needles in SHAPES.items():
            line,body=extract(text,name)
            if not all(n in body for n in needles):raise ValueError('emitted shape changed: '+name)
            result.append({'probe':probe,'c_sha256':digest(path),'function':name,'line':line,'excerpt':body})
    return result

def main():
    verified_build();result={'complete':True,'build_sha256':digest(ROOT/'build/plugin/build.json'),'inspection':inspect()}
    (ROOT/'build/plugin/layout.json').write_text(json.dumps(result,indent=2)+'\n')
    print('8 emitted parser stack/ownership checks passed')
if __name__=='__main__':main()
