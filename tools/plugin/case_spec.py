"""Exact Issue #4 native, affine, and resource inventories."""
import hashlib
import math
from fixtures import record,group,sub
ENTRYPOINTS={'driver','resource','contracts'}
HELPERS={'support','report','runner'}
OWNERS={'scanner','copy'}
CONTRACTS=['metadata-full','metadata-empty','metadata-end','metadata-u32-end','sticky-complete','drop-pending',
 'premature-eof-sticky','misplaced-window-resume','foreign-source-sticky','work-exact','work-one-less','live-exact',
 'live-one-less','incomplete-copy-refused','failed-copy-refused','flag-facts']+[f'partial-header-{n}' for n in range(1,24)]+[
 'copy-work-exact-sticky','copy-work-one-less','copy-drop-reading','copy-drop-waiting','copy-awaiting-buffer-refused',
 'copy-nonempty-handback-refused','copy-foreign-source','copy-premature-eof','metadata-wrong-run',
 'scanner-release-owner-returned','copy-release-owners-returned',
 'foreign-before-record-end','foreign-before-group-end','foreign-before-complete','foreign-after-complete','copy-foreign-after-complete']


def key(name,args,repeat=None):
    return name+':'+','.join(map(str,args))+('' if repeat is None else ':'+str(repeat))


def functional_cases():
    return [('contracts',[])]


def resource_cases():
    result=[]
    def add(group,kind,count,chunk=65536,output=65536,copying=0):
        for repeat in range(3):
            result.append({'group':group,'probe':'resource','args':list(map(str,[kind,count,chunk,output,copying])),'repeat':repeat})
    add('baseline-scan',0,1,1,1)
    add('baseline-copy',0,1,1,1,1)
    for depth in [0,1,64,65]:add('depth-'+str(depth),2,depth,25,23)
    for mib in [1,16,64]:
        add('scan-stream-'+str(mib),7,mib*1048576)
        add('copy-stream-'+str(mib),7,mib*1048576,65536,65536,1)
    add('source-256m',7,268435456)
    add('source-over',7,268435457)
    add('record-count-limit',0,2000000)
    add('record-count-over',0,2000001)
    add('subrecord-count-limit',1,8000000)
    add('subrecord-count-over',1,8000001)
    add('payload-limit',5,33554432)
    add('payload-over',5,33554433)
    for kind,n in [(3,65535),(4,65535),(4,65536)]:
        add('length-'+str(kind)+'-'+str(n),kind,n,65535,65536,1)
    for repeat in range(3):result.append({'group':'contract-lifecycles','probe':'contracts','args':[],'repeat':repeat})
    return result


