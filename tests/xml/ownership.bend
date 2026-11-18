import Base
import ../../core/budget.bend as B
import ../../core/error.bend as E
import ../../xml/ownership.bend as O

# Only the final report prints success. Each path must recover/drop all expected
# owners and finish every budget with zero cumulative consumption and no holds.
def finished(okay: Bool, result: Result<&1,&2,E.Error & B.Budget,B.Six>) -> Bool:
  match result:
    case Done{B.Six{0,0,0,0,0,0}}: okay
    case _: False{}

def released(okay: Bool, p: B.Budget & Result<&1,&2,E.Error & O.Claim,Unit>) -> Bool:
  (budget,result) = p
  match result:
    case Done{u}: finished(okay,B.finish(budget))
    case _: False{}

def unexpected(budget: B.Budget, residual: Maybe<&1,O.Claim>) -> Bool:
  match residual:
    case None{}: finished(False{},B.finish(budget))
    case Some{claim}: released(False{},O.release(budget,claim))

def defaults() -> B.Six:
  B.Six{100,100,100,100,1048576,100}

# An Active claim must survive failed release against run 2. Check the retained
# identity before releasing through its original run-1 budget.
def active_identity(original: B.Budget, okay: Bool, p: B.Allocation & U32 & U32) -> Bool:
  (allocation,run,serial) = p
  released(Bool.and(okay,Bool.and(U32.is_eq(run,1),U32.is_eq(serial,1))),O.release(original,O.Active{allocation}))

def active_residual(original: B.Budget, wrong: B.Budget, error: E.Error, claim: O.Claim) -> Bool:
  match error claim:
    case E.InternalInvariant{4} O.Active{allocation}: active_identity(original,finished(True{},B.finish(wrong)),B.identity(allocation))
    case _ other: released(False{},O.release(original,other))

def active_rejected(original: B.Budget, p: B.Budget & Result<&1,&2,E.Error & O.Claim,Unit>) -> Bool:
  (wrong,result) = p
  match result:
    case Fail{pair}:
      (error,claim) = pair
      active_residual(original,wrong,error,claim)
    case Done{u}: finished(False{},B.finish(wrong))

def active_wrong_started(original: B.Budget, claim: O.Claim, result: Result<&2,&1,E.Error,B.Budget>) -> Bool:
  match result:
    case Done{wrong}: active_rejected(original,O.release(wrong,claim))
    case _: released(False{},O.release(original,claim))

def active_ready(budget: B.Budget, claim: O.Claim, wrong: Bool) -> Bool:
  match wrong:
    case False{}: released(True{},O.release(budget,claim))
    case True{}: active_wrong_started(budget,claim,B.start(2,defaults()))

def active_acquired(wrong: Bool, p: B.Budget & O.Outcome) -> Bool:
  (budget,result) = p
  match result:
    case O.ClaimReady{claim}: active_ready(budget,claim,wrong)
    case O.ClaimFailed{error,residual}: unexpected(budget,residual)

# Wrong-run settlement must become ClaimFailed with Reserved residual. A second
# wrong-run cancel must retain that same reservation; only the original budget
# can cancel it and clear the held amount.
def reserved_cancel_residual(original: B.Budget, wrong: B.Budget, error: E.Error, claim: O.Claim) -> Bool:
  match error claim:
    case E.InternalInvariant{3} O.Reserved{ticket}: released(finished(True{},B.finish(wrong)),O.release(original,O.Reserved{ticket}))
    case _ other: released(False{},O.release(original,other))

def reserved_cancelled(original: B.Budget, p: B.Budget & Result<&1,&2,E.Error & O.Claim,Unit>) -> Bool:
  (wrong,result) = p
  match result:
    case Fail{pair}:
      (error,claim) = pair
      reserved_cancel_residual(original,wrong,error,claim)
    case Done{u}: finished(False{},B.finish(wrong))

def reserved_failed(original: B.Budget, wrong: B.Budget, error: E.Error, claim: O.Claim) -> Bool:
  match error claim:
    case E.InternalInvariant{3} O.Reserved{ticket}: reserved_cancelled(original,O.release(wrong,O.Reserved{ticket}))
    case _ other: released(False{},O.release(original,other))

def reserved_settled(original: B.Budget, p: B.Budget & O.Outcome) -> Bool:
  (wrong,result) = p
  match result:
    case O.ClaimFailed{error,Some{claim}}: reserved_failed(original,wrong,error,claim)
    case O.ClaimFailed{error,None{}}: finished(False{},B.finish(wrong))
    case O.ClaimReady{claim}: released(False{},O.release(wrong,claim))

def reserved_wrong_started(original: B.Budget, ticket: B.Reservation, result: Result<&2,&1,E.Error,B.Budget>) -> Bool:
  match result:
    case Done{wrong}: reserved_settled(original,O.settled(B.settle(wrong,ticket,B.live(4096))))
    case _: released(False{},O.release(original,O.Reserved{ticket}))

def reserved(p: B.Budget & Result<&2,&1,E.Error,B.Reservation>) -> Bool:
  (budget,result) = p
  match result:
    case Done{ticket}: reserved_wrong_started(budget,ticket,B.start(2,defaults()))
    case _: finished(False{},B.finish(budget))

def refusal_error(mode: U32, error: E.Error) -> Bool:
  match mode error:
    case 3 E.InternalInvariant{501}: True{}
    case 4 E.ResourceLimit{4,65536,65536,8192}: True{}
    case _ _: False{}

def refused(mode: U32, p: B.Budget & O.Outcome) -> Bool:
  (budget,result) = p
  match result:
    case O.ClaimFailed{error,None{}}: finished(refusal_error(mode,error),B.finish(budget))
    case O.ClaimFailed{error,Some{claim}}: released(False{},O.release(budget,claim))
    case O.ClaimReady{claim}: released(False{},O.release(budget,claim))

def started_mode(mode: U32, budget: B.Budget) -> Bool:
  match mode:
    case 0: active_acquired(False{},O.acquire(budget,4096))
    case 1: active_acquired(True{},O.acquire(budget,4096))
    case 2: reserved(B.reserve_many(budget,B.live(4096)))
    case 3: refused(3,O.acquire(budget,0))
    case 4: refused(4,O.acquire(budget,4096))
    case _: finished(False{},B.finish(budget))

def started(mode: U32, result: Result<&2,&1,E.Error,B.Budget>) -> Bool:
  match result:
    case Fail{error}: False{}
    case Done{budget}: started_mode(mode,budget)

def run(mode: U32) -> Bool:
  match mode:
    case 4: started(4,B.start(1,B.Six{100,100,100,100,65536,100}))
    case other: started(other,B.start(1,defaults()))

def cases(fuel: Nat, +mode: U32, okay: Bool) -> Bool:
  match fuel:
    case 0n: okay
    case 1n+rest: cases(rest,U32.inc(mode),Bool.and(okay,run(mode)))

def report(okay: Bool) -> IO(Unit):
  match okay:
    case True{}: IO.print("ownership-balanced")
    case False{}: IO.die(Unit,70,"ownership refusal, recovery or balance failed")

def main() -> IO(Unit):
  report(cases(5n,0,True{}))
