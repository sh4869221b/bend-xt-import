import Base
import ../../core/budget.bend as B
import ../../core/bytes.bend as Bytes
import ../../core/cursor.bend as C
import ../../core/error.bend as E

type Case is Data:
  Case{width: U32, little: Bool, value: U32, foreign: Bool, work: U32, base: U32}

def assert_bool(valid: Bool) -> IO(Unit):
  match valid:
    case True{}: IO.print("cursor-balanced")
    case False{}: IO.die(Unit,70,"cursor work mismatch")

def assert_work(expected: U32, actual: U32) -> IO(Unit):
  assert_bool(U32.is_eq(expected,actual))

def finished(expected: U32, result: Result<&1, &2, E.Error & B.Budget, B.Six>) -> IO(Unit):
  match result:
    case Done{B.Six{0,0,0,0,0,actual}}: assert_work(expected,actual)
    case _: IO.die(Unit,70,"cursor budget imbalance")

def source_dropped(work: U32, p: B.Budget & Result<&1, &2, E.Error & B.Allocation, Unit>) -> IO(Unit):
  (budget,result) = p
  match result:
    case Done{u}: finished(work,B.finish(budget))
    case _: IO.die(Unit,70,"source drop failed")

def bytes_dropped(source: C.SourceOwner, work: U32, p: B.Budget & Result<&1, &2, E.Error & B.Allocation, Unit>) -> IO(Unit):
  (budget,result) = p
  match result:
    case Done{u}: source_dropped(work,C.drop_source(budget,source))
    case _: IO.die(Unit,70,"bytes drop failed")

def cleanup(budget: B.Budget, work: U32, pair: C.SourceOwner & Bytes.OwnedBytes) -> IO(Unit):
  (source,bytes) = pair
  bytes_dropped(source,work,Bytes.drop(budget,bytes))

def verified(budget: B.Budget, window: C.ByteWindow, work: U32, valid: Bool) -> IO(Unit):
  match valid:
    case True{}: cleanup(budget,work,C.unbind(window))
    case False{}: IO.die(Unit,70,"cursor result mismatch")

def completed(scenario: Case, p: B.Budget & C.ByteWindow & C.ReadResult) -> IO(Unit):
  match scenario:
    case Case{width,little,expected,foreign,work,+base}:
      (budget,window,result) = p
      match result:
        case C.ReadDone{C.Cursor{range,position},value}: verified(budget,window,work,Bool.and(U32.is_eq(U32.add(base,width),position),Bool.and(U32.is_eq(value,expected),Bool.not(foreign))))
        case C.ReadFail{E.InternalInvariant{20},state}: verified(budget,window,work,foreign)
        case _: IO.die(Unit,70,"cursor did not complete")

def rebound(scenario: Case, budget: B.Budget, state: C.ReadState, r: Result<&1, &1, E.Error & C.SourceOwner & Bytes.OwnedBytes, C.ByteWindow>) -> IO(Unit):
  match r:
    case Fail{error}: IO.die(Unit,70,"refill bind failed")
    case Done{window}: completed(scenario,C.continued(budget,window,state))

def case_base(scenario: Case) -> U32:
  match scenario:
    case Case{width,little,value,foreign,work,base}: base
def replacement_created(+scenario: Case, bytes: Bytes.OwnedBytes, state: C.ReadState, p: B.Budget & Result<&2, &1, E.Error, C.SourceOwner>) -> IO(Unit):
  (budget,result) = p
  match result:
    case Fail{error}: IO.die(Unit,70,"replacement source failed")
    case Done{source}: rebound(scenario,budget,state,C.bind(source,bytes,U32.add(case_base(scenario),2)))

def original_dropped(+scenario: Case, bytes: Bytes.OwnedBytes, state: C.ReadState, p: B.Budget & Result<&1, &2, E.Error & B.Allocation, Unit>) -> IO(Unit):
  (budget,result) = p
  match result:
    case Done{u}: replacement_created(scenario,bytes,state,C.source(budget,U32.add(case_base(scenario),4)))
    case _: IO.die(Unit,70,"original source drop failed")

def select_source(scenario: Case, budget: B.Budget, source: C.SourceOwner, bytes: Bytes.OwnedBytes, state: C.ReadState) -> IO(Unit):
  match scenario:
    case Case{width,little,value,True{},work,+base}: original_dropped(Case{width,little,value,True{},work,base},bytes,state,C.drop_source(budget,source))
    case Case{width,little,value,False{},work,+base}: rebound(Case{width,little,value,False{},work,base},budget,state,C.bind(source,bytes,U32.add(base,2)))

def refilled_two(scenario: Case, source: C.SourceOwner, state: C.ReadState, p: B.Budget & Bytes.OwnedBytes & Result<&2, &2, E.Error, Unit>) -> IO(Unit):
  (budget,bytes,result) = p
  match result:
    case Done{u}: select_source(scenario,budget,source,bytes,state)
    case _: IO.die(Unit,70,"refill append2 failed")

