import Base
import ./error.bend as E
import ./checked.bend as C
import ./charges.bend as Charges

# Fixed-shape metadata. Profile costs are provisional until measured.
type Six is Data:
  Six{input: U32, expanded: U32, output: U32, logical: U32, live: U32, work: U32}

type Budget is Type:
  Book{run: U32, next: U32, limits: Six, used: Six, held: Six}

type Reservation is Type:
  Ticket{run: U32, serial: U32, amounts: Six}

type Allocation is Type:
  Live{run: U32, serial: U32, amount: U32}

# Only the invocation entry point creates a budget; all phases thread it.
# run identifies that invocation. Raw constructors are implementation-only.
def zero() -> Six:
  Six{0, 0, 0, 0, 0, 0}

def live(n: U32) -> Six:
  Six{0, 0, 0, 0, n, 0}

def start_checked(run: U32, limits: Six, check: Maybe<&2, E.Error>) -> Result<&2, &1, E.Error, Budget>:
  match check:
    case None{}: Done{Book{run, 1, limits, live(Charges.budget_state()), zero()}}
    case Some{error}: Fail{error}

def first(a: Maybe<&2, E.Error>, b: Maybe<&2, E.Error>) -> Maybe<&2, E.Error>:
  match a:
    case None{}: b
    case Some{error}: Some{error}

def dimension_fit(d: U32, limit: U32, used: U32, request: U32, fits: Bool) -> Maybe<&2, E.Error>:
  match fits:
    case True{}: None{}
    case False{}: Some{E.ResourceLimit{d, limit, used, request}}

def dimension_held(d: U32, +limit: U32, +used: U32, +held: U32, +request: U32, fits: Bool) -> Maybe<&2, E.Error>:
  match fits:
    case False{}: Some{E.InternalInvariant{1}}
    case True{}: dimension_fit(d, limit, U32.add(used, held), request, U32.is_le(request, U32.sub(U32.sub(limit, used), held)))

def dimension_used(d: U32, +limit: U32, +used: U32, +held: U32, request: U32, fits: Bool) -> Maybe<&2, E.Error>:
  match fits:
    case False{}: Some{E.InternalInvariant{2}}
    case True{}: dimension_held(d, limit, used, held, request, U32.is_le(held, U32.sub(limit, used)))

def dimension(d: U32, +limit: U32, +used: U32, held: U32, request: U32) -> Maybe<&2, E.Error>:
  dimension_used(d, limit, used, held, request, U32.is_le(used, limit))

def check_all(limits: Six, used: Six, held: Six, request: Six) -> Maybe<&2, E.Error>:
  match limits used held request:
    case Six{a,b,c,d,e,f} Six{g,h,i,j,k,l} Six{m,n,o,p,q,r} Six{s,t,u,v,w,x}:
      first(dimension(0,a,g,m,s), first(dimension(1,b,h,n,t), first(dimension(2,c,i,o,u), first(dimension(3,d,j,p,v), first(dimension(4,e,k,q,w), dimension(5,f,l,r,x))))))

# Unchecked component arithmetic is only used after full preflight.
def profile_limits() -> Six:
  Six{1073741824,1073741824,1073741824,536870912,268435456,1073741824}
def start(+run: U32, +limits: Six) -> Result<&2, &1, E.Error, Budget>:
  start_checked(run, limits, first(check_all(profile_limits(),zero(),zero(),limits),check_all(limits, zero(), zero(), live(Charges.budget_state()))))

def work(n: U32) -> Six:
  Six{0, 0, 0, 0, 0, n}

def plus(a: Six, b: Six) -> Six:
  match a b:
    case Six{a,b,c,d,e,f} Six{g,h,i,j,k,l}:
      Six{U32.add(a,g), U32.add(b,h), U32.add(c,i), U32.add(d,j), U32.add(e,k), U32.add(f,l)}

def minus(a: Six, b: Six) -> Six:
  match a b:
    case Six{a,b,c,d,e,f} Six{g,h,i,j,k,l}:
      Six{U32.sub(a,g), U32.sub(b,h), U32.sub(c,i), U32.sub(d,j), U32.sub(e,k), U32.sub(f,l)}

