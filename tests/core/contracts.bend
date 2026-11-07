import Base
import ../../core/error.bend as E
import ../../core/checked.bend as C
import ../../core/budget.bend as B

def check(name: String, yes: Bool) -> IO(Unit):
  match yes:
    case True{}: IO.print(name)
    case False{}: IO.die(Unit,70,name)

def number(name: String, expected: U32, actual: Result<&2, &2, E.Error, U32>) -> IO(Unit):
  match actual:
    case Fail{error}: IO.die(Unit,70,name)
    case Done{value}: check(name,U32.is_eq(expected,value))

def overflow(name: String, expected: U32, actual: Result<&2, &2, E.Error, U32>) -> IO(Unit):
  match actual:
    case Fail{E.Overflow{op,left,right}}: check(name,U32.is_eq(expected,op))
    case _: IO.die(Unit,70,name)

def cap(name: String, size: U32, depth: U32, actual: Result<&2, &1, E.Error, U32 & U32>) -> IO(Unit):
  match actual:
    case Fail{error}: IO.die(Unit,70,name)
    case Done{pair}:
      (s,d) = pair
      check(name,Bool.and(U32.is_eq(s,size),U32.is_eq(d,depth)))

def cap_fail(actual: Result<&2, &1, E.Error, U32 & U32>) -> IO(Unit):
  match actual:
    case Fail{E.Bounds{0,65537,65536}}: IO.print("capacity-over")
    case _: IO.die(Unit,70,"capacity-over")

def byte_fail(actual: Result<&2, &2, E.Error, U32>) -> IO(Unit):
  match actual:
    case Fail{E.InvalidByte{value}}: IO.print("invalid-byte")
    case _: IO.die(Unit,70,"invalid-byte")

def arithmetic() -> IO(Unit):
  do IO<Unit>:
    number("add-zero",0,C.add(0,0))
    number("add-max",4294967295,C.add(4294967294,1))
    overflow("add-overflow",0,C.add(4294967295,1))
    number("sub-zero",0,C.sub(4294967295,4294967295))
    overflow("sub-underflow",1,C.sub(0,1))
    number("mul-zero",0,C.mul(4294967295,0))
    number("mul-max",4294967295,C.mul(4294967295,1))
    number("mul-edge",4294901760,C.mul(65535,65536))
    overflow("mul-overflow",2,C.mul(65536,65536))
    number("byte-255",255,C.byte(255))
    byte_fail(C.byte(256))
    byte_fail(C.byte(4294967295))
    cap("empty-capacity",1,0,C.ceil_capacity(0))
    cap("one-capacity",1,0,C.ceil_capacity(1))
    cap("round-capacity",65536,16,C.ceil_capacity(65535))
    cap("max-capacity",65536,16,C.ceil_capacity(65536))
    cap_fail(C.ceil_capacity(65537))

def final_usage(name: String, +expected: B.Six, r: Result<&1, &2, E.Error & B.Budget, B.Six>) -> IO(Unit):
  match r:
    case Fail{error}: IO.die(Unit,70,name)
    case Done{+used}: check(name,Bool.and(B.fits(used,expected),B.fits(expected,used)))

def cumulative_rejected(p: B.Budget & Result<&2, &2, E.Error, Unit>) -> IO(Unit):
  (budget,result) = p
  match result:
    case Fail{E.ResourceLimit{5,10,10,1}}: final_usage("cumulative-not-reset",B.Six{2,4,6,8,0,10},B.finish(budget))
    case _: IO.die(Unit,70,"cumulative-rejection")

def cumulative_second(p: B.Budget & Result<&2, &2, E.Error, Unit>) -> IO(Unit):
  (budget,result) = p
  match result:
    case Fail{error}: IO.die(Unit,70,"second-consumption")
    case Done{u}: cumulative_rejected(B.consume(budget,B.work(1)))

