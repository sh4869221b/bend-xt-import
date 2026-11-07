import Base
import ../../core/error.bend as E
import ../../core/budget.bend as B
import ../../core/bytes.bend as Bytes
import ../../hash/sha256.bend as SHA
import ./lib/buffer_assert.bend as A

def finished(result: Result<&1, &2, E.Error & B.Budget, B.Six>) -> IO(Unit):
  match result:
    case Done{B.Six{0,0,0,0,0,1}}: IO.print("sha-error-unchanged")
    case _: IO.die(Unit,70,"SHA error changed work/lifecycle")

def bytes_dropped(p: B.Budget & Result<&1, &2, E.Error & B.Allocation, Unit>) -> IO(Unit):
  (budget,result) = p
  match result:
    case Done{u}: finished(B.finish(budget))
    case _: IO.die(Unit,70,"byte drop")

def sha_dropped(bytes: Bytes.OwnedBytes, p: B.Budget & Result<&1, &2, E.Error & B.Allocation, Unit>) -> IO(Unit):
  (budget,result) = p
  match result:
    case Done{u}: bytes_dropped(Bytes.drop(budget,bytes))
    case _: IO.die(Unit,70,"sha drop")

def checked(budget: B.Budget, bytes: Bytes.OwnedBytes, state: SHA.ShaState, valid: Bool) -> IO(Unit):
  match valid:
    case False{}: IO.die(Unit,70,"wrong SHA error")
    case True{}: sha_dropped(bytes,SHA.drop(budget,state))

def result(mode: U32, p: B.Budget & Bytes.OwnedBytes & SHA.ShaState & Result<&2, &2, E.Error, Unit>) -> IO(Unit):
  (budget,bytes,state,r) = p
  match r:
    case Fail{E.Bounds{1,1,1}}: checked(budget,bytes,state,U32.is_eq(mode,0))
    case Fail{E.Overflow{3,536870911,4294967295}}: checked(budget,bytes,state,U32.is_eq(mode,1))
    case _: IO.die(Unit,70,"wrong SHA rejection/context")

def injected(mode: U32, budget: B.Budget, bytes: Bytes.OwnedBytes, state: SHA.ShaState) -> IO(Unit):
  match mode state:
    case 0 state: result(0,SHA.update(budget,state,bytes,1,1))
    case _ SHA.Sha{words,schedule,pending,high,low,allocation}: result(1,SHA.update(budget,SHA.Sha{words,schedule,63,536870911,4294967295,allocation},bytes,0,1))

def initialized(mode: U32, bytes: Bytes.OwnedBytes, p: B.Budget & Result<&2, &1, E.Error, SHA.ShaState>) -> IO(Unit):
  (budget,r) = p
  match r:
    case Done{state}: injected(mode,budget,bytes,state)
    case _: IO.die(Unit,70,"sha init")

def created(mode: U32, p: B.Budget & Result<&2, &1, E.Error, Bytes.OwnedBytes>) -> IO(Unit):
  (budget,r) = p
  match r:
    case Done{bytes}: initialized(mode,bytes,SHA.init(budget))
    case _: IO.die(Unit,70,"byte new")

def started(mode: U32, r: Result<&2, &1, E.Error, B.Budget>) -> IO(Unit):
  match r:
    case Done{budget}: created(mode,Bytes.new(budget,1))
    case _: IO.die(Unit,70,"start")

# The only state inspection below is bounded test-only metadata inspection.
# Resuming/finalizing against the independent SHA256(abc) vector checks its content.
def state_length(+expected: U32, state: SHA.ShaState) -> IO(SHA.ShaState):
  match state:
    case SHA.Sha{words,schedule,+pending,+high,+low,allocation}:
      do IO<SHA.ShaState>:
        A.check("sha pending prefix",U32.is_eq(pending,expected))
        A.check("sha high length",U32.is_eq(high,0))
        A.check("sha low length",U32.is_eq(low,expected))
        IO.pure(SHA.ShaState,SHA.Sha{words,schedule,pending,high,low,allocation})

def sha_created(p: B.Budget & Result<&2, &1, E.Error, SHA.ShaState>) -> IO(B.Budget & SHA.ShaState):
  (budget,r) = p
  match r:
    case Done{state}: IO.pure(B.Budget & SHA.ShaState,(budget,state))
    case _: IO.die(B.Budget & SHA.ShaState,70,"sha init")

