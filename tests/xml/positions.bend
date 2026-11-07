# Independent, literal original-source position assertions. No parser-produced
# coordinates generate the expectations. See positions-golden.json for bytes.
# Reuse only the test adapter's affine ownership and chunk scheduling, not its
# digest, to decide whether metadata is correct.
import Base
import ../../core/budget.bend as B
import ../../core/error.bend as E
import ../../core/bytes.bend as Bytes
import ../../core/cursor.bend as C
import ../../xml/types.bend as X
import ../../xml/numbers.bend as N
import ../../xml/reader.bend as R
import ./driver.bend as D

def position(actual: X.Position, byte: U32, line: U32, column: U32) -> Bool:
  match actual:
    case X.Position{b,l,c}: Bool.and(U32.is_eq(b,byte),Bool.and(U32.is_eq(l,line),U32.is_eq(c,column)))

def span(actual: X.Span, a: U32, b: U32, c: U32, d: U32, e: U32, f: U32) -> Bool:
  match actual:
    case X.Span{start,end}: Bool.and(position(start,a,b,c),position(end,d,e,f))

def source(actual: X.SourceKey) -> Bool:
  match actual:
    case X.SourceKey{run,origin}: Bool.and(U32.is_eq(run,1),U32.is_eq(origin,42))

def field(actual: X.FieldRef, start: U32, length: U32, bytes: U32, a: U32, b: U32, c: U32, d: U32, e: U32, f: U32) -> Bool:
  match actual:
    case X.FieldRef{present,s,n,w,element}: Bool.and(present,Bool.and(U32.is_eq(s,start),Bool.and(U32.is_eq(n,length),Bool.and(U32.is_eq(w,bytes),span(element,a,b,c,d,e,f)))))

def fuz(actual: X.Fuz, id: U32, count: U32, a: U32, b: U32, c: U32, d: U32, e: U32, f: U32) -> Bool:
  match actual:
    case X.Fuz{present,i,n,element}: Bool.and(present,Bool.and(U32.is_eq(i,id),Bool.and(U32.is_eq(n,count),span(element,a,b,c,d,e,f))))

def absent_fuz(actual: X.Fuz) -> Bool:
  match actual:
    case X.Fuz{False{},0,0,element}: span(element,0,1,1,0,1,1)
    case _: False{}

def entry_one(meta: X.EntryMeta) -> Bool:
  match meta:
    case X.EntryMeta{key,number,element,list,p,s,r,i,edid,src,dest,f}:
      Bool.and(source(key),Bool.and(U32.is_eq(number,1),Bool.and(span(element,155,6,1,384,11,53),Bool.and(field(edid,0,3,3,172,6,18,193,6,39),Bool.and(field(src,3,7,12,215,7,1,265,8,20),Bool.and(field(dest,10,4,8,266,9,1,313,10,16),fuz(f,7,1,313,10,16,375,11,44)))))))

def entry_two(meta: X.EntryMeta) -> Bool:
  match meta:
    case X.EntryMeta{key,number,element,list,p,s,r,i,edid,src,dest,f}:
      Bool.and(source(key),Bool.and(U32.is_eq(number,2),Bool.and(span(element,385,12,1,473,12,89),Bool.and(field(edid,0,5,5,409,12,25,427,12,43),Bool.and(field(src,5,0,0,427,12,43,444,12,60),Bool.and(field(dest,0,0,0,402,12,18,409,12,25),absent_fuz(f)))))))

def entry_no_bom(meta: X.EntryMeta) -> Bool:
  match meta:
    case X.EntryMeta{key,number,element,list,p,s,r,i,edid,src,dest,f}:
      Bool.and(source(key),Bool.and(U32.is_eq(number,1),Bool.and(span(element,42,2,28,207,3,128),Bool.and(field(edid,4,2,2,132,3,53,147,3,68),Bool.and(field(src,0,2,2,59,2,45,90,3,14),Bool.and(field(dest,2,2,5,90,3,14,112,3,33),fuz(f,0,1,147,3,68,198,3,119)))))))

def entry_case(fixture: U32, count: U32, meta: X.EntryMeta) -> Bool:
  match fixture count:
    case 0 _: True{}
    case 1 0: entry_one(meta)
    case 1 1: entry_two(meta)
    case 2 0: entry_no_bom(meta)
    case _ _: False{}

