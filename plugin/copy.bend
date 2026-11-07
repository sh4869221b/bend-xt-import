import Base
import ../core/budget.bend as B
import ../core/bytes.bend as Bytes
import ../core/cursor.bend as C
import ../core/error.bend as E
import ./types.bend as T
import ./error.bend as D
import ./state.bend as S
import ./frame.bend as F

type CopyMode is Data:
  Reading{}
  PendingByte{+byte: U32}
  WaitingOutput{}
  CopyFinished{}
  CopyBroken{+diagnostic: D.Diagnostic, pending: Maybe<&2,U32>}

type CopyState is Type:
  CopyState{scanner: S.Scanner, +source: C.Range, +position: U32, mode: CopyMode, output: Maybe<&1,Bytes.OwnedBytes>, +requested: Bool}

type CopyResult is Type:
  CopyNeedWindow{+offset: U32}
  ChunkReady{bytes: Bytes.OwnedBytes, +final: Bool}
  CopyFailed{+diagnostic: D.Diagnostic}
  CopyDone{}

type CopyTick is Type:
  CopyAgain{}
  CopyReturn{result: CopyResult}

def diagnostic(+source: C.Range, cause: D.Cause, +position: U32, +declared: U32) -> D.Diagnostic:
  D.make(source,cause,position,0,T.range_end(source),None{},0,declared)

def failed(budget: B.Budget, window: C.ByteWindow, scanner: S.Scanner, +source: C.Range, +position: U32, output: Maybe<&1,Bytes.OwnedBytes>, pending: Maybe<&2,U32>, +error: D.Diagnostic) -> B.Budget & C.ByteWindow & CopyState & CopyTick:
  (budget,window,CopyState{scanner,source,position,CopyBroken{error,pending},output,False{}},CopyReturn{CopyFailed{error}})

def start_buffer(scanner: S.Scanner, +machine: S.Machine, output: Bytes.OwnedBytes, +valid: Bool) -> Result<&1,&1,D.Diagnostic & S.Scanner & Bytes.OwnedBytes,CopyState>:
  match machine valid:
    case S.Machine{source,limits,position,depth,parent_start,parent_end,records,objects,subrecords,opaque,S.Finished{summary}} True{}: Done{CopyState{scanner,source,0,Reading{},Some{output},False{}}}
    case _ _: Fail{(S.context(machine,D.Format{26},S.position_of(machine),S.owner_of(machine),0),scanner,output)}

def start_metadata(scanner: S.Scanner, +machine: S.Machine, p: Bytes.OwnedBytes & U32 & U32 & U32 & U32) -> Result<&1,&1,D.Diagnostic & S.Scanner & Bytes.OwnedBytes,CopyState>:
  (output,length,+capacity,run,origin) = p
  start_buffer(scanner,machine,output,Bool.and(U32.is_zero(length),Bool.and(U32.is_le(1,capacity),U32.is_le(capacity,65536))))

def start_inspected(output: Bytes.OwnedBytes, p: S.Scanner & S.Machine) -> Result<&1,&1,D.Diagnostic & S.Scanner & Bytes.OwnedBytes,CopyState>:
  (scanner,machine) = p
  start_metadata(scanner,machine,Bytes.metadata(output))

# Only a completed affine Scanner grants whole-source copy authorization.
def start(scanner: S.Scanner, output: Bytes.OwnedBytes) -> Result<&1,&1,D.Diagnostic & S.Scanner & Bytes.OwnedBytes,CopyState>:
  start_inspected(output,S.inspect(scanner))

def read_result(scanner: S.Scanner, +source: C.Range, +position: U32, output: Bytes.OwnedBytes, p: B.Budget & C.ByteWindow & C.ReadResult) -> B.Budget & C.ByteWindow & CopyState & CopyTick:
  (budget,window,result) = p
  match result:
    case C.ReadDone{cursor,byte}: (budget,window,CopyState{scanner,source,U32.inc(position),PendingByte{byte},Some{output},False{}},CopyAgain{})
    case C.NeedMore{state}: (budget,window,CopyState{scanner,source,position,Reading{},Some{output},True{}},CopyReturn{CopyNeedWindow{position}})
    case C.ReadFail{error,state}: failed(budget,window,scanner,source,position,Some{output},None{},diagnostic(source,D.Core{error},position,0))
    case _: failed(budget,window,scanner,source,position,Some{output},None{},diagnostic(source,D.Format{26},position,0))

def read_begun(budget: B.Budget, window: C.ByteWindow, scanner: S.Scanner, +source: C.Range, +position: U32, output: Bytes.OwnedBytes, result: Result<&2,&2,E.Error,C.ReadState>) -> B.Budget & C.ByteWindow & CopyState & CopyTick:
  match result:
    case Fail{error}: failed(budget,window,scanner,source,position,Some{output},None{},diagnostic(source,D.Core{error},position,0))
    case Done{state}: read_result(scanner,source,position,output,C.continued(budget,window,state))