def updated(p: B.Budget & Bytes.OwnedBytes & SHA.ShaState & Result<&2, &2, E.Error, Unit>) -> IO(B.Budget & Bytes.OwnedBytes & SHA.ShaState):
  (budget,bytes,state,r) = p
  match r:
    case Done{u}: IO.pure(B.Budget & Bytes.OwnedBytes & SHA.ShaState,(budget,bytes,state))
    case _: IO.die(B.Budget & Bytes.OwnedBytes & SHA.ShaState,70,"sha update")

def update_failed(expected: E.Error, p: B.Budget & Bytes.OwnedBytes & SHA.ShaState & Result<&2, &2, E.Error, Unit>) -> IO(B.Budget & Bytes.OwnedBytes & SHA.ShaState):
  (budget,bytes,state,r) = p
  match r:
    case Fail{error}:
      do IO<B.Budget & Bytes.OwnedBytes & SHA.ShaState>:
        A.check("sha update ResourceLimit context",A.error_equal(expected,error))
        IO.pure(B.Budget & Bytes.OwnedBytes & SHA.ShaState,(budget,bytes,state))
    case _: IO.die(B.Budget & Bytes.OwnedBytes & SHA.ShaState,70,"sha update must fail")

def final_none(expected: E.Error, p: B.Budget & SHA.FinalResult) -> IO(B.Budget & SHA.ShaState):
  (budget,r) = p
  match r:
    case SHA.HashFailed{error,state,None{}}:
      do IO<B.Budget & SHA.ShaState>:
        A.check("sha finalize None context",A.error_equal(expected,error))
        IO.pure(B.Budget & SHA.ShaState,(budget,state))
    case _: IO.die(B.Budget & SHA.ShaState,70,"sha finalize expected HashFailed None")

def final_some(expected: E.Error, p: B.Budget & SHA.FinalResult) -> IO(B.Budget & SHA.ShaState & Bytes.OwnedBytes):
  (budget,r) = p
  match r:
    case SHA.HashFailed{error,state,Some{digest}}:
      do IO<B.Budget & SHA.ShaState & Bytes.OwnedBytes>:
        A.check("sha finalize Some context",A.error_equal(expected,error))
        IO.pure(B.Budget & SHA.ShaState & Bytes.OwnedBytes,(budget,state,digest))
    case _: IO.die(B.Budget & SHA.ShaState & Bytes.OwnedBytes,70,"sha finalize expected HashFailed Some")

def final_done(p: B.Budget & SHA.FinalResult) -> IO(B.Budget & Bytes.OwnedBytes):
  (budget,r) = p
  match r:
    case SHA.HashDone{digest}: IO.pure(B.Budget & Bytes.OwnedBytes,(budget,digest))
    case _: IO.die(B.Budget & Bytes.OwnedBytes,70,"sha finalization success expected")

def verify_values(values: List<U32>, +index: U32, p: B.Budget & Bytes.OwnedBytes) -> IO(B.Budget & Bytes.OwnedBytes):
  match values:
    case Nil{}: IO.pure(B.Budget & Bytes.OwnedBytes,p)
    case value <> rest:
      (budget,bytes) = p
      do IO<B.Budget & Bytes.OwnedBytes>:
        next : B.Budget & Bytes.OwnedBytes <- A.read(value,Bytes.get(budget,bytes,index))
        verify_values(rest,U32.inc(index),next)

# Known SHA-256 abc vector, generated/independently verified with Python hashlib.
def verify_abc(p: B.Budget & Bytes.OwnedBytes) -> IO(B.Budget & Bytes.OwnedBytes):
  verify_values(186 <> 120 <> 22 <> 191 <> 143 <> 1 <> 207 <> 234 <> 65 <> 65 <> 64 <> 222 <> 93 <> 174 <> 34 <> 35 <> 176 <> 3 <> 97 <> 163 <> 150 <> 23 <> 122 <> 156 <> 180 <> 16 <> 255 <> 97 <> 242 <> 0 <> 21 <> 173 <> Nil{},0,p)

