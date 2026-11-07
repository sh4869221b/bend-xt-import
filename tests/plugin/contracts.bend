# Authored ownership/lifecycle tests, independent of the event oracle driver.
import Base
import ../../core/budget.bend as B
import ../../core/bytes.bend as Bytes
import ../../core/cursor.bend as C
import ../../core/error.bend as E
import ../../plugin/types.bend as T
import ../../plugin/error.bend as D
import ../../plugin/state.bend as S
import ../../plugin/frame.bend as F
import ../../plugin/copy.bend as Copy
import ./support.bend as H
import ./report.bend as R
import ./runner.bend as Run

def assert(ok: Bool) -> IO(Unit):
  match ok:
    case True{}: IO.pure(Unit,Unit{})
    case False{}: IO.die(Unit,70,"contract assertion failed")

def finished(name: String, r: Result<&1, &2, E.Error & B.Budget, B.Six>) -> IO(Unit):
  match r:
    case Done{B.Six{input,expanded,output,logical,0,work}}: IO.print("CONTRACT " ++ name)
    case _: IO.die(Unit,70,"contract budget imbalance")

def cleanup_window(name: String, budget: B.Budget, window: C.ByteWindow) -> IO(Unit):
  do IO<Unit>:
    budget : B.Budget <- H.drop_window(budget,window)
    finished(name,B.finish(budget))

def cleanup(name: String, window: C.ByteWindow, p: B.Budget & Result<&1, &2, E.Error & B.Allocation, Unit>) -> IO(Unit):
  do IO<Unit>:
    budget : B.Budget <- H.dropped(p)
    cleanup_window(name,budget,window)

def input_new(fixture: H.Fixture, fill: U32, base: U32, source: C.SourceOwner, p: B.Budget & Result<&2, &1, E.Error, Bytes.OwnedBytes>) -> IO(B.Budget & C.ByteWindow):
  (budget,result) = p
  match result:
    case Done{bytes}: H.window(budget,source,bytes,fixture,fill,base)
    case _: IO.die(B.Budget & C.ByteWindow,70,"contract bytes allocation failed")

def source_new(fixture: H.Fixture, capacity: U32, fill: U32, base: U32, p: B.Budget & Result<&2, &1, E.Error, C.SourceOwner>) -> IO(B.Budget & C.ByteWindow):
  (budget,result) = p
  match result:
    case Done{source}: input_new(fixture,fill,base,source,Bytes.new(budget,capacity))
    case _: IO.die(B.Budget & C.ByteWindow,70,"contract source allocation failed")

def make_window(+fixture: H.Fixture, capacity: U32, fill: U32, base: U32, result: Result<&2, &1, E.Error, B.Budget>) -> IO(B.Budget & C.ByteWindow):
  match result:
    case Done{budget}: source_new(fixture,capacity,fill,base,C.source(budget,H.size(fixture)))
    case _: IO.die(B.Budget & C.ByteWindow,70,"contract budget start failed")

def window(capacity: U32, fill: U32, base: U32, work: U32, live: U32) -> IO(B.Budget & C.ByteWindow):
  make_window(H.synthetic(0,1),capacity,fill,base,B.start(1,B.Six{0,0,0,0,live,work}))

def start(p: B.Budget & C.ByteWindow) -> B.Budget & C.ByteWindow & F.StartResult:
  (budget,window) = p
  F.start(budget,window,T.defaults())

def started(p: B.Budget & C.ByteWindow & F.StartResult) -> IO(B.Budget & C.ByteWindow & S.Scanner & S.Status):
  (budget,window,result) = p
  match result:
    case F.Started{scanner}: IO.pure(B.Budget & C.ByteWindow & S.Scanner & S.Status,(budget,window,scanner,S.NeedWindow{0}))
    case _: IO.die(B.Budget & C.ByteWindow & S.Scanner & S.Status,70,"contract scanner start failed")

def scan_steps(fuel: Nat, p: B.Budget & C.ByteWindow & S.Scanner & S.Status) -> B.Budget & C.ByteWindow & S.Scanner & S.Status:
  match fuel:
    case 0n: p
    case 1n+rest:
      (budget,window,scanner,status) = p
      scan_steps(rest,F.next(budget,window,scanner))

def status(s: S.Status) -> String:
  match s:
    case S.NeedWindow{offset}: "NEED " ++ U32.show(offset)
    case S.Complete{summary}: R.summary(summary)
    case S.Failed{diagnostic}: R.diagnostic(diagnostic)
    case S.Yield{event}: R.event_line(event)

def clean_status(name: String, expected: String, p: B.Budget & C.ByteWindow & S.Scanner & S.Status) -> IO(Unit):
  (budget,window,scanner,result) = p
  do IO<Unit>:
    assert(String.eq(expected,status(result)))
    cleanup(name,window,S.drop(budget,scanner))

def sticky(name: String, p: B.Budget & C.ByteWindow & S.Scanner & S.Status) -> IO(Unit):
  (budget,window,scanner,result) = p
  clean_status(name,status(result),scan_steps(2n,F.next(budget,window,scanner)))

def finished_status(name: String, p: B.Budget & C.ByteWindow & S.Scanner & S.Status) -> IO(Unit):
  (budget,window,scanner,result) = p
  match result:
    case S.Complete{summary}: sticky(name,(budget,window,scanner,S.Complete{summary}))
    case _: IO.die(Unit,70,"expected complete status")

