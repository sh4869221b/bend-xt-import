"""Exact native protocols and independent, finite XML test expectations."""
from functools import lru_cache
import hashlib
import json
from pathlib import Path
from cases import corpus
from digest import digest as typed_digest
from differential import logical_bytes
from oracle import result

ROOT = Path(__file__).resolve().parents[2]
RTS = ['+RTS', '--threads', '1', '--gpu', 'off', '-RTS']


def key(probe, args=(), repeat=None):
    return json.dumps([probe, list(map(str, args)), repeat], separators=(',', ':'))


def parse(stdout):
    parts = stdout.split()
    if stdout != ' '.join(parts) + '\n':
        raise ValueError('noncanonical native protocol')
    if len(parts) == 6 and parts[0] == 'ok' and parts[-1] == 'balanced':
        names = ('digest', 'count', 'logical', 'work')
    elif len(parts) == 10 and parts[0] == 'error' and parts[-1] == 'balanced':
        names = ('phase', 'reason', 'entry', 'byte', 'line', 'column', 'logical', 'work')
    else:
        raise ValueError('missing success/error and balanced native result')
    values = [int(v) for v in parts[1:-1]]
    if any(v < 0 or v > 0xffffffff for v in values):
        raise ValueError('non-U32 native result')
    return {'accepted': parts[0] == 'ok', **dict(zip(names, values))}


def verify_fixture(raw, stdout, accepted, *, typed=True):
    actual = parse(stdout)
    if actual['accepted'] is not accepted:
        raise ValueError('native acceptance differs from independent expected value')
    if accepted and typed:
        checksum, count = typed_digest(raw)
        if (actual['digest'], actual['count'], actual['logical']) != (checksum, count, logical_bytes(raw)):
            raise ValueError('native typed value or logical count differs')
    if not accepted and actual['byte'] > len(raw):
        raise ValueError('error position outside source')
    return actual


def schedules(raw):
    # Encoded >65536 means exactly two chunks with this first-cut offset.
    chunks = [1, 2, 3, 7, 31, 4095, 4096, 65535, 65536]
    if len(raw) <= 4096:
        chunks += [65536 + cut for cut in range(1, len(raw))]
    return sorted(set(chunks))


def functional_cases():
    from case_spec import MARKERS
    return [(name, []) for name in sorted(MARKERS)]


def verify_output(name, args, stdout):
    from case_spec import MARKERS
    if name in MARKERS:
        if args or stdout != MARKERS[name]:
            raise ValueError('native marker or argument inventory differs: ' + name)
        return
    if name == 'stream':
        expected = stream_expected(*map(int, args))
        actual = parse(stdout)
        if not actual['accepted'] or any(actual[k] != v for k, v in expected.items() if k in ('digest', 'count', 'logical')):
            raise ValueError('generated stream typed/count/logical result differs')
        return
    if name == 'driver':
        raw = bytes.fromhex(args[0])
        if len(args) == 2:
            verify_fixture(raw, stdout, result(raw)['accepted'])
        else:
            manifest = json.loads((ROOT / 'tests/xml/limit-cases.json').read_text())
            matches = [c for c in manifest['cases'] if raw == manifest['fixtures'][c['fixture']]['xml'].encode()
                       and list(map(str, (c['field'], c['value']))) == args[2:]]
            if len(matches) != 1:
                raise ValueError('unknown/ambiguous bounded driver invocation')
            verify_fixture(raw, stdout, matches[0]['accepted'])
        return
    raise ValueError('unrecognized native entrypoint')


PREFIX = b'<SSTXMLRessources><Params><Addon>A.esp</Addon><Source>en</Source><Dest>ja</Dest><Version>2</Version></Params><Content>'
ENTRY_OPEN = b'<String List="0"><EDID>A</EDID><REC>WEAP:FULL</REC><Source>'
ENTRY_CLOSE = b'</Source><Dest/></String>'
SUFFIX = b'</Content></SSTXMLRessources>'


@lru_cache(maxsize=64)
def stream_expected(total, payload, width):
    """Independent serialization, not a copy of generated-byte switch tables.

    At most a single <=1 MiB entry is constructed. Source identity is hashed
    incrementally. Neither the native generator nor this oracle builds a whole
    large document, a DOM, or an array of expected entries.
    """
    if width not in (1, 3, 4) or payload % width or not 147 <= total <= 67108864 or not 0 <= payload <= 1048565:
        raise ValueError('unsupported stream inventory')
    unit = {1: 'a', 3: '日', 4: '😀'}[width]
    assert len(PREFIX) == 118 and len(SUFFIX) == 29 and len(ENTRY_OPEN + ENTRY_CLOSE) == 84
    count = min(200000, (total - len(PREFIX + SUFFIX)) // (84 + payload))
    entry = ENTRY_OPEN + (unit * (payload // width)).encode() + ENTRY_CLOSE
    raw_sha = hashlib.sha256(PREFIX)
    h = 2166136261
    def mix(v):
        nonlocal h
        h = ((h * 16777619) & 0xffffffff) ^ v
    for number in range(1, count + 1):
        raw_sha.update(entry)
        # Field spans are scalar spans in EDID, Source, Dest encounter order.
        for v in (0xE001, number, 0, 0, 0, int.from_bytes(b'WEAP', 'big'), int.from_bytes(b'FULL', 'big'), 0, 0,
                  1, 0, 1, 1, 1, 1, payload // width, payload, 1, 1 + payload // width, 0, 0,
                  0, 0, 0, 0xE002, ord('A')):
            mix(v)
        for _ in range(payload // width):
            mix(ord(unit))
        mix(0xE003)
    raw_sha.update(SUFFIX)
    padding = total - (147 + count * (84 + payload))
    while padding:
        n = min(padding, 65536)
        raw_sha.update(b' ' * n)
        padding -= n
    for v in (0xD001, count, 1, 0, 5, 5, 1, 5, 2, 2, 1, 7, 2, 2, 0xD002,
              *map(ord, 'A.espenja'), 0xD003):
        mix(v)
    return {'digest': h, 'count': count, 'logical': 10 + count * (11 + payload),
            'source_sha256': raw_sha.hexdigest(), 'bytes': total}


def input_initialization_work(length, chunk):
    """Public core Storage.new initializes the ceil-power-of-two capacity.

    The test adapter's input setup is charged separately from parser work. The
    sum differs between partitions even when the same source bytes are visited.
    Only accepted inputs are guaranteed to initialize the complete source.
    """
    offset = 0
    total = 0
    while offset < length:
        size = chunk if chunk <= 65536 else (chunk - 65536 if offset == 0 else 65536)
        size = min(size, length - offset)
        total += 1 << (size - 1).bit_length()
        offset += size
    return total


def partition_key(actual, length, chunk):
    if actual['accepted']:
        return (actual['digest'], actual['count'], actual['logical'],
                actual['work'] - input_initialization_work(length, chunk))
    return tuple(actual[k] for k in ('phase', 'reason', 'entry', 'byte', 'line', 'column'))
