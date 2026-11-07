import Base
import ../core/budget.bend as B
import ../core/bytes.bend as Bytes
import ../core/cursor.bend as C
import ../core/error.bend as E
import ./types.bend as T
import ./error.bend as D
import ./state.bend as S
import ./subrecords.bend as Sub

type StartResult is Type:
  Started{scanner: S.Scanner}
  StartFailed{diagnostic: D.Diagnostic, reservation: Maybe<&1,B.Reservation>}

type Tick is Data:
  Again{}
  Returned{status: S.Status}

def fail(+machine: S.Machine, +reason: U32, +offset: U32, +declared: U32) -> S.Decision:
  S.fail(machine,D.Format{reason},offset,S.owner_of(machine),declared)

def core_fail(+machine: S.Machine, +error: E.Error) -> S.Decision:
  S.fail(machine,D.Core{error},S.position_of(machine),S.owner_of(machine),0)

def compressed_count_valid(+compressed: Bool) -> U32:
  match compressed:
    case True{}: 1
    case False{}: 0

def compressed_count(+flags: U32) -> U32:
  compressed_count_valid(T.compressed(flags))

def record_complete(+machine: S.Machine, +signature: U32, +size: U32, +flags: U32, +form_id: U32, +revision: U32, +final_word: U32, +header: C.Range, +payload: C.Range, result: Result<&2,&2,E.Error,C.Range>) -> S.Decision:
  match machine result:
    case S.Machine{source,limits,position,depth,parent_start,parent_end,records,objects,subrecords,opaque,phase} Fail{error}:
      core_fail(S.Machine{source,limits,position,depth,parent_start,parent_end,records,objects,subrecords,opaque,phase},error)
    case S.Machine{source,limits,position,+depth,+parent_start,+parent_end,+records,objects,subrecords,opaque,phase} Done{+full}:
      +record = {T.Record{signature,flags,form_id,revision,U32.and(final_word,65535),U32.shrn(final_word,16n),header,payload,full,parent_start,parent_end,depth,records,T.body_kind(flags)}: T.Record}
      S.Emitted{S.Machine{source,limits,position,depth,parent_start,parent_end,U32.inc(records),U32.inc(objects),subrecords,U32.add(opaque,compressed_count(flags)),S.Body{record,0,S.SubStart{}}},T.RecordStart{record}}

def record_payload(+machine: S.Machine, +signature: U32, +size: U32, +flags: U32, +form_id: U32, +revision: U32, +final_word: U32, +start: U32, +header: C.Range, result: Result<&2,&2,E.Error,C.Range>) -> S.Decision:
  match result:
    case Fail{error}: core_fail(machine,error)
    case Done{payload}: record_complete(machine,signature,size,flags,form_id,revision,final_word,header,payload,C.subrange(S.source_of(machine),start,U32.add(24,size)))

def record_header(+machine: S.Machine, +signature: U32, +size: U32, +flags: U32, +form_id: U32, +revision: U32, +final_word: U32, +start: U32, result: Result<&2,&2,E.Error,C.Range>) -> S.Decision:
  match result:
    case Fail{error}: core_fail(machine,error)
    case Done{header}: record_payload(machine,signature,size,flags,form_id,revision,final_word,start,header,C.subrange(S.source_of(machine),U32.add(start,24),size))

def record_counts(+machine: S.Machine, +signature: U32, +size: U32, +flags: U32, +form_id: U32, +revision: U32, +final_word: U32, +start: U32, +record_count: U32, +object_count: U32, +enough_records: Bool, +enough_objects: Bool) -> S.Decision:
  match enough_records enough_objects:
    case False{} _: fail(machine,18,start,record_count)
    case True{} False{}: fail(machine,19,start,object_count)
    case True{} True{}: record_header(machine,signature,size,flags,form_id,revision,final_word,start,C.subrange(S.source_of(machine),start,24))