def update_work_prefix_step_11(p19: B.Budget & Bytes.OwnedBytes) -> IO(Unit):
  (bv,dv) = p19
  do IO<Unit>:
    end : B.Budget <- A.dropped(Bytes.drop(bv,dv))
    A.finished("sha-update-work-prefix-resume-abc",B.Six{0,0,0,0,0,109},B.finish(end))

def update_work_prefix_step_10(p17: B.Budget & Bytes.OwnedBytes) -> IO(Unit):
  (bf,digest) = p17
  do IO<Unit>:
    bc : B.Budget <- A.usage(B.Six{0,0,0,0,135168,77},B.zero(),B.inspect(bf))
    p19 : B.Budget & Bytes.OwnedBytes <- verify_abc((bc,digest))
    update_work_prefix_step_11(p19)

def update_work_prefix_step_9(p13: B.Budget & Bytes.OwnedBytes & SHA.ShaState) -> IO(Unit):
  (b11,x11,s11) = p13
  do IO<Unit>:
    s12 : SHA.ShaState <- state_length(3,s11)
    b12 : B.Budget <- A.usage(B.Six{0,0,0,0,204800,13},B.zero(),B.inspect(b11))
    b13 : B.Budget <- A.dropped(Bytes.drop(b12,x11))
    p17 : B.Budget & Bytes.OwnedBytes <- final_done(SHA.finalize(b13,s12))
    update_work_prefix_step_10(p17)

def update_work_prefix_step_8(+prefix: U32, checked: SHA.ShaState, p12: B.Budget & Bytes.OwnedBytes) -> IO(Unit):
  (b10,x10) = p12
  do IO<Unit>:
    p13 : B.Budget & Bytes.OwnedBytes & SHA.ShaState <- updated(SHA.update(b10,checked,x10,prefix,U32.sub(3,prefix)))
    update_work_prefix_step_9(p13)

def update_work_prefix_step_7(+prefix: U32, ticket: B.Reservation, p8: B.Budget & Bytes.OwnedBytes & SHA.ShaState) -> IO(Unit):
  (b7,source,state) = p8
  do IO<Unit>:
    checked : SHA.ShaState <- state_length(prefix,state)
    b8 : B.Budget <- A.usage(B.Six{0,0,0,0,204800,U32.add(7,prefix)},B.Six{0,0,0,0,4096,110},B.inspect(b7))
    b9 : B.Budget <- A.cancelled(B.cancel(b8,ticket))
    p12 : B.Budget & Bytes.OwnedBytes <- verify_values(97 <> 98 <> 99 <> Nil{},0,(b9,source))
    update_work_prefix_step_8(prefix,checked,p12)

def update_work_prefix_step_6(+prefix: U32, x4: Bytes.OwnedBytes, sha: SHA.ShaState, p7: B.Budget & B.Reservation) -> IO(Unit):
  (b6,ticket) = p7
  do IO<Unit>:
    p8 : B.Budget & Bytes.OwnedBytes & SHA.ShaState <- update_failed(E.ResourceLimit{5,U32.add(117,prefix),U32.add(117,prefix),1},SHA.update(b6,sha,x4,0,3))
    update_work_prefix_step_7(prefix,ticket,p8)

def update_work_prefix_step_5(+prefix: U32, x4: Bytes.OwnedBytes, p6: B.Budget & SHA.ShaState) -> IO(Unit):
  (b5,sha) = p6
  do IO<Unit>:
    p7 : B.Budget & B.Reservation <- A.reserved(B.reserve_many(b5,B.work(110)))
    update_work_prefix_step_6(prefix,x4,sha,p7)

def update_work_prefix_step_4(+prefix: U32, p5: B.Budget & Bytes.OwnedBytes) -> IO(Unit):
  (b4,x4) = p5
  do IO<Unit>:
    p6 : B.Budget & SHA.ShaState <- sha_created(SHA.init(b4))
    update_work_prefix_step_5(prefix,x4,p6)

def update_work_prefix_step_3(+prefix: U32, p4: B.Budget & Bytes.OwnedBytes) -> IO(Unit):
  (b3,x3) = p4
  do IO<Unit>:
    p5 : B.Budget & Bytes.OwnedBytes <- A.changed(Bytes.put(b3,x3,2,99))
    update_work_prefix_step_4(prefix,p5)

