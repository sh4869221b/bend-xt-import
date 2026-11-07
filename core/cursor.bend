import Base
import ./error.bend as E
import ./checked.bend as C
import ./bytes.bend as Bytes
import ./budget.bend as B

type Range is Data:
  Range{run: U32, origin: U32, start: U32, end: U32}

type Cursor is Data:
  Cursor{range: Range, position: U32}

type ReadState is Data:
  ReadState{cursor: Cursor, width: U32, seen: U32, value: U32, little: Bool}

type ReadResult is Data:
  ReadDone{cursor: Cursor, value: U32}
  NeedMore{state: ReadState}
  ReadProgress{state: ReadState}
  ReadFail{error: E.Error, state: ReadState}

type SourceOwner is Type:
  Source{run: U32, origin: U32, size: U32, allocation: B.Allocation}

type ByteWindow is Type:
  ByteWindow{source: SourceOwner, bytes: Bytes.OwnedBytes, base: U32}

def range_valid(run: U32, origin: U32, start: U32, end: U32, size: U32, valid: Bool) -> Result<&2, &2, E.Error, Range>:
  match valid:
    case True{}: Done{Range{run,origin,start,end}}
    case False{}: Fail{E.Bounds{start,end,size}}

def range_internal(run: U32, origin: U32, +start: U32, +end: U32, +size: U32) -> Result<&2, &2, E.Error, Range>:
  range_valid(run,origin,start,end,size,Bool.and(U32.is_le(start,end),U32.is_le(end,size)))

def child_valid(run: U32, origin: U32, +start: U32, end: U32, +offset: U32, n: U32, valid: Bool) -> Result<&2, &2, E.Error, Range>:
  match valid:
    case False{}: Fail{E.Bounds{offset,n,U32.sub(end,start)}}
    case True{}: Done{Range{run,origin,U32.add(start,offset),U32.add(U32.add(start,offset),n)}}

def child_offset(run: U32, origin: U32, +start: U32, +end: U32, +offset: U32, +n: U32, valid: Bool) -> Result<&2, &2, E.Error, Range>:
  match valid:
    case False{}: Fail{E.Bounds{offset,n,U32.sub(end,start)}}
    case True{}: child_valid(run,origin,start,end,offset,n,U32.is_le(n,U32.sub(U32.sub(end,start),offset)))

def child_order(run: U32, origin: U32, +start: U32, +end: U32, +offset: U32, n: U32, valid: Bool) -> Result<&2, &2, E.Error, Range>:
  match valid:
    case False{}: Fail{E.Bounds{start,0,end}}
    case True{}: child_offset(run,origin,start,end,offset,n,U32.is_le(offset,U32.sub(end,start)))

def subrange(parent: Range, +offset: U32, +n: U32) -> Result<&2, &2, E.Error, Range>:
  match parent:
    case Range{run,origin,+start,+end}:
      child_order(run,origin,start,end,offset,n,U32.is_le(start,end))

def cursor_valid(range: Range, position: U32, end: U32, valid: Bool) -> Result<&2, &2, E.Error, Cursor>:
  match valid:
    case False{}: Fail{E.Bounds{position,0,end}}
    case True{}: Done{Cursor{range,position}}

def cursor(r: Range, +position: U32) -> Result<&2, &2, E.Error, Cursor>:
  match r:
    case Range{+run,+origin,+start,+end}:
      cursor_valid(Range{run,origin,start,end},position,end,Bool.and(U32.is_le(start,position),U32.is_le(position,end)))

def take_fit(+run: U32, +origin: U32, start: U32, end: U32, +position: U32, +n: U32, valid: Bool) -> Result<&2, &1, E.Error, Cursor & Range>:
  match valid:
    case False{}: Fail{E.Bounds{position,n,end}}
    case True{}: (Done{(Cursor{Range{run,origin,start,end},U32.add(position,n)},Range{run,origin,position,U32.add(position,n)})})

