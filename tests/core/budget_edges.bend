# All six counters are checked independently. Failed requests and oversettlement
# preserve used/held and the original affine ticket; actual consumption is never refunded.
import Base
import ../../core/error.bend as E
import ../../core/budget.bend as B
import ../../core/bytes.bend as Bytes
import ./lib/buffer_assert.bend as A

def consume_failed(expected: E.Error, p: B.Budget & Result<&2, &2, E.Error, Unit>) -> IO(B.Budget):
  (budget,result) = p
  match result:
    case Fail{error}:
      do IO<B.Budget>:
        A.check("consume rejection context",A.error_equal(expected,error))
        IO.pure(B.Budget,budget)
    case _: IO.die(B.Budget,70,"consume should fail")

def consumed(p: B.Budget & Result<&2, &2, E.Error, Unit>) -> IO(B.Budget):
  (budget,result) = p
  match result:
    case Done{u}: IO.pure(B.Budget,budget)
    case _: IO.die(B.Budget,70,"exact consume failed")

def reserve_failed(expected: E.Error, p: B.Budget & Result<&2, &1, E.Error, B.Reservation>) -> IO(B.Budget):
  (budget,result) = p
  match result:
    case Fail{error}:
      do IO<B.Budget>:
        A.check("reserve rejection context",A.error_equal(expected,error))
        IO.pure(B.Budget,budget)
    case _: IO.die(B.Budget,70,"reserve should fail")

def settle_none(p: B.Budget & Result<&1, &1, E.Error & B.Reservation, Maybe<&1, B.Allocation>>) -> IO(B.Budget):
  (budget,result) = p
  match result:
    case Done{None{}}: IO.pure(B.Budget,budget)
    case _: IO.die(B.Budget,70,"zero live must not retain owner")

def settle_failed(p: B.Budget & Result<&1, &1, E.Error & B.Reservation, Maybe<&1, B.Allocation>>) -> IO(B.Budget & B.Reservation):
  (budget,result) = p
  match result:
    case Fail{pair}:
      (error,ticket) = pair
      do IO<B.Budget & B.Reservation>:
        A.check("oversettlement error",A.error_equal(E.InternalInvariant{3},error))
        IO.pure(B.Budget & B.Reservation,(budget,ticket))
    case _: IO.die(B.Budget & B.Reservation,70,"oversettlement must preserve ticket")

def dimension_edge_step_2(+dimension: U32, +unit: B.Six, +twice: B.Six, +used_once: B.Six, +held_once: B.Six, +used_twice: B.Six, p8: B.Budget & B.Reservation) -> IO(Unit):
  (b7,returned) = p8
  do IO<Unit>:
    b8 : B.Budget <- A.usage(used_once,held_once,B.inspect(b7))
    b9 : B.Budget <- settle_none(B.settle(b8,returned,unit))
    b10 : B.Budget <- A.usage(used_twice,B.zero(),B.inspect(b9))
    b11 : B.Budget <- consume_failed(E.ResourceLimit{dimension,2,2,1},B.consume(b10,unit))
    A.finished("budget-consumable-exact-plus-one-preserved",twice,B.finish(b11))

def dimension_edge_step_1(+dimension: U32, +unit: B.Six, +twice: B.Six, +used_once: B.Six, +held_once: B.Six, +used_twice: B.Six, p3: B.Budget & B.Reservation) -> IO(Unit):
  (b2,ticket) = p3
  do IO<Unit>:
    b3 : B.Budget <- A.usage(used_once,held_once,B.inspect(b2))
    b4 : B.Budget <- consume_failed(E.ResourceLimit{dimension,2,2,1},B.consume(b3,unit))
    b5 : B.Budget <- reserve_failed(E.ResourceLimit{dimension,2,2,1},B.reserve_many(b4,unit))
    b6 : B.Budget <- A.usage(used_once,held_once,B.inspect(b5))
    p8 : B.Budget & B.Reservation <- settle_failed(B.settle(b6,ticket,twice))
    dimension_edge_step_2(dimension,unit,twice,used_once,held_once,used_twice,p8)

def dimension_edge(+dimension: U32, +unit: B.Six, +twice: B.Six, limits: B.Six, +used_once: B.Six, +held_once: B.Six, +used_twice: B.Six) -> IO(Unit):
  do IO<Unit>:
    b0 : B.Budget <- A.start(B.start(1,limits))
    b1 : B.Budget <- consumed(B.consume(b0,unit))
    p3 : B.Budget & B.Reservation <- A.reserved(B.reserve_many(b1,unit))
    dimension_edge_step_1(dimension,unit,twice,used_once,held_once,used_twice,p3)

def live_edge_step_2(p5: B.Budget & B.Reservation) -> IO(Unit):
  (b4,returned) = p5
  do IO<Unit>:
    b5 : B.Budget <- A.usage(B.live(65536),B.live(4097),B.inspect(b4))
    b6 : B.Budget <- A.cancelled(B.cancel(b5,returned))
    b7 : B.Budget <- A.usage(B.live(65536),B.zero(),B.inspect(b6))
    A.finished("budget-live-exact-plus-one-preserved",B.zero(),B.finish(b7))

def live_edge_step_1(p2: B.Budget & B.Reservation) -> IO(Unit):
  (b1,ticket) = p2
  do IO<Unit>:
    b2 : B.Budget <- reserve_failed(E.ResourceLimit{4,69633,69633,4097},B.reserve_many(b1,B.live(1)))
    b3 : B.Budget <- A.usage(B.live(65536),B.live(4097),B.inspect(b2))
    p5 : B.Budget & B.Reservation <- settle_failed(B.settle(b3,ticket,B.live(2)))
    live_edge_step_2(p5)

