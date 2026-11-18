"""Test-driver serialization of the independently parsed oracle value.

The fixed checksum is an assertion codec, not a production identity/hash. Raw
source spans are separately checked by source-position tests, never replaced by
this checksum. UTF-8 text comes from Expat, not the Bend implementation.
"""
from oracle import tree, typed


def digest(raw: bytes) -> tuple[int, int]:
    value = typed(raw)
    root = tree(raw)
    params = next(x for x in root.children if x.name == 'Params')
    content = next(x for x in root.children if x.name == 'Content')
    h = 2166136261

    def mix(*values):
        nonlocal h
        for v in values:
            h = ((h * 16777619) & 0xffffffff) ^ v

    def fields(node, ordered):
        refs, scalars = {}, []
        for child in node.children:
            if child.name in ordered:
                text = child.text
                refs[child.name] = (1, len(scalars), len(text), len(text.encode('utf-8')))
                scalars += [ord(c) for c in text]
        for name in ordered:
            mix(*refs[name])
        return scalars

    for item, node in zip(value['entries'], content.children, strict=True):
        mix(0xE001, item['number'], item['list'], item['partial'])
        sid = item['sid']
        mix(0) if sid is None else mix(1, sid['value'], sid['width'])
        mix(int.from_bytes(item['record'].encode('ascii'), 'big'),
            int.from_bytes(item['field'].encode('ascii'), 'big'))
        occurrence = item['occurrence']
        mix(0) if occurrence is None else mix(1, occurrence['index'], occurrence['maxIndex'])
        identity = item['identity']
        if identity['kind'] == 'literal':
            mix(0)
        elif identity['kind'] == 'bracket':
            mix(1, identity['value'])
        else:
            mix(2, identity['reason'])
        scalars = fields(node, ('EDID', 'Source', 'Dest'))
        fuz = item['fuz']
        mix(0, 0, 0) if fuz is None else mix(1, fuz['responseId'], fuz['count'])
        mix(0xE002, *scalars, 0xE003)
    mix(0xD001, len(value['entries']))
    scalars = fields(params, ('Addon', 'Source', 'Dest'))
    mix(0xD002, *scalars, 0xD003)
    return h, len(value['entries'])