def take_order(+run: U32, +origin: U32, start: U32, +end: U32, +position: U32, +n: U32, valid: Bool) -> Result<&2, &1, E.Error, Cursor & Range>:
  match valid:
    case False{}: Fail{E.Bounds{position,n,end}}
    case True{}: take_fit(run,origin,start,end,position,n,U32.is_le(n,U32.sub(end,position)))

def take(c: Cursor, n: U32) -> Result<&2, &1, E.Error, Cursor & Range>:
  match c:
    case Cursor{Range{run,origin,+start,+end},+position}:
      take_order(run,origin,start,end,position,n,Bool.and(U32.is_le(start,position),U32.is_le(position,end)))

def skip_ready(r: Result<&2, &1, E.Error, Cursor & Range>) -> Result<&2, &2, E.Error, Cursor>:
  match r:
    case Fail{error}: Fail{error}
    case Done{pair}:
      (cursor,range) = pair
      Done{cursor}

def skip(cursor: Cursor, n: U32) -> Result<&2, &2, E.Error, Cursor>:
  skip_ready(take(cursor,n))

def remaining_valid(position: U32, end: U32, valid: Bool) -> Result<&2, &2, E.Error, U32>:
  match valid:
    case False{}: Fail{E.Bounds{position,0,end}}
    case True{}: Done{U32.sub(end,position)}

def remaining(c: Cursor) -> Result<&2, &2, E.Error, U32>:
  match c:
    case Cursor{Range{run,origin,+start,+end},+position}:
      remaining_valid(position,end,Bool.and(U32.is_le(start,position),U32.is_le(position,end)))

def begin_ready(c: Cursor, width: U32, little: Bool, r: Result<&2, &1, E.Error, Cursor & Range>) -> Result<&2, &2, E.Error, ReadState>:
  match r:
    case Fail{error}: Fail{error}
    case Done{pair}: Done{ReadState{c,width,0,0,little}}

def begin_width(+c: Cursor, +width: U32, little: Bool, valid: Bool) -> Result<&2, &2, E.Error, ReadState>:
  match valid:
    case False{}: Fail{E.Bounds{0,width,4}}
    case True{}: begin_ready(c,width,little,take(c,width))

def begin(c: Cursor, +width: U32, little: Bool) -> Result<&2, &2, E.Error, ReadState>:
  begin_width(c,width,little,Bool.or(U32.is_eq(width,1),Bool.or(U32.is_eq(width,2),U32.is_eq(width,4))))

# seen is at most 3, so the shift is in 0..24. Modular OR is intentional.
def combine(value: U32, byte: U32, seen: U32, little: Bool) -> U32:
  match little:
    case True{}: U32.or(value,U32.shln(byte,U32.to_nat(U32.mul(seen,8))))
    case False{}: U32.or(U32.shln(value,8n),byte)

def read_byte(fuel: Nat, base: U32, length: U32, cursor: Cursor, width: U32, +seen: U32, value: U32, +little: Bool, p: B.Budget & Bytes.OwnedBytes & Result<&2, &2, E.Error, U32>) -> B.Budget & Bytes.OwnedBytes & ReadResult:
  match cursor:
    case Cursor{range,position}:
      (budget,bytes,result) = p
      match result:
        case Fail{error}: (budget,bytes,ReadFail{error,ReadState{Cursor{range,position},width,seen,value,little}})
        case Done{byte}: (budget,bytes,ReadProgress{ReadState{Cursor{range,U32.inc(position)},width,U32.inc(seen),combine(value,byte,seen,little),little}})

def read_available(fuel: Nat, budget: B.Budget, bytes: Bytes.OwnedBytes, +base: U32, length: U32, cursor: Cursor, position: U32, width: U32, seen: U32, value: U32, little: Bool, available: Bool) -> B.Budget & Bytes.OwnedBytes & ReadResult:
  match available:
    case False{}: (budget,bytes,NeedMore{ReadState{cursor,width,seen,value,little}})
    case True{}: read_byte(fuel,base,length,cursor,width,seen,value,little,Bytes.get(budget,bytes,U32.sub(position,base)))

