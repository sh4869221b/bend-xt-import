import Base
import ../core/budget.bend as B
import ../core/cursor.bend as C
import ../core/error.bend as E
import ./types.bend as T
import ./error.bend as D

type Words is Data:
  Words{a: U32, b: U32, c: U32, d: U32, e: U32, f: U32}

type Subphase is Data:
  SubStart{}
  SubHeader{start: U32, seen: U32, signature: U32, size: U32, escape: Maybe<&2, C.Range>, effective: U32}
  EscapeLength{start: U32, seen: U32, value: U32}

type Phase is Data:
  Object{}
  Header{start: U32, seen: U32, words: Words}
  Body{record: T.Record, ordinal: U32, phase: Subphase}
  RecordFinish{record: T.Record, count: U32}
  Finished{summary: T.Summary}
  Broken{diagnostic: D.Diagnostic}

type Machine is Data:
  Machine{source: C.Range, limits: T.Limits, position: U32, depth: U32, parent_start: U32, parent_end: U32, records: U32, objects: U32, subrecords: U32, opaque: U32, phase: Phase}

type Scanner is Type:
  Scanner{allocation: B.Allocation, starts: Array<U32>, ends: Array<U32>, machine: Machine, requested: Bool}

type Status is Data:
  Yield{event: T.ScanEvent}
  NeedWindow{offset: U32}
  Complete{summary: T.Summary}
  Failed{diagnostic: D.Diagnostic}

type Decision is Data:
  ReadByte{machine: Machine}
  Emitted{machine: Machine, event: T.ScanEvent}
  Advance{machine: Machine}
  PushGroup{machine: Machine, group: T.Group}
  PopGroup{machine: Machine}
  Stopped{machine: Machine, status: Status}

# Combined scanner/stack/event/copy metadata charge; independently profiled.
def charge() -> U32:
  65536

def inspect(scanner: Scanner) -> Scanner & Machine:
  match scanner:
    case Scanner{allocation,starts,ends,+machine,requested}: (Scanner{allocation,starts,ends,machine,requested},machine)

def replace(scanner: Scanner, machine: Machine) -> Scanner:
  match scanner:
    case Scanner{allocation,starts,ends,old,requested}: Scanner{allocation,starts,ends,machine,requested}

def initial(+source: C.Range, limits: T.Limits) -> Machine:
  match source:
    case C.Range{run,origin,start,end}: Machine{source,limits,0,0,0,end,0,0,0,0,Object{}}

def allocated(machine: Machine, p: B.Budget & Result<&1, &1, E.Error & B.Reservation, Maybe<&1, B.Allocation>>) -> B.Budget & Result<&1, &1, E.Error & Maybe<&1, B.Reservation>, Scanner>:
  (budget,result) = p
  match result:
    case Fail{pair}:
      (error,ticket) = pair
      (budget,Fail{(error,Some{ticket})})
    case Done{None{}}: (budget,Fail{(E.InternalInvariant{40},None{})})
    case Done{Some{allocation}}: (budget,Done{Scanner{allocation,Array.new(U32,6n,0),Array.new(U32,6n,0),machine,False{}}})

def reserved(machine: Machine, p: B.Budget & Result<&2, &1, E.Error, B.Reservation>) -> B.Budget & Result<&1, &1, E.Error & Maybe<&1, B.Reservation>, Scanner>:
  (budget,result) = p
  match result:
    case Fail{error}: (budget,Fail{(error,None{})})
    case Done{ticket}: allocated(machine,B.settle(budget,ticket,B.live(charge())))

# State allocation failures retain a ticket if a violated budget invariant prevents settle.
def new(budget: B.Budget, machine: Machine) -> B.Budget & Result<&1, &1, E.Error & Maybe<&1, B.Reservation>, Scanner>:
  reserved(machine,B.reserve_many(budget,B.live(charge())))

def drop(budget: B.Budget, scanner: Scanner) -> B.Budget & Result<&1, &2, E.Error & B.Allocation, Unit>:
  match scanner:
    case Scanner{allocation,starts,ends,machine,requested}: B.release(budget,allocation)

def with_position(machine: Machine, next: U32) -> Machine:
  match machine:
    case Machine{source,limits,position,depth,parent_start,parent_end,records,objects,subrecords,opaque,phase}: Machine{source,limits,next,depth,parent_start,parent_end,records,objects,subrecords,opaque,phase}

def with_phase(machine: Machine, next: Phase) -> Machine:
  match machine:
    case Machine{source,limits,position,depth,parent_start,parent_end,records,objects,subrecords,opaque,phase}: Machine{source,limits,position,depth,parent_start,parent_end,records,objects,subrecords,opaque,next}

