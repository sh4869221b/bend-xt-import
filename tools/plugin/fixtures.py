"""Project-authored FO4 wire fixtures; Python is only a test producer/oracle."""
from dataclasses import dataclass
import random
import struct

@dataclass(frozen=True)
class Fixture:
    name: str
    data: bytes
    valid: bool = True
    reason: str | None = None
    offset: int | None = None
    diagnostic: tuple[int,int] | None = None


def record(sig=b'TES4', body=b'', flags=0, formid=0, revision=0, version=131, unknown=0):
    return struct.pack('<4sIIIIHH', sig, len(body), flags, formid, revision, version, unknown)+body


def group(body=b'', label=b'WEAP', kind=0, stamp1=0, stamp2=0):
    return struct.pack('<4sI4sIII', b'GRUP',24+len(body),label,kind,stamp1,stamp2)+body


def sub(sig=b'DATA', body=b'', *, extended=False, ignored=0):
    if extended:
        return struct.pack('<4sHI4sH',b'XXXX',4,len(body),sig,ignored)+body
    return struct.pack('<4sH',sig,len(body))+body


def patch32(data, offset, value):
    return data[:offset]+struct.pack('<I',value)+data[offset+4:]


def fixed_fixtures():
    tes=record()
    hedr=struct.pack('<fII',1.0,0x5a5a0102,0x810)
    unusual=record(b'TES4',sub(b'HEDR',hedr)+sub(b'MAST',b'Zeta.esm\0')+sub(b'DATA',b'\xff'*8)+
                   sub(b'MAST',b'Alpha.esm\0')+sub(b'DATA',b'\x7f'*8)+sub(b'OFST',b'\x00\xff'),
                   0xfffbffff,0xdeadbeef,0xabcd1234,0xffff,0xa55a)
    weird=record(b'\xff\0?!',sub(b'\0\xff!?',b'\xff\x80\0TES4GRUPXXXX',extended=True,ignored=65535),
                 0xfffbffff,0xfedcba98,0x01234567,0x4321,0xffff)
    examples=[Fixture('minimal',tes),Fixture('unknown-record-and-bytes',tes+weird),
              Fixture('empty-group',tes+group()),Fixture('nested-empty-groups',tes+group(group(group()))),
              Fixture('siblings',tes+record(b'WEAP',sub(b'FULL',b'a\0'))+record(b'MISC')),
              Fixture('metadata-and-master-order',unusual+group(weird,label=b'\0\xff\x80\x7f',kind=0xffffffff,
                      stamp1=0xaabbccdd,stamp2=0x12345678)),
              Fixture('deleted-record',tes+record(b'WEAP',sub(b'FULL',b'deleted\0'),flags=0x20)),
              Fixture('opaque-compressed-short',tes+record(b'UNKN',b'\xff\0\x80',flags=0x40000)),
              Fixture('opaque-compressed-empty',tes+record(b'UNKN',flags=0x40020)),
              Fixture('opaque-compressed-tes4',record(b'TES4',b'TES4XXXX',flags=0x40081))]
    for flags in [0,1,0x80,0x200,0x281,0x80000000]:
        examples.append(Fixture('tes4-flags-'+str(flags),record(flags=flags)))
    for n in [0,1,7,255,65535,65536]:
        body=bytes([0xa7])*n
        examples.append(Fixture('xxxx-'+str(n),tes+record(b'WEAP',sub(b'FULL',body,extended=True,ignored=123))))
    examples.append(Fixture('ordinary-65535',tes+record(b'WEAP',sub(b'FULL',b'\x81'*65535))))
    examples.append(Fixture('repeated-real-fields',tes+record(b'WEAP',sub(b'FULL',b'a')+
                    sub(b'FULL',b'b',extended=True,ignored=65535)+sub(b'FULL'))))
    for n in range(24):
        examples.append(Fixture('truncated-initial-'+str(n),tes[:n],False))
    examples += [Fixture('first-not-tes4',record(b'WEAP'),False),Fixture('first-group',group(tes),False),
                 Fixture('duplicate-tes4',tes+tes,False),Fixture('nested-duplicate-tes4',tes+group(tes),False)]
    for n in range(1,24):
        examples.append(Fixture('trailing-object-'+str(n),tes+b'\xff'*n,False))
        examples.append(Fixture('group-trailer-'+str(n),tes+group(b'\xff'*n),False))
    for n in range(1,6):
        examples.append(Fixture('subheader-tail-'+str(n),record(body=b'\x80'*n),False))
    for n in [0,23,0xffffffff]:
        examples.append(Fixture('group-declared-'+str(n),tes+patch32(group(),4,n),False))
    examples += [Fixture('record-parent-crossing',tes+group(patch32(record(b'WEAP'),4,1)),False),
                 Fixture('group-parent-crossing',tes+group(patch32(group(),4,25)),False),
                 Fixture('record-u32-wrap',patch32(tes,4,0xffffffff),False),
                 Fixture('overlap-no-resync',tes+group(patch32(record(b'WEAP'),4,1))+record(b'MISC'),False),
                 Fixture('unknown-malformed-body',tes+record(b'????',b'\0'),False)]
    for n in [0,3,5,65535]:
        examples.append(Fixture('xxxx-bad-size-'+str(n),record(body=struct.pack('<4sH',b'XXXX',n)+b'\0'*4),False))
    for n in range(4):
        examples.append(Fixture('xxxx-truncated-length-'+str(n),record(body=b'XXXX\4\0'+b'\0'*n),False))
    examples += [Fixture('xxxx-dangling',record(body=b'XXXX\4\0'+b'\0'*4),False),
                 Fixture('xxxx-repeated',record(body=b'XXXX\4\0'+b'\0'*4+b'XXXX\4\0'+b'\0'*4),False),
                 Fixture('xxxx-payload-overrun',record(body=b'XXXX\4\0'+struct.pack('<I',2)+b'FULL\0\0x'),False),
                 Fixture('xxxx-u32-wrap',record(body=b'XXXX\4\0'+b'\xff'*4+b'FULL\0\0'),False),
                 Fixture('ordinary-payload-overrun',record(body=b'FULL\2\0x'),False)]
    for n in range(1,6):
        examples.append(Fixture('xxxx-next-header-'+str(n),record(body=b'XXXX\4\0'+b'\0'*4+b'FULL\0\0'[:n]),False))
    return examples