def failure_status(name: String, reason: U32, p: B.Budget & C.ByteWindow & S.Scanner & S.Status) -> IO(Unit):
  (budget,window,scanner,result) = p
  match result:
    case S.Failed{D.Diagnostic{D.Format{actual},run,origin,offset,parent_start,parent_end,record,depth,declared}}:
      do IO<Unit>:
        assert(U32.is_eq(reason,actual))
        sticky(name,F.next(budget,window,scanner))
    case _: IO.die(Unit,70,"expected format diagnostic")

def input_ended(p: B.Budget & C.ByteWindow & S.Scanner & S.Status) -> B.Budget & C.ByteWindow & S.Scanner & S.Status:
  (budget,window,scanner,status) = p
  F.next(budget,window,F.input_ended(scanner))

def need_zero(p: B.Budget & C.ByteWindow & S.Scanner & S.Status) -> IO(B.Budget & C.ByteWindow & S.Scanner & S.Status):
  (budget,window,scanner,result) = p
  match result:
    case S.NeedWindow{0}: IO.pure(B.Budget & C.ByteWindow & S.Scanner & S.Status,(budget,window,scanner,result))
    case _: IO.die(B.Budget & C.ByteWindow & S.Scanner & S.Status,70,"expected requested offset zero")

def discard_pending(name: String, p: B.Budget & C.ByteWindow & S.Scanner & S.Status) -> IO(Unit):
  (budget,window,scanner,result) = p
  cleanup(name,window,S.drop(budget,scanner))

def refilled(scanner: S.Scanner, p: B.Budget & C.ByteWindow) -> B.Budget & C.ByteWindow & S.Scanner & S.Status:
  (budget,window) = p
  (budget,window,scanner,S.NeedWindow{0})

def resume_full(p: B.Budget & C.ByteWindow & S.Scanner & S.Status) -> IO(B.Budget & C.ByteWindow & S.Scanner & S.Status):
  (budget,window,scanner,result) = p
  do IO<B.Budget & C.ByteWindow & S.Scanner & S.Status>:
    next : B.Budget & C.ByteWindow <- H.refill(budget,window,H.synthetic(0,1),24,0)
    return refilled(scanner,next)

def metadata_result(name: String, budget: B.Budget, expected_size: U32, expected_base: U32, expected_length: U32, p: C.ByteWindow & Result<&2, &1, E.Error, C.Range & U32 & U32>) -> IO(Unit):
  (window,result) = p
  match result:
    case Done{metadata}:
      (range,base,length) = metadata
      do IO<Unit>:
        assert(String.eq("1 1 0 " ++ U32.show(expected_size),H.range(range)))
        assert(Bool.and(U32.is_eq(base,expected_base),U32.is_eq(length,expected_length)))
        cleanup_window(name,budget,window)
    case _: IO.die(Unit,70,"window metadata rejected valid window")

def check_metadata(name: String, size: U32, base: U32, length: U32, p: B.Budget & C.ByteWindow) -> IO(Unit):
  (budget,window) = p
  metadata_result(name,budget,size,base,length,C.window_metadata(window))

def foreign_new(scanner: S.Scanner, bytes: Bytes.OwnedBytes, p: B.Budget & Result<&2, &1, E.Error, C.SourceOwner>) -> IO(B.Budget & C.ByteWindow & S.Scanner & S.Status):
  (budget,result) = p
  match result:
    case Done{source}:
      do IO<B.Budget & C.ByteWindow & S.Scanner & S.Status>:
        bound : B.Budget & C.ByteWindow <- H.bound(budget,C.bind(source,bytes,0))
        return refilled(scanner,bound)
    case _: IO.die(B.Budget & C.ByteWindow & S.Scanner & S.Status,70,"foreign source allocation failed")

def foreign_unbound(size: U32, budget: B.Budget, scanner: S.Scanner, p: C.SourceOwner & Bytes.OwnedBytes) -> IO(B.Budget & C.ByteWindow & S.Scanner & S.Status):
  (source,bytes) = p
  do IO<B.Budget & C.ByteWindow & S.Scanner & S.Status>:
    budget : B.Budget <- H.dropped(C.drop_source(budget,source))
    foreign_new(scanner,bytes,C.source(budget,size))

def foreign(p: B.Budget & C.ByteWindow & S.Scanner & S.Status) -> IO(B.Budget & C.ByteWindow & S.Scanner & S.Status):
  (budget,window,scanner,result) = p
  foreign_unbound(24,budget,scanner,C.unbind(window))

def work_checked(name: String, expected: U32, window: C.ByteWindow, scanner: S.Scanner, p: B.Budget & B.Six & B.Six) -> IO(Unit):
  (budget,used,held) = p
  match used:
    case B.Six{a,b,c,d,e,work}:
      do IO<Unit>:
        assert(U32.is_eq(work,expected))
        cleanup(name,window,S.drop(budget,scanner))

def work_success(p: B.Budget & C.ByteWindow & S.Scanner & S.Status) -> IO(Unit):
  (budget,window,scanner,result) = p
  match result:
    case S.Complete{summary}: work_checked("work-exact",80,window,scanner,B.inspect(budget))
    case _: IO.die(Unit,70,"exact work did not complete")

def work_failure(p: B.Budget & C.ByteWindow & S.Scanner & S.Status) -> IO(Unit):
  (budget,window,scanner,result) = p
  match result:
    case S.Failed{D.Diagnostic{D.Core{E.ResourceLimit{5,79,79,1}},run,origin,23,parent_start,parent_end,record,depth,declared}}: work_checked("work-one-less",79,window,scanner,B.inspect(budget))
    case _: IO.die(Unit,70,"one-less work diagnostic mismatch")