def read_cursor(budget: B.Budget, window: C.ByteWindow, scanner: S.Scanner, +source: C.Range, +position: U32, output: Bytes.OwnedBytes, result: Result<&2,&2,E.Error,C.Cursor>) -> B.Budget & C.ByteWindow & CopyState & CopyTick:
  match result:
    case Fail{error}: failed(budget,window,scanner,source,position,Some{output},None{},diagnostic(source,D.Core{error},position,0))
    case Done{cursor}: read_begun(budget,window,scanner,source,position,output,C.read_u8(cursor))

def output_room(budget: B.Budget, window: C.ByteWindow, scanner: S.Scanner, +source: C.Range, +position: U32, output: Bytes.OwnedBytes, +complete: Bool, +full: Bool) -> B.Budget & C.ByteWindow & CopyState & CopyTick:
  match complete full:
    case True{} _: (budget,window,CopyState{scanner,source,position,CopyFinished{},None{},False{}},CopyReturn{ChunkReady{output,True{}}})
    case False{} True{}: (budget,window,CopyState{scanner,source,position,WaitingOutput{},None{},False{}},CopyReturn{ChunkReady{output,False{}}})
    case False{} False{}: read_cursor(budget,window,scanner,source,position,output,C.cursor(source,position))

def output_metadata(budget: B.Budget, window: C.ByteWindow, scanner: S.Scanner, +source: C.Range, +position: U32, p: Bytes.OwnedBytes & U32 & U32 & U32 & U32) -> B.Budget & C.ByteWindow & CopyState & CopyTick:
  (output,length,capacity,run,origin) = p
  output_room(budget,window,scanner,source,position,output,U32.is_eq(position,T.range_end(source)),U32.is_eq(length,capacity))

def appended(window: C.ByteWindow, scanner: S.Scanner, +source: C.Range, +position: U32, +byte: U32, p: B.Budget & Bytes.OwnedBytes & Result<&2,&2,E.Error,Unit>) -> B.Budget & C.ByteWindow & CopyState & CopyTick:
  (budget,output,result) = p
  match result:
    case Fail{error}: failed(budget,window,scanner,source,position,Some{output},Some{byte},diagnostic(source,D.Core{error},U32.sub(position,1),1))
    case Done{unit}: (budget,window,CopyState{scanner,source,position,Reading{},Some{output},False{}},CopyAgain{})

def once(budget: B.Budget, window: C.ByteWindow, copy: CopyState) -> B.Budget & C.ByteWindow & CopyState & CopyTick:
  match copy:
    case CopyState{scanner,+source,+position,Reading{},Some{output},requested}: output_metadata(budget,window,scanner,source,position,Bytes.metadata(output))
    case CopyState{scanner,+source,+position,PendingByte{+byte},Some{output},requested}: appended(window,scanner,source,position,byte,Bytes.append(budget,output,byte))
    case CopyState{scanner,+source,+position,CopyFinished{},output,requested}: (budget,window,CopyState{scanner,source,position,CopyFinished{},output,requested},CopyReturn{CopyDone{}})
    case CopyState{scanner,+source,+position,CopyBroken{+error,pending},output,requested}: (budget,window,CopyState{scanner,source,position,CopyBroken{error,pending},output,requested},CopyReturn{CopyFailed{error}})
    case CopyState{scanner,+source,+position,mode,output,requested}: failed(budget,window,scanner,source,position,output,None{},diagnostic(source,D.Format{26},position,0))

def exhausted(budget: B.Budget, window: C.ByteWindow, copy: CopyState) -> B.Budget & C.ByteWindow & CopyState & CopyResult:
  match copy:
    case CopyState{scanner,+source,+position,mode,output,requested}:
      +error = diagnostic(source,D.Format{26},position,131074)
      (budget,window,CopyState{scanner,source,position,CopyBroken{error,None{}},output,False{}},CopyFailed{error})

def loop(fuel: Nat, p: B.Budget & C.ByteWindow & CopyState & CopyTick) -> B.Budget & C.ByteWindow & CopyState & CopyResult:
  match fuel:
    case 0n:
      (budget,window,copy,tick) = p
      match tick:
        case CopyReturn{result}: (budget,window,copy,result)
        case CopyAgain{}: exhausted(budget,window,copy)
    case 1n+rest:
      (budget,window,copy,tick) = p
      match tick:
        case CopyReturn{result}: (budget,window,copy,result)
        case CopyAgain{}: loop(rest,once(budget,window,copy))

