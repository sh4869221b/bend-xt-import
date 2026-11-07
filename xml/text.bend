import Base
import ../core/budget.bend as B
import ../core/error.bend as E
import ../core/scalars.bend as S
import ./ownership.bend as O
import ./charges.bend as Charges

# The Reader or ProvisionalEntry charge covers this fixed arena wrapper.
# A link owns its own charge; every payload keeps its core allocation until drop.
type Payload is Type:
  LivePayload{data: S.ScalarChunk}
  ReleasePayload{allocation: B.Allocation}

type Pages is Type:
  NoPages{}
  Page{data: Maybe<&1, Payload>, claim: O.Claim, tail: Pages}

type Meta is Data:
  Meta{length: U32, bytes: U32, sealed: Bool, cursor: U32, error: Maybe<&2, E.Error>}

type Arena is Type:
  Arena{pages: Pages, current: Maybe<&1, Payload>, visited: Pages, residual: Maybe<&1, O.Claim>, meta: Meta}

def empty() -> Arena:
  Arena{NoPages{},None{},NoPages{},None{},Meta{0,0,False{},0,None{}}}

def width3(low: Bool) -> U32:
  match low:
    case True{}: 3
    case False{}: 4

def width2(value: U32, low: Bool) -> U32:
  match low:
    case True{}: 2
    case False{}: width3(U32.is_lt(value,65536))

def width1(+value: U32, low: Bool) -> U32:
  match low:
    case True{}: 1
    case False{}: width2(value,U32.is_lt(value,2048))

def width(+value: U32) -> U32:
  width1(value,U32.is_lt(value,128))

def count(meta: Meta) -> U32:
  match meta:
    case Meta{length,bytes,sealed,cursor,error}: length

def fault(meta: Meta) -> Maybe<&2, E.Error>:
  match meta:
    case Meta{length,bytes,sealed,cursor,error}: error

def first_error(previous: Maybe<&2, E.Error>, error: E.Error) -> Maybe<&2, E.Error>:
  match previous:
    case None{}: Some{error}
    case Some{old}: Some{old}

def broken(meta: Meta, error: E.Error) -> Meta:
  match meta:
    case Meta{length,bytes,sealed,cursor,old}: Meta{length,bytes,sealed,cursor,first_error(old,error)}

def mark(arena: Arena, error: E.Error) -> Arena:
  match arena:
    case Arena{pages,current,visited,residual,meta}: Arena{pages,current,visited,residual,broken(meta,error)}

def failed(budget: B.Budget, arena: Arena, +error: E.Error) -> B.Budget & Arena & Result<&2, &2, E.Error, Unit>:
  (budget,mark(arena,error),Fail{error})

def metadata(arena: Arena) -> Arena & U32 & U32:
  match arena:
    case Arena{pages,current,visited,residual,Meta{+length,+bytes,sealed,cursor,error}}:
      (Arena{pages,current,visited,residual,Meta{length,bytes,sealed,cursor,error}},length,bytes)

def emitted(meta: Meta, value: U32) -> Meta:
  match meta:
    case Meta{length,bytes,sealed,cursor,error}: Meta{U32.inc(length),U32.add(bytes,width(value)),sealed,cursor,error}

def appended(pages: Pages, visited: Pages, residual: Maybe<&1,O.Claim>, meta: Meta, value: U32, p: B.Budget & S.ScalarChunk & Result<&2,&2,E.Error,Unit>) -> B.Budget & Arena & Result<&2,&2,E.Error,Unit>:
  (budget,data,result) = p
  match result:
    case Fail{error}: failed(budget,Arena{pages,Some{LivePayload{data}},visited,residual,meta},error)
    case Done{u}: (budget,Arena{pages,Some{LivePayload{data}},visited,residual,emitted(meta,value)},Done{u})

def created(pages: Pages, visited: Pages, residual: Maybe<&1,O.Claim>, meta: Meta, +value: U32, p: B.Budget & Result<&2,&1,E.Error,S.ScalarChunk>) -> B.Budget & Arena & Result<&2,&2,E.Error,Unit>:
  (budget,result) = p
  match result:
    case Fail{error}: failed(budget,Arena{pages,None{},visited,residual,meta},error)
    case Done{data}: appended(pages,visited,residual,meta,value,S.append(budget,S.clear(data),value))

def linked(pages: Pages, current: S.ScalarChunk, visited: Pages, meta: Meta, value: U32, p: B.Budget & O.Outcome) -> B.Budget & Arena & Result<&2,&2,E.Error,Unit>:
  (budget,result) = p
  match result:
    case O.ClaimFailed{error,residual}: failed(budget,Arena{pages,Some{LivePayload{current}},visited,residual,meta},error)
    case O.ClaimReady{claim}: created(Page{Some{LivePayload{current}},claim,pages},visited,None{},meta,value,S.new(budget,4096))