def fits(a: Six, b: Six) -> Bool:
  match a b:
    case Six{a,b,c,d,e,f} Six{g,h,i,j,k,l}:
      Bool.and(U32.is_le(a,g), Bool.and(U32.is_le(b,h), Bool.and(U32.is_le(c,i), Bool.and(U32.is_le(d,j), Bool.and(U32.is_le(e,k), U32.is_le(f,l))))))

def get_live(s: Six) -> U32:
  match s:
    case Six{a,b,c,d,e,f}: e

def replace_live(s: Six, n: U32) -> Six:
  match s:
    case Six{a,b,c,d,e,f}: Six{a,b,c,d,n,f}

# A ticket's bounded metadata is itself reserved before constructing it.
def reserve_commit(+run: U32, +next: U32, limits: Six, used: Six, +held: Six, +request: Six, check: Maybe<&2, E.Error>) -> Budget & Result<&2, &1, E.Error, Reservation>:
  match check:
    case Some{error}: (Book{run,next,limits,used,held}, Fail{error})
    case None{}: (Book{run,U32.inc(next),limits,used,plus(held,request)}, Done{Ticket{run,next,request}})

# Settle all actual consumption at once. On failure the ticket is returned.
def reserve_checked(budget: Budget, +request: Six) -> Budget & Result<&2, &1, E.Error, Reservation>:
  match budget:
    case Book{run,+next,+limits,+used,+held}:
      reserve_commit(run, next, limits, used, held, request, first(dimension(6, 4294967294, next, 0, 0), check_all(limits, used, held, request)))

def reserve_metadata(budget: Budget, request: Six, amount: Result<&2, &2, E.Error, U32>) -> Budget & Result<&2, &1, E.Error, Reservation>:
  match amount:
    case Fail{error}: (budget, Fail{error})
    case Done{n}: reserve_checked(budget, replace_live(request, n))

def reserve_many(budget: Budget, +request: Six) -> Budget & Result<&2, &1, E.Error, Reservation>:
  reserve_metadata(budget, request, C.add(get_live(request), Charges.owner_metadata()))

def retained(actual: Six, n: U32, empty: Bool) -> Six:
  match empty:
    case True{}: replace_live(actual, 0)
    case False{}: replace_live(actual, U32.add(n,Charges.owner_metadata()))

def live_token(run: U32, serial: U32, amount: U32, empty: Bool) -> Maybe<&1, Allocation>:
  match empty:
    case True{}: None{}
    case False{}: Some{Live{run,serial,amount}}
def settle_commit(+run: U32, next: U32, limits: Six, used: Six, held: Six, serial: U32, request: Six, +actual: Six) -> Budget & Result<&1, &1, E.Error & Reservation, Maybe<&1, Allocation>>:
  (Book{run,next,limits,plus(used,actual),minus(held,request)}, Done{live_token(run,serial,get_live(actual),U32.is_zero(get_live(actual)))})

def settle_valid(run: U32, next: U32, limits: Six, used: Six, held: Six, owner: U32, serial: U32, request: Six, +actual: Six, valid: Bool) -> Budget & Result<&1, &1, E.Error & Reservation, Maybe<&1, Allocation>>:
  match valid:
    case False{}: (Book{run,next,limits,used,held}, Fail{(E.InternalInvariant{3},Ticket{owner,serial,request})})
    case True{}: settle_commit(run,next,limits,used,held,serial,request,retained(actual,get_live(actual),U32.is_zero(get_live(actual))))

def settle(budget: Budget, ticket: Reservation, +actual: Six) -> Budget & Result<&1, &1, E.Error & Reservation, Maybe<&1, Allocation>>:
  match budget ticket:
    case Book{+run,next,limits,used,+held} Ticket{+owner,serial,+request}:
      settle_valid(run,next,limits,used,held,owner,serial,request,actual,Bool.and(U32.is_eq(run,owner), Bool.and(fits(request,held), fits(actual,minus(request,live(Charges.owner_metadata()))))))

