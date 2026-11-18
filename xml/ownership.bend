import Base
import ../core/budget.bend as B
import ../core/error.bend as E

# A failed settlement retains its reservation. The caller must dispose residual
# claims even when creation failed. This module never initializes a Budget.
type Claim is Type:
  Active{allocation: B.Allocation}
  Reserved{ticket: B.Reservation}

type Outcome is Type:
  ClaimReady{claim: Claim}
  ClaimFailed{error: E.Error, residual: Maybe<&1, Claim>}

def settled(p: B.Budget & Result<&1, &1, E.Error & B.Reservation, Maybe<&1, B.Allocation>>) -> B.Budget & Outcome:
  (budget,result) = p
  match result:
    case Fail{pair}:
      (error,ticket) = pair
      (budget,ClaimFailed{error,Some{Reserved{ticket}}})
    case Done{None{}}: (budget,ClaimFailed{E.InternalInvariant{500},None{}})
    case Done{Some{allocation}}: (budget,ClaimReady{Active{allocation}})

def reserved(amount: U32, p: B.Budget & Result<&2, &1, E.Error, B.Reservation>) -> B.Budget & Outcome:
  (budget,result) = p
  match result:
    case Fail{error}: (budget,ClaimFailed{error,None{}})
    case Done{ticket}: settled(B.settle(budget,ticket,B.live(amount)))

def acquire_checked(budget: B.Budget, +amount: U32, valid: Bool) -> B.Budget & Outcome:
  match valid:
    case False{}: (budget,ClaimFailed{E.InternalInvariant{501},None{}})
    case True{}: reserved(amount,B.reserve_many(budget,B.live(amount)))

def acquire(budget: B.Budget, +amount: U32) -> B.Budget & Outcome:
  acquire_checked(budget,amount,U32.is_gt(amount,0))

def released(p: B.Budget & Result<&1, &2, E.Error & B.Allocation, Unit>) -> B.Budget & Result<&1, &2, E.Error & Claim, Unit>:
  (budget,result) = p
  match result:
    case Fail{pair}:
      (error,allocation) = pair
      (budget,Fail{(error,Active{allocation})})
    case Done{u}: (budget,Done{u})

def cancelled(p: B.Budget & Result<&1, &1, E.Error & B.Reservation, Maybe<&1, B.Allocation>>) -> B.Budget & Result<&1, &2, E.Error & Claim, Unit>:
  (budget,result) = p
  match result:
    case Fail{pair}:
      (error,ticket) = pair
      (budget,Fail{(error,Reserved{ticket})})
    case Done{None{}}: (budget,Done{Unit{}})
    case Done{Some{allocation}}: released(B.release(budget,allocation))

def release(budget: B.Budget, claim: Claim) -> B.Budget & Result<&1, &2, E.Error & Claim, Unit>:
  match claim:
    case Active{allocation}: released(B.release(budget,allocation))
    case Reserved{ticket}: cancelled(B.cancel(budget,ticket))