def update_work_prefix_step_2(+prefix: U32, p3: B.Budget & Bytes.OwnedBytes) -> IO(Unit):
  (b2,x2) = p3
  do IO<Unit>:
    p4 : B.Budget & Bytes.OwnedBytes <- A.changed(Bytes.put(b2,x2,1,98))
    update_work_prefix_step_3(prefix,p4)

def update_work_prefix_step_1(+prefix: U32, p2: B.Budget & Bytes.OwnedBytes) -> IO(Unit):
  (b1,x1) = p2
  do IO<Unit>:
    p3 : B.Budget & Bytes.OwnedBytes <- A.changed(Bytes.put(b1,x1,0,97))
    update_work_prefix_step_2(prefix,p3)

def update_work_prefix(+prefix: U32) -> IO(Unit):
  do IO<Unit>:
    b0 : B.Budget <- A.start(B.start(1,B.Six{0,0,0,0,278528,U32.add(117,prefix)}))
    p2 : B.Budget & Bytes.OwnedBytes <- A.created(Bytes.new(b0,3))
    update_work_prefix_step_1(prefix,p2)

def final_live_refusal_step_10(p15: B.Budget & Bytes.OwnedBytes) -> IO(Unit):
  (bv,dv) = p15
  do IO<Unit>:
    end : B.Budget <- A.dropped(Bytes.drop(bv,dv))
    A.finished("sha-final-live-refusal-none-retry-abc",B.Six{0,0,0,0,0,109},B.finish(end))

def final_live_refusal_step_9(p13: B.Budget & Bytes.OwnedBytes) -> IO(Unit):
  (bf,digest) = p13
  do IO<Unit>:
    bc : B.Budget <- A.usage(B.Six{0,0,0,0,135168,77},B.zero(),B.inspect(bf))
    p15 : B.Budget & Bytes.OwnedBytes <- verify_abc((bc,digest))
    final_live_refusal_step_10(p15)

def final_live_refusal_step_8(checked: SHA.ShaState, p11: B.Budget & Bytes.OwnedBytes) -> IO(Unit):
  (b9,x9) = p11
  do IO<Unit>:
    b10 : B.Budget <- A.dropped(Bytes.drop(b9,x9))
    p13 : B.Budget & Bytes.OwnedBytes <- final_done(SHA.finalize(b10,checked))
    final_live_refusal_step_9(p13)

def final_live_refusal_step_7(source: Bytes.OwnedBytes, p8: B.Budget & SHA.ShaState) -> IO(Unit):
  (b7,s7) = p8
  do IO<Unit>:
    checked : SHA.ShaState <- state_length(3,s7)
    b8 : B.Budget <- A.usage(B.Six{0,0,0,0,204800,10},B.zero(),B.inspect(b7))
    p11 : B.Budget & Bytes.OwnedBytes <- verify_values(97 <> 98 <> 99 <> Nil{},0,(b8,source))
    final_live_refusal_step_8(checked,p11)

def final_live_refusal_step_6(p7: B.Budget & Bytes.OwnedBytes & SHA.ShaState) -> IO(Unit):
  (b6,source,state) = p7
  do IO<Unit>:
    p8 : B.Budget & SHA.ShaState <- final_none(E.ResourceLimit{4,204800,204800,69632},SHA.finalize(b6,state))
    final_live_refusal_step_7(source,p8)

def final_live_refusal_step_5(x4: Bytes.OwnedBytes, p6: B.Budget & SHA.ShaState) -> IO(Unit):
  (b5,sha) = p6
  do IO<Unit>:
    p7 : B.Budget & Bytes.OwnedBytes & SHA.ShaState <- updated(SHA.update(b5,sha,x4,0,3))
    final_live_refusal_step_6(p7)

def final_live_refusal_step_4(p5: B.Budget & Bytes.OwnedBytes) -> IO(Unit):
  (b4,x4) = p5
  do IO<Unit>:
    p6 : B.Budget & SHA.ShaState <- sha_created(SHA.init(b4))
    final_live_refusal_step_5(x4,p6)

