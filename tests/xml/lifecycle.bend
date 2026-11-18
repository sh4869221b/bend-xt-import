# Test-only: caller abandonment, sticky failures, retained provisional owners,
# and repeated create/drop with the same invocation budget.
import Base
import ../../core/budget.bend as B
import ../../core/error.bend as E
import ../../core/bytes.bend as Bytes
import ../../core/cursor.bend as C
import ../../xml/types.bend as X
import ../../xml/reader.bend as R
import ./driver.bend as D

def six_equal(a: B.Six, b: B.Six) -> Bool:
  match a b:
    case B.Six{a,b,c,d,e,f} B.Six{g,h,i,j,k,l}: Bool.and(U32.is_eq(a,g),Bool.and(U32.is_eq(b,h),Bool.and(U32.is_eq(c,i),Bool.and(U32.is_eq(d,j),Bool.and(U32.is_eq(e,k),U32.is_eq(f,l))))))

def core_hash(error: Maybe<&2,E.Error>) -> U32:
  match error:
    case None{}: 0
    case Some{E.Bounds{a,b,c}}: D.mix(D.mix(D.mix(1,a),b),c)
    case Some{E.InvalidByte{a}}: D.mix(2,a)
    case Some{E.Overflow{a,b,c}}: D.mix(D.mix(D.mix(3,a),b),c)
    case Some{E.InvalidEncoding{a,b,c}}: D.mix(D.mix(D.mix(4,a),b),c)
    case Some{E.ResourceLimit{a,b,c,d}}: D.mix(D.mix(D.mix(D.mix(5,a),b),c),d)
    case Some{E.Io{a,b,c}}: D.mix(D.mix(D.mix(6,a),b),c)
    case Some{E.Unsupported{a}}: D.mix(7,a)
    case Some{E.SourceChanged{}}: 8
    case Some{E.UnsafeNamespace{a}}: D.mix(9,a)
    case Some{E.ResidualWork{a}}: D.mix(10,a)
    case Some{E.InternalInvariant{a}}: D.mix(11,a)

def position_hash(hash: U32, p: X.Position) -> U32:
  match p:
    case X.Position{a,b,c}: D.mix(D.mix(D.mix(hash,a),b),c)

def source_hash(hash: U32,source: X.SourceKey) -> U32:
  match source:
    case X.SourceKey{run,origin}: D.mix(D.mix(hash,run),origin)

def diagnostic_hash(d: X.Diagnostic) -> U32:
  match d:
    case X.Diagnostic{phase,reason,at,entry,start,expected,observed,core,source}: source_hash(D.mix(D.mix(D.mix(position_hash(D.mix(position_hash(D.mix(phase,reason),at),entry),start),expected),observed),core_hash(core)),source)

def same_budget(used: B.Six, held: B.Six, p: B.Budget & B.Six & B.Six) -> B.Budget & Bool:
  (budget,nowUsed,nowHeld) = p
  (budget,Bool.and(six_equal(used,nowUsed),six_equal(held,nowHeld)))

def retry_finish(expected: U32,p: B.Budget & R.FinishResult) -> B.Budget & Maybe<&1,R.Reader> & Bool:
  (budget,result) = p
  match result:
    case R.FinishFailed{reader,error}: (budget,Some{reader},U32.is_eq(expected,diagnostic_hash(error)))
    case _: (budget,None{},False{})

def finish_reader(expected: U32,budget: B.Budget,reader: Maybe<&1,R.Reader>) -> B.Budget & Maybe<&1,R.Reader> & Bool:
  match reader:
    case Some{reader}: retry_finish(expected,R.finish(budget,reader))
    case None{}: (budget,None{},False{})

def finish_again(expected: U32,budget: B.Budget,reader: Maybe<&1,R.Reader>,okay: Bool) -> B.Budget & Maybe<&1,R.Reader> & Bool:
  match okay:
    case True{}: finish_reader(expected,budget,reader)
    case False{}: (budget,reader,False{})

def retry_twice(expected: U32,p: B.Budget & Maybe<&1,R.Reader> & Bool) -> B.Budget & Maybe<&1,R.Reader> & Bool:
  (budget,reader,okay) = p
  finish_again(expected,budget,reader,okay)