def checked_record_limit(+machine: S.Machine, +signature: U32, +size: U32, +flags: U32, +form_id: U32, +revision: U32, +final_word: U32, +start: U32, +record_count: U32, +object_count: U32, +record_limit: U32, +object_limit: U32, +fits: Bool) -> S.Decision:
  match fits:
    case False{}: fail(machine,9,start,size)
    case True{}: record_counts(machine,signature,size,flags,form_id,revision,final_word,start,record_count,object_count,U32.is_lt(record_count,record_limit),U32.is_lt(object_count,object_limit))

def record_fit(+machine: S.Machine, +signature: U32, +size: U32, +flags: U32, +form_id: U32, +revision: U32, +final_word: U32, +start: U32, +record_count: U32, +object_count: U32, +payload_limit: U32, +record_limit: U32, +object_limit: U32, +fits: Bool) -> S.Decision:
  match fits:
    case False{}: fail(machine,8,start,size)
    case True{}: checked_record_limit(machine,signature,size,flags,form_id,revision,final_word,start,record_count,object_count,record_limit,object_limit,U32.is_le(size,payload_limit))

def group_complete(+machine: S.Machine, +label: U32, +group_type: U32, stamp1: U32, stamp2: U32, +header: C.Range, result: Result<&2,&2,E.Error,C.Range>) -> S.Decision:
  match machine result:
    case S.Machine{source,limits,position,depth,parent_start,parent_end,records,objects,subrecords,opaque,phase} Fail{error}:
      core_fail(S.Machine{source,limits,position,depth,parent_start,parent_end,records,objects,subrecords,opaque,phase},error)
    case S.Machine{source,limits,position,+depth,+parent_start,+parent_end,+records,objects,subrecords,opaque,phase} Done{+full}:
      S.PushGroup{S.Machine{source,limits,position,U32.inc(depth),position,T.range_end(full),records,U32.inc(objects),subrecords,opaque,S.Object{}},T.Group{label,group_type,stamp1,stamp2,header,full,parent_start,parent_end,U32.inc(depth)}}

def group_header(+machine: S.Machine, +start: U32, +size: U32, +label: U32, +group_type: U32, stamp1: U32, stamp2: U32, result: Result<&2,&2,E.Error,C.Range>) -> S.Decision:
  match result:
    case Fail{error}: core_fail(machine,error)
    case Done{header}: group_complete(machine,label,group_type,stamp1,stamp2,header,C.subrange(S.source_of(machine),start,size))

def group_counts(+machine: S.Machine, +start: U32, +size: U32, +label: U32, +group_type: U32, stamp1: U32, stamp2: U32, +depth: U32, +count: U32, +depth_ok: Bool, +count_ok: Bool) -> S.Decision:
  match depth_ok count_ok:
    case False{} _: fail(machine,21,start,depth)
    case True{} False{}: fail(machine,19,start,count)
    case True{} True{}: group_header(machine,start,size,label,group_type,stamp1,stamp2,C.subrange(S.source_of(machine),start,24))

def group_fit(+machine: S.Machine, +start: U32, +size: U32, +label: U32, +group_type: U32, stamp1: U32, stamp2: U32, +depth: U32, +depth_cap: U32, +count: U32, +count_cap: U32, +fits: Bool) -> S.Decision:
  match fits:
    case False{}: fail(machine,8,start,size)
    case True{}: group_counts(machine,start,size,label,group_type,stamp1,stamp2,depth,count,U32.is_lt(depth,depth_cap),U32.is_lt(count,count_cap))

def group_size(+machine: S.Machine, +start: U32, +size: U32, +label: U32, +group_type: U32, stamp1: U32, stamp2: U32, +parent_end: U32, +depth: U32, +depth_cap: U32, +count: U32, +count_cap: U32, +valid: Bool) -> S.Decision:
  match valid:
    case False{}: fail(machine,7,start,size)
    case True{}: group_fit(machine,start,size,label,group_type,stamp1,stamp2,depth,depth_cap,count,count_cap,U32.is_le(size,U32.sub(parent_end,start)))