def live_refusal(p: B.Budget & C.ByteWindow & F.StartResult) -> IO(Unit):
  (budget,window,result) = p
  match result:
    case F.StartFailed{D.Diagnostic{D.Core{E.ResourceLimit{4,208895,139264,69632}},run,origin,offset,ps,pe,record,depth,declared},None{}}: cleanup_window("live-one-less",budget,window)
    case _: IO.die(Unit,70,"one-less live diagnostic mismatch")

def invalid_state(diagnostic: D.Diagnostic) -> Bool:
  match diagnostic:
    case D.Diagnostic{D.Format{26},run,origin,offset,ps,pe,owner,depth,declared}: True{}
    case _: False{}

def refused_copy(name: String, budget: B.Budget, window: C.ByteWindow, result: Result<&1, &1, D.Diagnostic & S.Scanner & Bytes.OwnedBytes, Copy.CopyState>) -> IO(Unit):
  match result:
    case Fail{owned}:
      (diagnostic,scanner,output) = owned
      do IO<Unit>:
        assert(invalid_state(diagnostic))
        budget : B.Budget <- H.dropped(Bytes.drop(budget,output))
        cleanup(name,window,S.drop(budget,scanner))
    case _: IO.die(Unit,70,"incomplete scanner authorized copy")

def refusal_buffer(name: String, window: C.ByteWindow, scanner: S.Scanner, p: B.Budget & Result<&2, &1, E.Error, Bytes.OwnedBytes>) -> IO(Unit):
  (budget,result) = p
  match result:
    case Done{output}: refused_copy(name,budget,window,Copy.start(scanner,Bytes.clear(output)))
    case _: IO.die(Unit,70,"copy refusal buffer allocation failed")

def refusal(name: String, p: B.Budget & C.ByteWindow & S.Scanner & S.Status) -> IO(Unit):
  (budget,window,scanner,result) = p
  refusal_buffer(name,window,scanner,Bytes.new(budget,1))

def flags() -> IO(Unit):
  do IO<Unit>:
    assert(Bool.not(T.compressed(0)))
    assert(Bool.not(T.deleted(0)))
    assert(Bool.not(T.tes4_master(0)))
    assert(Bool.not(T.tes4_localized(0)))
    assert(Bool.not(T.tes4_light(0)))
    assert(T.compressed(262144))
    assert(T.deleted(32))
    assert(T.tes4_master(1))
    assert(T.tes4_localized(128))
    assert(T.tes4_light(512))
    assert(Bool.and(T.compressed(262817),Bool.and(T.deleted(262817),Bool.and(T.tes4_master(262817),Bool.and(T.tes4_localized(262817),T.tes4_light(262817))))))
    assert(Bool.not(T.compressed(2147483648)))
    assert(Bool.not(T.deleted(2147483648)))
    assert(Bool.not(T.tes4_master(2147483648)))
    assert(Bool.not(T.tes4_localized(2147483648)))
    assert(Bool.not(T.tes4_light(2147483648)))
    IO.print("CONTRACT flag-facts")

def partial_failed(+expected: U32, p: B.Budget & C.ByteWindow & S.Scanner & S.Status) -> IO(Unit):
  (budget,window,scanner,result) = p
  match result:
    case S.Failed{D.Diagnostic{D.Format{25},run,origin,offset,parent_start,parent_end,record,depth,declared}}:
      do IO<Unit>:
        assert(U32.is_eq(expected,offset))
        cleanup("partial-header-" ++ U32.show(expected),window,S.drop(budget,scanner))
    case _: IO.die(Unit,70,"partial header interruption diagnostic mismatch")

def partial_headers(fuel: Nat, +count: U32) -> IO(Unit):
  match fuel:
    case 0n: IO.pure(Unit,Unit{})
    case 1n+rest:
      do IO<Unit>:
        p : B.Budget & C.ByteWindow <- window(24,count,0,1024,1048576)
        p : B.Budget & C.ByteWindow & S.Scanner & S.Status <- started(start(p))
        partial_failed(count,input_ended(scan_steps(1n,p)))
        partial_headers(rest,U32.inc(count))

def copy_opened(budget: B.Budget, window: C.ByteWindow, result: Result<&1, &1, D.Diagnostic & S.Scanner & Bytes.OwnedBytes, Copy.CopyState>) -> IO(B.Budget & C.ByteWindow & Copy.CopyState & Copy.CopyResult):
  match result:
    case Done{copy}: IO.pure(B.Budget & C.ByteWindow & Copy.CopyState & Copy.CopyResult,(budget,window,copy,Copy.CopyDone{}))
    case _: IO.die(B.Budget & C.ByteWindow & Copy.CopyState & Copy.CopyResult,70,"valid copier start failed")

def copier_buffer(window: C.ByteWindow, scanner: S.Scanner, p: B.Budget & Result<&2, &1, E.Error, Bytes.OwnedBytes>) -> IO(B.Budget & C.ByteWindow & Copy.CopyState & Copy.CopyResult):
  (budget,result) = p
  match result:
    case Done{bytes}: copy_opened(budget,window,Copy.start(scanner,Bytes.clear(bytes)))
    case _: IO.die(B.Budget & C.ByteWindow & Copy.CopyState & Copy.CopyResult,70,"copier contract buffer allocation failed")