def random_fixtures(seed=0xF04, count=48):
    rng=random.Random(seed)
    signatures=[b'WEAP',b'UNKN',b'????',b'NPC_',b'\0\xff\x80!']
    def body():
        result=b''
        for _ in range(rng.randrange(5)):
            payload=rng.randbytes(rng.randrange(20))
            result+=sub(rng.choice([b'FULL',b'DATA',b'????']),payload,
                        extended=bool(rng.getrandbits(1)),ignored=rng.randrange(65536))
        return result
    def children(depth):
        output=b''
        for _ in range(rng.randrange(5)):
            if depth<3 and rng.randrange(3)==0:
                output+=group(children(depth+1),rng.randbytes(4),rng.getrandbits(32),rng.getrandbits(32),rng.getrandbits(32))
            else:
                flags=rng.getrandbits(32)
                payload=rng.randbytes(rng.randrange(20)) if flags&0x40000 else body()
                output+=record(rng.choice(signatures),payload,flags,rng.getrandbits(32),rng.getrandbits(32),rng.randrange(65536),rng.randrange(65536))
        return output
    return [Fixture('seed-f04-'+str(i),record(body=body(),flags=rng.choice([0,1,0x80,0x200,0x281]))+children(0)) for i in range(count)]


def expected_error(fixture):
    """Authored reason/position expectations, independent from the parser source.

    IDs are the public diagnostic contract. Other malformed mutations must still
    fail for a format error with valid source context.
    """
    if fixture.diagnostic is not None:return fixture.diagnostic
    name=fixture.name
    if name=='truncated-initial-0':return 1,0
    if name.startswith('truncated-initial-'):return 4,0
    if name in {'first-not-tes4','first-group'}:return 2,0
    if name=='duplicate-tes4':return 3,24
    if name=='nested-duplicate-tes4':return 3,48
    if name.startswith('trailing-object-'):return 6,24
    if name.startswith('group-trailer-'):return 5,48
    if name.startswith('subheader-tail-'):return 10,24
    if name in {'group-declared-0','group-declared-23'}:return 7,24
    if name=='group-declared-4294967295':return 8,24
    if name in {'record-parent-crossing','group-parent-crossing','overlap-no-resync'}:return 8,48
    if name=='record-u32-wrap':return 8,0
    if name=='unknown-malformed-body':return 10,48
    if name.startswith('xxxx-bad-size-'):return 12,24
    if name.startswith('xxxx-truncated-length-'):return 13,24
    if name=='xxxx-dangling':return 14,24
    if name.startswith('xxxx-next-header-'):return 15,34
    if name=='xxxx-repeated':return 16,34
    if name in {'xxxx-payload-overrun','xxxx-u32-wrap'}:return 17,34
    if name=='ordinary-payload-overrun':return 11,24
    return None


def all_fixtures():
    result=fixed_fixtures()+random_fixtures()
    if len({x.name for x in result})!=len(result):raise AssertionError('duplicate fixture')
    return result


