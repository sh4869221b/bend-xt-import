"""Finite three-run matrix for actual XML shapes, not a depth-64 document."""
import json
from checks import ROOT, key, stream_expected


def cases():
    base = []
    def add(group, probe, args):
        base.append({'group': group, 'probe': probe, 'args': list(map(str, args))})
    add('baseline-empty', 'stream', [147, 0, 1])
    add('baseline-one', 'stream', [232, 1, 1])
    for mib in (1, 16, 64):
        add('stream-ascii-' + str(mib), 'stream', [mib * 1048576, 4095, 1])
    # EDID occupies the first scalar. These straddle the first two page edges.
    for payload in (4094, 4095, 4096, 8191, 8192):
        add('page-ascii-' + str(payload), 'stream', [147 + 84 + payload, payload, 1])
    for width, label in ((3, 'japanese'), (4, 'nonbmp')):
        for scalars in (4094, 4095, 4096):
            payload = scalars * width
            add('page-' + label + '-' + str(scalars), 'stream', [147 + 84 + payload, payload, width])
        add('stream-' + label + '-1', 'stream', [1048576, 4095 * width, width])
    add('maximum-entry', 'stream', [147 + 84 + 1048565, 1048565, 1])
    add('maximum-entry-count', 'stream', [147 + 84 * 200000, 0, 1])
    add('text-ownership-reuse', 'text', [])
    add('reader-lifecycle-reuse', 'lifecycle', [])
    manifest = json.loads((ROOT / 'tests/xml/limit-cases.json').read_text())
    for c in manifest['cases']:
        if 'depth' in c['name']:
            raw = manifest['fixtures'][c['fixture']]['xml'].encode()
            add(c['name'], 'driver', [raw.hex(), 7, c['field'], c['value']])
    return [{**item, 'repeat': repeat, 'key': key(item['probe'], item['args'], repeat)}
            for item in base for repeat in (1, 2, 3)]


def live_charge(case):
    # Conservative published core buffer charges plus XML fixed/link charges.
    # Reader + budget + scalar scratch + input window + params + current entry.
    fixed = 65536 * 3 + (65536 * 16 + 4096) + (4096 * 32 + 4096) + 65536 + 4096
    if case['probe'] == 'stream':
        _, payload, width = map(int, case['args'])
        pages = (1 + payload // width + 4095) // 4096
        return fixed + pages * (4096 * 32 + 4096 + 4096)
    # The lifecycle/arena probes deliberately retain a previous entry. This
    # allowance must stay bounded independently of repetition/source length.
    return fixed + 4 * (4096 * 32 + 4096 + 4096)