def object_kind(+machine: S.Machine, +start: U32, +signature: U32, +size: U32, +c: U32, +d: U32, +e: U32, +f: U32, +group: Bool) -> S.Decision:
  match machine group:
    case S.Machine{source,T.Limits{source_cap,payload_cap,record_cap,object_cap,sub_cap,depth_cap},position,depth,parent_start,parent_end,records,objects,subrecords,opaque,phase} True{}:
      group_size(machine,start,size,c,d,e,f,parent_end,depth,depth_cap,objects,object_cap,U32.is_le(24,size))
    case S.Machine{source,T.Limits{source_cap,payload_cap,record_cap,object_cap,sub_cap,depth_cap},position,depth,parent_start,parent_end,records,objects,subrecords,opaque,phase} False{}:
      record_fit(machine,signature,size,c,d,e,f,start,records,objects,payload_cap,record_cap,object_cap,U32.is_le(size,U32.sub(parent_end,position)))

def header_tes4(+machine: S.Machine, +start: U32, +signature: U32, +size: U32, +c: U32, +d: U32, +e: U32, +f: U32, +first: Bool, tes4: Bool) -> S.Decision:
  match first tes4:
    case True{} False{}: fail(machine,2,start,signature)
    case False{} True{}: fail(machine,3,start,signature)
    case _ _: object_kind(machine,start,signature,size,c,d,e,f,U32.is_eq(signature,T.grup()))

def header_complete(+machine: S.Machine, +start: U32, +words: S.Words, +records: U32) -> S.Decision:
  match words:
    case S.Words{signature,size,c,d,e,f}: header_tes4(machine,start,signature,size,c,d,e,f,U32.is_zero(records),U32.is_eq(signature,T.tes4()))

def object_room(+machine: S.Machine, +position: U32, +depth: U32, +records: U32, +room: Bool) -> S.Decision:
  match depth records room:
    case _ 0 False{}: fail(machine,4,position,24)
    case 0 _ False{}: fail(machine,6,position,24)
    case _ _ False{}: fail(machine,5,position,24)
    case _ _ True{}: S.Advance{S.with_phase(machine,S.Header{position,0,S.Words{0,0,0,0,0,0}})}

def object_end(+machine: S.Machine, +position: U32, +depth: U32, +parent_end: U32, +records: U32, +at_end: Bool) -> S.Decision:
  match machine depth records at_end:
    case S.Machine{source,limits,position0,depth0,parent_start,parent_end0,records0,objects,subrecords,opaque,phase} 0 0 True{}: fail(machine,1,position,0)
    case S.Machine{source,limits,position0,depth0,parent_start,parent_end0,records0,objects,subrecords,opaque,phase} 0 _ True{}:
      +summary = {T.Summary{source,records,objects,subrecords,opaque,U32.is_zero(opaque)}: T.Summary}
      S.Stopped{S.with_phase(machine,S.Finished{summary}),S.Complete{summary}}
    case _ _ _ True{}: S.PopGroup{machine}
    case _ _ _ False{}: object_room(machine,position,depth,records,U32.is_le(24,U32.sub(parent_end,position)))

def finish_record(+machine: S.Machine, +record: T.Record, +count: U32) -> S.Decision:
  match record:
    case T.Record{signature,flags,form_id,revision,version,unknown,header,payload,C.Range{run,origin,start,end},parent_start,parent_end,depth,ordinal,body}:
      S.Emitted{S.with_phase(machine,S.Object{}),T.RecordEnd{start,end,count,body}}