def retry_resumed(expected: U32,p: B.Budget & R.Reader & Bytes.OwnedBytes & U32 & R.ReadResult) -> B.Budget & Maybe<&1,R.Reader> & Maybe<&1,Bytes.OwnedBytes> & Bool:
  (budget,reader,bytes,index,result) = p
  match result:
    case R.ReadFailed{error}: (budget,Some{reader},Some{bytes},U32.is_eq(expected,diagnostic_hash(error)))
    case _: (budget,Some{reader},Some{bytes},False{})

def resume_reader(expected: U32,budget: B.Budget,bytes: Bytes.OwnedBytes,reader: Maybe<&1,R.Reader>) -> B.Budget & Maybe<&1,R.Reader> & Maybe<&1,Bytes.OwnedBytes> & Bool:
  match reader:
    case Some{reader}: retry_resumed(expected,R.resume(budget,reader,C.Range{99,99,99,100},bytes))
    case None{}: (budget,None{},Some{bytes},True{})

def resume_again(expected: U32,budget: B.Budget,bytes: Bytes.OwnedBytes,reader: Maybe<&1,R.Reader>,okay: Bool) -> B.Budget & Maybe<&1,R.Reader> & Maybe<&1,Bytes.OwnedBytes> & Bool:
  match okay:
    case True{}: resume_reader(expected,budget,bytes,reader)
    case False{}: (budget,reader,Some{bytes},False{})

def retry_with_bytes(expected: U32,bytes: Bytes.OwnedBytes,p: B.Budget & Maybe<&1,R.Reader> & Bool) -> B.Budget & Maybe<&1,R.Reader> & Maybe<&1,Bytes.OwnedBytes> & Bool:
  (budget,reader,okay) = p
  resume_again(expected,budget,bytes,reader,okay)

def retry_resume(expected: U32,bytes: Maybe<&1,Bytes.OwnedBytes>,p: B.Budget & Maybe<&1,R.Reader> & Bool) -> B.Budget & Maybe<&1,R.Reader> & Maybe<&1,Bytes.OwnedBytes> & Bool:
  match bytes:
    case Some{bytes}: retry_with_bytes(expected,bytes,p)
    case None{}:
      (budget,reader,okay) = p
      (budget,reader,None{},okay)

def retry_progress(p: D.Progress,valid: Bool) -> D.Progress:
  match valid:
    case True{}: p
    case False{}: D.fatal(p)

def retry_checked(reader: Maybe<&1,R.Reader>,bytes: Maybe<&1,Bytes.OwnedBytes>,rest: String,p: D.Progress,okay: Bool,pair: B.Budget & Bool) -> D.Harness:
  (budget,same) = pair
  D.Harness{budget,reader,bytes,None{},None{},None{},rest,retry_progress(p,Bool.and(okay,same))}

def retry_compared(used: B.Six,held: B.Six,rest: String,p: D.Progress,pair: B.Budget & Maybe<&1,R.Reader> & Maybe<&1,Bytes.OwnedBytes> & Bool) -> D.Harness:
  (budget,reader,bytes,okay) = pair
  retry_checked(reader,bytes,rest,p,okay,same_budget(used,held,B.inspect(budget)))

def retry_inspected(reader: R.Reader,bytes: Maybe<&1,Bytes.OwnedBytes>,rest: String,p: D.Progress,error: X.Diagnostic,pair: B.Budget & B.Six & B.Six) -> D.Harness:
  (budget,used,held) = pair
  +expected = {diagnostic_hash(error): U32}
  retry_compared(used,held,rest,p,retry_resume(expected,bytes,retry_twice(expected,retry_finish(expected,R.finish(budget,reader)))))

# One held entry remains live while a following entry is parsed and discarded.
type State is Type:
  State{harness: D.Harness, held: Maybe<&1,R.ProvisionalEntry>, stopped: Bool, checked: Bool}

def from_step(held: Maybe<&1,R.ProvisionalEntry>,checked: Bool,result: D.Running) -> State:
  match result:
    case D.Run{harness}: State{harness,held,False{},checked}
    case D.Stop{harness}: State{harness,held,True{},checked}