def append_space(budget: B.Budget, pages: Pages, current: S.ScalarChunk, visited: Pages, residual: Maybe<&1,O.Claim>, meta: Meta, +value: U32, space: Bool) -> B.Budget & Arena & Result<&2,&2,E.Error,Unit>:
  match space:
    case True{}: appended(pages,visited,residual,meta,value,S.append(budget,current,value))
    case False{}: linked(pages,current,visited,meta,value,O.acquire(budget,Charges.link()))

def append_current(budget: B.Budget, pages: Pages, visited: Pages, residual: Maybe<&1,O.Claim>, meta: Meta, value: U32, p: S.ScalarChunk & U32 & U32 & U32 & U32) -> B.Budget & Arena & Result<&2,&2,E.Error,Unit>:
  (current,length,capacity,run,origin) = p
  append_space(budget,pages,current,visited,residual,meta,value,U32.is_lt(length,capacity))

def append_ready(budget: B.Budget, arena: Arena, value: U32) -> B.Budget & Arena & Result<&2,&2,E.Error,Unit>:
  match arena:
    case Arena{pages,None{},visited,residual,meta}: created(pages,visited,residual,meta,value,S.new(budget,4096))
    case Arena{pages,Some{LivePayload{current}},visited,residual,meta}: append_current(budget,pages,visited,residual,meta,value,S.metadata(current))
    case Arena{pages,Some{ReleasePayload{allocation}},visited,residual,meta}: failed(budget,Arena{pages,Some{ReleasePayload{allocation}},visited,residual,meta},E.InternalInvariant{510})

def append_fit(budget: B.Budget, arena: Arena, value: U32, okay: Bool) -> B.Budget & Arena & Result<&2,&2,E.Error,Unit>:
  match okay:
    case False{}: failed(budget,arena,E.ResourceLimit{50,1048576,1048576,1})
    case True{}: append_ready(budget,arena,value)

def append_state(budget: B.Budget, arena: Arena, +value: U32, bytes: U32, sealed: Bool, error: Maybe<&2,E.Error>) -> B.Budget & Arena & Result<&2,&2,E.Error,Unit>:
  match sealed error:
    case _ Some{error}: (budget,arena,Fail{error})
    case True{} None{}: failed(budget,arena,E.InternalInvariant{511})
    case False{} None{}: append_fit(budget,arena,value,U32.is_le(width(value),U32.sub(1048576,bytes)))

def append(budget: B.Budget, arena: Arena, value: U32) -> B.Budget & Arena & Result<&2,&2,E.Error,Unit>:
  match arena:
    case Arena{pages,current,visited,residual,Meta{length,+bytes,+sealed,cursor,+error}}:
      append_state(budget,Arena{pages,current,visited,residual,Meta{length,bytes,sealed,cursor,error}},value,bytes,sealed,error)

def reverse(pages: Pages, acc: Pages) -> Pages:
  match pages:
    case NoPages{}: acc
    case Page{data,claim,tail}: reverse(tail,Page{data,claim,acc})

def seal_state(budget: B.Budget, pages: Pages, current: Maybe<&1,Payload>, visited: Pages, residual: Maybe<&1,O.Claim>, length: U32, bytes: U32, sealed: Bool, cursor: U32, error: Maybe<&2,E.Error>) -> B.Budget & Arena & Result<&2,&2,E.Error,Unit>:
  match sealed error:
    case _ Some{+error}: (budget,Arena{pages,current,visited,residual,Meta{length,bytes,sealed,cursor,Some{error}}},Fail{error})
    case True{} None{}: (budget,Arena{pages,current,visited,residual,Meta{length,bytes,True{},cursor,None{}}},Done{Unit{}})
    case False{} None{}: (budget,Arena{reverse(pages,NoPages{}),current,visited,residual,Meta{length,bytes,True{},0,None{}}},Done{Unit{}})

def seal(budget: B.Budget, arena: Arena) -> B.Budget & Arena & Result<&2,&2,E.Error,Unit>:
  match arena:
    case Arena{pages,current,visited,residual,Meta{length,bytes,sealed,cursor,error}}:
      seal_state(budget,pages,current,visited,residual,length,bytes,sealed,cursor,error)

# Iteration is monotonic and moves already-owned page links to visited; no
# payload copies or repeated prefix searches are performed.
def advanced(meta: Meta) -> Meta:
  match meta:
    case Meta{length,bytes,sealed,cursor,error}: Meta{length,bytes,sealed,U32.inc(cursor),error}