def cumulative_first(p: B.Budget & Result<&2, &2, E.Error, Unit>) -> IO(Unit):
  (budget,result) = p
  match result:
    case Fail{error}: IO.die(Unit,70,"first-consumption")
    case Done{u}: cumulative_second(B.consume(budget,B.Six{1,2,3,4,0,5}))

def cumulative_start(r: Result<&2, &1, E.Error, B.Budget>) -> IO(Unit):
  match r:
    case Fail{error}: IO.die(Unit,70,"start")
    case Done{budget}: cumulative_first(B.consume(budget,B.Six{1,2,3,4,0,5}))

def no_live(expected: B.Six, p: B.Budget & Result<&1, &1, E.Error & B.Reservation, Maybe<&1, B.Allocation>>) -> IO(Unit):
  (budget,result) = p
  match result:
    case Done{None{}}: final_usage("zero-live-none",expected,B.finish(budget))
    case _: IO.die(Unit,70,"unexpected allocation or settlement failure")

def compete_rejected(ticket: B.Reservation, p: B.Budget & Result<&2, &1, E.Error, B.Reservation>) -> IO(Unit):
  (budget,result) = p
  match result:
    case Fail{E.ResourceLimit{4,69632,69632,4096}}: no_live(B.Six{7,0,0,0,0,0},B.settle(budget,ticket,B.Six{7,0,0,0,0,0}))
    case _: IO.die(Unit,70,"reservation competition failed")

def competed(p: B.Budget & Result<&2, &1, E.Error, B.Reservation>) -> IO(Unit):
  (budget,result) = p
  match result:
    case Fail{error}: IO.die(Unit,70,"reserve failed")
    case Done{ticket}: compete_rejected(ticket,B.reserve_many(budget,B.zero()))

def compete_start(r: Result<&2, &1, E.Error, B.Budget>) -> IO(Unit):
  match r:
    case Fail{error}: IO.die(Unit,70,"start")
    case Done{budget}: competed(B.reserve_many(budget,B.Six{10,0,0,0,0,0}))

def zero_reserved(p: B.Budget & Result<&2, &1, E.Error, B.Reservation>) -> IO(Unit):
  (budget,result) = p
  match result:
    case Fail{error}: IO.die(Unit,70,"reserve failed")
    case Done{ticket}: no_live(B.zero(),B.cancel(budget,ticket))

def zero_start(r: Result<&2, &1, E.Error, B.Budget>) -> IO(Unit):
  match r:
    case Fail{error}: IO.die(Unit,70,"start")
    case Done{budget}: zero_reserved(B.reserve_many(budget,B.zero()))

def invalid_actual(p: B.Budget & Result<&1, &1, E.Error & B.Reservation, Maybe<&1, B.Allocation>>) -> IO(Unit):
  (budget,result) = p
  match result:
    case Fail{pair}:
      (error,ticket) = pair
      match error:
        case E.InternalInvariant{3}: no_live(B.zero(),B.cancel(budget,ticket))
        case _: IO.die(Unit,70,"wrong settlement error")
    case _: IO.die(Unit,70,"invalid settlement succeeded")

def invalid_reserved(p: B.Budget & Result<&2, &1, E.Error, B.Reservation>) -> IO(Unit):
  (budget,result) = p
  match result:
    case Fail{error}: IO.die(Unit,70,"reserve failed")
    case Done{ticket}: invalid_actual(B.settle(budget,ticket,B.Six{11,0,0,0,0,0}))

def invalid_start(r: Result<&2, &1, E.Error, B.Budget>) -> IO(Unit):
  match r:
    case Fail{error}: IO.die(Unit,70,"start")
    case Done{budget}: invalid_reserved(B.reserve_many(budget,B.Six{10,0,0,0,0,0}))

def main() -> IO(Unit):
  do IO<Unit>:
    arithmetic()
    cumulative_start(B.start(1,B.Six{2,4,6,8,65536,10}))
    compete_start(B.start(2,B.Six{10,0,0,0,69632,0}))
    zero_start(B.start(3,B.Six{0,0,0,0,69632,0}))
    invalid_start(B.start(4,B.Six{10,0,0,0,69632,0}))