def alter_phase(harness: D.Harness,value: U32) -> D.Harness:
  match harness:
    case D.Harness{budget,reader,bytes,entry,document,residual,rest,p}: D.Harness{budget,reader,bytes,entry,document,residual,rest,D.set_phase(p,value)}

def abandon_checked(harness: D.Harness,held: Maybe<&1,R.ProvisionalEntry>,checked: Bool,abandon: Bool) -> State:
  match abandon:
    case True{}: from_step(held,True{},D.step(alter_phase(harness,80)))
    case False{}: from_step(held,checked,D.step(harness))

def retry_owned(bytes: Maybe<&1,Bytes.OwnedBytes>,rest: String,p: D.Progress,error: X.Diagnostic,pair: B.Budget & Maybe<&1,R.Reader>) -> D.Harness:
  (budget,reader) = pair
  match reader:
    case Some{reader}: retry_inspected(reader,bytes,rest,p,error,B.inspect(budget))
    case None{}: D.Harness{budget,None{},bytes,None{},None{},None{},rest,D.fatal(p)}

def retry_error(budget: B.Budget,reader: Maybe<&1,R.Reader>,bytes: Maybe<&1,Bytes.OwnedBytes>,rest: String,p: D.Progress,error: Maybe<&2,X.Diagnostic>) -> D.Harness:
  match error:
    case Some{error}: retry_owned(bytes,rest,p,error,(budget,reader))
    case None{}: D.Harness{budget,reader,bytes,None{},None{},None{},rest,D.fatal(p)}

def retry_harness(harness: D.Harness) -> D.Harness:
  match harness:
    case D.Harness{budget,reader,bytes,entry,document,residual,rest,+p}: retry_error(budget,reader,bytes,rest,p,D.get_error(p))

def failed_checked(harness: D.Harness,held: Maybe<&1,R.ProvisionalEntry>,checked: Bool) -> State:
  match checked:
    case False{}: State{retry_harness(harness),held,False{},True{}}
    case True{}: from_step(held,checked,D.step(harness))

def retain_harness(harness: D.Harness,checked: Bool) -> State:
  match harness:
    case D.Harness{budget,reader,bytes,entry,document,residual,rest,+p}: State{D.Harness{budget,reader,bytes,None{},document,residual,rest,D.set_phase(D.set_count(p,1),D.get_after(p))},entry,False{},checked}

def retain_first(harness: D.Harness,checked: Bool,held: Maybe<&1,R.ProvisionalEntry>) -> State:
  match held:
    case None{}: retain_harness(harness,checked)
    case Some{held}: from_step(Some{held},checked,D.step(harness))

def retain_checked(harness: D.Harness,held: Maybe<&1,R.ProvisionalEntry>,checked: Bool,retain: Bool) -> State:
  match retain:
    case False{}: from_step(held,checked,D.step(harness))
    case True{}: retain_first(harness,checked,held)

def dispatch_entry(+mode: U32,held: Maybe<&1,R.ProvisionalEntry>,checked: Bool,harness: D.Harness,p: D.Progress,isEntry: Bool) -> State:
  match isEntry:
    case True{}: retain_checked(harness,held,checked,Bool.and(Bool.or(U32.is_eq(mode,2),U32.is_eq(mode,5)),U32.is_eq(D.get_count(p),0)))
    case False{}: from_step(held,checked,D.step(harness))

def dispatch_start(+mode: U32,cut: U32,held: Maybe<&1,R.ProvisionalEntry>,checked: Bool,harness: D.Harness,p: D.Progress,phase: U32,isStart: Bool) -> State:
  match isStart:
    case True{}: abandon_checked(harness,held,checked,Bool.and(Bool.or(U32.is_eq(mode,1),U32.is_eq(mode,5)),U32.is_ge(D.get_start(p),cut)))
    case False{}: dispatch_entry(mode,held,checked,harness,p,U32.is_eq(phase,30))

def dispatch_error(mode: U32,cut: U32,held: Maybe<&1,R.ProvisionalEntry>,checked: Bool,harness: D.Harness,p: D.Progress,+phase: U32,isError: Bool) -> State:
  match isError:
    case True{}: failed_checked(harness,held,checked)
    case False{}: dispatch_start(mode,cut,held,checked,harness,p,phase,U32.is_eq(phase,0))