def live_edge() -> IO(Unit):
  do IO<Unit>:
    b0 : B.Budget <- A.start(B.start(1,B.Six{0,0,0,0,69633,0}))
    p2 : B.Budget & B.Reservation <- A.reserved(B.reserve_many(b0,B.live(1)))
    live_edge_step_1(p2)

def reservation_overflow_step_1(p2: B.Budget & B.Reservation) -> IO(Unit):
  (b1,ticket) = p2
  do IO<Unit>:
    b2 : B.Budget <- reserve_failed(E.Overflow{0,4294967295,4096},B.reserve_many(b1,B.live(4294967295)))
    b3 : B.Budget <- A.usage(B.live(65536),B.live(4096),B.inspect(b2))
    b4 : B.Budget <- A.cancelled(B.cancel(b3,ticket))
    A.finished("budget-overflow-preserves-existing-ticket",B.zero(),B.finish(b4))

def reservation_overflow() -> IO(Unit):
  do IO<Unit>:
    b0 : B.Budget <- A.start(B.start(1,B.Six{0,0,0,0,69632,0}))
    p2 : B.Budget & B.Reservation <- A.reserved(B.reserve_many(b0,B.zero()))
    reservation_overflow_step_1(p2)

def start_rejected(expected: E.Error, r: Result<&2, &1, E.Error, B.Budget>) -> IO(Unit):
  match r:
    case Fail{error}:
      do IO<Unit>:
        A.check("profile limit rejection",A.error_equal(expected,error))
        IO.print("budget-profile-overflow-rejected")
    case _: IO.die(Unit,70,"unsupported profile should fail")

def atomic_multi_dimension_step_1(p2: B.Budget & B.Reservation) -> IO(Unit):
  (b1,ticket) = p2
  do IO<Unit>:
    b2 : B.Budget <- reserve_failed(E.ResourceLimit{5,1,1,1},B.reserve_many(b1,B.work(1)))
    b3 : B.Budget <- A.usage(B.live(65536),B.Six{1,1,1,1,4096,1},B.inspect(b2))
    b4 : B.Budget <- A.cancelled(B.cancel(b3,ticket))
    b5 : B.Budget <- consume_failed(E.ResourceLimit{5,1,0,2},B.consume(b4,B.Six{1,1,1,1,0,2}))
    b6 : B.Budget <- A.usage(B.live(65536),B.zero(),B.inspect(b5))
    b7 : B.Budget <- consumed(B.consume(b6,B.Six{1,1,1,1,0,1}))
    A.finished("budget-multidimension-atomic-no-refund",B.Six{1,1,1,1,0,1},B.finish(b7))

def atomic_multi_dimension() -> IO(Unit):
  do IO<Unit>:
    b0 : B.Budget <- A.start(B.start(1,B.Six{1,1,1,1,73728,1}))
    p2 : B.Budget & B.Reservation <- A.reserved(B.reserve_many(b0,B.Six{1,1,1,1,0,1}))
    atomic_multi_dimension_step_1(p2)

def main() -> IO(Unit):
  do IO<Unit>:
    dimension_edge(0,B.Six{1,0,0,0,0,0},B.Six{2,0,0,0,0,0},B.Six{2,0,0,0,73728,0},B.Six{1,0,0,0,65536,0},B.Six{1,0,0,0,4096,0},B.Six{2,0,0,0,65536,0})
    dimension_edge(1,B.Six{0,1,0,0,0,0},B.Six{0,2,0,0,0,0},B.Six{0,2,0,0,73728,0},B.Six{0,1,0,0,65536,0},B.Six{0,1,0,0,4096,0},B.Six{0,2,0,0,65536,0})
    dimension_edge(2,B.Six{0,0,1,0,0,0},B.Six{0,0,2,0,0,0},B.Six{0,0,2,0,73728,0},B.Six{0,0,1,0,65536,0},B.Six{0,0,1,0,4096,0},B.Six{0,0,2,0,65536,0})
    dimension_edge(3,B.Six{0,0,0,1,0,0},B.Six{0,0,0,2,0,0},B.Six{0,0,0,2,73728,0},B.Six{0,0,0,1,65536,0},B.Six{0,0,0,1,4096,0},B.Six{0,0,0,2,65536,0})
    dimension_edge(5,B.Six{0,0,0,0,0,1},B.Six{0,0,0,0,0,2},B.Six{0,0,0,0,73728,2},B.Six{0,0,0,0,65536,1},B.Six{0,0,0,0,4096,1},B.Six{0,0,0,0,65536,2})
    live_edge()
    reservation_overflow()
    atomic_multi_dimension()
    start_rejected(E.ResourceLimit{0,1073741824,0,4294967295},B.start(1,B.Six{4294967295,0,0,0,65536,0}))
    start_rejected(E.ResourceLimit{1,1073741824,0,4294967295},B.start(1,B.Six{0,4294967295,0,0,65536,0}))
    start_rejected(E.ResourceLimit{2,1073741824,0,4294967295},B.start(1,B.Six{0,0,4294967295,0,65536,0}))
    start_rejected(E.ResourceLimit{3,536870912,0,4294967295},B.start(1,B.Six{0,0,0,4294967295,65536,0}))
    start_rejected(E.ResourceLimit{4,268435456,0,4294967295},B.start(1,B.Six{0,0,0,0,4294967295,0}))
    start_rejected(E.ResourceLimit{5,1073741824,0,4294967295},B.start(1,B.Six{0,0,0,0,65536,4294967295}))
    IO.print("budget-edges-ok")
