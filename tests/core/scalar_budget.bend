import Base
import ../../core/error.bend as E
import ../../core/budget.bend as B
import ../../core/scalars.bend as S

def assert_work(ok: Bool) -> IO(Unit):
  match ok:
    case True{}: IO.print("scalar-budget-balanced")
    case False{}: IO.die(Unit,70,"scalar work mismatch")

def finished(expected: U32, result: Result<&1, &2, E.Error & B.Budget, B.Six>) -> IO(Unit):
  match result:
    case Done{B.Six{0,0,0,0,0,actual}}: assert_work(U32.is_eq(expected,actual))
    case _: IO.die(Unit,70,"scalar owner imbalance")

def dropped(work: U32, p: B.Budget & Result<&1, &2, E.Error & B.Allocation, Unit>) -> IO(Unit):
  (budget,result) = p
  match result:
    case Done{u}: finished(work,B.finish(budget))
    case _: IO.die(Unit,70,"scalar drop failed")

def checked_read(budget: B.Budget, scalars: S.ScalarChunk, work: U32, okay: Bool) -> IO(Unit):
  match okay:
    case True{}: dropped(work,S.drop(budget,scalars))
    case False{}: IO.die(Unit,70,"scalar value mismatch")

def read_success(value: U32, work: U32, p: B.Budget & S.ScalarChunk & Result<&2, &2, E.Error, U32>) -> IO(Unit):
  (budget,scalars,result) = p
  match result:
    case Done{actual}: checked_read(budget,scalars,work,U32.is_eq(value,actual))
    case _: IO.die(Unit,70,"scalar exact limit read failed")

def read_failure(+width: U32, p: B.Budget & S.ScalarChunk & Result<&2, &2, E.Error, U32>) -> IO(Unit):
  (budget,scalars,result) = p
  match result:
    case Fail{E.ResourceLimit{5,limit,used,requested}}: checked_read(budget,scalars,U32.inc(width),Bool.and(U32.is_eq(limit,U32.mul(width,2)),Bool.and(U32.is_eq(used,U32.inc(width)),U32.is_eq(requested,width))))
    case _: IO.die(Unit,70,"scalar failed to reject before inspection")

def written(value: U32, +width: U32, success: Bool, p: B.Budget & S.ScalarChunk & Result<&2, &2, E.Error, Unit>) -> IO(Unit):
  match success:
    case True{}:
      (budget,scalars,result) = p
      match result:
        case Done{u}: read_success(value,U32.inc(U32.mul(width,2)),S.get(budget,scalars,0))
        case _: IO.die(Unit,70,"scalar put failed")
    case False{}:
      (budget,scalars,result) = p
      match result:
        case Done{u}: read_failure(width,S.get(budget,scalars,0))
        case _: IO.die(Unit,70,"scalar put failed")

def created(+value: U32, width: U32, success: Bool, p: B.Budget & Result<&2, &1, E.Error, S.ScalarChunk>) -> IO(Unit):
  (budget,result) = p
  match result:
    case Done{scalars}: written(value,width,success,S.put(budget,scalars,0,value))
    case _: IO.die(Unit,70,"scalar new failed")

def started(value: U32, width: U32, success: Bool, r: Result<&2, &1, E.Error, B.Budget>) -> IO(Unit):
  match r:
    case Done{budget}: created(value,width,success,S.new(budget,1))
    case _: IO.die(Unit,70,"start failed")

def run(value: U32, +width: U32, success: Bool) -> IO(Unit):
  match success:
    case True{}: started(value,width,True{},B.start(1,B.Six{0,0,0,0,1048576,U32.inc(U32.mul(width,2))}))
    case False{}: started(value,width,False{},B.start(1,B.Six{0,0,0,0,1048576,U32.mul(width,2)}))

def main() -> IO(Unit):
  do IO<Unit>:
    run(97,1,True{})
    run(97,1,False{})
    run(233,2,True{})
    run(233,2,False{})
    run(26085,3,True{})
    run(26085,3,False{})
    run(128512,4,True{})
    run(128512,4,False{})