def dispatch_phase(mode: U32,cut: U32,held: Maybe<&1,R.ProvisionalEntry>,checked: Bool,harness: D.Harness,p: D.Progress,+phase: U32) -> State:
  dispatch_error(mode,cut,held,checked,harness,p,phase,U32.is_eq(phase,80))

def inspect_phase(mode: U32,cut: U32,held: Maybe<&1,R.ProvisionalEntry>,checked: Bool,harness: D.Harness) -> State:
  match harness:
    case D.Harness{budget,reader,bytes,entry,document,residual,rest,+p}: dispatch_phase(mode,cut,held,checked,D.Harness{budget,reader,bytes,entry,document,residual,rest,p},p,D.get_phase(p))

def loop(fuel: Nat,+mode: U32,+cut: U32,state: State) -> State:
  match fuel:
    case 0n: state
    case 1n+left:
      match state:
        case State{harness,held,True{},checked}: State{harness,held,True{},checked}
        case State{harness,held,False{},checked}: loop(left,mode,cut,inspect_phase(mode,cut,held,checked,harness))

def budget_done(okay: Bool,result: Result<&1,&2,E.Error & B.Budget,B.Six>) -> Bool:
  match result:
    case Done{B.Six{input,inflate,output,logical,0,work}}: okay
    case _: False{}

def held_dropped(okay: Bool,p: B.Budget & Maybe<&1,R.ProvisionalEntry> & Maybe<&2,E.Error>) -> Bool:
  (budget,entry,error) = p
  match entry error:
    case None{} None{}: budget_done(okay,B.finish(budget))
    case _ _: False{}

def retained_value(index: U32) -> U32:
  match index:
    case 0: 65
    case 1: 26085
    case 2: 10
    case 3: 38
    case 4: 120
    case 5: 128512
    case _: 10

def retained_scalar(+index: U32,okay: Bool,p: B.Budget & R.ProvisionalEntry & Result<&2,&2,E.Error,Maybe<&2,U32>>) -> B.Budget & R.ProvisionalEntry & Bool:
  (budget,entry,result) = p
  match result:
    case Done{Some{value}}: (budget,entry,Bool.and(okay,Bool.and(U32.is_lt(index,7),U32.is_eq(value,retained_value(index)))))
    case Done{None{}}: (budget,entry,Bool.and(okay,U32.is_eq(index,7)))
    case Fail{error}: (budget,entry,False{})

def retained_loop(fuel: Nat,+index: U32,p: B.Budget & R.ProvisionalEntry & Bool) -> Bool:
  match fuel:
    case 0n:
      (budget,entry,okay) = p
      held_dropped(okay,R.drop_entry(budget,entry))
    case 1n+left:
      (budget,entry,okay) = p
      retained_loop(left,U32.inc(index),retained_scalar(index,okay,R.entry_next(budget,entry)))

def expected_source(source: X.SourceKey) -> Bool:
  match source:
    case X.SourceKey{run,origin}: Bool.and(U32.is_eq(run,1),U32.is_eq(origin,42))

def retained_meta(meta: X.EntryMeta) -> Bool:
  match meta:
    case X.EntryMeta{source,number,span,list,partial,sid,rec,identity,edid,src,dest,fuz}: Bool.and(expected_source(source),Bool.and(U32.is_eq(number,1),U32.is_eq(list,0)))

def retained_checked(budget: B.Budget,okay: Bool,p: R.ProvisionalEntry & X.EntryMeta) -> Bool:
  (entry,meta) = p
  retained_loop(8n,0,(budget,entry,Bool.and(okay,retained_meta(meta))))

def retained_cleanup(budget: B.Budget,entry: R.ProvisionalEntry,okay: Bool,verify: Bool) -> Bool:
  match verify:
    case True{}: retained_checked(budget,okay,R.entry_metadata(entry))
    case False{}: held_dropped(False{},R.drop_entry(budget,entry))