def refilled_one(scenario: Case, source: C.SourceOwner, state: C.ReadState, p: B.Budget & Bytes.OwnedBytes & Result<&2, &2, E.Error, Unit>) -> IO(Unit):
  (budget,bytes,result) = p
  match result:
    case Done{u}: refilled_two(scenario,source,state,Bytes.append(budget,bytes,4))
    case _: IO.die(Unit,70,"refill append1 failed")

def refill(scenario: Case, budget: B.Budget, state: C.ReadState, p: C.SourceOwner & Bytes.OwnedBytes) -> IO(Unit):
  (source,bytes) = p
  refilled_one(scenario,source,state,Bytes.append(budget,Bytes.clear(bytes),3))

def first_read(+scenario: Case, p: B.Budget & C.ByteWindow & C.ReadResult) -> IO(Unit):
  (budget,window,result) = p
  match result:
    case C.NeedMore{state}: refill(scenario,budget,state,C.unbind(window))
    case C.ReadDone{cursor,value}: completed(scenario,(budget,window,C.ReadDone{cursor,value}))
    case _: IO.die(Unit,70,"first read failed")

def bound(+scenario: Case, budget: B.Budget, state: C.ReadState, r: Result<&1, &1, E.Error & C.SourceOwner & Bytes.OwnedBytes, C.ByteWindow>) -> IO(Unit):
  match r:
    case Fail{error}: IO.die(Unit,70,"bind failed")
    case Done{window}: first_read(scenario,C.continued(budget,window,state))

def begun(+scenario: Case, budget: B.Budget, source: C.SourceOwner, bytes: Bytes.OwnedBytes, r: Result<&2, &2, E.Error, C.ReadState>) -> IO(Unit):
  match r:
    case Fail{error}: IO.die(Unit,70,"begin failed")
    case Done{state}: bound(scenario,budget,state,C.bind(source,bytes,case_base(scenario)))

def cursor_made(scenario: Case, budget: B.Budget, source: C.SourceOwner, bytes: Bytes.OwnedBytes, r: Result<&2, &2, E.Error, C.Cursor>) -> IO(Unit):
  match scenario:
    case Case{+width,+little,value,foreign,work,base}:
      match r:
        case Fail{error}: IO.die(Unit,70,"cursor failed")
        case Done{cursor}: begun(Case{width,little,value,foreign,work,base},budget,source,bytes,C.begin(cursor,width,little))

def ranged(+scenario: Case, budget: B.Budget, bytes: Bytes.OwnedBytes, p: C.SourceOwner & Result<&2, &2, E.Error, C.Range>) -> IO(Unit):
  (source,result) = p
  match result:
    case Fail{error}: IO.die(Unit,70,"range failed")
    case Done{range}: cursor_made(scenario,budget,source,bytes,C.cursor(range,case_base(scenario)))

def source_created(+scenario: Case, bytes: Bytes.OwnedBytes, p: B.Budget & Result<&2, &1, E.Error, C.SourceOwner>) -> IO(Unit):
  (budget,result) = p
  match result:
    case Fail{error}: IO.die(Unit,70,"source failed")
    case Done{source}: ranged(scenario,budget,bytes,C.source_range(source,case_base(scenario),U32.add(case_base(scenario),4)))

def filled_two(+scenario: Case, p: B.Budget & Bytes.OwnedBytes & Result<&2, &2, E.Error, Unit>) -> IO(Unit):
  (budget,bytes,result) = p
  match result:
    case Done{u}: source_created(scenario,bytes,C.source(budget,U32.add(case_base(scenario),4)))
    case _: IO.die(Unit,70,"fill2 failed")

def filled_one(scenario: Case, p: B.Budget & Bytes.OwnedBytes & Result<&2, &2, E.Error, Unit>) -> IO(Unit):
  (budget,bytes,result) = p
  match result:
    case Done{u}: filled_two(scenario,Bytes.put(budget,bytes,1,2))
    case _: IO.die(Unit,70,"fill1 failed")

def created(scenario: Case, p: B.Budget & Result<&2, &1, E.Error, Bytes.OwnedBytes>) -> IO(Unit):
  (budget,result) = p
  match result:
    case Done{bytes}: filled_one(scenario,Bytes.put(budget,bytes,0,1))
    case _: IO.die(Unit,70,"create failed")

def started(scenario: Case, r: Result<&2, &1, E.Error, B.Budget>) -> IO(Unit):
  match r:
    case Done{budget}: created(scenario,Bytes.new(budget,2))
    case _: IO.die(Unit,70,"start failed")

def run(scenario: Case) -> IO(Unit):
  started(scenario,B.start(1,B.Six{0,0,0,0,1048576,100}))

def main() -> IO(Unit):
  do IO<Unit>:
    run(Case{1,False{},1,False{},5,0})
    run(Case{2,False{},258,False{},6,0})
    run(Case{2,True{},513,False{},6,0})
    run(Case{4,False{},16909060,False{},10,0})
    run(Case{4,True{},67305985,False{},10,0})
    run(Case{4,False{},0,True{},8,0})
    run(Case{4,False{},16909060,False{},10,65534})
    run(Case{4,True{},67305985,False{},10,4294967291})