def params_one(meta: X.ParamsMeta, count: U32) -> Bool:
  match meta:
    case X.ParamsMeta{key,addon,src,dest,element}:
      Bool.and(source(key),Bool.and(U32.is_eq(count,2),Bool.and(span(element,46,3,1,143,4,64),Bool.and(field(addon,0,6,10,54,3,9,79,3,30),Bool.and(field(src,6,2,2,80,4,1,99,4,20),field(dest,8,2,2,99,4,20,114,4,35))))))

def params_no_bom(meta: X.ParamsMeta, count: U32) -> Bool:
  match meta:
    case X.ParamsMeta{key,addon,src,dest,element}:
      Bool.and(source(key),Bool.and(U32.is_eq(count,1),Bool.and(span(element,219,4,1,317,4,97),Bool.and(field(addon,1,7,7,263,4,43,289,4,69),Bool.and(field(src,8,2,2,289,4,69,308,4,88),field(dest,0,1,3,247,4,29,263,4,43))))))

def params_case(fixture: U32, meta: X.ParamsMeta, count: U32) -> Bool:
  match fixture:
    case 0: True{}
    case 1: params_one(meta,count)
    case 2: params_no_bom(meta,count)
    case _: False{}

# Failure still drops every owner and finishes the budget. Test-only phase 6
# identifies metadata assertion failure, never a production parsing diagnostic.
def bad(p: D.Progress, reason: U32) -> D.Progress:
  D.reject(p,X.error(6,reason,X.zero_position(),0,0))

def entry_verified(budget: B.Budget, reader: Maybe<&1,R.Reader>, bytes: Maybe<&1,Bytes.OwnedBytes>, entry: R.ProvisionalEntry, rest: String, p: D.Progress, meta: X.EntryMeta, okay: Bool) -> D.Harness:
  match okay:
    case True{}: D.entry_metadata(budget,reader,bytes,rest,p,(entry,meta))
    case False{}: D.Harness{budget,reader,bytes,Some{entry},None{},None{},rest,D.set_phase(D.set_after(bad(p,1),80),32)}

def entry_seen(fixture: U32, budget: B.Budget, reader: Maybe<&1,R.Reader>, bytes: Maybe<&1,Bytes.OwnedBytes>, rest: String, +p: D.Progress, pair: R.ProvisionalEntry & X.EntryMeta) -> D.Running:
  (entry,+meta) = pair
  D.Run{entry_verified(budget,reader,bytes,entry,rest,p,meta,entry_case(fixture,D.get_count(p),meta))}

def entry_phase(fixture: U32, budget: B.Budget, reader: Maybe<&1,R.Reader>, bytes: Maybe<&1,Bytes.OwnedBytes>, entry: R.ProvisionalEntry, rest: String, p: D.Progress, check: Bool) -> D.Running:
  match check:
    case True{}: entry_seen(fixture,budget,reader,bytes,rest,p,R.entry_metadata(entry))
    case False{}: D.step(D.Harness{budget,reader,bytes,Some{entry},None{},None{},rest,p})

def params_verified(budget: B.Budget, document: R.ValidatedDocument, rest: String, p: D.Progress, meta: X.ParamsMeta, count: U32, okay: Bool) -> D.Harness:
  match okay:
    case True{}: D.document_metadata(budget,rest,p,(document,meta,count))
    case False{}: D.Harness{budget,None{},None{},None{},Some{document},None{},rest,D.set_phase(bad(p,2),42)}

def params_seen(fixture: U32, budget: B.Budget, rest: String, p: D.Progress, pair: R.ValidatedDocument & X.ParamsMeta & U32) -> D.Running:
  (document,+meta,count0) = pair
  +count = {count0: U32}
  D.Run{params_verified(budget,document,rest,p,meta,count,params_case(fixture,meta,count))}

def params_phase(fixture: U32, budget: B.Budget, document: R.ValidatedDocument, rest: String, p: D.Progress, check: Bool) -> D.Running:
  match check:
    case True{}: params_seen(fixture,budget,rest,p,R.document_metadata(document))
    case False{}: D.step(D.Harness{budget,None{},None{},None{},Some{document},None{},rest,p})