def cleanup_held(+mode: U32,budget: B.Budget,held: Maybe<&1,R.ProvisionalEntry>,okay: Bool) -> Bool:
  match held:
    case None{}: budget_done(Bool.and(okay,Bool.not(Bool.or(U32.is_eq(mode,2),U32.is_eq(mode,5)))),B.finish(budget))
    case Some{entry}: retained_cleanup(budget,entry,okay,Bool.or(U32.is_eq(mode,2),U32.is_eq(mode,5)))

def at_position(actual: X.Position,byte: U32,line: U32,column: U32) -> Bool:
  match actual:
    case X.Position{a,b,c}: Bool.and(U32.is_eq(a,byte),Bool.and(U32.is_eq(b,line),U32.is_eq(c,column)))

def eof_core(core: E.Error) -> Bool:
  match core:
    case E.ResourceLimit{dim,limit,used,request}: Bool.and(U32.is_eq(dim,5),Bool.and(U32.is_eq(limit,9099),Bool.and(U32.is_eq(used,9099),U32.is_eq(request,1))))
    case _: False{}

def core_failure(core: Maybe<&2,E.Error>) -> Bool:
  match core:
    case Some{error}: eof_core(error)
    case None{}: False{}

def no_core(core: Maybe<&2,E.Error>) -> Bool:
  match core:
    case Some{error}: False{}
    case None{}: True{}

def eof_refusal_value(error: X.Diagnostic) -> Bool:
  match error:
    case X.Diagnostic{phase,reason,at,entry,start,expected,observed,core,source}: Bool.and(U32.is_eq(phase,4),Bool.and(U32.is_eq(reason,3),Bool.and(at_position(at,178,1,179),Bool.and(U32.is_eq(entry,1),Bool.and(at_position(start,118,1,119),Bool.and(U32.is_eq(expected,0),Bool.and(U32.is_eq(observed,0),Bool.and(core_failure(core),expected_source(source)))))))))

def eof_neighbor_value(error: X.Diagnostic) -> Bool:
  match error:
    case X.Diagnostic{phase,reason,at,entry,start,expected,observed,core,source}: Bool.and(U32.is_eq(phase,2),Bool.and(U32.is_eq(reason,6),Bool.and(at_position(at,179,2,1),Bool.and(U32.is_eq(entry,1),Bool.and(at_position(start,118,1,119),Bool.and(U32.is_eq(expected,0),Bool.and(U32.is_eq(observed,0),Bool.and(no_core(core),expected_source(source)))))))))

def eof_error(error: Maybe<&2,X.Diagnostic>) -> Bool:
  match error:
    case Some{error}: eof_refusal_value(error)
    case None{}: False{}

def eof_neighbor(error: Maybe<&2,X.Diagnostic>) -> Bool:
  match error:
    case Some{error}: eof_neighbor_value(error)
    case None{}: False{}

def expected_error(error: Maybe<&2,X.Diagnostic>,wanted: Bool) -> Bool:
  match error:
    case None{}: Bool.not(wanted)
    case Some{e}: wanted

def outcome(count: U32,error: Maybe<&2,X.Diagnostic>,checked: Bool,mode: U32) -> Bool:
  match mode:
    case 0: Bool.and(checked,expected_error(error,True{}))
    case 1: Bool.and(checked,expected_error(error,False{}))
    case 2: Bool.and(U32.is_eq(count,2),expected_error(error,False{}))
    case 3: Bool.and(checked,eof_error(error))
    case 4: Bool.and(checked,eof_neighbor(error))
    case 5: Bool.and(checked,Bool.and(U32.is_eq(count,1),expected_error(error,False{})))
    case _: False{}

def finished(+mode: U32,state: State) -> Bool:
  match state:
    case State{D.Harness{budget,None{},None{},None{},None{},None{},rest,D.Progress{length,size,start,end,fill,digest,count,9,after,error}},held,True{},checked}:
      cleanup_held(mode,budget,held,outcome(count,error,checked,mode))
    case _: False{}

def begun(hex: String,+mode: U32,cut: U32,+p: D.Progress,pair: B.Budget & R.BeginResult) -> Bool:
  (budget,result) = pair
  match result:
    case R.ReaderReady{reader}: finished(mode,loop(U32.to_nat(U32.add(U32.mul(D.get_length(p),8),1000)),mode,cut,State{D.Harness{budget,Some{reader},None{},None{},None{},None{},hex,p},None{},False{},False{}}))
    case R.ReaderInitFailed{error,residual}: finished(mode,loop(100n,mode,cut,State{D.Harness{budget,residual,None{},None{},None{},None{},hex,D.reject(p,error)},None{},False{},False{}}))

