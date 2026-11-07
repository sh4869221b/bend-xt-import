import Base
import ../core/cursor.bend as C
import ../core/error.bend as E
import ./types.bend as T
import ./error.bend as D
import ./state.bend as S

# Pure framing transitions. Only frame.next reads bytes or owns Scanner.
def broken(+machine: S.Machine, +error: E.Error, +offset: U32, +owner: U32) -> S.Decision:
  S.fail(machine,D.Core{error},offset,Some{owner},0)

def field_done(+machine: S.Machine, +record: T.Record, +ordinal: U32, +signature: U32, +original_size: U32, +length: U32, escape: Maybe<&2,C.Range>, +start: U32, +owner: U32, +header: C.Range, +payload: C.Range, result: Result<&2,&2,E.Error,C.Range>) -> S.Decision:
  match machine result:
    case S.Machine{source,limits,position,depth,parent_start,parent_end,records,objects,subrecords,opaque,phase} Fail{error}:
      broken(S.Machine{source,limits,position,depth,parent_start,parent_end,records,objects,subrecords,opaque,phase},error,start,owner)
    case S.Machine{source,limits,position,depth,parent_start,parent_end,records,objects,subrecords,opaque,phase} Done{+full}:
      match full:
        case C.Range{run,origin,first,end}:
          S.Emitted{S.Machine{source,limits,end,depth,parent_start,parent_end,records,objects,U32.inc(subrecords),opaque,S.Body{record,U32.inc(ordinal),S.SubStart{}}},T.Field{T.Subrecord{signature,original_size,length,header,payload,full,escape,owner,ordinal}}}

def field_payload(+machine: S.Machine, +record: T.Record, +ordinal: U32, +signature: U32, +original_size: U32, +length: U32, +escape: Maybe<&2,C.Range>, +start: U32, +owner: U32, +header: C.Range, result: Result<&2,&2,E.Error,C.Range>) -> S.Decision:
  match escape result:
    case None{} Fail{error}: broken(machine,error,start,owner)
    case Some{range} Fail{error}: broken(machine,error,start,owner)
    case None{} Done{payload}: field_done(machine,record,ordinal,signature,original_size,length,None{},start,owner,header,payload,C.subrange(S.source_of(machine),start,U32.add(6,length)))
    case Some{+range} Done{payload}: field_done(machine,record,ordinal,signature,original_size,length,Some{range},start,owner,header,payload,C.subrange(S.source_of(machine),T.range_start(range),U32.add(16,length)))

def field_header(+machine: S.Machine, +record: T.Record, +ordinal: U32, +signature: U32, +original_size: U32, +length: U32, escape: Maybe<&2,C.Range>, +start: U32, +owner: U32, result: Result<&2,&2,E.Error,C.Range>) -> S.Decision:
  match result:
    case Fail{error}: broken(machine,error,start,owner)
    case Done{header}: field_payload(machine,record,ordinal,signature,original_size,length,escape,start,owner,header,C.subrange(S.source_of(machine),U32.add(start,6),length))

def field_fit(+machine: S.Machine, +record: T.Record, +ordinal: U32, +signature: U32, +original_size: U32, +length: U32, escape: Maybe<&2,C.Range>, +start: U32, +owner: U32, +reason: U32, +fits: Bool) -> S.Decision:
  match fits:
    case False{}: S.fail(machine,D.Format{reason},start,Some{owner},length)
    case True{}: field_header(machine,record,ordinal,signature,original_size,length,escape,start,owner,C.subrange(S.source_of(machine),start,6))

def real_header(+machine: S.Machine, +record: T.Record, +ordinal: U32, +signature: U32, +size: U32, escape: Maybe<&2,C.Range>, +effective: U32, +start: U32, +owner: U32, +position: U32, +end: U32) -> S.Decision:
  match escape:
    case None{}: field_fit(machine,record,ordinal,signature,size,size,None{},start,owner,11,U32.is_le(size,U32.sub(end,position)))
    case Some{range}: field_fit(machine,record,ordinal,signature,size,effective,Some{range},start,owner,17,U32.is_le(effective,U32.sub(end,position)))

def escape_room(+machine: S.Machine, +record: T.Record, +ordinal: U32, +start: U32, +owner: U32, +room: Bool) -> S.Decision:
  match room:
    case False{}: S.fail(machine,D.Format{13},start,Some{owner},4)
    case True{}: S.Advance{S.with_phase(machine,S.Body{record,ordinal,S.EscapeLength{start,0,0}})}

def escape_size(+machine: S.Machine, +record: T.Record, +ordinal: U32, +start: U32, +owner: U32, +size: U32, +position: U32, +end: U32, +valid: Bool) -> S.Decision:
  match valid:
    case False{}: S.fail(machine,D.Format{12},start,Some{owner},size)
    case True{}: escape_room(machine,record,ordinal,start,owner,U32.is_le(4,U32.sub(end,position)))

def header_kind(+machine: S.Machine, +record: T.Record, +ordinal: U32, +signature: U32, +size: U32, escape: Maybe<&2,C.Range>, +effective: U32, +start: U32, +owner: U32, +position: U32, +end: U32, +is_escape: Bool) -> S.Decision:
  match escape is_escape:
    case None{} False{}: real_header(machine,record,ordinal,signature,size,None{},effective,start,owner,position,end)
    case Some{range} False{}: real_header(machine,record,ordinal,signature,size,Some{range},effective,start,owner,position,end)
    case Some{range} True{}: S.fail(machine,D.Format{16},start,Some{owner},size)
    case None{} True{}: escape_size(machine,record,ordinal,start,owner,size,position,end,U32.is_eq(size,4))

