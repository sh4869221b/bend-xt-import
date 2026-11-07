"""Strict native protocol checks and independent semantic expectations."""
from fixtures import reference,expected_error

def numbers(words,count):
    if len(words)!=count:raise AssertionError('protocol field count')
    values=[int(x) for x in words]
    if any(x<0 or x>0xffffffff for x in values):raise AssertionError('non-U32 protocol field')
    return values

def parse(stdout):
    events=[];ranges=[];status=None;usage=None;copied=None;payload=bytearray();balanced=0;extras=[]
    lines=stdout.splitlines()
    for line in lines:
        words=line.split()
        if not words:raise AssertionError('blank native protocol line')
        tag=words[0]
        if tag=='R':
            v=numbers(words[1:],23)
            sig,flags,fid,rev,ver,unknown=v[:6];h,p,f=v[6:10],v[10:14],v[14:18];ranges.extend([h,p,f])
            if h[2:]!=[f[2],f[2]+24] or p[2:]!=[h[3],f[3]]:raise AssertionError('record spans')
            if v[22] not in [0,1]:raise AssertionError('body kind')
            events.append(dict(kind='record-start',signature=sig,flags=flags,formid=fid,revision=rev,version=ver,
                unknown=unknown,start=f[2],end=f[3],payload_start=p[2],parent_start=v[18],parent_end=v[19],
                depth=v[20],ordinal=v[21],compressed=bool(v[22]),deleted=bool(flags&32)))
        elif tag=='G':
            v=numbers(words[1:],15);h,f=v[4:8],v[8:12];ranges.extend([h,f])
            if h[2:]!=[f[2],f[2]+24]:raise AssertionError('group header span')
            events.append(dict(kind='group-start',label=v[0],group_type=v[1],stamp1=v[2],stamp2=v[3],
                start=f[2],end=f[3],parent_start=v[12],parent_end=v[13],depth=v[14]))
        elif tag=='F':
            v=numbers(words[1:],22);h,p,f=v[3:7],v[7:11],v[11:15];ranges.extend([h,p,f])
            escaped=v[15]
            if escaped not in [0,1]:raise AssertionError('escape discriminator')
            if escaped:
                x=v[16:20];ranges.append(x)
                if x[2:]!=[f[2],f[2]+10] or x[3]!=h[2]:raise AssertionError('escape span')
            elif v[16:20]!=[0,0,0,0] or f[2]!=h[2]:raise AssertionError('absent escape payload')
            if h[3]-h[2]!=6 or p[2]!=h[3] or p[3]!=f[3] or p[3]-p[2]!=v[2]:raise AssertionError('subrecord spans')
            events.append(dict(kind='subrecord',signature=v[0],raw_size=v[1],length=v[2],header_start=h[2],
                payload_start=p[2],start=f[2],end=f[3],extended=bool(escaped),record_start=v[20],ordinal=v[21]))
        elif tag=='E':
            v=numbers(words[1:],4)
            if v[3] not in [0,1]:raise AssertionError('record-end body')
            events.append(dict(kind='record-end',start=v[0],end=v[1],count=v[2],compressed=bool(v[3])))
        elif tag=='Z':
            v=numbers(words[1:],3);events.append(dict(kind='group-end',start=v[0],end=v[1],depth=v[2]))
        elif tag=='STATUS':
            if status is not None:raise AssertionError('duplicate status')
            if len(words)<2:raise AssertionError('missing status')
            if words[1]=='OK':
                v=numbers(words[2:],9);ranges.append(v[:4]);status={'ok':True,'source':v[:4],
                    'records':v[4],'objects':v[5],'subrecords':v[6],'opaque':v[7],'all_bodies':v[8]}
            elif words[1]=='ERROR':
                v=numbers(words[2:],15)
                status={'ok':False,'cause':v[:6],'run':v[6],'origin':v[7],'offset':v[8],
                    'parent_start':v[9],'parent_end':v[10],'has_record':v[11],'record':v[12],'depth':v[13],'declared':v[14]}
            else:raise AssertionError('unknown status')
        elif tag=='COPY':
            if len(words)!=2:raise AssertionError('copy framing')
            hx=words[1]
            if len(hx)%2 or hx.lower()!=hx or any(c not in '0123456789abcdef' for c in hx):raise AssertionError('copy hex')
            payload.extend(bytes.fromhex(hx))
        elif tag=='COPIED':
            if copied is not None:raise AssertionError('duplicate copied count')
            copied=numbers(words[1:],1)[0]
        elif tag=='USAGE':
            if usage is not None:raise AssertionError('duplicate usage')
            usage=numbers(words[1:],6)
        elif tag=='BALANCED':
            if len(words)!=1:raise AssertionError('bad balance marker')
            balanced+=1
        elif tag in {'SHA256','CONTRACT','RESOURCE'}:
            extras.append(words)
        else:raise AssertionError('unknown native line: '+line)
    if balanced!=1 or not lines or lines[-1]!='BALANCED' or usage is None or usage[4]!=0:
        raise AssertionError('unfinished or unbalanced native run')
    if status is None:raise AssertionError('missing parse status')
    identity=status['source'][:2] if status['ok'] else [status['run'],status['origin']]
    if identity[0]!=1 or identity[1]==0:raise AssertionError('source identity')
    for r in ranges:
        if r[:2]!=identity or r[2]>r[3]:raise AssertionError('mixed/invalid source span')
    return {'events':events,'status':status,'usage':usage,'copy':bytes(payload),'copied':copied,'extras':extras}