def charged(hex: String,mode: U32,cut: U32,+p: D.Progress,pair: B.Budget & Result<&2,&2,E.Error,Unit>) -> Bool:
  (budget,result) = pair
  match result:
    case Done{u}: begun(hex,mode,cut,p,R.begin(budget,C.Range{1,42,0,D.get_length(p)},X.defaults()))
    case _: False{}

def started(hex: String,mode: U32,cut: U32,+length: U32,result: Result<&2,&1,E.Error,B.Budget>) -> Bool:
  match result:
    case Done{budget}: charged(hex,mode,cut,D.Progress{length,1,0,0,0,2166136261,0,0,0,None{}},B.consume(budget,B.Six{length,0,0,0,0,0}))
    case _: False{}

def run(+hex: String,mode: U32,cut: U32) -> Bool:
  started(hex,mode,cut,U32.div(U32.from_nat(String.length(hex)),2),B.start(1,D.budget_defaults()))

def work_refusal(+hex: String) -> Bool:
  started(hex,3,0,U32.div(U32.from_nat(String.length(hex)),2),B.start(1,B.Six{67108864,0,0,536870912,268435456,9099}))

def work_neighbor(+hex: String) -> Bool:
  started(hex,4,0,U32.div(U32.from_nat(String.length(hex)),2),B.start(1,B.Six{67108864,0,0,536870912,268435456,9100}))

def cuts(fuel: Nat,+hex: String,+cut: U32,okay: Bool) -> Bool:
  match fuel:
    case 0n: okay
    case 1n+left: cuts(left,hex,U32.inc(cut),Bool.and(okay,run(hex,1,cut)))

def reused_drop(p: B.Budget & Maybe<&1,R.Reader> & Maybe<&2,E.Error>) -> B.Budget & Bool:
  (budget,reader,error) = p
  match reader error:
    case None{} None{}: (budget,True{})
    case _ _: (budget,False{})

def reused_begin(p: B.Budget & R.BeginResult) -> B.Budget & Bool:
  (budget,result) = p
  match result:
    case R.ReaderReady{reader}: reused_drop(R.drop(budget,reader))
    case _: (budget,False{})

def reuse(fuel: Nat,p: B.Budget & Bool) -> Bool:
  match fuel:
    case 0n:
      (budget,okay) = p
      budget_done(okay,B.finish(budget))
    case 1n+left:
      (budget,okay) = p
      match okay:
        case False{}: False{}
        case True{}: reuse(left,reused_begin(R.begin(budget,C.Range{1,42,0,0},X.defaults())))

def reuse_start(result: Result<&2,&1,E.Error,B.Budget>) -> Bool:
  match result:
    case Done{budget}: reuse(1000n,(budget,True{}))
    case _: False{}

def report(okay: Bool) -> IO(Unit):
  match okay:
    case True{}: IO.print("lifecycle-balanced")
    case False{}: IO.die(Unit,70,"lifecycle invariant or owner balance failed")