def prepare(+machine: S.Machine) -> S.Decision:
  match machine:
    case S.Machine{source,limits,position,depth,parent_start,parent_end,records,objects,subrecords,opaque,S.Object{}}: object_end(machine,position,depth,parent_end,records,U32.is_eq(position,parent_end))
    case S.Machine{source,limits,position,depth,parent_start,parent_end,records,objects,subrecords,opaque,S.Header{start,24,words}}: header_complete(machine,start,words,records)
    case S.Machine{source,limits,position,depth,parent_start,parent_end,records,objects,subrecords,opaque,S.Header{start,+seen,words}}: S.ReadByte{machine}
    case S.Machine{source,limits,position,depth,parent_start,parent_end,records,objects,subrecords,opaque,S.Body{record,ordinal,phase}}: Sub.prepare(machine,record,ordinal,phase)
    case S.Machine{source,limits,position,depth,parent_start,parent_end,records,objects,subrecords,opaque,S.RecordFinish{record,count}}: finish_record(machine,record,count)
    case S.Machine{source,limits,position,depth,parent_start,parent_end,records,objects,subrecords,opaque,S.Finished{summary}}: S.Stopped{machine,S.Complete{summary}}
    case S.Machine{source,limits,position,depth,parent_start,parent_end,records,objects,subrecords,opaque,S.Broken{diagnostic}}: S.Stopped{machine,S.Failed{diagnostic}}

# A complete header requires at most 24 one-byte checked reads. No partial byte
# is ever reread, and each public call performs a fixed maximum of 64 transitions.
def word_slot(+a: U32, +b: U32, +c: U32, +d: U32, +e: U32, +f: U32, +slot: U32, +index: U32, +byte: U32) -> S.Words:
  match slot:
    case 0: S.Words{Sub.assemble(a,byte,index),b,c,d,e,f}
    case 1: S.Words{a,Sub.assemble(b,byte,index),c,d,e,f}
    case 2: S.Words{a,b,Sub.assemble(c,byte,index),d,e,f}
    case 3: S.Words{a,b,c,Sub.assemble(d,byte,index),e,f}
    case 4: S.Words{a,b,c,d,Sub.assemble(e,byte,index),f}
    case +_: S.Words{a,b,c,d,e,Sub.assemble(f,byte,index)}

def word_byte(+words: S.Words, +index: U32, +byte: U32) -> S.Words:
  match words:
    case S.Words{a,b,c,d,e,f}:
      word_slot(a,b,c,d,e,f,U32.div(index,4),U32.mod(index,4),byte)

def accept(+machine: S.Machine, +byte: U32) -> S.Machine:
  match machine:
    case S.Machine{source,limits,position,depth,parent_start,parent_end,records,objects,subrecords,opaque,S.Header{start,+seen,words}}:
      S.Machine{source,limits,U32.inc(position),depth,parent_start,parent_end,records,objects,subrecords,opaque,S.Header{start,U32.inc(seen),word_byte(words,seen,byte)}}
    case S.Machine{source,limits,position,depth,parent_start,parent_end,records,objects,subrecords,opaque,S.Body{record,ordinal,phase}}:
      S.Machine{source,limits,U32.inc(position),depth,parent_start,parent_end,records,objects,subrecords,opaque,S.Body{record,ordinal,Sub.accept(phase,byte)}}
    case _: machine

def stopped(budget: B.Budget, window: C.ByteWindow, scanner: S.Scanner, decision: S.Decision) -> B.Budget & C.ByteWindow & S.Scanner & Tick:
  match decision:
    case S.Stopped{machine,status}: (budget,window,S.replace(scanner,machine),Returned{status})
    case _: (budget,window,scanner,Returned{S.Failed{D.Diagnostic{D.Format{26},0,0,0,0,0,None{},0,0}}})

def read_result(scanner: S.Scanner, +machine: S.Machine, p: B.Budget & C.ByteWindow & C.ReadResult) -> B.Budget & C.ByteWindow & S.Scanner & Tick:
  (budget,window,result) = p
  match result:
    case C.ReadDone{cursor,byte}: (budget,window,S.replace(scanner,accept(machine,byte)),Again{})
    case C.NeedMore{state}: (budget,window,S.mark_requested(S.replace(scanner,machine),True{}),Returned{S.NeedWindow{S.position_of(machine)}})
    case C.ReadFail{error,state}: stopped(budget,window,scanner,core_fail(machine,error))
    case _: stopped(budget,window,scanner,fail(machine,26,S.position_of(machine),0))

