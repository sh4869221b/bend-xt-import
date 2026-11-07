import Base
import ../../core/budget.bend as B
import ../../core/error.bend as E

def finish(r: Result<&1, &2, E.Error & B.Budget, B.Six>) -> IO(Unit):
  match r:
    case Fail{error}: IO.die(Unit,70,"unbalanced budget")
    case Done{used}: IO.print("budget-balanced")

def released(p: B.Budget & Result<&1, &2, E.Error & B.Allocation, Unit>) -> IO(Unit):
  (budget,result) = p
  match result:
    case Fail{error}: IO.die(Unit,70,"release failed")
    case Done{u}: finish(B.finish(budget))

def settled(p: B.Budget & Result<&1, &1, E.Error & B.Reservation, Maybe<&1, B.Allocation>>) -> IO(Unit):
  (budget,result) = p
  match result:
    case Fail{error}: IO.die(Unit,70,"settle failed")
    case Done{Some{allocation}}: released(B.release(budget,allocation))
    case Done{None{}}: finish(B.finish(budget))

def reserved(p: B.Budget & Result<&2, &1, E.Error, B.Reservation>) -> IO(Unit):
  (budget,result) = p
  match result:
    case Fail{error}: IO.die(Unit,70,"reserve failed")
    case Done{ticket}: settled(B.settle(budget,ticket,B.Six{1,2,3,4,500,6}))

def started(r: Result<&2, &1, E.Error, B.Budget>) -> IO(Unit):
  match r:
    case Fail{error}: IO.die(Unit,70,"start failed")
    case Done{budget}: reserved(B.reserve_many(budget,B.Six{10,20,30,40,500,60}))

def main() -> IO(Unit):
  started(B.start(1,B.Six{100,100,100,100,1048576,100}))