def resource_info(kind,n):
    if kind==0:return {'size':24*n,'records':n,'objects':n,'subrecords':0,'opaque':0}
    if kind==1:
        records=max(1,(n+999999)//1000000)
        return {'size':records*24+n*6,'records':records,'objects':records,'subrecords':n,'opaque':0}
    if kind==2:return {'size':24*(n+1),'records':1,'objects':n+1,'subrecords':0,'opaque':0}
    if kind in [3,4,5]:return {'size':n+{3:54,4:64,5:48}[kind],'records':2,'objects':2,'subrecords':0 if kind==5 else 1,'opaque':int(kind==5)}
    if kind==6:return {'size':n,'records':0,'objects':0,'subrecords':0,'opaque':0}
    if kind==7:
        total=n-24;full,rem=divmod(total,16777216)
        segments=full+bool(rem)
        if full and 0<rem<24:segments-=1
        return {'size':n,'records':1+segments,'objects':1+segments,'subrecords':0,'opaque':segments}
    raise ValueError('unknown generator')


def resource_error(kind,n):
    if kind==0 and n==0:return 1
    if kind==0 and n>2000000:return 18
    if kind==1 and n>8000000:return 20
    if kind==2 and n>64:return 21
    if kind==4 and n+16>33554432:return 9
    if kind==5 and n>33554432:return 9
    if kind in [6,7] and n>268435456:return 22
    if kind==6:return 1 if n==0 else 4 if n<24 else 2
    return None


def repeat_parts(pattern,count):
    # At most 64KiB per update, independent of the requested synthetic size.
    width=max(1,65536//len(pattern));block=pattern*width
    while count>=width:yield block;count-=width
    if count:yield pattern*count


def payload_parts(length,start=0):
    pattern=bytes(range(256));pos=start
    while length:
        n=min(length,65536)
        block=(pattern*((n+255+pos%256)//256))[pos%256:pos%256+n]
        yield block;length-=n;pos+=n


def resource_parts(kind,n):
    if kind==0:
        if n:yield record()
        yield from repeat_parts(record(b'WEAP'),max(0,n-1));return
    if kind==1:
        left=n;first=True
        while first or left:
            count=min(left,1000000);sig=b'TES4' if first else b'WEAP';first=False
            # Header length is declared without allocating the synthetic body.
            import struct
            yield struct.pack('<4sIIIIHH',sig,count*6,0,0,0,131,0)
            yield from repeat_parts(sub(),count);left-=count
        return
    if kind==2:
        yield record()
        import struct
        for level in range(n):yield struct.pack('<4sIIIII',b'GRUP',24*(n-level),0,0,0,131)
        return
    if kind in [3,4,5]:
        import struct
        yield record()
        payload=n+{3:6,4:16,5:0}[kind]
        yield struct.pack('<4sIIIIHH',b'WEAP',payload,0x40000 if kind==5 else 0,0,0,131,0)
        if kind==3:
            yield struct.pack('<4sH',b'FULL',n);yield from repeat_parts(b'\x81',n)
        elif kind==4:
            yield struct.pack('<4sHI4sH',b'XXXX',4,n,b'FULL',123);yield from repeat_parts(b'\xa7',n)
        else:yield from payload_parts(n)
        return
    if kind==7:
        import struct
        yield record();remaining=n-24
        while remaining:
            length=min(16777216,remaining)
            if 0<remaining-length<24:length=remaining
            yield struct.pack('<4sIIIIHH',b'WEAP',length-24,0x40000,0,0,131,0)
            yield from payload_parts(length-24,24);remaining-=length
        return
    yield from repeat_parts(b'\0',n)


_DIGESTS={}
def resource_digest(kind,n):
    k=(kind,n)
    if k not in _DIGESTS:
        h=hashlib.sha256()
        for part in resource_parts(kind,n):h.update(part)
        _DIGESTS[k]=h.hexdigest()
    return _DIGESTS[k]


def verify_resource(args,stdout):
    from checks import parse
    kind,n,chunk,output,copying=map(int,args[:5]);result=parse(stdout);s=result['status'];error=resource_error(kind,n)
    if len(args)!=5:raise AssertionError('unknown resource options in mandatory suite')
    if s['ok']!=(error is None):raise AssertionError('resource acceptance mismatch: '+str(args)+' '+repr(s))
    if result['events'] or result['copy']:raise AssertionError('resource run is not bounded/quiet')
    if error is not None:
        if s['cause'][:2]!=[0,error] or result['copied'] is not None or result['extras']:raise AssertionError('resource refusal mismatch')
        return
    expected=resource_info(kind,n)
    if s['source'][2:]!=[0,expected['size']] or any(s[k]!=expected[k] for k in ['records','objects','subrecords','opaque']) or s['all_bodies']!=int(expected['opaque']==0):
        raise AssertionError('synthetic summary differs')
    if copying:
        if result['copied']!=expected['size'] or result['extras']!=[['SHA256',resource_digest(kind,n)]]:
            raise AssertionError('synthetic copied count/digest differs')
    elif result['copied'] is not None or result['extras']:raise AssertionError('scan-only emitted copy')


def capacity(n):return 1<<(max(1,n)-1).bit_length()

def live_charge(case):
    if case['probe']=='contracts':return 1048576
    _,_,chunk,output,copying=map(int,case['args'])
    # Budget + source + scanner + input; copy additionally overlaps output/SHA.
    total=65536+4096+65536+4096+max(65536,16*capacity(chunk))+4096
    if copying:total+=max(65536,16*capacity(output))+4096+65536+4096+65536+4096
    return total