def read_begun(budget: B.Budget, window: C.ByteWindow, scanner: S.Scanner, +machine: S.Machine, result: Result<&2,&2,E.Error,C.ReadState>) -> B.Budget & C.ByteWindow & S.Scanner & Tick:
  match result:
    case Fail{error}: stopped(budget,window,scanner,core_fail(machine,error))
    case Done{state}: read_result(scanner,machine,C.continued(budget,window,state))

def read_cursor(budget: B.Budget, window: C.ByteWindow, scanner: S.Scanner, +machine: S.Machine, result: Result<&2,&2,E.Error,C.Cursor>) -> B.Budget & C.ByteWindow & S.Scanner & Tick:
  match result:
    case Fail{error}: stopped(budget,window,scanner,core_fail(machine,error))
    case Done{cursor}: read_begun(budget,window,scanner,machine,C.read_u8(cursor))

def pushed(budget: B.Budget, window: C.ByteWindow, +machine: S.Machine, +group: T.Group, p: S.Scanner & Result<&2,&2,E.Error,Unit>) -> B.Budget & C.ByteWindow & S.Scanner & Tick:
  (scanner,result) = p
  match result:
    case Fail{error}: stopped(budget,window,scanner,core_fail(machine,error))
    case Done{unit}: (budget,window,S.replace(scanner,machine),Returned{S.Yield{T.GroupStart{group}}})

def push_group(budget: B.Budget, window: C.ByteWindow, scanner: S.Scanner, +machine: S.Machine, +group: T.Group) -> B.Budget & C.ByteWindow & S.Scanner & Tick:
  match group:
    case T.Group{label,kind,stamp1,stamp2,header,full,parent_start,parent_end,depth}:
      pushed(budget,window,machine,group,S.push(scanner,U32.sub(depth,1),T.range_start(full),T.range_end(full)))

def parent_popped(budget: B.Budget, window: C.ByteWindow, +machine: S.Machine, +old_start: U32, +old_end: U32, +old_depth: U32, p: S.Scanner & Result<&2,&1,E.Error,U32 & U32>) -> B.Budget & C.ByteWindow & S.Scanner & Tick:
  match machine:
    case S.Machine{source,limits,position,depth,parent_start,parent_end,records,objects,subrecords,opaque,phase}:
      (scanner,result) = p
      match result:
        case Fail{error}: stopped(budget,window,scanner,core_fail(machine,error))
        case Done{pair}:
          (start,end) = pair
          (budget,window,S.replace(scanner,S.Machine{source,limits,position,U32.sub(depth,1),start,end,records,objects,subrecords,opaque,S.Object{}}),Returned{S.Yield{T.GroupEnd{old_start,old_end,old_depth}}})

def popped_parent_result(p: S.Scanner & Result<&2,&1,E.Error,U32 & U32>) -> S.Scanner & Result<&2,&1,E.Error,U32 & U32>:
  (scanner,result) = p
  match result:
    case Fail{error}: (scanner,Fail{error})
    case Done{pair}:
      (start,end) = pair
      (scanner,Done{(U32.add(start,24),end)})

def popped_parent(budget: B.Budget, window: C.ByteWindow, scanner: S.Scanner, +machine: S.Machine, +start: U32, +end: U32, +depth: U32, +root: Bool) -> B.Budget & C.ByteWindow & S.Scanner & Tick:
  match root:
    case True{}: parent_popped(budget,window,machine,start,end,depth,(scanner,Done{(0,T.range_end(S.source_of(machine)))}))
    case False{}: parent_popped(budget,window,machine,start,end,depth,popped_parent_result(S.top(scanner,U32.sub(depth,2))))

def pop_group(budget: B.Budget, window: C.ByteWindow, scanner: S.Scanner, +machine: S.Machine) -> B.Budget & C.ByteWindow & S.Scanner & Tick:
  match machine:
    case S.Machine{source,limits,position,depth,parent_start,parent_end,records,objects,subrecords,opaque,phase}:
      popped_parent(budget,window,scanner,machine,U32.sub(parent_start,24),parent_end,depth,U32.is_eq(depth,1))