def final_live_refusal_step_3(p4: B.Budget & Bytes.OwnedBytes) -> IO(Unit):
  (b3,x3) = p4
  do IO<Unit>:
    p5 : B.Budget & Bytes.OwnedBytes <- A.changed(Bytes.put(b3,x3,2,99))
    final_live_refusal_step_4(p5)

def final_live_refusal_step_2(p3: B.Budget & Bytes.OwnedBytes) -> IO(Unit):
  (b2,x2) = p3
  do IO<Unit>:
    p4 : B.Budget & Bytes.OwnedBytes <- A.changed(Bytes.put(b2,x2,1,98))
    final_live_refusal_step_3(p4)

def final_live_refusal_step_1(p2: B.Budget & Bytes.OwnedBytes) -> IO(Unit):
  (b1,x1) = p2
  do IO<Unit>:
    p3 : B.Budget & Bytes.OwnedBytes <- A.changed(Bytes.put(b1,x1,0,97))
    final_live_refusal_step_2(p3)

def final_live_refusal() -> IO(Unit):
  do IO<Unit>:
    b0 : B.Budget <- A.start(B.start(1,B.Six{0,0,0,0,204800,109}))
    p2 : B.Budget & Bytes.OwnedBytes <- A.created(Bytes.new(b0,3))
    final_live_refusal_step_1(p2)

def final_initialization_refusal_step_11(p17: B.Budget & Bytes.OwnedBytes) -> IO(Unit):
  (bv,dv) = p17
  do IO<Unit>:
    end : B.Budget <- A.dropped(Bytes.drop(bv,dv))
    A.finished("sha-final-initialization-refusal-none-retry-abc",B.Six{0,0,0,0,0,109},B.finish(end))

def final_initialization_refusal_step_10(p15: B.Budget & Bytes.OwnedBytes) -> IO(Unit):
  (bf,digest) = p15
  do IO<Unit>:
    bc : B.Budget <- A.usage(B.Six{0,0,0,0,135168,77},B.zero(),B.inspect(bf))
    p17 : B.Budget & Bytes.OwnedBytes <- verify_abc((bc,digest))
    final_initialization_refusal_step_11(p17)

def final_initialization_refusal_step_9(checked: SHA.ShaState, p13: B.Budget & Bytes.OwnedBytes) -> IO(Unit):
  (b11,x11) = p13
  do IO<Unit>:
    b12 : B.Budget <- A.dropped(Bytes.drop(b11,x11))
    p15 : B.Budget & Bytes.OwnedBytes <- final_done(SHA.finalize(b12,checked))
    final_initialization_refusal_step_10(p15)

def final_initialization_refusal_step_8(source: Bytes.OwnedBytes, ticket: B.Reservation, p9: B.Budget & SHA.ShaState) -> IO(Unit):
  (b8,s8) = p9
  do IO<Unit>:
    checked : SHA.ShaState <- state_length(3,s8)
    b9 : B.Budget <- A.usage(B.Six{0,0,0,0,204800,10},B.Six{0,0,0,0,4096,110},B.inspect(b8))
    b10 : B.Budget <- A.cancelled(B.cancel(b9,ticket))
    p13 : B.Budget & Bytes.OwnedBytes <- verify_values(97 <> 98 <> 99 <> Nil{},0,(b10,source))
    final_initialization_refusal_step_9(checked,p13)

def final_initialization_refusal_step_7(source: Bytes.OwnedBytes, state: SHA.ShaState, p8: B.Budget & B.Reservation) -> IO(Unit):
  (b7,ticket) = p8
  do IO<Unit>:
    p9 : B.Budget & SHA.ShaState <- final_none(E.ResourceLimit{5,151,120,32},SHA.finalize(b7,state))
    final_initialization_refusal_step_8(source,ticket,p9)

def final_initialization_refusal_step_6(p7: B.Budget & Bytes.OwnedBytes & SHA.ShaState) -> IO(Unit):
  (b6,source,state) = p7
  do IO<Unit>:
    p8 : B.Budget & B.Reservation <- A.reserved(B.reserve_many(b6,B.work(110)))
    final_initialization_refusal_step_7(source,state,p8)