def read_failed(budget: B.Budget, arena: Arena, +error: E.Error) -> B.Budget & Arena & Result<&2,&2,E.Error,Maybe<&2,U32>>:
  (budget,mark(arena,error),Fail{error})

def read_page_done(current: Maybe<&1,Payload>, visited: Pages, residual: Maybe<&1,O.Claim>, meta: Meta, data: S.ScalarChunk, claim: O.Claim, tail: Pages, value: U32, end: Bool, budget: B.Budget) -> B.Budget & Arena & Result<&2,&2,E.Error,Maybe<&2,U32>>:
  match end:
    case False{}: (budget,Arena{Page{Some{LivePayload{data}},claim,tail},current,visited,residual,advanced(meta)},Done{Some{value}})
    case True{}: (budget,Arena{tail,current,Page{Some{LivePayload{data}},claim,visited},residual,advanced(meta)},Done{Some{value}})

def read_page(current: Maybe<&1,Payload>, visited: Pages, residual: Maybe<&1,O.Claim>, +meta: Meta, claim: O.Claim, tail: Pages, end: Bool, p: B.Budget & S.ScalarChunk & Result<&2,&2,E.Error,U32>) -> B.Budget & Arena & Result<&2,&2,E.Error,Maybe<&2,U32>>:
  (budget,data,result) = p
  match result:
    case Fail{error}: read_failed(budget,Arena{Page{Some{LivePayload{data}},claim,tail},current,visited,residual,meta},error)
    case Done{value}: read_page_done(current,visited,residual,meta,data,claim,tail,value,end,budget)

def read_tail(visited: Pages, residual: Maybe<&1,O.Claim>, meta: Meta, p: B.Budget & S.ScalarChunk & Result<&2,&2,E.Error,U32>) -> B.Budget & Arena & Result<&2,&2,E.Error,Maybe<&2,U32>>:
  (budget,data,result) = p
  match result:
    case Fail{error}: read_failed(budget,Arena{NoPages{},Some{LivePayload{data}},visited,residual,meta},error)
    case Done{value}: (budget,Arena{NoPages{},Some{LivePayload{data}},visited,residual,advanced(meta)},Done{Some{value}})

def read_ready(budget: B.Budget, arena: Arena, +index: U32) -> B.Budget & Arena & Result<&2,&2,E.Error,Maybe<&2,U32>>:
  match arena:
    case Arena{Page{Some{LivePayload{data}},claim,tail},current,visited,residual,meta}:
      read_page(current,visited,residual,meta,claim,tail,U32.is_eq(index,4095),S.get(budget,data,index))
    case Arena{NoPages{},Some{LivePayload{data}},visited,residual,meta}: read_tail(visited,residual,meta,S.get(budget,data,index))
    case other: read_failed(budget,other,E.InternalInvariant{512})

def read_end(budget: B.Budget, arena: Arena, cursor: U32, end: Bool) -> B.Budget & Arena & Result<&2,&2,E.Error,Maybe<&2,U32>>:
  match end:
    case True{}: (budget,arena,Done{None{}})
    case False{}: read_ready(budget,arena,U32.mod(cursor,4096))

def read_state(budget: B.Budget, arena: Arena, +length: U32, +cursor: U32, sealed: Bool, error: Maybe<&2,E.Error>) -> B.Budget & Arena & Result<&2,&2,E.Error,Maybe<&2,U32>>:
  match sealed error:
    case _ Some{error}: (budget,arena,Fail{error})
    case False{} None{}: read_failed(budget,arena,E.InternalInvariant{513})
    case True{} None{}: read_end(budget,arena,cursor,U32.is_ge(cursor,length))

def next(budget: B.Budget, arena: Arena) -> B.Budget & Arena & Result<&2,&2,E.Error,Maybe<&2,U32>>:
  match arena:
    case Arena{pages,current,visited,residual,Meta{+length,bytes,+sealed,+cursor,+error}}:
      read_state(budget,Arena{pages,current,visited,residual,Meta{length,bytes,sealed,cursor,error}},length,cursor,sealed,error)

# Cleanup failures keep both the failed allocation and all unvisited owners.
def payload_released(p: B.Budget & Result<&1,&2,E.Error & B.Allocation,Unit>) -> B.Budget & Maybe<&1,Payload> & Maybe<&2,E.Error>:
  (budget,result) = p
  match result:
    case Done{u}: (budget,None{},None{})
    case Fail{pair}:
      (error,allocation) = pair
      (budget,Some{ReleasePayload{allocation}},Some{error})

def drop_payload(budget: B.Budget, payload: Maybe<&1,Payload>) -> B.Budget & Maybe<&1,Payload> & Maybe<&2,E.Error>:
  match payload:
    case None{}: (budget,None{},None{})
    case Some{LivePayload{data}}: payload_released(S.drop(budget,data))
    case Some{ReleasePayload{allocation}}: payload_released(B.release(budget,allocation))