def escape_span(+machine: S.Machine, +record: T.Record, +ordinal: U32, +start: U32, +owner: U32, +position: U32, +effective: U32, result: Result<&2,&2,E.Error,C.Range>) -> S.Decision:
  match result:
    case Fail{error}: broken(machine,error,start,owner)
    case Done{range}: S.Advance{S.with_phase(machine,S.Body{record,ordinal,S.SubHeader{position,0,0,0,Some{range},effective}})}

def escape_header(+machine: S.Machine, +record: T.Record, +ordinal: U32, +start: U32, +owner: U32, +position: U32, +effective: U32, +room: Bool) -> S.Decision:
  match room:
    case False{}: S.fail(machine,D.Format{15},position,Some{owner},6)
    case True{}: escape_span(machine,record,ordinal,start,owner,position,effective,C.subrange(S.source_of(machine),start,10))

def escape_complete(+machine: S.Machine, +record: T.Record, +ordinal: U32, +start: U32, +owner: U32, +position: U32, +end: U32, +effective: U32, +at_end: Bool) -> S.Decision:
  match at_end:
    case True{}: S.fail(machine,D.Format{14},start,Some{owner},effective)
    case False{}: escape_header(machine,record,ordinal,start,owner,position,effective,U32.is_le(6,U32.sub(end,position)))

def begin_room(+machine: S.Machine, +record: T.Record, +ordinal: U32, +position: U32, +owner: U32, +room: Bool) -> S.Decision:
  match room:
    case False{}: S.fail(machine,D.Format{10},position,Some{owner},6)
    case True{}: S.Advance{S.with_phase(machine,S.Body{record,ordinal,S.SubHeader{position,0,0,0,None{},0}})}

def begin_count(+machine: S.Machine, +record: T.Record, +ordinal: U32, +position: U32, +end: U32, +owner: U32, +count: U32, +allowed: Bool) -> S.Decision:
  match allowed:
    case False{}: S.fail(machine,D.Format{20},position,Some{owner},count)
    case True{}: begin_room(machine,record,ordinal,position,owner,U32.is_le(6,U32.sub(end,position)))

def begin_end(+machine: S.Machine, +record: T.Record, +ordinal: U32, +position: U32, +end: U32, +owner: U32, +count: U32, +limit: U32, +at_end: Bool) -> S.Decision:
  match at_end:
    case True{}: S.Advance{S.with_phase(machine,S.RecordFinish{record,ordinal})}
    case False{}: begin_count(machine,record,ordinal,position,end,owner,count,U32.is_lt(count,limit))

def prepare_phase(+machine: S.Machine, +record: T.Record, +ordinal: U32, +phase: S.Subphase, +position: U32, +end: U32, +owner: U32, +count: U32, +limit: U32) -> S.Decision:
  match phase:
    case S.SubStart{}: begin_end(machine,record,ordinal,position,end,owner,count,limit,U32.is_eq(position,end))
    case S.SubHeader{start,6,+signature,size,escape,effective}: header_kind(machine,record,ordinal,signature,size,escape,effective,start,owner,position,end,U32.is_eq(signature,T.xxxx()))
    case S.SubHeader{start,seen,signature,size,escape,effective}: S.ReadByte{machine}
    case S.EscapeLength{start,4,effective}: escape_complete(machine,record,ordinal,start,owner,position,end,effective,U32.is_eq(position,end))
    case S.EscapeLength{start,seen,value}: S.ReadByte{machine}

def prepare_record(+machine: S.Machine, +record: T.Record, +ordinal: U32, +phase: S.Subphase, +position: U32, +count: U32, +limit: U32) -> S.Decision:
  match record:
    case T.Record{signature,flags,form_id,revision,version,unknown,header,payload,C.Range{run,origin,owner,end},parent_start,parent_end,depth,index,T.OpaqueCompressed{}}:
      S.Advance{S.with_position(S.with_phase(machine,S.RecordFinish{record,0}),end)}
    case T.Record{signature,flags,form_id,revision,version,unknown,header,payload,C.Range{run,origin,owner,end},parent_start,parent_end,depth,index,T.Structural{}}:
      prepare_phase(machine,record,ordinal,phase,position,end,owner,count,limit)

def prepare(+machine: S.Machine, +record: T.Record, +ordinal: U32, +phase: S.Subphase) -> S.Decision:
  match machine:
    case S.Machine{source,T.Limits{source_cap,payload_cap,record_cap,object_cap,sub_cap,depth_cap},position,depth,parent_start,parent_end,records,objects,count,opaque,old}:
      prepare_record(machine,record,ordinal,phase,position,count,sub_cap)

# All shifts are bounded by at most three preceding bytes.
def assemble(+value: U32, +byte: U32, +seen: U32) -> U32:
  U32.or(value,U32.shln(byte,U32.to_nat(U32.mul(seen,8))))

def header_byte(+start: U32, +seen: U32, +signature: U32, +size: U32, escape: Maybe<&2,C.Range>, +effective: U32, +byte: U32, +in_signature: Bool) -> S.Subphase:
  match in_signature:
    case True{}: S.SubHeader{start,U32.inc(seen),assemble(signature,byte,seen),size,escape,effective}
    case False{}: S.SubHeader{start,U32.inc(seen),signature,assemble(size,byte,U32.sub(seen,4)),escape,effective}

def accept(+phase: S.Subphase, +byte: U32) -> S.Subphase:
  match phase:
    case S.SubStart{}: S.SubStart{}
    case S.SubHeader{start,+seen,signature,size,escape,effective}: header_byte(start,seen,signature,size,escape,effective,byte,U32.is_lt(seen,4))
    case S.EscapeLength{start,+seen,value}: S.EscapeLength{start,U32.inc(seen),assemble(value,byte,seen)}