def copier(p: B.Budget & C.ByteWindow & S.Scanner & S.Status) -> IO(B.Budget & C.ByteWindow & Copy.CopyState & Copy.CopyResult):
  (budget,window,scanner,result) = p
  copier_buffer(window,scanner,Bytes.new(budget,1))

def pump(p: B.Budget & C.ByteWindow & Copy.CopyState & Copy.CopyResult) -> B.Budget & C.ByteWindow & Copy.CopyState & Copy.CopyResult:
  (budget,window,state,result) = p
  Copy.pump(budget,window,state)

def copy_resumed(budget: B.Budget, window: C.ByteWindow, result: Result<&1, &1, D.Diagnostic & Copy.CopyState & Bytes.OwnedBytes, Copy.CopyState>) -> IO(B.Budget & C.ByteWindow & Copy.CopyState & Copy.CopyResult):
  match result:
    case Done{copy}: IO.pure(B.Budget & C.ByteWindow & Copy.CopyState & Copy.CopyResult,Copy.pump(budget,window,copy))
    case _: IO.die(B.Budget & C.ByteWindow & Copy.CopyState & Copy.CopyResult,70,"empty handback failed")

def copy_drain(fuel: Nat, p: B.Budget & C.ByteWindow & Copy.CopyState & Copy.CopyResult) -> IO(B.Budget & C.ByteWindow & Copy.CopyState & Copy.CopyResult):
  match fuel:
    case 0n: IO.die(B.Budget & C.ByteWindow & Copy.CopyState & Copy.CopyResult,70,"copy contract fuel exhausted")
    case 1n+rest:
      (budget,window,state,result) = p
      match result:
        case Copy.ChunkReady{bytes,False{}}:
          do IO<B.Budget & C.ByteWindow & Copy.CopyState & Copy.CopyResult>:
            next : B.Budget & C.ByteWindow & Copy.CopyState & Copy.CopyResult <- copy_resumed(budget,window,Copy.resume(state,Bytes.clear(bytes)))
            copy_drain(rest,next)
        case _: IO.pure(B.Budget & C.ByteWindow & Copy.CopyState & Copy.CopyResult,(budget,window,state,result))

def cleanup_copy(name: String, budget: B.Budget, window: C.ByteWindow, state: Copy.CopyState) -> IO(Unit):
  do IO<Unit>:
    budget : B.Budget <- Run.copy_dropped(Copy.drop(budget,state))
    cleanup_window(name,budget,window)

def copy_done(name: String, p: B.Budget & C.ByteWindow & Copy.CopyState & Copy.CopyResult) -> IO(Unit):
  (budget,window,state,result) = p
  match result:
    case Copy.CopyDone{}: cleanup_copy(name,budget,window,state)
    case _: IO.die(Unit,70,"copy complete was not sticky")

def copy_exact_usage(name: String, window: C.ByteWindow, state: Copy.CopyState, p: B.Budget & B.Six & B.Six) -> IO(Unit):
  (budget,used,held) = p
  match used:
    case B.Six{a,b,c,d,e,129}: copy_done(name,pump(Copy.pump(budget,window,state)))
    case _: IO.die(Unit,70,"copy exact work mismatch")

def copy_completed(name: String, p: B.Budget & C.ByteWindow & Copy.CopyState & Copy.CopyResult) -> IO(Unit):
  (budget,window,state,result) = p
  match result:
    case Copy.ChunkReady{bytes,True{}}:
      do IO<Unit>:
        budget : B.Budget <- H.dropped(Bytes.drop(budget,bytes))
        copy_exact_usage(name,window,state,B.inspect(budget))
    case _: IO.die(Unit,70,"expected final copied chunk")

def copy_failure_sticky(name: String, expected: String, p: B.Budget & C.ByteWindow & Copy.CopyState & Copy.CopyResult) -> IO(Unit):
  (budget,window,state,result) = p
  match result:
    case Copy.CopyFailed{diagnostic}:
      do IO<Unit>:
        assert(String.eq(expected,R.diagnostic(diagnostic)))
        cleanup_copy(name,budget,window,state)
    case _: IO.die(Unit,70,"copy failure was not sticky")

def copy_failed(name: String, p: B.Budget & C.ByteWindow & Copy.CopyState & Copy.CopyResult) -> IO(Unit):
  (budget,window,state,result) = p
  match result:
    case Copy.CopyFailed{+diagnostic}: copy_failure_sticky(name,R.diagnostic(diagnostic),pump(Copy.pump(budget,window,Copy.input_ended(state))))
    case _: IO.die(Unit,70,"expected copy failure")

def copy_format_failed(name: String, expected: U32, p: B.Budget & C.ByteWindow & Copy.CopyState & Copy.CopyResult) -> IO(Unit):
  (budget,window,state,result) = p
  match result:
    case Copy.CopyFailed{D.Diagnostic{D.Format{reason},run,origin,offset,ps,pe,owner,depth,declared}}:
      do IO<Unit>:
        assert(U32.is_eq(reason,expected))
        copy_failed(name,Copy.pump(budget,window,state))
    case _: IO.die(Unit,70,"copy format reason mismatch")