def link_released(tail: Pages, p: B.Budget & Result<&1,&2,E.Error & O.Claim,Unit>) -> B.Budget & Pages & Maybe<&2,E.Error>:
  (budget,result) = p
  match result:
    case Done{u}: (budget,tail,None{})
    case Fail{pair}:
      (error,claim) = pair
      (budget,Page{None{},claim,tail},Some{error})

def page_dropped(claim: O.Claim, tail: Pages, p: B.Budget & Maybe<&1,Payload> & Maybe<&2,E.Error>) -> B.Budget & Pages & Maybe<&2,E.Error>:
  (budget,payload,error) = p
  match error:
    case Some{+error}: (budget,Page{payload,claim,tail},Some{error})
    case None{}: link_released(tail,O.release(budget,claim))

def drop_one(budget: B.Budget, pages: Pages) -> B.Budget & Pages & Maybe<&2,E.Error>:
  match pages:
    case NoPages{}: (budget,NoPages{},None{})
    case Page{data,claim,tail}: page_dropped(claim,tail,drop_payload(budget,data))

def drop_loop(fuel: Nat, p: B.Budget & Pages & Maybe<&2,E.Error>) -> B.Budget & Pages & Maybe<&2,E.Error>:
  match fuel:
    case 0n: p
    case 1n+rest:
      (budget,pages,error) = p
      match error:
        case Some{error}: (budget,pages,Some{error})
        case None{}: drop_loop(rest,drop_one(budget,pages))

def drop_current(meta: Meta, p: B.Budget & Maybe<&1,Payload> & Maybe<&2,E.Error>) -> B.Budget & Maybe<&1,Arena> & Maybe<&2,E.Error>:
  (budget,current,error) = p
  match error:
    case None{}: (budget,None{},None{})
    case Some{+error}: (budget,Some{Arena{NoPages{},current,NoPages{},None{},broken(meta,error)}},Some{error})

def drop_visited(current: Maybe<&1,Payload>, meta: Meta, p: B.Budget & Pages & Maybe<&2,E.Error>) -> B.Budget & Maybe<&1,Arena> & Maybe<&2,E.Error>:
  (budget,visited,error) = p
  match visited error:
    case NoPages{} None{}: drop_current(meta,drop_payload(budget,current))
    case other Some{+error}: (budget,Some{Arena{NoPages{},current,other,None{},broken(meta,error)}},Some{error})
    case other None{}: (budget,Some{Arena{NoPages{},current,other,None{},meta}},Some{E.InternalInvariant{514}})

def drop_sealed(current: Maybe<&1,Payload>, visited: Pages, +meta: Meta, p: B.Budget & Pages & Maybe<&2,E.Error>) -> B.Budget & Maybe<&1,Arena> & Maybe<&2,E.Error>:
  (budget,pages,error) = p
  match pages error:
    case NoPages{} None{}: drop_visited(current,meta,drop_loop(U32.to_nat(U32.inc(U32.div(count(meta),4096))),(budget,visited,None{})))
    case other Some{+error}: (budget,Some{Arena{other,current,visited,None{},broken(meta,error)}},Some{error})
    case other None{}: (budget,Some{Arena{other,current,visited,None{},meta}},Some{E.InternalInvariant{515}})

def drop_pages(budget: B.Budget, pages: Pages, current: Maybe<&1,Payload>, visited: Pages, +meta: Meta) -> B.Budget & Maybe<&1,Arena> & Maybe<&2,E.Error>:
  drop_sealed(current,visited,meta,drop_loop(U32.to_nat(U32.inc(U32.div(count(meta),4096))),(budget,pages,None{})))

def drop_residual(pages: Pages, current: Maybe<&1,Payload>, visited: Pages, meta: Meta, p: B.Budget & Result<&1,&2,E.Error & O.Claim,Unit>) -> B.Budget & Maybe<&1,Arena> & Maybe<&2,E.Error>:
  (budget,result) = p
  match result:
    case Done{u}: drop_pages(budget,pages,current,visited,meta)
    case Fail{pair}:
      (error,claim) = pair
      (budget,Some{Arena{pages,current,visited,Some{claim},meta}},Some{error})

def drop(budget: B.Budget, arena: Arena) -> B.Budget & Maybe<&1,Arena> & Maybe<&2,E.Error>:
  match arena:
    case Arena{pages,current,visited,None{},meta}: drop_pages(budget,pages,current,visited,meta)
    case Arena{pages,current,visited,Some{claim},meta}: drop_residual(pages,current,visited,meta,O.release(budget,claim))