def context(machine: Machine, cause: D.Cause, offset: U32, record: Maybe<&2, U32>, declared: U32) -> D.Diagnostic:
  match machine:
    case Machine{source,limits,position,depth,parent_start,parent_end,records,objects,subrecords,opaque,phase}: D.make(source,cause,offset,parent_start,parent_end,record,depth,declared)

def fail(+machine: Machine, cause: D.Cause, offset: U32, record: Maybe<&2, U32>, declared: U32) -> Decision:
  +diagnostic = context(machine,cause,offset,record,declared)
  Stopped{with_phase(machine,Broken{diagnostic}),Failed{diagnostic}}

def source_of(machine: Machine) -> C.Range:
  match machine:
    case Machine{source,limits,position,depth,parent_start,parent_end,records,objects,subrecords,opaque,phase}: source

def position_of(machine: Machine) -> U32:
  match machine:
    case Machine{source,limits,position,depth,parent_start,parent_end,records,objects,subrecords,opaque,phase}: position

def phase_of(machine: Machine) -> Phase:
  match machine:
    case Machine{source,limits,position,depth,parent_start,parent_end,records,objects,subrecords,opaque,phase}: phase

# Index validation always precedes masked Array access.
def pushed(scanner: Scanner, +depth: U32, start: U32, end: U32, valid: Bool) -> Scanner & Result<&2, &2, E.Error, Unit>:
  match scanner valid:
    case Scanner{allocation,starts,ends,machine,requested} False{}: (Scanner{allocation,starts,ends,machine,requested},Fail{E.Bounds{depth,1,64}})
    case Scanner{allocation,starts,ends,machine,requested} True{}:
      (Scanner{allocation,Array.set(U32,starts,depth,start),Array.set(U32,ends,depth,end),machine,requested},Done{Unit{}})

def push(scanner: Scanner, +depth: U32, start: U32, end: U32) -> Scanner & Result<&2, &2, E.Error, Unit>:
  pushed(scanner,depth,start,end,U32.is_lt(depth,64))

def top_end(allocation: B.Allocation, starts: Array<U32>, machine: Machine, requested: Bool, start: U32, p: Array<U32> & U32) -> Scanner & Result<&2, &1, E.Error, U32 & U32>:
  (ends,end) = p
  (Scanner{allocation,starts,ends,machine,requested},Done{(start,end)})

def top_start(allocation: B.Allocation, ends: Array<U32>, machine: Machine, requested: Bool, index: U32, p: Array<U32> & U32) -> Scanner & Result<&2, &1, E.Error, U32 & U32>:
  (starts,start) = p
  top_end(allocation,starts,machine,requested,start,Array.get(U32,ends,index))

def top_valid(scanner: Scanner, +index: U32, valid: Bool) -> Scanner & Result<&2, &1, E.Error, U32 & U32>:
  match scanner valid:
    case Scanner{allocation,starts,ends,machine,requested} False{}: (Scanner{allocation,starts,ends,machine,requested},Fail{E.Bounds{index,1,64}})
    case Scanner{allocation,starts,ends,machine,requested} True{}:
      top_start(allocation,ends,machine,requested,index,Array.get(U32,starts,index))

def top(scanner: Scanner, +index: U32) -> Scanner & Result<&2, &1, E.Error, U32 & U32>:
  top_valid(scanner,index,U32.is_lt(index,64))

def record_start(record: T.Record) -> U32:
  match record:
    case T.Record{signature,flags,form_id,revision,version,unknown,header,payload,full,parent_start,parent_end,depth,ordinal,body}: T.range_start(full)

def owner_of(machine: Machine) -> Maybe<&2,U32>:
  match machine:
    case Machine{source,limits,position,depth,parent_start,parent_end,records,objects,subrecords,opaque,Body{record,ordinal,phase}}: Some{record_start(record)}
    case Machine{source,limits,position,depth,parent_start,parent_end,records,objects,subrecords,opaque,RecordFinish{record,count}}: Some{record_start(record)}
    case _: None{}

def mark_requested(scanner: Scanner, requested: Bool) -> Scanner:
  match scanner:
    case Scanner{allocation,starts,ends,machine,old}: Scanner{allocation,starts,ends,machine,requested}

def inspect_request(scanner: Scanner) -> Scanner & Machine & Bool:
  match scanner:
    case Scanner{allocation,starts,ends,+machine,+requested}: (Scanner{allocation,starts,ends,machine,requested},machine,requested)