def copy_one_less(p: B.Budget & C.ByteWindow & Copy.CopyState & Copy.CopyResult) -> IO(Unit):
  (budget,window,state,result) = p
  match result:
    case Copy.CopyFailed{D.Diagnostic{D.Core{E.ResourceLimit{5,128,128,1}},run,origin,23,0,24,None{},0,1}}: copy_failed("copy-work-one-less",Copy.pump(budget,window,state))
    case _: IO.die(Unit,70,"copy one-less work context mismatch")

def drop_reading(p: B.Budget & C.ByteWindow & Copy.CopyState & Copy.CopyResult) -> IO(Unit):
  (budget,window,state,result) = p
  cleanup_copy("copy-drop-reading",budget,window,state)

def waiting_drop(name: String, misuse: Bool, budget: B.Budget, window: C.ByteWindow, state: Copy.CopyState) -> IO(Unit):
  match misuse:
    case False{}: cleanup_copy(name,budget,window,state)
    case True{}: copy_format_failed(name,26,Copy.pump(budget,window,state))

def copy_waiting(name: String, misuse: Bool, p: B.Budget & C.ByteWindow & Copy.CopyState & Copy.CopyResult) -> IO(Unit):
  (budget,window,state,result) = p
  match result:
    case Copy.ChunkReady{bytes,False{}}:
      do IO<Unit>:
        budget : B.Budget <- H.dropped(Bytes.drop(budget,bytes))
        waiting_drop(name,misuse,budget,window,state)
    case _: IO.die(Unit,70,"expected output handback state")

def nonempty_refused(budget: B.Budget, window: C.ByteWindow, result: Result<&1, &1, D.Diagnostic & Copy.CopyState & Bytes.OwnedBytes, Copy.CopyState>) -> IO(Unit):
  match result:
    case Fail{pair}:
      (diagnostic,state,bytes) = pair
      do IO<Unit>:
        assert(invalid_state(diagnostic))
        p : B.Budget & C.ByteWindow & Copy.CopyState & Copy.CopyResult <- copy_resumed(budget,window,Copy.resume(state,Bytes.clear(bytes)))
        p : B.Budget & C.ByteWindow & Copy.CopyState & Copy.CopyResult <- copy_drain(32n,p)
        copy_completed("copy-nonempty-handback-refused",p)
    case _: IO.die(Unit,70,"copy accepted nonempty handback")

def nonempty_handback(p: B.Budget & C.ByteWindow & Copy.CopyState & Copy.CopyResult) -> IO(Unit):
  (budget,window,state,result) = p
  match result:
    case Copy.ChunkReady{bytes,False{}}: nonempty_refused(budget,window,Copy.resume(state,bytes))
    case _: IO.die(Unit,70,"nonempty handback setup")

def copy_new_window(state: Copy.CopyState, p: B.Budget & C.ByteWindow) -> B.Budget & C.ByteWindow & Copy.CopyState & Copy.CopyResult:
  (budget,window) = p
  Copy.pump(budget,window,state)

def copy_foreign_new(state: Copy.CopyState, bytes: Bytes.OwnedBytes, p: B.Budget & Result<&2, &1, E.Error, C.SourceOwner>) -> IO(B.Budget & C.ByteWindow & Copy.CopyState & Copy.CopyResult):
  (budget,result) = p
  match result:
    case Done{source}:
      do IO<B.Budget & C.ByteWindow & Copy.CopyState & Copy.CopyResult>:
        bound : B.Budget & C.ByteWindow <- H.bound(budget,C.bind(source,bytes,0))
        return copy_new_window(state,bound)
    case _: IO.die(B.Budget & C.ByteWindow & Copy.CopyState & Copy.CopyResult,70,"copy foreign allocation failed")
def copy_foreign_unbound(name: String, budget: B.Budget, state: Copy.CopyState, p: C.SourceOwner & Bytes.OwnedBytes) -> IO(Unit):
  (source,bytes) = p
  do IO<Unit>:
    budget : B.Budget <- H.dropped(C.drop_source(budget,source))
    p : B.Budget & C.ByteWindow & Copy.CopyState & Copy.CopyResult <- copy_foreign_new(state,bytes,C.source(budget,24))
    copy_format_failed(name,23,p)

def copy_foreign(p: B.Budget & C.ByteWindow & Copy.CopyState & Copy.CopyResult) -> IO(Unit):
  (budget,window,state,result) = p
  copy_foreign_unbound("copy-foreign-source",budget,state,C.unbind(window))

def copy_eof(p: B.Budget & C.ByteWindow & Copy.CopyState & Copy.CopyResult) -> IO(Unit):
  (budget,window,state,result) = p
  match result:
    case Copy.CopyNeedWindow{0}: copy_format_failed("copy-premature-eof",25,Copy.pump(budget,window,Copy.input_ended(state)))
    case _: IO.die(Unit,70,"expected copy refill request")

def copy_empty_window(p: B.Budget & C.ByteWindow & Copy.CopyState & Copy.CopyResult) -> IO(Unit):
  (budget,window,state,result) = p
  do IO<Unit>:
    next : B.Budget & C.ByteWindow <- H.refill(budget,window,H.synthetic(0,1),0,0)
    copy_eof(copy_new_window(state,next))
def budget_ok(result: Result<&1, &2, E.Error & B.Budget, B.Six>) -> IO(Unit):
  match result:
    case Done{B.Six{a,b,c,d,0,work}}: IO.pure(Unit,Unit{})
    case _: IO.die(Unit,70,"wrong-run cleanup imbalance")