# Fixture modes 3/4 use a second public source identity. Mode 4 deliberately
# supplies that root to a different budget run to exercise Input init failure.
def run(fixture: U32) -> U32:
  match fixture:
    case 3: 7
    case 4: 7
    case _: 1

def origin(fixture: U32) -> U32:
  match fixture:
    case 3: 43
    case 4: 43
    case _: 42

def budget_run(fixture: U32) -> U32:
  match fixture:
    case 3: 7
    case _: 1

def input_phase(+fixture: U32, budget: B.Budget, reader: R.Reader, bytes: Bytes.OwnedBytes, rest: String, +p: D.Progress, resume: Bool) -> D.Running:
  match resume:
    case True{}: D.Run{D.resumed(rest,p,R.resume(budget,reader,C.Range{run(fixture),origin(fixture),D.get_start(p),D.get_end(p)},bytes))}
    case False{}: D.step(D.Harness{budget,Some{reader},Some{bytes},None{},None{},None{},rest,p})

def step(fixture: U32, harness: D.Harness) -> D.Running:
  match harness:
    case D.Harness{budget,reader,bytes,Some{entry},None{},None{},rest,+p}: entry_phase(fixture,budget,reader,bytes,entry,rest,p,U32.is_eq(D.get_phase(p),30))
    case D.Harness{budget,None{},None{},None{},Some{document},None{},rest,+p}: params_phase(fixture,budget,document,rest,p,U32.is_eq(D.get_phase(p),40))
    case D.Harness{budget,Some{reader},Some{bytes},None{},None{},None{},rest,+p}: input_phase(fixture,budget,reader,bytes,rest,p,U32.is_eq(D.get_phase(p),2))
    case other: D.step(other)

def loop(+fixture: U32, fuel: Nat, running: D.Running) -> D.Harness:
  match fuel running:
    case _ D.Stop{harness}: harness
    case 0n D.Run{harness}: harness
    case 1n+left D.Run{harness}: loop(fixture,left,step(fixture,harness))

def diagnostic_source(+fixture: U32, source: X.SourceKey) -> Bool:
  match source:
    case X.SourceKey{r,o}: Bool.and(U32.is_eq(r,run(fixture)),U32.is_eq(o,origin(fixture)))

# Literal entry starts for the reference and live-neighbor fixtures. Errors
# outside an admitted String must retain the zero-entry sentinel position.
def diagnostic_start(entry: U32, at: X.Position, start: X.Position) -> Bool:
  match entry at:
    case 0 _: position(start,0,1,1)
    case 1 X.Position{190,l,c}: position(start,123,2,1)
    case 1 X.Position{133,l,c}: position(start,119,2,1)
    case 1 X.Position{184,l,c}: position(start,122,2,1)
    case 1 X.Position{201,l,c}: position(start,118,1,119)
    case _ _: False{}

def diagnostic_checked(p: D.Progress, okay: Bool) -> D.Progress:
  match okay:
    case True{}: p
    case False{}: D.set_error(p,Some{X.error(6,3,X.zero_position(),0,0)})

def public_checked(fixture: U32, p: D.Progress, error: X.Diagnostic) -> D.Progress:
  match error:
    case X.Diagnostic{phase,reason,at,entry,start,expected,observed,core,key}:
      diagnostic_checked(p,Bool.and(diagnostic_source(fixture,key),diagnostic_start(entry,at,start)))

def public_diagnostic(fixture: U32, p: D.Progress, error: X.Diagnostic, check: Bool) -> D.Progress:
  match check:
    case False{}: p
    case True{}: public_checked(fixture,p,error)

def error_progress(fixture: U32, p: D.Progress, error: Maybe<&2,X.Diagnostic>) -> D.Progress:
  match error:
    case None{}: p
    case Some{+error}:
      match error:
        case X.Diagnostic{+phase,reason,at,entry,start,expected,observed,core,key}: public_diagnostic(fixture,p,error,U32.is_le(phase,4))

def checked(fixture: U32, harness: D.Harness) -> IO(Unit):
  match harness:
    case D.Harness{budget,reader,bytes,entry,document,residual,rest,+p}:
      D.checked(D.Harness{budget,reader,bytes,entry,document,residual,rest,error_progress(fixture,p,D.get_error(p))})