def final_initialization_refusal_step_5(x4: Bytes.OwnedBytes, p6: B.Budget & SHA.ShaState) -> IO(Unit):
  (b5,sha) = p6
  do IO<Unit>:
    p7 : B.Budget & Bytes.OwnedBytes & SHA.ShaState <- updated(SHA.update(b5,sha,x4,0,3))
    final_initialization_refusal_step_6(p7)

def final_initialization_refusal_step_4(p5: B.Budget & Bytes.OwnedBytes) -> IO(Unit):
  (b4,x4) = p5
  do IO<Unit>:
    p6 : B.Budget & SHA.ShaState <- sha_created(SHA.init(b4))
    final_initialization_refusal_step_5(x4,p6)

def final_initialization_refusal_step_3(p4: B.Budget & Bytes.OwnedBytes) -> IO(Unit):
  (b3,x3) = p4
  do IO<Unit>:
    p5 : B.Budget & Bytes.OwnedBytes <- A.changed(Bytes.put(b3,x3,2,99))
    final_initialization_refusal_step_4(p5)

def final_initialization_refusal_step_2(p3: B.Budget & Bytes.OwnedBytes) -> IO(Unit):
  (b2,x2) = p3
  do IO<Unit>:
    p4 : B.Budget & Bytes.OwnedBytes <- A.changed(Bytes.put(b2,x2,1,98))
    final_initialization_refusal_step_3(p4)

def final_initialization_refusal_step_1(p2: B.Budget & Bytes.OwnedBytes) -> IO(Unit):
  (b1,x1) = p2
  do IO<Unit>:
    p3 : B.Budget & Bytes.OwnedBytes <- A.changed(Bytes.put(b1,x1,0,97))
    final_initialization_refusal_step_2(p3)

def final_initialization_refusal() -> IO(Unit):
  do IO<Unit>:
    b0 : B.Budget <- A.start(B.start(1,B.Six{0,0,0,0,278528,151}))
    p2 : B.Budget & Bytes.OwnedBytes <- A.created(Bytes.new(b0,3))
    final_initialization_refusal_step_1(p2)

def final_writes_refusal_step_12(p21: B.Budget & Bytes.OwnedBytes) -> IO(Unit):
  (bv,dv) = p21
  do IO<Unit>:
    end : B.Budget <- A.dropped(Bytes.drop(bv,dv))
    A.finished("sha-final-writes-refusal-some-zero-output-retry-abc",B.Six{0,0,0,0,0,173},B.finish(end))

def final_writes_refusal_step_11(p19: B.Budget & Bytes.OwnedBytes) -> IO(Unit):
  (bf,digest) = p19
  do IO<Unit>:
    bc : B.Budget <- A.usage(B.Six{0,0,0,0,135168,141},B.zero(),B.inspect(bf))
    p21 : B.Budget & Bytes.OwnedBytes <- verify_abc((bc,digest))
    final_writes_refusal_step_12(p21)

def final_writes_refusal_step_10(checked: SHA.ShaState, p17: B.Budget & Bytes.OwnedBytes) -> IO(Unit):
  (b14,x14) = p17
  do IO<Unit>:
    b15 : B.Budget <- A.dropped(Bytes.drop(b14,x14))
    p19 : B.Budget & Bytes.OwnedBytes <- final_done(SHA.finalize(b15,checked))
    final_writes_refusal_step_11(p19)

def final_writes_refusal_step_9(source: Bytes.OwnedBytes, checked: SHA.ShaState, p14: B.Budget & Bytes.OwnedBytes) -> IO(Unit):
  (b11,d11) = p14
  do IO<Unit>:
    b12 : B.Budget <- A.dropped(Bytes.drop(b11,d11))
    b13 : B.Budget <- A.usage(B.Six{0,0,0,0,204800,74},B.zero(),B.inspect(b12))
    p17 : B.Budget & Bytes.OwnedBytes <- verify_values(97 <> 98 <> 99 <> Nil{},0,(b13,source))
    final_writes_refusal_step_10(checked,p17)