def execute(budget: B.Budget, window: C.ByteWindow, scanner: S.Scanner, decision: S.Decision) -> B.Budget & C.ByteWindow & S.Scanner & Tick:
  match decision:
    case S.Advance{machine}: (budget,window,S.replace(scanner,machine),Again{})
    case S.Emitted{machine,event}: (budget,window,S.replace(scanner,machine),Returned{S.Yield{event}})
    case S.Stopped{machine,status}: (budget,window,S.replace(scanner,machine),Returned{status})
    case S.PushGroup{machine,group}: push_group(budget,window,scanner,machine,group)
    case S.PopGroup{machine}: pop_group(budget,window,scanner,machine)
    case S.ReadByte{+machine}: read_cursor(budget,window,scanner,machine,C.cursor(S.source_of(machine),S.position_of(machine)))

def once(budget: B.Budget, window: C.ByteWindow, p: S.Scanner & S.Machine) -> B.Budget & C.ByteWindow & S.Scanner & Tick:
  (scanner,machine) = p
  execute(budget,window,scanner,prepare(machine))

def exhausted(budget: B.Budget, window: C.ByteWindow, p: S.Scanner & S.Machine) -> B.Budget & C.ByteWindow & S.Scanner & S.Status:
  (scanner,+machine) = p
  +diagnostic = S.context(machine,D.Format{26},S.position_of(machine),S.owner_of(machine),64)
  (budget,window,S.replace(scanner,S.with_phase(machine,S.Broken{diagnostic})),S.Failed{diagnostic})

def loop(fuel: Nat, p: B.Budget & C.ByteWindow & S.Scanner & Tick) -> B.Budget & C.ByteWindow & S.Scanner & S.Status:
  match fuel:
    case 0n:
      (budget,window,scanner,tick) = p
      match tick:
        case Returned{status}: (budget,window,scanner,status)
        case Again{}: exhausted(budget,window,S.inspect(scanner))
    case 1n+rest:
      (budget,window,scanner,tick) = p
      match tick:
        case Returned{status}: (budget,window,scanner,status)
        case Again{}: loop(rest,once(budget,window,S.inspect(scanner)))

def same_source(+left: C.Range, +right: C.Range) -> Bool:
  match left right:
    case C.Range{a,b,c,d} C.Range{e,f,g,h}: Bool.and(U32.is_eq(a,e),Bool.and(U32.is_eq(b,f),Bool.and(U32.is_eq(c,g),U32.is_eq(d,h))))

def next_identity(budget: B.Budget, window: C.ByteWindow, scanner: S.Scanner, +machine: S.Machine, +valid: Bool) -> B.Budget & C.ByteWindow & S.Scanner & S.Status:
  match machine valid:
    case S.Machine{source,limits,position,depth,parent_start,parent_end,records,objects,subrecords,opaque,S.Broken{diagnostic}} _: (budget,window,scanner,S.Failed{diagnostic})
    case _ True{}: loop(64n,(budget,window,S.mark_requested(scanner,False{}),Again{}))
    case _ False{}: loop(0n,stopped(budget,window,scanner,fail(machine,23,S.position_of(machine),0)))

def metadata_failed(budget: B.Budget, window: C.ByteWindow, scanner: S.Scanner, +machine: S.Machine, error: E.Error) -> B.Budget & C.ByteWindow & S.Scanner & S.Status:
  match machine:
    case S.Machine{source,limits,position,depth,parent_start,parent_end,records,objects,subrecords,opaque,S.Broken{diagnostic}}: (budget,window,scanner,S.Failed{diagnostic})
    case _: loop(0n,stopped(budget,window,scanner,core_fail(machine,error)))

def next_metadata(budget: B.Budget, scanner: S.Scanner, +machine: S.Machine, p: C.ByteWindow & Result<&2,&1,E.Error,C.Range & U32 & U32>) -> B.Budget & C.ByteWindow & S.Scanner & S.Status:
  (window,result) = p
  match result:
    case Fail{error}: metadata_failed(budget,window,scanner,machine,error)
    case Done{metadata}:
      (source,base,length) = metadata
      next_identity(budget,window,scanner,machine,same_source(S.source_of(machine),source))