def cancel(budget: Budget, ticket: Reservation) -> Budget & Result<&1, &1, E.Error & Reservation, Maybe<&1, Allocation>>:
  settle(budget,ticket,zero())

def release_valid(run: U32, next: U32, limits: Six, used: Six, held: Six, owner: U32, serial: U32, amount: U32, valid: Bool) -> Budget & Result<&1, &2, E.Error & Allocation, Unit>:
  match valid:
    case False{}: (Book{run,next,limits,used,held}, Fail{(E.InternalInvariant{4},Live{owner,serial,amount})})
    case True{}: (Book{run,next,limits,minus(used,live(amount)),held}, Done{Unit{}})

# No object/ticket is created for immediate byte visits. Checks precede work.
def release(budget: Budget, allocation: Allocation) -> Budget & Result<&1, &2, E.Error & Allocation, Unit>:
  match budget allocation:
    case Book{+run,next,limits,+used,held} Live{+owner,serial,+amount}:
      release_valid(run,next,limits,used,held,owner,serial,amount,Bool.and(U32.is_eq(run,owner),U32.is_le(amount,get_live(used))))

def consume_commit(run: U32, next: U32, limits: Six, used: Six, held: Six, cost: Six, check: Maybe<&2, E.Error>) -> Budget & Result<&2, &2, E.Error, Unit>:
  match check:
    case Some{error}: (Book{run,next,limits,used,held},Fail{error})
    case None{}: (Book{run,next,limits,plus(used,cost),held},Done{Unit{}})

def consume(budget: Budget, +cost: Six) -> Budget & Result<&2, &2, E.Error, Unit>:
  match budget:
    case Book{run,next,+limits,+used,+held}:
      consume_commit(run,next,limits,used,held,cost,first(dimension(4,0,0,0,get_live(cost)),check_all(limits,used,held,cost)))

def inspect(budget: Budget) -> Budget & Six & Six:
  match budget:
    case Book{run,next,limits,+used,+held}: (Book{run,next,limits,used,held},used,held)

def finish_checked(run: U32, next: U32, limits: Six, +used: Six, held: Six, ok: Bool) -> Result<&1, &2, E.Error & Budget, Six>:
  match ok:
    case True{}: Done{replace_live(used,0)}
    case False{}: Fail{(E.InternalInvariant{5},Book{run,next,limits,used,held})}

def finish(budget: Budget) -> Result<&1, &2, E.Error & Budget, Six>:
  match budget:
    case Book{run,next,limits,+used,+held}:
      finish_checked(run,next,limits,used,held,Bool.and(fits(held,zero()),U32.is_eq(get_live(used),Charges.budget_state())))

def allocate_commit(+run: U32, +next: U32, limits: Six, used: Six, held: Six, +amount: U32, visits: U32, check: Maybe<&2, E.Error>) -> Budget & Result<&2, &1, E.Error, Allocation>:
  match check:
    case Some{error}: (Book{run,next,limits,used,held},Fail{error})
    case None{}: (Book{run,U32.inc(next),limits,plus(used,Six{0,0,0,0,amount,visits}),held},Done{Live{run,next,amount}})

def allocate_checked(budget: Budget, +visits: U32, amount: Result<&2, &2, E.Error, U32>) -> Budget & Result<&2, &1, E.Error, Allocation>:
  match budget amount:
    case Book{run,+next,+limits,+used,+held} Fail{error}: (Book{run,next,limits,used,held},Fail{error})
    case Book{run,+next,+limits,+used,+held} Done{+n}:
      allocate_commit(run,next,limits,used,held,n,visits,first(dimension(6,4294967294,next,0,0),check_all(limits,used,held,Six{0,0,0,0,n,visits})))

# Pure allocations have known actual costs, so no partial-IO ticket is needed.
def allocate(budget: Budget, amount: U32, visits: U32) -> Budget & Result<&2, &1, E.Error, Allocation>:
  allocate_checked(budget,visits,C.add(amount,Charges.owner_metadata()))

def identity(allocation: Allocation) -> Allocation & U32 & U32:
  match allocation:
    case Live{+run,+serial,amount}: (Live{run,serial,amount},run,serial)