def read_base(fuel: Nat, budget: B.Budget, bytes: Bytes.OwnedBytes, +base: U32, +length: U32, cursor: Cursor, +position: U32, width: U32, seen: U32, value: U32, little: Bool, valid: Bool) -> B.Budget & Bytes.OwnedBytes & ReadResult:
  match valid:
    case False{}: (budget,bytes,NeedMore{ReadState{cursor,width,seen,value,little}})
    case True{}: read_available(fuel,budget,bytes,base,length,cursor,position,width,seen,value,little,U32.is_lt(U32.sub(position,base),length))

def read_position(fuel: Nat, budget: B.Budget, bytes: Bytes.OwnedBytes, +base: U32, length: U32, cursor: Cursor, width: U32, seen: U32, value: U32, little: Bool) -> B.Budget & Bytes.OwnedBytes & ReadResult:
  match cursor:
    case Cursor{range,+position}:
      read_base(fuel,budget,bytes,base,length,Cursor{range,position},position,width,seen,value,little,U32.is_le(base,position))

def read_complete(fuel: Nat, budget: B.Budget, bytes: Bytes.OwnedBytes, base: U32, length: U32, cursor: Cursor, width: U32, seen: U32, value: U32, little: Bool, complete: Bool) -> B.Budget & Bytes.OwnedBytes & ReadResult:
  match complete:
    case True{}: (budget,bytes,ReadDone{cursor,value})
    case False{}: read_position(fuel,budget,bytes,base,length,cursor,width,seen,value,little)

def read_one(budget: B.Budget, bytes: Bytes.OwnedBytes, base: U32, length: U32, state: ReadState) -> B.Budget & Bytes.OwnedBytes & ReadResult:
  match state:
    case ReadState{cursor,+width,+seen,value,little}:
      read_complete(0n,budget,bytes,base,length,cursor,width,seen,value,little,U32.is_eq(seen,width))

def read_loop(fuel: Nat, +base: U32, +length: U32, p: B.Budget & Bytes.OwnedBytes & ReadResult) -> B.Budget & Bytes.OwnedBytes & ReadResult:
  match fuel:
    case 0n: p
    case 1n+rest:
      (budget,bytes,result) = p
      match result:
        case ReadProgress{state}: read_loop(rest,base,length,read_one(budget,bytes,base,length,state))
        case ReadDone{cursor,value}: (budget,bytes,ReadDone{cursor,value})
        case NeedMore{state}: (budget,bytes,NeedMore{state})
        case ReadFail{error,state}: (budget,bytes,ReadFail{error,state})

def continue_valid(budget: B.Budget, bytes: Bytes.OwnedBytes, +base: U32, +length: U32, state: ReadState, valid: Bool) -> B.Budget & Bytes.OwnedBytes & ReadResult:
  match valid:
    case False{}: (budget,bytes,ReadFail{E.InternalInvariant{20},state})
    case True{}: read_loop(4n,base,length,read_one(budget,bytes,base,length,state))

def continue_identity(budget: B.Budget, bytes: Bytes.OwnedBytes, base: U32, length: U32, +run: U32, +origin: U32, state: ReadState) -> B.Budget & Bytes.OwnedBytes & ReadResult:
  match state:
    case ReadState{Cursor{Range{+owner,+source,start,end},position},width,seen,value,little}:
      continue_valid(budget,bytes,base,length,ReadState{Cursor{Range{owner,source,start,end},position},width,seen,value,little},Bool.and(U32.is_eq(run,owner),U32.is_eq(origin,source)))

def source_identity(size: U32, p: B.Allocation & U32 & U32) -> SourceOwner:
  (allocation,run,origin) = p
  Source{run,origin,size,allocation}

def source_allocated(size: U32, p: B.Budget & Result<&2, &1, E.Error, B.Allocation>) -> B.Budget & Result<&2, &1, E.Error, SourceOwner>:
  (budget,result) = p
  match result:
    case Fail{error}: (budget,Fail{error})
    case Done{allocation}: (budget,Done{source_identity(size,B.identity(allocation))})

def source(budget: B.Budget, size: U32) -> B.Budget & Result<&2, &1, E.Error, SourceOwner>:
  source_allocated(size,B.allocate(budget,0,0))