def next_inspected(budget: B.Budget, window: C.ByteWindow, p: S.Scanner & S.Machine) -> B.Budget & C.ByteWindow & S.Scanner & S.Status:
  (scanner,machine) = p
  next_metadata(budget,scanner,machine,C.window_metadata(window))

def next(budget: B.Budget, window: C.ByteWindow, scanner: S.Scanner) -> B.Budget & C.ByteWindow & S.Scanner & S.Status:
  next_inspected(budget,window,S.inspect(scanner))

def started(window: C.ByteWindow, +source: C.Range, p: B.Budget & Result<&1,&1,E.Error & Maybe<&1,B.Reservation>,S.Scanner>) -> B.Budget & C.ByteWindow & StartResult:
  (budget,result) = p
  match result:
    case Done{scanner}: (budget,window,Started{scanner})
    case Fail{pair}:
      (error,ticket) = pair
      (budget,window,StartFailed{D.source(source,D.Core{error},0),ticket})

def start_size(budget: B.Budget, window: C.ByteWindow, +source: C.Range, +limits: T.Limits, +size: U32, +fits: Bool) -> B.Budget & C.ByteWindow & StartResult:
  match fits:
    case False{}: (budget,window,StartFailed{D.source(source,D.Format{22},size),None{}})
    case True{}: started(window,source,S.new(budget,S.initial(source,limits)))

def start_limits(budget: B.Budget, window: C.ByteWindow, +source: C.Range, +limits: T.Limits, +valid: Bool) -> B.Budget & C.ByteWindow & StartResult:
  match limits valid:
    case T.Limits{cap,payload,records,objects,subrecords,depth} False{}: (budget,window,StartFailed{D.source(source,D.Format{27},0),None{}})
    case T.Limits{cap,payload,records,objects,subrecords,depth} True{}: start_size(budget,window,source,limits,T.range_end(source),U32.is_le(T.range_end(source),cap))

def start_metadata(budget: B.Budget, +limits: T.Limits, p: C.ByteWindow & Result<&2,&1,E.Error,C.Range & U32 & U32>) -> B.Budget & C.ByteWindow & StartResult:
  (window,result) = p
  match result:
    case Fail{error}: (budget,window,StartFailed{D.Diagnostic{D.Core{error},0,0,0,0,0,None{},0,0},None{}})
    case Done{metadata}:
      (source,base,length) = metadata
      start_limits(budget,window,source,limits,T.limits_valid(limits))

def start(budget: B.Budget, window: C.ByteWindow, +limits: T.Limits) -> B.Budget & C.ByteWindow & StartResult:
  start_metadata(budget,limits,C.window_metadata(window))

def ended_requested(scanner: S.Scanner, +machine: S.Machine, +requested: Bool) -> S.Scanner:
  match machine requested:
    case S.Machine{source,limits,position,depth,parent_start,parent_end,records,objects,subrecords,opaque,S.Finished{summary}} _: scanner
    case S.Machine{source,limits,position,depth,parent_start,parent_end,records,objects,subrecords,opaque,S.Broken{diagnostic}} _: scanner
    case _ True{}: S.replace(scanner,S.with_phase(machine,S.Broken{S.context(machine,D.Format{25},S.position_of(machine),S.owner_of(machine),0)}))
    case _ False{}: S.replace(scanner,S.with_phase(machine,S.Broken{S.context(machine,D.Format{26},S.position_of(machine),S.owner_of(machine),0)}))

def ended_inspected(p: S.Scanner & S.Machine & Bool) -> S.Scanner:
  (scanner,machine,requested) = p
  ended_requested(scanner,machine,requested)

def input_ended(scanner: S.Scanner) -> S.Scanner:
  ended_inspected(S.inspect_request(scanner))