def identity(budget: B.Budget, window: C.ByteWindow, copy: CopyState, +same: Bool) -> B.Budget & C.ByteWindow & CopyState & CopyResult:
  match copy same:
    case CopyState{scanner,+source,+position,CopyBroken{+error,pending},output,requested} _: (budget,window,CopyState{scanner,source,position,CopyBroken{error,pending},output,requested},CopyFailed{error})
    case CopyState{scanner,+source,+position,mode,output,requested} True{}: loop(131074n,(budget,window,CopyState{scanner,source,position,mode,output,False{}},CopyAgain{}))
    case CopyState{scanner,+source,+position,mode,output,requested} False{}: loop(0n,failed(budget,window,scanner,source,position,output,None{},diagnostic(source,D.Format{23},position,0)))

def metadata_failed(budget: B.Budget, window: C.ByteWindow, copy: CopyState, error: E.Error) -> B.Budget & C.ByteWindow & CopyState & CopyResult:
  match copy:
    case CopyState{scanner,source,position,CopyBroken{+diagnostic,pending},output,requested}: (budget,window,CopyState{scanner,source,position,CopyBroken{diagnostic,pending},output,requested},CopyFailed{diagnostic})
    case CopyState{scanner,+source,+position,mode,output,requested}: loop(0n,failed(budget,window,scanner,source,position,output,None{},diagnostic(source,D.Core{error},position,0)))

def metadata(budget: B.Budget, copy: CopyState, p: C.ByteWindow & Result<&2,&1,E.Error,C.Range & U32 & U32>) -> B.Budget & C.ByteWindow & CopyState & CopyResult:
  match copy:
    case CopyState{scanner,+source,+position,mode,output,requested}:
      (window,result) = p
      match result:
        case Fail{error}: metadata_failed(budget,window,CopyState{scanner,source,position,mode,output,requested},error)
        case Done{values}:
          (full,base,length) = values
          identity(budget,window,CopyState{scanner,source,position,mode,output,requested},F.same_source(source,full))

def pump(budget: B.Budget, window: C.ByteWindow, copy: CopyState) -> B.Budget & C.ByteWindow & CopyState & CopyResult:
  metadata(budget,copy,C.window_metadata(window))

def resume_valid(copy: CopyState, bytes: Bytes.OwnedBytes, +valid: Bool) -> Result<&1,&1,D.Diagnostic & CopyState & Bytes.OwnedBytes,CopyState>:
  match copy valid:
    case CopyState{scanner,+source,+position,WaitingOutput{},None{},requested} True{}: Done{CopyState{scanner,source,position,Reading{},Some{bytes},False{}}}
    case CopyState{scanner,+source,+position,mode,output,requested} _: Fail{(diagnostic(source,D.Format{26},position,0),CopyState{scanner,source,position,mode,output,requested},bytes)}

def resume_metadata(copy: CopyState, p: Bytes.OwnedBytes & U32 & U32 & U32 & U32) -> Result<&1,&1,D.Diagnostic & CopyState & Bytes.OwnedBytes,CopyState>:
  (bytes,length,+capacity,run,origin) = p
  resume_valid(copy,bytes,Bool.and(U32.is_zero(length),Bool.and(U32.is_le(1,capacity),U32.is_le(capacity,65536))))

def resume(copy: CopyState, bytes: Bytes.OwnedBytes) -> Result<&1,&1,D.Diagnostic & CopyState & Bytes.OwnedBytes,CopyState>:
  resume_metadata(copy,Bytes.metadata(bytes))

def ended_reason(+requested: Bool) -> U32:
  match requested:
    case True{}: 25
    case False{}: 26

def input_ended(copy: CopyState) -> CopyState:
  match copy:
    case CopyState{scanner,+source,+position,CopyFinished{},output,requested}: CopyState{scanner,source,position,CopyFinished{},output,requested}
    case CopyState{scanner,+source,+position,CopyBroken{+error,pending},output,requested}: CopyState{scanner,source,position,CopyBroken{error,pending},output,requested}
    case CopyState{scanner,+source,+position,mode,output,requested}: CopyState{scanner,source,position,CopyBroken{diagnostic(source,D.Format{ended_reason(requested)},position,0),None{}},output,False{}}

def dropped(output: Maybe<&1,Bytes.OwnedBytes>, p: B.Budget & Result<&1,&2,E.Error & B.Allocation,Unit>) -> B.Budget & Maybe<&1,Bytes.OwnedBytes> & Result<&1,&2,E.Error & B.Allocation,Unit>:
  (budget,result) = p
  (budget,output,result)

def drop(budget: B.Budget, copy: CopyState) -> B.Budget & Maybe<&1,Bytes.OwnedBytes> & Result<&1,&2,E.Error & B.Allocation,Unit>:
  match copy:
    case CopyState{scanner,+source,+position,mode,output,requested}: dropped(output,S.drop(budget,scanner))