def source_range(owner: SourceOwner, start: U32, end: U32) -> SourceOwner & Result<&2, &2, E.Error, Range>:
  match owner:
    case Source{+run,+origin,+size,allocation}:
      (Source{run,origin,size,allocation},range_internal(run,origin,start,end,size))

# Adapter-only. The caller guarantees bytes were read from this same source.
def bind_valid(source: SourceOwner, bytes: Bytes.OwnedBytes, base: U32, length: U32, size: U32, valid: Bool) -> Result<&1, &1, E.Error & SourceOwner & Bytes.OwnedBytes, ByteWindow>:
  match valid:
    case False{}: Fail{(E.Bounds{base,length,size},source,bytes)}
    case True{}: Done{ByteWindow{source,bytes,base}}

def bind_base(source: SourceOwner, bytes: Bytes.OwnedBytes, +base: U32, +length: U32, +size: U32, valid: Bool) -> Result<&1, &1, E.Error & SourceOwner & Bytes.OwnedBytes, ByteWindow>:
  match valid:
    case False{}: Fail{(E.Bounds{base,length,size},source,bytes)}
    case True{}: bind_valid(source,bytes,base,length,size,U32.is_le(length,U32.sub(size,base)))

def bind_meta(owner: SourceOwner, +base: U32, p: Bytes.OwnedBytes & U32 & U32 & U32 & U32) -> Result<&1, &1, E.Error & SourceOwner & Bytes.OwnedBytes, ByteWindow>:
  match owner:
    case Source{run,origin,+size,allocation}:
      (bytes,length,capacity,storageRun,storageOrigin) = p
      bind_base(Source{run,origin,size,allocation},bytes,base,length,size,U32.is_le(base,size))

def bind(owner: SourceOwner, bytes: Bytes.OwnedBytes, base: U32) -> Result<&1, &1, E.Error & SourceOwner & Bytes.OwnedBytes, ByteWindow>:
  bind_meta(owner,base,Bytes.metadata(bytes))

# Adapter-only; consuming the window is necessary to replace its storage.
def unbind(window: ByteWindow) -> SourceOwner & Bytes.OwnedBytes:
  match window:
    case ByteWindow{source,bytes,base}: (source,bytes)

def window_read_done(source: SourceOwner, base: U32, p: B.Budget & Bytes.OwnedBytes & ReadResult) -> B.Budget & ByteWindow & ReadResult:
  (budget,bytes,result) = p
  (budget,ByteWindow{source,bytes,base},result)

def window_read_meta(budget: B.Budget, source: SourceOwner, +base: U32, state: ReadState, p: Bytes.OwnedBytes & U32 & U32 & U32 & U32) -> B.Budget & ByteWindow & ReadResult:
  match source:
    case Source{+run,+origin,size,allocation}:
      (bytes,length,capacity,storageRun,storageOrigin) = p
      window_read_done(Source{run,origin,size,allocation},base,continue_identity(budget,bytes,base,length,run,origin,state))

def continued(budget: B.Budget, window: ByteWindow, state: ReadState) -> B.Budget & ByteWindow & ReadResult:
  match window:
    case ByteWindow{source,bytes,base}: window_read_meta(budget,source,base,state,Bytes.metadata(bytes))

def drop_source(budget: B.Budget, source: SourceOwner) -> B.Budget & Result<&1, &2, E.Error & B.Allocation, Unit>:
  match source:
    case Source{run,origin,size,allocation}: B.release(budget,allocation)

def read_u8(cursor: Cursor) -> Result<&2, &2, E.Error, ReadState>:
  begin(cursor,1,False{})
def read_u16_le(cursor: Cursor) -> Result<&2, &2, E.Error, ReadState>:
  begin(cursor,2,True{})
def read_u16_be(cursor: Cursor) -> Result<&2, &2, E.Error, ReadState>:
  begin(cursor,2,False{})
def read_u32_le(cursor: Cursor) -> Result<&2, &2, E.Error, ReadState>:
  begin(cursor,4,True{})
def read_u32_be(cursor: Cursor) -> Result<&2, &2, E.Error, ReadState>:
  begin(cursor,4,False{})
