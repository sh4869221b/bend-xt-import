"""Reviewable generated-C anchors for fixed FSM, affine pages and tail loops.

This is a finite compiler-shape regression check, not a general stack proof.
Physical boundedness still requires the independent native resource matrix.
"""
import hashlib
import json
import re
from integrity import ROOT, digest
from experiment import verified_build

SHAPES = {
    'xml_input_next_loop': ['WL_AGAIN(spin_______xml_input_next_loop)', 'spin_______xml_input_step(e,'],
    'xml_text_reverse': ['WL_AGAIN(spin_______xml_text_reverse)', 'CID_______xml_text_Page', 'e.mem[_nd_0 + 20] = _acc_0;'],
    'xml_text_drop_loop': ['WL_AGAIN(spin_______xml_text_drop_loop)', 'spin_______xml_text_drop_one(e,'],
    'xml_text_linked': ['spin_______core_scalars_new(e,', '4096ull', 'CID_______xml_text_Page'],
    'xml_reader_limits_valid': ['<=, 64ull', '<=, 1048576ull', '<=, 200000ull', '<=, 67108864ull'],
    'xml_xtranslator_v2_open_valid': ['spin_______xml_xtranslator_v2_depth(e,', 'spin_______xml_xtranslator_v2_depth_limit(e,', 'spin_______xml_xtranslator_v2_open_depth(e,'],
    'xml_ownership_release': ['spin_______core_budget_release(e,', 'spin_______core_budget_cancel(e,'],
    'xml_reader_entry_text_dropped': ['spin_______xml_ownership_release(e,', 'spin_______xml_reader_entry_claim_dropped(e,'],
}


def extract(text, name):
    matches = list(re.finditer(r'(?:INLINE|DFAR) Term (spin_\w*' + re.escape(name) + r')\([^\n]*\) \{', text))
    if len(matches) != 1:
        raise ValueError('missing/ambiguous generated function: ' + name)
    start = matches[0].start()
    end = text.find('\n}\n', start)
    if end < 0:
        raise ValueError('unterminated generated function')
    return text[:start].count('\n') + 1, text[start:end + 3]


def inspect(probes=('driver', 'stream')):
    records = []
    for probe in probes:
        path = ROOT / 'build/xml' / (probe + '.c')
        text = path.read_text()
        if 'return (u64)*blk_ptr(H, loc, i);' not in text:
            raise ValueError('locked runtime scalar block representation changed')
        for name, needles in SHAPES.items():
            line, body = extract(text, name)
            if not all(needle in body for needle in needles):
                raise ValueError('generated ownership/FSM/loop shape changed: ' + name)
            # Local scratch extents must be compile-time constants; no VLA.
            arrays = re.findall(r'Term\s+\w+\[([^\]]+)\]', body)
            if any(not count.isdigit() for count in arrays):
                raise ValueError('dynamic generated stack scratch in ' + name)
            records.append({'probe': probe, 'c_sha256': digest(path), 'function': name, 'line': line,
                            'body_sha256': hashlib.sha256(body.encode()).hexdigest(),
                            'fixed_term_scratch_slots': sum(map(int, arrays)),
                            'anchors': needles, 'excerpt': body})
    return records


def main():
    verified_build()
    data = {'complete': True, 'acceptance_complete': False,
            'build_sha256': digest(ROOT / 'build/xml/build.json'), 'inspection': inspect()}
    (ROOT / 'build/xml/layout.json').write_text(json.dumps(data, indent=2) + '\n')
    print(len(data['inspection']), 'generated XML ownership/FSM/tail-loop shapes checked')


if __name__ == '__main__':
    main()