def final_writes_refusal_step_8(source: Bytes.OwnedBytes, ticket: B.Reservation, p9: B.Budget & SHA.ShaState & Bytes.OwnedBytes) -> IO(Unit):
  (b8,s8,partial) = p9
  do IO<Unit>:
    checked : SHA.ShaState <- state_length(3,s8)
    partial_checked : Bytes.OwnedBytes <- A.metadata(32,32,1,4,Bytes.metadata(partial))
    b9 : B.Budget <- A.usage(B.Six{0,0,0,0,274432,42},B.Six{0,0,0,0,4096,110},B.inspect(b8))
    b10 : B.Budget <- A.cancelled(B.cancel(b9,ticket))
    p14 : B.Budget & Bytes.OwnedBytes <- verify_values(0 <> 0 <> 0 <> 0 <> 0 <> 0 <> 0 <> 0 <> 0 <> 0 <> 0 <> 0 <> 0 <> 0 <> 0 <> 0 <> 0 <> 0 <> 0 <> 0 <> 0 <> 0 <> 0 <> 0 <> 0 <> 0 <> 0 <> 0 <> 0 <> 0 <> 0 <> 0 <> Nil{},0,(b10,partial_checked))
    final_writes_refusal_step_9(source,checked,p14)

def final_writes_refusal_step_7(source: Bytes.OwnedBytes, state: SHA.ShaState, p8: B.Budget & B.Reservation) -> IO(Unit):
  (b7,ticket) = p8
  do IO<Unit>:
    p9 : B.Budget & SHA.ShaState & Bytes.OwnedBytes <- final_some(E.ResourceLimit{5,183,152,32},SHA.finalize(b7,state))
    final_writes_refusal_step_8(source,ticket,p9)

def final_writes_refusal_step_6(p7: B.Budget & Bytes.OwnedBytes & SHA.ShaState) -> IO(Unit):
  (b6,source,state) = p7
  do IO<Unit>:
    p8 : B.Budget & B.Reservation <- A.reserved(B.reserve_many(b6,B.work(110)))
    final_writes_refusal_step_7(source,state,p8)

def final_writes_refusal_step_5(x4: Bytes.OwnedBytes, p6: B.Budget & SHA.ShaState) -> IO(Unit):
  (b5,sha) = p6
  do IO<Unit>:
    p7 : B.Budget & Bytes.OwnedBytes & SHA.ShaState <- updated(SHA.update(b5,sha,x4,0,3))
    final_writes_refusal_step_6(p7)

def final_writes_refusal_step_4(p5: B.Budget & Bytes.OwnedBytes) -> IO(Unit):
  (b4,x4) = p5
  do IO<Unit>:
    p6 : B.Budget & SHA.ShaState <- sha_created(SHA.init(b4))
    final_writes_refusal_step_5(x4,p6)

def final_writes_refusal_step_3(p4: B.Budget & Bytes.OwnedBytes) -> IO(Unit):
  (b3,x3) = p4
  do IO<Unit>:
    p5 : B.Budget & Bytes.OwnedBytes <- A.changed(Bytes.put(b3,x3,2,99))
    final_writes_refusal_step_4(p5)

def final_writes_refusal_step_2(p3: B.Budget & Bytes.OwnedBytes) -> IO(Unit):
  (b2,x2) = p3
  do IO<Unit>:
    p4 : B.Budget & Bytes.OwnedBytes <- A.changed(Bytes.put(b2,x2,1,98))
    final_writes_refusal_step_3(p4)

def final_writes_refusal_step_1(p2: B.Budget & Bytes.OwnedBytes) -> IO(Unit):
  (b1,x1) = p2
  do IO<Unit>:
    p3 : B.Budget & Bytes.OwnedBytes <- A.changed(Bytes.put(b1,x1,0,97))
    final_writes_refusal_step_2(p3)

def final_writes_refusal() -> IO(Unit):
  do IO<Unit>:
    b0 : B.Budget <- A.start(B.start(1,B.Six{0,0,0,0,278528,183}))
    p2 : B.Budget & Bytes.OwnedBytes <- A.created(Bytes.new(b0,3))
    final_writes_refusal_step_1(p2)

def final_exact_success_step_10(p14: B.Budget & Bytes.OwnedBytes) -> IO(Unit):
  (b13,d13) = p14
  do IO<Unit>:
    end : B.Budget <- A.dropped(Bytes.drop(b13,d13))
    A.finished("sha-final-exact-neighbor-abc",B.Six{0,0,0,0,0,109},B.finish(end))