def verify_fixture(fixture,stdout):
    result=parse(stdout);s=result['status']
    if s['ok']!=fixture.valid:raise AssertionError(fixture.name+': acceptance differs '+repr(s))
    if fixture.valid:
        import hashlib
        if result['extras']!=[['SHA256',hashlib.sha256(fixture.data).hexdigest()]]:raise AssertionError('copy digest differs')
        expected,counts=reference(fixture.data)
        if result['events']!=expected:
            pairs=list(zip(result['events'],expected))
            mismatch=next(((i,a,b) for i,(a,b) in enumerate(pairs) if a!=b),None)
            raise AssertionError(fixture.name+': event mismatch '+repr(mismatch or (len(result['events']),len(expected))))
        if s['source'][2:]!=[0,len(fixture.data)] or s['records']!=counts['records'] or s['objects']!=counts['records']+counts['groups'] or s['subrecords']!=counts['subrecords'] or s['opaque']!=counts['compressed'] or s['all_bodies']!=int(counts['compressed']==0):
            raise AssertionError(fixture.name+': summary differs')
        if result['copy']!=fixture.data or result['copied']!=len(fixture.data):raise AssertionError(fixture.name+': unchanged copy differs')
    else:
        if result['extras']:raise AssertionError('failed parse emitted digest')
        if result['copy'] or result['copied'] is not None:raise AssertionError('failed parse emitted copy')
        if s['offset']>len(fixture.data) or not 0<=s['parent_start']<=s['parent_end']<=len(fixture.data):raise AssertionError('diagnostic outside source')
        if s['cause'][0]!=0:raise AssertionError('malformed fixture failed for non-format reason')
        expected=expected_error(fixture)
        if expected is not None and (s['cause'][1],s['offset'])!=expected:
            raise AssertionError(fixture.name+': wrong exact diagnostic '+repr(s))
    return result


def verify_output(name,args,stdout):
    # Contract/resource protocols are installed alongside their native drivers.
    if name=='contracts':
        from case_spec import CONTRACTS
        expected=''.join('CONTRACT '+c+'\n' for c in CONTRACTS)
        if stdout!=expected:raise AssertionError('contract inventory incomplete or unexpected output')
        return
    if name=='resource':
        from case_spec import verify_resource
        verify_resource(args,stdout);return
    raise AssertionError('unknown functional entrypoint')