def began(+fixture: U32, rest: String, +p: D.Progress, pair: B.Budget & R.BeginResult) -> IO(Unit):
  (budget,result) = pair
  match result:
    case R.ReaderReady{reader}: checked(fixture,loop(fixture,U32.to_nat(U32.add(U32.mul(D.get_length(p),8),1000)),D.Run{D.Harness{budget,Some{reader},None{},None{},None{},None{},rest,p}}))
    case R.ReaderInitFailed{error,residual}: checked(fixture,loop(fixture,100n,D.Run{D.Harness{budget,residual,None{},None{},None{},None{},rest,D.reject(p,error)}}))

def charged(+fixture: U32, rest: String, +p: D.Progress, limits: X.Limits, pair: B.Budget & Result<&2,&2,E.Error,Unit>) -> IO(Unit):
  (budget,result) = pair
  match result:
    case Done{u}: began(fixture,rest,p,R.begin(budget,C.Range{run(fixture),origin(fixture),0,D.get_length(p)},limits))
    case Fail{error}: D.budget_finished(D.set_phase(D.reject(p,X.core_error(5,5,X.zero_position(),error)),9),B.finish(budget))

def started(fixture: U32, rest: String, +p: D.Progress, limits: X.Limits, result: Result<&2,&1,E.Error,B.Budget>) -> IO(Unit):
  match result:
    case Done{budget}: charged(fixture,rest,p,limits,B.consume(budget,B.Six{D.get_length(p),0,0,0,0,0}))
    case Fail{error}: IO.die(Unit,70,"positions budget start failed")

def valid(hex: String, length: U32, size: U32, +fixture: U32, limits: X.Limits, costs: B.Six, okay: Bool) -> IO(Unit):
  match okay:
    case False{}: IO.die(Unit,64,"invalid positions arguments")
    case True{}: started(fixture,hex,D.Progress{length,size,0,0,0,2166136261,0,0,0,None{}},limits,B.start(budget_run(fixture),costs))

def sized(hex: String, +length: U32, fixture: U32, limits: X.Limits, costs: B.Six, result: Result<&2,&2,U32,U32>) -> IO(Unit):
  match result:
    case Fail{reason}: IO.die(Unit,64,"invalid chunk size")
    case Done{+size}: valid(hex,U32.div(length,2),size,fixture,limits,costs,Bool.and(U32.is_gt(size,0),Bool.and(U32.is_le(length,10000),U32.is_eq(U32.mod(length,2),0))))

def selected(+hex: String, size: String, limits: X.Limits, costs: B.Six, result: Result<&2,&2,U32,U32>) -> IO(Unit):
  match result:
    case Fail{reason}: IO.die(Unit,64,"invalid fixture id")
    case Done{fixture}: sized(hex,U32.from_nat(String.length(hex)),fixture,limits,costs,D.size_number(size,N.begin(False{})))

def override_value(fixture: String, hex: String, size: String, +field: U32, result: Result<&2,&2,U32,U32>) -> IO(Unit):
  match result:
    case Fail{reason}: IO.die(Unit,64,"invalid limit value")
    case Done{+value}: selected(hex,size,D.limits_override(X.defaults(),field,value),D.budget_override(D.budget_defaults(),field,value),D.uint_number(fixture,N.begin(False{})))

def override_field(fixture: String, hex: String, size: String, value: String, result: Result<&2,&2,U32,U32>) -> IO(Unit):
  match result:
    case Fail{reason}: IO.die(Unit,64,"invalid limit field")
    case Done{field}: override_value(fixture,hex,size,field,D.uint_number(value,N.begin(False{})))

def command(args: List<String>) -> IO(Unit):
  match args:
    case _ <> fixture <> hex <> size <> Nil{}: selected(hex,size,X.defaults(),D.budget_defaults(),D.uint_number(fixture,N.begin(False{})))
    case _ <> fixture <> hex <> size <> field <> value <> Nil{}: override_field(fixture,hex,size,value,D.uint_number(field,N.begin(False{})))
    case _: IO.die(Unit,64,"usage: positions CASE_ID HEX_BYTES CHUNK_SIZE [FIELD VALUE]")

def main() -> IO(Unit):
  do IO<Unit>:
    args : List<String> <- IO.args()
    command(args)