def final_exact_success_step_9(digest: Bytes.OwnedBytes, p12: B.Budget & Bytes.OwnedBytes) -> IO(Unit):
  (b11,x11) = p12
  do IO<Unit>:
    b12 : B.Budget <- A.dropped(Bytes.drop(b11,x11))
    p14 : B.Budget & Bytes.OwnedBytes <- verify_abc((b12,digest))
    final_exact_success_step_10(p14)

def final_exact_success_step_8(source: Bytes.OwnedBytes, ticket: B.Reservation, p9: B.Budget & Bytes.OwnedBytes) -> IO(Unit):
  (b8,digest) = p9
  do IO<Unit>:
    b9 : B.Budget <- A.usage(B.Six{0,0,0,0,204800,74},B.Six{0,0,0,0,4096,35},B.inspect(b8))
    b10 : B.Budget <- A.cancelled(B.cancel(b9,ticket))
    p12 : B.Budget & Bytes.OwnedBytes <- verify_values(97 <> 98 <> 99 <> Nil{},0,(b10,source))
    final_exact_success_step_9(digest,p12)

def final_exact_success_step_7(source: Bytes.OwnedBytes, state: SHA.ShaState, p8: B.Budget & B.Reservation) -> IO(Unit):
  (b7,ticket) = p8
  do IO<Unit>:
    p9 : B.Budget & Bytes.OwnedBytes <- final_done(SHA.finalize(b7,state))
    final_exact_success_step_8(source,ticket,p9)

def final_exact_success_step_6(p7: B.Budget & Bytes.OwnedBytes & SHA.ShaState) -> IO(Unit):
  (b6,source,state) = p7
  do IO<Unit>:
    p8 : B.Budget & B.Reservation <- A.reserved(B.reserve_many(b6,B.work(35)))
    final_exact_success_step_7(source,state,p8)

def final_exact_success_step_5(x4: Bytes.OwnedBytes, p6: B.Budget & SHA.ShaState) -> IO(Unit):
  (b5,sha) = p6
  do IO<Unit>:
    p7 : B.Budget & Bytes.OwnedBytes & SHA.ShaState <- updated(SHA.update(b5,sha,x4,0,3))
    final_exact_success_step_6(p7)

def final_exact_success_step_4(p5: B.Budget & Bytes.OwnedBytes) -> IO(Unit):
  (b4,x4) = p5
  do IO<Unit>:
    p6 : B.Budget & SHA.ShaState <- sha_created(SHA.init(b4))
    final_exact_success_step_5(x4,p6)

def final_exact_success_step_3(p4: B.Budget & Bytes.OwnedBytes) -> IO(Unit):
  (b3,x3) = p4
  do IO<Unit>:
    p5 : B.Budget & Bytes.OwnedBytes <- A.changed(Bytes.put(b3,x3,2,99))
    final_exact_success_step_4(p5)

def final_exact_success_step_2(p3: B.Budget & Bytes.OwnedBytes) -> IO(Unit):
  (b2,x2) = p3
  do IO<Unit>:
    p4 : B.Budget & Bytes.OwnedBytes <- A.changed(Bytes.put(b2,x2,1,98))
    final_exact_success_step_3(p4)

def final_exact_success_step_1(p2: B.Budget & Bytes.OwnedBytes) -> IO(Unit):
  (b1,x1) = p2
  do IO<Unit>:
    p3 : B.Budget & Bytes.OwnedBytes <- A.changed(Bytes.put(b1,x1,0,97))
    final_exact_success_step_2(p3)

def final_exact_success() -> IO(Unit):
  do IO<Unit>:
    b0 : B.Budget <- A.start(B.start(1,B.Six{0,0,0,0,278528,109}))
    p2 : B.Budget & Bytes.OwnedBytes <- A.created(Bytes.new(b0,3))
    final_exact_success_step_1(p2)

def main() -> IO(Unit):
  do IO<Unit>:
    started(0,B.start(1,B.Six{0,0,0,0,1048576,100}))
    started(1,B.start(2,B.Six{0,0,0,0,1048576,100}))
    update_work_prefix(0)
    update_work_prefix(2)
    final_live_refusal()
    final_initialization_refusal()
    final_writes_refusal()
    final_exact_success()
    IO.print("sha-errors-ok")