def wrong_run_drop(first: B.Budget, second: B.Budget, p: C.SourceOwner & Bytes.OwnedBytes) -> IO(Unit):
  (source,bytes) = p
  do IO<Unit>:
    first : B.Budget <- H.dropped(C.drop_source(first,source))
    second : B.Budget <- H.dropped(Bytes.drop(second,bytes))
    budget_ok(B.finish(first))
    budget_ok(B.finish(second))
    IO.print("CONTRACT metadata-wrong-run")

def wrong_run_metadata(first: B.Budget, second: B.Budget, p: C.ByteWindow & Result<&2, &1, E.Error, C.Range & U32 & U32>) -> IO(Unit):
  (window,result) = p
  match result:
    case Fail{E.InternalInvariant{21}}: wrong_run_drop(first,second,C.unbind(window))
    case _: IO.die(Unit,70,"wrong-run window metadata accepted")

def wrong_run_bound(first: B.Budget, second: B.Budget, result: Result<&1, &1, E.Error & C.SourceOwner & Bytes.OwnedBytes, C.ByteWindow>) -> IO(Unit):
  match result:
    case Done{window}: wrong_run_metadata(first,second,C.window_metadata(window))
    case _: IO.die(Unit,70,"wrong-run synthetic bind failed")

def wrong_run_bytes(first: B.Budget, source: C.SourceOwner, p: B.Budget & Result<&2, &1, E.Error, Bytes.OwnedBytes>) -> IO(Unit):
  (second,result) = p
  match result:
    case Done{bytes}: wrong_run_bound(first,second,C.bind(source,Bytes.clear(bytes),0))
    case _: IO.die(Unit,70,"wrong-run bytes allocation")

def wrong_run_budget(first: B.Budget, source: C.SourceOwner, result: Result<&2, &1, E.Error, B.Budget>) -> IO(Unit):
  match result:
    case Done{second}: wrong_run_bytes(first,source,Bytes.new(second,1))
    case _: IO.die(Unit,70,"wrong-run second budget")

def wrong_run_source(p: B.Budget & Result<&2, &1, E.Error, C.SourceOwner>) -> IO(Unit):
  (first,result) = p
  match result:
    case Done{source}: wrong_run_budget(first,source,B.start(2,B.Six{0,0,0,0,1048576,1024}))
    case _: IO.die(Unit,70,"wrong-run source allocation")

def wrong_run(result: Result<&2, &1, E.Error, B.Budget>) -> IO(Unit):
  match result:
    case Done{first}: wrong_run_source(C.source(first,24))
    case _: IO.die(Unit,70,"wrong-run first budget")

def release_error(error: E.Error) -> Bool:
  match error:
    case E.InternalInvariant{4}: True{}
    case _: False{}

def scanner_release_returned(first: B.Budget, window: C.ByteWindow, p: B.Budget & Result<&1, &2, E.Error & B.Allocation, Unit>) -> IO(Unit):
  (second,result) = p
  match result:
    case Fail{pair}:
      (error,allocation) = pair
      do IO<Unit>:
        assert(release_error(error))
        budget_ok(B.finish(second))
        first : B.Budget <- H.dropped(B.release(first,allocation))
        cleanup_window("scanner-release-owner-returned",first,window)
    case _: IO.die(Unit,70,"wrong-budget scanner release accepted")

def scanner_release_wrong(first: B.Budget, window: C.ByteWindow, scanner: S.Scanner, result: Result<&2, &1, E.Error, B.Budget>) -> IO(Unit):
  match result:
    case Done{second}: scanner_release_returned(first,window,S.drop(second,scanner))
    case _: IO.die(Unit,70,"second release budget start")

def scanner_release(p: B.Budget & C.ByteWindow & S.Scanner & S.Status) -> IO(Unit):
  (first,window,scanner,status) = p
  scanner_release_wrong(first,window,scanner,B.start(2,B.Six{0,0,0,0,1048576,1024}))

def copy_release_returned(first: B.Budget, window: C.ByteWindow, p: B.Budget & Maybe<&1, Bytes.OwnedBytes> & Result<&1, &2, E.Error & B.Allocation, Unit>) -> IO(Unit):
  (second,bytes,result) = p
  match result:
    case Fail{pair}:
      (error,allocation) = pair
      do IO<Unit>:
        assert(release_error(error))
        budget_ok(B.finish(second))
        first : B.Budget <- H.dropped(B.release(first,allocation))
        first : B.Budget <- Run.drop_optional(first,bytes)
        cleanup_window("copy-release-owners-returned",first,window)
    case _: IO.die(Unit,70,"wrong-budget copy release accepted")

def copy_release_wrong(first: B.Budget, window: C.ByteWindow, copy: Copy.CopyState, result: Result<&2, &1, E.Error, B.Budget>) -> IO(Unit):
  match result:
    case Done{second}: copy_release_returned(first,window,Copy.drop(second,copy))
    case _: IO.die(Unit,70,"second copy release budget start")

def copy_release(p: B.Budget & C.ByteWindow & Copy.CopyState & Copy.CopyResult) -> IO(Unit):
  (first,window,copy,result) = p
  copy_release_wrong(first,window,copy,B.start(2,B.Six{0,0,0,0,1048576,1024}))


# Check source identity before transitions that consume no bytes, including
# repeated calls after successful completion. The old and new source lengths
# match, so only the unforgeable origin distinguishes them.
def transition_tag(status: S.Status) -> U32:
  match status:
    case S.Yield{T.RecordStart{record}}: 1
    case S.Yield{T.GroupStart{group}}: 2
    case S.Yield{T.RecordEnd{start,end,count,body}}: 3
    case S.Complete{summary}: 4
    case _: 0

