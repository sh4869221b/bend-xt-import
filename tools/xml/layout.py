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
    'xml_text_reverse': ['WL_AGAIN(spin_______xml_text_reverse)', 'CID_______xml_text_Page'],
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


def reverse_shape(body):
    """Accept exactly the two observed pinned-compiler Page reversal forms.

    Both move all 20 payload/claim slots unchanged, replace only the final
    tail slot with the accumulator, advance over the old tail and tail-loop.
    The reference-count-aware form uses ctr_take and rfc_seal; neither form
    may introduce another allocation/copy/drop/call or a changed control flow.
    This intentionally remains a narrow emitted-shape check, not a C parser.
    """
    observed = [line.strip() for line in body.splitlines() if line.strip()]
    for refcounted in (False, True):
        signature = ('Term r0, u64 q0, Term r1, u64 q1' if refcounted else 'Term r0, Term r1')
        expected = [f'INLINE Term spin_______xml_text_reverse(Env e, THR Term* o, {signature}) {{',
                    'u32 wpoll = 0;']
        if refcounted:
            expected += ['Term h0 = r0;', 'Term h1 = r1;']
        expected += ['Term _pages_0 = r0;', 'Term _acc_0 = r1;', 'WL_SPIN',
                     'if (term_aux(_pages_0) == CID_______xml_text_NoPages) {',
                     'o[0] = _acc_0;', '} else {']
        expected += (['Term _fb_0[21];', 'u64 _sp_0 = ctr_take(e, _pages_0, 21, _fb_0);']
                     if refcounted else ['u64 _sp_0 = term_loc(_pages_0);'])
        for slot in range(21):
            kind = 'Term' if slot in (2, 10, 20) else 'u32'
            source = f'_fb_0[{slot}]' if refcounted else f'e.mem[_sp_0 + {slot}]'
            expected.append(f'{kind} _f_{slot} = {source};')
        expected.append('u64 _nd_0 = _sp_0 >= HEAP_OFF ? _sp_0 : heap_alloc(e, 5);'
                        if refcounted else 'u64 _nd_0 = _sp_0;')
        for slot in range(21):
            value = '_acc_0' if slot == 20 else f'_f_{slot}'
            if refcounted:
                value = f'rfc_seal(e, {value})'
            expected.append(f'e.mem[_nd_0 + {slot}] = {value};')
        expected += ['r0 = _f_20;', 'r1 = term_ctr(CID_______xml_text_Page, _nd_0);',
                     '_pages_0 = r0;', '_acc_0 = r1;', 'WL_AGAIN(spin_______xml_text_reverse);',
                     '}', 'break;', '}', 'return 1;', '}']
        if observed == expected:
            return 'refcount-aware-21-slot-page' if refcounted else 'direct-21-slot-page'
    raise ValueError('generated Page reverse ownership/tail-loop shape changed')


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
            variant = reverse_shape(body) if name == 'xml_text_reverse' else None
            # Local scratch extents must be compile-time constants; no VLA.
            arrays = re.findall(r'Term\s+\w+\[([^\]]+)\]', body)
            if any(not count.isdigit() for count in arrays):
                raise ValueError('dynamic generated stack scratch in ' + name)
            records.append({'probe': probe, 'c_sha256': digest(path), 'function': name, 'line': line,
                            'body_sha256': hashlib.sha256(body.encode()).hexdigest(),
                            'fixed_term_scratch_slots': sum(map(int, arrays)),
                            'anchors': needles, 'shape_variant': variant, 'excerpt': body})
    return records


def main():
    verified_build()
    data = {'complete': True, 'acceptance_complete': False,
            'build_sha256': digest(ROOT / 'build/xml/build.json'), 'inspection': inspect()}
    (ROOT / 'build/xml/layout.json').write_text(json.dumps(data, indent=2) + '\n')
    print(len(data['inspection']), 'generated XML ownership/FSM/tail-loop shapes checked')


if __name__ == '__main__':
    main()