def reference(data):
    """Recursive reference traversal, independent from Bend's streaming machine.

    Returns dictionaries, not the native wire protocol. Full input is test-only.
    Opaque compressed bodies are deliberately not validated as compression.
    """
    events=[];counts={'records':0,'groups':0,'subrecords':0,'compressed':0}
    seen=False
    def objects(start,end,depth,parent_start):
        nonlocal seen
        pos=start
        while pos<end:
            if end-pos<24:raise ValueError('short object')
            sig,size,a,b,c,d=struct.unpack_from('<6I',data,pos)
            if not seen:
                if pos!=0 or data[pos:pos+4]!=b'TES4':raise ValueError('first not TES4')
                seen=True
            elif data[pos:pos+4]==b'TES4':raise ValueError('duplicate TES4')
            if data[pos:pos+4]==b'GRUP':
                if size<24 or size>end-pos or depth>=64:raise ValueError('group bounds')
                stop=pos+size;counts['groups']+=1
                event={'kind':'group-start','start':pos,'end':stop,'parent_start':parent_start,'parent_end':end,
                       'depth':depth+1,'label':a,'group_type':b,'stamp1':c,'stamp2':d}
                events.append(event);objects(pos+24,stop,depth+1,pos+24)
                events.append({'kind':'group-end','start':pos,'end':stop,'depth':depth+1})
            else:
                if size>end-pos-24:raise ValueError('record bounds')
                stop=pos+24+size;ordinal=counts['records'];counts['records']+=1
                compressed=bool(a&0x40000)
                if compressed:counts['compressed']+=1
                event={'kind':'record-start','signature':sig,'start':pos,'end':stop,'payload_start':pos+24,
                       'parent_start':parent_start,'parent_end':end,'depth':depth,'ordinal':ordinal,
                       'flags':a,'formid':b,'revision':c,'version':d&65535,'unknown':d>>16,
                       'compressed':compressed,'deleted':bool(a&0x20)}
                events.append(event)
                ordinal_sub=0;p=pos+24
                while not compressed and p<stop:
                    begin=p
                    if stop-p<6:raise ValueError('short subrecord')
                    name,short=struct.unpack_from('<4sH',data,p);p+=6;escaped=False
                    if name==b'XXXX':
                        if short!=4 or stop-p<4:raise ValueError('XXXX size')
                        length=struct.unpack_from('<I',data,p)[0];p+=4;escaped=True
                        if stop-p<6:raise ValueError('XXXX dangling')
                        name,short=struct.unpack_from('<4sH',data,p);p+=6
                        if name==b'XXXX':raise ValueError('XXXX repeated')
                    else:length=short
                    if length>stop-p:raise ValueError('subrecord bounds')
                    events.append({'kind':'subrecord','signature':int.from_bytes(name,'little'),'record_start':pos,
                        'start':begin,'header_start':p-6,'payload_start':p,'end':p+length,
                        'raw_size':short,'length':length,'extended':escaped,'ordinal':ordinal_sub})
                    counts['subrecords']+=1;ordinal_sub+=1;p+=length
                events.append({'kind':'record-end','start':pos,'end':stop,'count':ordinal_sub,'compressed':compressed})
            pos=stop
    objects(0,len(data),0,0)
    if not seen:raise ValueError('missing TES4')
    return events,counts

if __name__=='__main__':
    corpus=all_fixtures()
    for f in corpus:
        try:reference(f.data);ok=True
        except ValueError:ok=False
        assert ok==f.valid,f.name
    print(len(corpus),'authored/seeded fixtures agree with independent grammar')


def limit_fixtures():
    """Authored lower/zero/invalid ceilings, independent of implementation flow."""
    default=[268435456,33554432,2000000,2000000,8000000,64]
    result=[]
    def add(name,data,changes,error=None):
        limits=default.copy()
        for index,value in changes.items():limits[index]=value
        fixture=Fixture('limit-'+name,data,error is None,diagnostic=error)
        result.append((fixture,limits))
    add('source-exact',record(),{0:24})
    add('source-over',record(),{0:23},(22,0))
    add('payload-exact',record(body=sub()),{1:6})
    add('payload-over',record(body=sub()),{1:5},(9,0))
    add('records-exact',record()+record(b'WEAP'),{2:2})
    add('records-over',record()+record(b'WEAP'),{2:1},(18,24))
    add('objects-exact',record()+group(),{2:1,3:2})
    add('objects-over',record()+group(),{2:1,3:1},(19,24))
    add('subrecords-exact',record(body=sub()),{4:1})
    add('subrecords-over',record(body=sub()+sub()),{4:1},(20,30))
    add('depth-exact',record()+group(),{5:1})
    add('depth-over',record()+group(group()),{5:1},(21,48))
    add('zero-payload-subs-depth',record(),{1:0,2:1,3:1,4:0,5:0})
    add('zero-source',record(),{0:0},(22,0))
    add('zero-records-objects',record(),{2:0,3:0},(18,0))
    add('zero-payload',record(body=sub()),{1:0},(9,0))
    add('zero-subrecords',record(body=sub()),{4:0},(20,24))
    add('zero-depth',record()+group(),{5:0},(21,24))
    add('all-zero-empty',b'',dict(enumerate([0]*6)),(1,0))
    for index,value in enumerate([268435457,33554433,2000001,2000001,8000001,65]):
        add('invalid-'+str(index),record(),{index:value},(27,0))
    add('invalid-record-object-relation',record(),{2:2,3:1},(27,0))
    return result