def foreign_transition(name: String, tag: U32, size: U32, p: B.Budget & C.ByteWindow & S.Scanner & S.Status) -> IO(Unit):
  (budget,window,scanner,result) = p
  do IO<Unit>:
    assert(U32.is_eq(transition_tag(result),tag))
    p : B.Budget & C.ByteWindow & S.Scanner & S.Status <- foreign_unbound(size,budget,scanner,C.unbind(window))
    failure_status(name,23,scan_steps(1n,p))

def completed_copy_foreign(p: B.Budget & C.ByteWindow & Copy.CopyState & Copy.CopyResult) -> IO(Unit):
  (budget,window,state,result) = p
  match result:
    case Copy.CopyDone{}: copy_foreign_unbound("copy-foreign-after-complete",budget,state,C.unbind(window))
    case _: IO.die(Unit,70,"completed foreign-copy setup failed")

def final_copy_foreign(p: B.Budget & C.ByteWindow & Copy.CopyState & Copy.CopyResult) -> IO(Unit):
  (budget,window,state,result) = p
  match result:
    case Copy.ChunkReady{bytes,True{}}:
      do IO<Unit>:
        budget : B.Budget <- H.dropped(Bytes.drop(budget,bytes))
        completed_copy_foreign(Copy.pump(budget,window,state))
    case _: IO.die(Unit,70,"expected final copy chunk before foreign source")