def main() -> IO(Unit):
  report(Bool.and(Bool.and(work_refusal("3c535354584d4c526573736f75726365733e3c506172616d733e3c4164646f6e3e412e6573703c2f4164646f6e3e3c536f757263653e656e3c2f536f757263653e3c446573743e6a613c2f446573743e3c56657273696f6e3e323c2f56657273696f6e3e3c2f506172616d733e3c436f6e74656e743e3c537472696e67204c6973743d2230223e3c454449443e413c2f454449443e3c5245433e574541503a46554c4c3c2f5245433e3c536f757263653e580d"),work_neighbor("3c535354584d4c526573736f75726365733e3c506172616d733e3c4164646f6e3e412e6573703c2f4164646f6e3e3c536f757263653e656e3c2f536f757263653e3c446573743e6a613c2f446573743e3c56657273696f6e3e323c2f56657273696f6e3e3c2f506172616d733e3c436f6e74656e743e3c537472696e67204c6973743d2230223e3c454449443e413c2f454449443e3c5245433e574541503a46554c4c3c2f5245433e3c536f757263653e580d")),Bool.and(reuse_start(B.start(1,D.budget_defaults())),Bool.and(cuts(392n,"efbbbf3c535354584d4c526573736f75726365733e3c506172616d733e3c4164646f6e3e412e6573703c2f4164646f6e3e3c536f757263653e656e3c2f536f757263653e3c446573743e6a613c2f446573743e3c56657273696f6e3e323c2f56657273696f6e3e3c2f506172616d733e3c436f6e74656e743e3c537472696e67204c6973743d2230223e3c454449443e413c2f454449443e3c5245433e574541503a46554c4c3c2f5245433e3c536f757263653ee697a50d0a26616d703b3c215b43444154415b785d5d3e3c212d2d782d2d3ef09f98800d3c2f536f757263653e3c446573742f3e3c2f537472696e673e3c537472696e67204c6973743d2230223e3c454449443e413c2f454449443e3c5245433e574541503a46554c4c3c2f5245433e3c536f757263653ee697a50d0a26616d703b3c215b43444154415b785d5d3e3c212d2d782d2d3ef09f98800d3c2f536f757263653e3c446573742f3e3c2f537472696e673e3c2f436f6e74656e743e3c2f535354584d4c526573736f75726365733e0d",0,True{}),Bool.and(Bool.and(run("efbbbf3c535354584d4c526573736f75726365733e3c506172616d733e3c4164646f6e3e412e6573703c2f4164646f6e3e3c536f757263653e656e3c2f536f757263653e3c446573743e6a613c2f446573743e3c56657273696f6e3e323c2f56657273696f6e3e3c2f506172616d733e3c436f6e74656e743e3c537472696e67204c6973743d2230223e3c454449443e413c2f454449443e3c5245433e574541503a46554c4c3c2f5245433e3c536f757263653ee697a50d0a26616d703b3c215b43444154415b785d5d3e3c212d2d782d2d3ef09f98800d3c2f536f757263653e3c446573742f3e3c2f537472696e673e3c537472696e67204c6973743d2230223e3c454449443e423c2f454449443e3c5245433e574541503a46554c4c3c2f5245433e3c536f757263653e5a3c2f536f757263653e3c446573743e513c2f446573743e3c2f537472696e673e3c2f436f6e74656e743e3c2f535354584d4c526573736f75726365733e0d",2,0),run("efbbbf3c535354584d4c526573736f75726365733e3c506172616d733e3c4164646f6e3e412e6573703c2f4164646f6e3e3c536f757263653e656e3c2f536f757263653e3c446573743e6a613c2f446573743e3c56657273696f6e3e323c2f56657273696f6e3e3c2f506172616d733e3c436f6e74656e743e3c537472696e67204c6973743d2230223e3c454449443e413c2f454449443e3c5245433e574541503a46554c4c3c2f5245433e3c536f757263653ee697a50d0a26616d703b3c215b43444154415b785d5d3e3c212d2d782d2d3ef09f98800d3c2f536f757263653e3c446573742f3e3c2f537472696e673e3c537472696e67204c6973743d2230223e3c454449443e423c2f454449443e3c5245433e574541503a46554c4c3c2f5245433e3c536f757263653e5a3c2f536f757263653e3c446573743e513c2f446573743e3c2f537472696e673e3c2f436f6e74656e743e3c2f535354584d4c526573736f75726365733e0d",5,241)),Bool.and(run("3c535354584d4c526573736f75726365733e3c506172616d733e3c4164646f6e3e412e6573703c2f4164646f6e3e3c536f757263653e656e3c2f536f757263653e3c446573743e6a613c2f446573743e3c56657273696f6e3e323c2f56657273696f6e3e3c2f506172616d733e3c436f6e74656e743e3c537472696e67204c6973743d2230223e3c454449443e413c2f454449443e3c5245433e574541503a46554c4c3c2f5245433e3c536f757263653e26616d70",0,0),Bool.and(run("3c535354584d4c526573736f75726365733e3c506172616d733e3c4164646f6e3e412e6573703c2f4164646f6e3e3c536f757263653e656e3c2f536f757263653e3c446573743e6a613c2f446573743e3c56657273696f6e3e323c2f56657273696f6e3e3c2f506172616d733e3c436f6e74656e743e3c537472696e67204c6973743d2230223e3c454449443e413c2f454449443e3c5245433e574541503a46554c4c3c2f5245433e3c536f757263653e3c212d2d78",0,0),Bool.and(run("3c535354584d4c526573736f75726365733e3c506172616d733e3c4164646f6e3e412e6573703c2f4164646f6e3e3c536f757263653e656e3c2f536f757263653e3c446573743e6a613c2f446573743e3c56657273696f6e3e323c2f56657273696f6e3e3c2f506172616d733e3c436f6e74656e743e3c537472696e67204c6973743d2230223e3c454449443e413c2f454449443e3c5245433e574541503a46554c4c3c2f5245433e3c536f757263653e3c215b43444154415b78",0,0),Bool.and(run("3c535354584d4c526573736f75726365733e3c506172616d733e3c4164646f6e3e412e6573703c2f4164646f6e3e3c536f757263653e656e3c2f536f757263653e3c446573743e6a613c2f446573743e3c56657273696f6e3e323c2f56657273696f6e3e3c2f506172616d733e3c436f6e74656e743e3c537472696e67204c6973743d2230223e3c454449443e413c2f454449443e3c5245433e574541503a46554c4c3c2f5245433e3c536f757263653e6162630d",0,0),Bool.and(run("3c535354584d4c526573736f75726365733e3c506172616d733e3c4164646f6e3e412e6573703c2f4164646f6e3e3c536f757263653e656e3c2f536f757263653e3c446573743e6a613c2f446573743e3c56657273696f6e3e323c2f56657273696f6e3e3c2f506172616d733e3c436f6e74656e743e3c537472696e67204c6973743d2230223e3c454449443e413c2f454449443e3c5245433e574541503a46554c4c3c2f5245433e3c536f757263653e3c",0,0),Bool.and(run("3c535354584d4c526573736f75726365733e3c506172616d733e3c4164646f6e3e412e6573703c2f4164646f6e3e3c536f757263653e656e3c2f536f757263653e3c446573743e6a613c2f446573743e3c56657273696f6e3e323c2f56657273696f6e3e3c2f506172616d733e3c436f6e74656e743e3c537472696e67204c6973743d2230223e3c454449443e413c2f454449443e3c5245433e574541503a46554c4c3c2f5245433e3c536f757263653e26626f6775733b",0,0),Bool.and(run("3c535354584d4c526573736f75726365733e3c506172616d733e3c4164646f6e3e412e6573703c2f4164646f6e3e3c536f757263653e656e3c2f536f757263653e3c446573743e6a613c2f446573743e3c56657273696f6e3e323c2f56657273696f6e3e3c2f506172616d733e3c436f6e74656e743ef09f",0,0),Bool.and(run("3c6261642f3e",0,0),Bool.and(run("efbbbf3c535354584d4c526573736f75726365733e3c506172616d733e3c4164646f6e3e412e6573703c2f4164646f6e3e3c536f757263653e656e3c2f536f757263653e3c446573743e6a613c2f446573743e3c56657273696f6e3e323c2f56657273696f6e3e3c2f506172616d733e3c436f6e74656e743e3c537472696e67204c6973743d2230223e3c454449443e413c2f454449443e3c5245433e574541503a46554c4c3c2f5245433e3c536f757263653ee697a50d0a26616d703b3c215b43444154415b785d5d3e3c212d2d782d2d3ef09f98800d3c2f536f757263653e3c446573742f3e3c2f537472696e673e3c537472696e67204c6973743d2230223e3c454449443e413c2f454449443e3c5245433e574541503a46554c4c3c2f5245433e3c536f757263653ee697a50d0a26616d703b3c215b43444154415b785d5d3e3c212d2d782d2d3ef09f98800d3c2f536f757263653e3c446573742f3e3c2f537472696e673e3c2f436f6e74656e743e3c2f535354584d4c526573736f75726365733e0d78",0,0),True{}))))))))))))))