def main() -> IO(Unit):
  do IO<Unit>:
    p : B.Budget & C.ByteWindow <- window(24,24,0,1024,1048576)
    check_metadata("metadata-full",24,0,24,p)
    p : B.Budget & C.ByteWindow <- window(1,0,0,1024,1048576)
    check_metadata("metadata-empty",24,0,0,p)
    p : B.Budget & C.ByteWindow <- window(1,0,24,1024,1048576)
    check_metadata("metadata-end",24,24,0,p)
    p : B.Budget & C.ByteWindow <- make_window(H.Synthetic{6,4294967295,4294967295},1,0,4294967295,B.start(1,B.Six{0,0,0,0,1048576,1024}))
    check_metadata("metadata-u32-end",4294967295,4294967295,0,p)
    p : B.Budget & C.ByteWindow <- window(24,24,0,1024,1048576)
    p : B.Budget & C.ByteWindow & S.Scanner & S.Status <- started(start(p))
    finished_status("sticky-complete",scan_steps(3n,p))
    p : B.Budget & C.ByteWindow <- window(24,0,0,1024,1048576)
    p : B.Budget & C.ByteWindow & S.Scanner & S.Status <- started(start(p))
    p : B.Budget & C.ByteWindow & S.Scanner & S.Status <- need_zero(scan_steps(2n,p))
    discard_pending("drop-pending",p)
    p : B.Budget & C.ByteWindow <- window(24,0,0,1024,1048576)
    p : B.Budget & C.ByteWindow & S.Scanner & S.Status <- started(start(p))
    p : B.Budget & C.ByteWindow & S.Scanner & S.Status <- need_zero(scan_steps(2n,p))
    failure_status("premature-eof-sticky",25,input_ended(p))
    p : B.Budget & C.ByteWindow <- window(24,23,1,1024,1048576)
    p : B.Budget & C.ByteWindow & S.Scanner & S.Status <- started(start(p))
    p : B.Budget & C.ByteWindow & S.Scanner & S.Status <- need_zero(scan_steps(2n,p))
    p : B.Budget & C.ByteWindow & S.Scanner & S.Status <- resume_full(p)
    finished_status("misplaced-window-resume",scan_steps(3n,p))
    p : B.Budget & C.ByteWindow <- window(24,24,0,1024,1048576)
    p : B.Budget & C.ByteWindow & S.Scanner & S.Status <- started(start(p))
    p : B.Budget & C.ByteWindow & S.Scanner & S.Status <- foreign(p)
    failure_status("foreign-source-sticky",23,scan_steps(1n,p))
    p : B.Budget & C.ByteWindow <- window(24,24,0,80,1048576)
    p : B.Budget & C.ByteWindow & S.Scanner & S.Status <- started(start(p))
    work_success(scan_steps(3n,p))
    p : B.Budget & C.ByteWindow <- window(24,24,0,79,1048576)
    p : B.Budget & C.ByteWindow & S.Scanner & S.Status <- started(start(p))
    work_failure(scan_steps(3n,p))
    p : B.Budget & C.ByteWindow <- window(24,24,0,1024,208896)
    p : B.Budget & C.ByteWindow & S.Scanner & S.Status <- started(start(p))
    finished_status("live-exact",scan_steps(3n,p))
    p : B.Budget & C.ByteWindow <- window(24,24,0,1024,208895)
    live_refusal(start(p))
    p : B.Budget & C.ByteWindow <- window(24,24,0,1024,1048576)
    p : B.Budget & C.ByteWindow & S.Scanner & S.Status <- started(start(p))
    refusal("incomplete-copy-refused",p)
    p : B.Budget & C.ByteWindow <- window(24,0,0,1024,1048576)
    p : B.Budget & C.ByteWindow & S.Scanner & S.Status <- started(start(p))
    refusal("failed-copy-refused",input_ended(scan_steps(1n,p)))
    flags()
    partial_headers(23n,1)
    p : B.Budget & C.ByteWindow <- window(24,24,0,129,1048576)
    p : B.Budget & C.ByteWindow & S.Scanner & S.Status <- started(start(p))
    p : B.Budget & C.ByteWindow & Copy.CopyState & Copy.CopyResult <- copier(scan_steps(3n,p))
    p : B.Budget & C.ByteWindow & Copy.CopyState & Copy.CopyResult <- copy_drain(32n,pump(p))
    copy_completed("copy-work-exact-sticky",p)
    p : B.Budget & C.ByteWindow <- window(24,24,0,128,1048576)
    p : B.Budget & C.ByteWindow & S.Scanner & S.Status <- started(start(p))
    p : B.Budget & C.ByteWindow & Copy.CopyState & Copy.CopyResult <- copier(scan_steps(3n,p))
    p : B.Budget & C.ByteWindow & Copy.CopyState & Copy.CopyResult <- copy_drain(32n,pump(p))
    copy_one_less(p)
    p : B.Budget & C.ByteWindow <- window(24,24,0,1024,1048576)
    p : B.Budget & C.ByteWindow & S.Scanner & S.Status <- started(start(p))
    p : B.Budget & C.ByteWindow & Copy.CopyState & Copy.CopyResult <- copier(scan_steps(3n,p))
    drop_reading(p)
    p : B.Budget & C.ByteWindow <- window(24,24,0,1024,1048576)
    p : B.Budget & C.ByteWindow & S.Scanner & S.Status <- started(start(p))
    p : B.Budget & C.ByteWindow & Copy.CopyState & Copy.CopyResult <- copier(scan_steps(3n,p))
    copy_waiting("copy-drop-waiting",False{},pump(p))
    p : B.Budget & C.ByteWindow <- window(24,24,0,1024,1048576)
    p : B.Budget & C.ByteWindow & S.Scanner & S.Status <- started(start(p))
    p : B.Budget & C.ByteWindow & Copy.CopyState & Copy.CopyResult <- copier(scan_steps(3n,p))
    copy_waiting("copy-awaiting-buffer-refused",True{},pump(p))
    p : B.Budget & C.ByteWindow <- window(24,24,0,1024,1048576)
    p : B.Budget & C.ByteWindow & S.Scanner & S.Status <- started(start(p))
    p : B.Budget & C.ByteWindow & Copy.CopyState & Copy.CopyResult <- copier(scan_steps(3n,p))
    nonempty_handback(pump(p))
    p : B.Budget & C.ByteWindow <- window(24,24,0,1024,1048576)
    p : B.Budget & C.ByteWindow & S.Scanner & S.Status <- started(start(p))
    p : B.Budget & C.ByteWindow & Copy.CopyState & Copy.CopyResult <- copier(scan_steps(3n,p))
    copy_foreign(p)
    p : B.Budget & C.ByteWindow <- window(24,24,0,1024,1048576)
    p : B.Budget & C.ByteWindow & S.Scanner & S.Status <- started(start(p))
    p : B.Budget & C.ByteWindow & Copy.CopyState & Copy.CopyResult <- copier(scan_steps(3n,p))
    copy_empty_window(p)
    wrong_run(B.start(1,B.Six{0,0,0,0,1048576,1024}))
    p : B.Budget & C.ByteWindow <- window(24,24,0,1024,1048576)
    p : B.Budget & C.ByteWindow & S.Scanner & S.Status <- started(start(p))
    scanner_release(p)
    p : B.Budget & C.ByteWindow <- window(24,24,0,1024,1048576)
    p : B.Budget & C.ByteWindow & S.Scanner & S.Status <- started(start(p))
    p : B.Budget & C.ByteWindow & Copy.CopyState & Copy.CopyResult <- copier(scan_steps(3n,p))
    copy_release(p)
    p : B.Budget & C.ByteWindow <- window(24,24,0,1024,1048576)
    p : B.Budget & C.ByteWindow & S.Scanner & S.Status <- started(start(p))
    foreign_transition("foreign-before-record-end",1,24,scan_steps(1n,p))
    p : B.Budget & C.ByteWindow <- make_window(H.synthetic(2,1),48,48,0,B.start(1,B.Six{0,0,0,0,1048576,1024}))
    p : B.Budget & C.ByteWindow & S.Scanner & S.Status <- started(start(p))
    foreign_transition("foreign-before-group-end",2,48,scan_steps(3n,p))
    p : B.Budget & C.ByteWindow <- window(24,24,0,1024,1048576)
    p : B.Budget & C.ByteWindow & S.Scanner & S.Status <- started(start(p))
    foreign_transition("foreign-before-complete",3,24,scan_steps(2n,p))
    p : B.Budget & C.ByteWindow <- window(24,24,0,1024,1048576)
    p : B.Budget & C.ByteWindow & S.Scanner & S.Status <- started(start(p))
    foreign_transition("foreign-after-complete",4,24,scan_steps(3n,p))
    p : B.Budget & C.ByteWindow <- window(24,24,0,1024,1048576)
    p : B.Budget & C.ByteWindow & S.Scanner & S.Status <- started(start(p))
    p : B.Budget & C.ByteWindow & Copy.CopyState & Copy.CopyResult <- copier(scan_steps(3n,p))
    p : B.Budget & C.ByteWindow & Copy.CopyState & Copy.CopyResult <- copy_drain(32n,pump(p))
    final_copy_foreign(p)
