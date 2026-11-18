# Test-only dynamic adapter. No IO/filesystem parsing is part of xml/.
import Base
import ../../core/budget.bend as B
import ../../core/error.bend as E
import ../../core/bytes.bend as Bytes
import ../../core/cursor.bend as C
import ../../xml/types.bend as X
import ../../xml/numbers.bend as N
import ../../xml/reader.bend as R

type Progress is Data:
  Progress{length: U32, size: U32, start: U32, end: U32, fill: U32, digest: U32, count: U32, phase: U32, after: U32, error: Maybe<&2,X.Diagnostic>}

type Harness is Type:
  Harness{budget: B.Budget, reader: Maybe<&1,R.Reader>, bytes: Maybe<&1,Bytes.OwnedBytes>, entry: Maybe<&1,R.ProvisionalEntry>, document: Maybe<&1,R.ValidatedDocument>, residual: Maybe<&1,B.Allocation>, rest: String, +progress: Progress}

type Running is Type:
  Run{harness: Harness}
  Stop{harness: Harness}

def get_length(p: Progress) -> U32:
  match p:
    case Progress{length,size,start,end,fill,digest,count,phase,after,error}: length

def set_length(p: Progress, value: U32) -> Progress:
  match p:
    case Progress{length,size,start,end,fill,digest,count,phase,after,error}: Progress{value,size,start,end,fill,digest,count,phase,after,error}

def get_size(p: Progress) -> U32:
  match p:
    case Progress{length,size,start,end,fill,digest,count,phase,after,error}: size

def set_size(p: Progress, value: U32) -> Progress:
  match p:
    case Progress{length,size,start,end,fill,digest,count,phase,after,error}: Progress{length,value,start,end,fill,digest,count,phase,after,error}

def get_start(p: Progress) -> U32:
  match p:
    case Progress{length,size,start,end,fill,digest,count,phase,after,error}: start

def set_start(p: Progress, value: U32) -> Progress:
  match p:
    case Progress{length,size,start,end,fill,digest,count,phase,after,error}: Progress{length,size,value,end,fill,digest,count,phase,after,error}

def get_end(p: Progress) -> U32:
  match p:
    case Progress{length,size,start,end,fill,digest,count,phase,after,error}: end

def set_end(p: Progress, value: U32) -> Progress:
  match p:
    case Progress{length,size,start,end,fill,digest,count,phase,after,error}: Progress{length,size,start,value,fill,digest,count,phase,after,error}

def get_fill(p: Progress) -> U32:
  match p:
    case Progress{length,size,start,end,fill,digest,count,phase,after,error}: fill

def set_fill(p: Progress, value: U32) -> Progress:
  match p:
    case Progress{length,size,start,end,fill,digest,count,phase,after,error}: Progress{length,size,start,end,value,digest,count,phase,after,error}

def get_digest(p: Progress) -> U32:
  match p:
    case Progress{length,size,start,end,fill,digest,count,phase,after,error}: digest

def set_digest(p: Progress, value: U32) -> Progress:
  match p:
    case Progress{length,size,start,end,fill,digest,count,phase,after,error}: Progress{length,size,start,end,fill,value,count,phase,after,error}

def get_count(p: Progress) -> U32:
  match p:
    case Progress{length,size,start,end,fill,digest,count,phase,after,error}: count

def set_count(p: Progress, value: U32) -> Progress:
  match p:
    case Progress{length,size,start,end,fill,digest,count,phase,after,error}: Progress{length,size,start,end,fill,digest,value,phase,after,error}

def get_phase(p: Progress) -> U32:
  match p:
    case Progress{length,size,start,end,fill,digest,count,phase,after,error}: phase

def set_phase(p: Progress, value: U32) -> Progress:
  match p:
    case Progress{length,size,start,end,fill,digest,count,phase,after,error}: Progress{length,size,start,end,fill,digest,count,value,after,error}

def get_after(p: Progress) -> U32:
  match p:
    case Progress{length,size,start,end,fill,digest,count,phase,after,error}: after

def set_after(p: Progress, value: U32) -> Progress:
  match p:
    case Progress{length,size,start,end,fill,digest,count,phase,after,error}: Progress{length,size,start,end,fill,digest,count,phase,value,error}

def get_error(p: Progress) -> Maybe<&2,X.Diagnostic>:
  match p:
    case Progress{length,size,start,end,fill,digest,count,phase,after,error}: error

def set_error(p: Progress, value: Maybe<&2,X.Diagnostic>) -> Progress:
  match p:
    case Progress{length,size,start,end,fill,digest,count,phase,after,error}: Progress{length,size,start,end,fill,digest,count,phase,after,value}

def mix(hash: U32, value: U32) -> U32:
  U32.xor(U32.mul(hash,16777619),value)

def flag(value: Bool) -> U32:
  match value:
    case False{}: 0
    case True{}: 1

def field(hash: U32, value: X.FieldRef) -> U32:
  match value:
    case X.FieldRef{present,start,length,bytes,span}: mix(mix(mix(mix(hash,flag(present)),start),length),bytes)

def partial(hash: U32, value: X.Partial) -> U32:
  match value:
    case X.TranslatedAbsent{}: mix(hash,0)
    case X.Incomplete{}: mix(hash,1)
    case X.Locked{}: mix(hash,2)

def sid(hash: U32, value: Maybe<&2,X.Sid>) -> U32:
  match value:
    case None{}: mix(hash,0)
    case Some{X.Sid{value,width}}: mix(mix(mix(hash,1),value),width)

def occurrence(hash: U32, value: X.Occurrence) -> U32:
  match value:
    case X.Unspecified{}: mix(hash,0)
    case X.Explicit{index,maxIndex}: mix(mix(mix(hash,1),index),maxIndex)

def rec(hash: U32, value: X.Rec) -> U32:
  match value:
    case X.Rec{record,field,index}: occurrence(mix(mix(hash,record),field),index)

def identity(hash: U32, value: X.Identity) -> U32:
  match value:
    case X.LiteralEdid{}: mix(hash,0)
    case X.BracketFormId{value}: mix(mix(hash,1),value)
    case X.UnsupportedIdentity{reason}: mix(mix(hash,2),reason)

def fuz(hash: U32, value: X.Fuz) -> U32:
  match value:
    case X.Fuz{present,responseId,count,span}: mix(mix(mix(hash,flag(present)),responseId),count)

def entry_hash(hash: U32, value: X.EntryMeta) -> U32:
  match value:
    case X.EntryMeta{source,number,span,list,p,s,r,i,edid,sourceText,destText,f}:
      mix(fuz(field(field(field(identity(rec(sid(partial(mix(mix(mix(hash,57345),number),list),p),s),r),i),edid),sourceText),destText),f),57346)

def params_hash(hash: U32, value: X.ParamsMeta, count: U32) -> U32:
  match value:
    case X.ParamsMeta{source,addon,sourceLanguage,destLanguage,span}:
      mix(field(field(field(mix(mix(hash,53249),count),addon),sourceLanguage),destLanguage),53250)

def reject(p: Progress, error: X.Diagnostic) -> Progress:
  set_phase(set_error(p,Some{error}),80)

def fatal(p: Progress) -> Progress:
  set_phase(p,99)

def bump_hash(+p: Progress, value: U32) -> Progress:
  set_digest(p,mix(get_digest(p),value))

def allocated(reader: R.Reader, rest: String, +p: Progress, pair: B.Budget & Result<&2,&1,E.Error,Bytes.OwnedBytes>) -> Harness:
  (budget,result) = pair
  match result:
    case Done{bytes}: Harness{budget,Some{reader},Some{bytes},None{},None{},None{},rest,set_phase(set_fill(p,0),1)}
    case Fail{error}: Harness{budget,Some{reader},None{},None{},None{},None{},rest,reject(p,X.core_error(5,3,X.zero_position(),error))}

# 65536+cut requests a first chunk of cut bytes, then 65536-byte chunks.
# For a short fixture this tests the exact boundary between two chunks.
def split_size(size: U32, first: Bool) -> U32:
  match first:
    case True{}: U32.sub(size,65536)
    case False{}: 65536

def effective_size(+size: U32, start: U32, constant: Bool) -> U32:
  match constant:
    case True{}: size
    case False{}: split_size(size,U32.is_zero(start))

def allocate_chunk(budget: B.Budget, reader: R.Reader, rest: String, +p: Progress, atEnd: Bool) -> Harness:
  match atEnd:
    case True{}: Harness{budget,Some{reader},None{},None{},None{},None{},rest,set_phase(p,4)}
    case False{}:
      +length = {U32.min(effective_size(get_size(p),get_start(p),U32.is_le(get_size(p),65536)),U32.sub(get_length(p),get_start(p))): U32}
      allocated(reader,rest,set_end(p,U32.add(get_start(p),length)),Bytes.new(budget,length))

def written(reader: R.Reader, rest: String, +p: Progress, pair: B.Budget & Bytes.OwnedBytes & Result<&2,&2,E.Error,Unit>) -> Harness:
  (budget,bytes,result) = pair
  match result:
    case Done{u}: Harness{budget,Some{reader},Some{bytes},None{},None{},None{},rest,set_fill(p,U32.inc(get_fill(p)))}
    case Fail{error}: Harness{budget,Some{reader},Some{bytes},None{},None{},None{},rest,reject(p,X.core_error(5,4,X.zero_position(),error))}

def digits(budget: B.Budget, reader: R.Reader, bytes: Bytes.OwnedBytes, rest: String, +p: Progress, high: Maybe<&2,U32>, low: Maybe<&2,U32>) -> Harness:
  match high low:
    case Some{a} Some{b}: written(reader,rest,p,Bytes.put(budget,bytes,get_fill(p),U32.add(U32.mul(a,16),b)))
    case _ _: Harness{budget,Some{reader},Some{bytes},None{},None{},None{},rest,fatal(p)}

def write_byte(budget: B.Budget, reader: R.Reader, bytes: Bytes.OwnedBytes, rest: String, p: Progress) -> Harness:
  match rest:
    case SCon{Chr{a},SCon{Chr{b},tail}}: digits(budget,reader,bytes,tail,p,N.digit(16,a),N.digit(16,b))
    case other: Harness{budget,Some{reader},Some{bytes},None{},None{},None{},other,fatal(p)}

def fill_chunk(budget: B.Budget, reader: R.Reader, bytes: Bytes.OwnedBytes, rest: String, p: Progress, done: Bool) -> Harness:
  match done:
    case True{}: Harness{budget,Some{reader},Some{bytes},None{},None{},None{},rest,set_phase(p,2)}
    case False{}: write_byte(budget,reader,bytes,rest,p)

def consumed_progress(p: Progress, okay: Bool) -> Progress:
  match okay:
    case True{}: set_phase(p,7)
    case False{}: fatal(p)

def resumed(rest: String, +p: Progress, pair: B.Budget & R.Reader & Bytes.OwnedBytes & U32 & R.ReadResult) -> Harness:
  (budget,reader,bytes,index,result) = pair
  match result:
    case R.EntryReady{entry}: Harness{budget,Some{reader},Some{bytes},Some{entry},None{},None{},rest,set_phase(set_after(p,2),30)}
    case R.ReadMore{}: Harness{budget,Some{reader},Some{bytes},None{},None{},None{},rest,consumed_progress(p,U32.is_eq(index,U32.sub(get_end(p),get_start(p))))}
    case R.ReadFailed{error}: Harness{budget,Some{reader},Some{bytes},None{},None{},None{},rest,reject(p,error)}
    case _: Harness{budget,Some{reader},Some{bytes},None{},None{},None{},rest,fatal(p)}

def bytes_dropped(reader: Maybe<&1,R.Reader>, rest: String, +p: Progress, next: U32, pair: B.Budget & Result<&1,&2,E.Error & B.Allocation,Unit>) -> Harness:
  (budget,result) = pair
  match result:
    case Done{u}: Harness{budget,reader,None{},None{},None{},None{},rest,set_phase(set_start(p,get_end(p)),next)}
    case Fail{failure}:
      (error,allocation) = failure
      Harness{budget,reader,None{},None{},None{},Some{allocation},rest,fatal(p)}

def finished_input(rest: String, p: Progress, pair: B.Budget & R.FinishResult) -> Harness:
  (budget,result) = pair
  match result:
    case R.Finished{document}: Harness{budget,None{},None{},None{},Some{document},None{},rest,set_phase(p,40)}
    case R.FinishEntry{reader,entry}: Harness{budget,Some{reader},None{},Some{entry},None{},None{},rest,set_phase(set_after(p,4),30)}
    case R.FinishFailed{reader,error}: Harness{budget,Some{reader},None{},None{},None{},None{},rest,reject(p,error)}
    case R.Finishing{reader}: Harness{budget,Some{reader},None{},None{},None{},None{},rest,fatal(p)}

def entry_metadata(budget: B.Budget, reader: Maybe<&1,R.Reader>, bytes: Maybe<&1,Bytes.OwnedBytes>, rest: String, +p: Progress, pair: R.ProvisionalEntry & X.EntryMeta) -> Harness:
  (entry,meta) = pair
  Harness{budget,reader,bytes,Some{entry},None{},None{},rest,set_phase(set_count(set_digest(p,entry_hash(get_digest(p),meta)),U32.inc(get_count(p))),31)}

def entry_scalar(reader: Maybe<&1,R.Reader>, bytes: Maybe<&1,Bytes.OwnedBytes>, rest: String, p: Progress, pair: B.Budget & R.ProvisionalEntry & Result<&2,&2,E.Error,Maybe<&2,U32>>) -> Harness:
  (budget,entry,result) = pair
  match result:
    case Done{Some{value}}: Harness{budget,reader,bytes,Some{entry},None{},None{},rest,bump_hash(p,value)}
    case Done{None{}}: Harness{budget,reader,bytes,Some{entry},None{},None{},rest,set_phase(bump_hash(p,57347),32)}
    case Fail{error}: Harness{budget,reader,bytes,Some{entry},None{},None{},rest,set_phase(set_after(reject(p,X.core_error(5,1,X.zero_position(),error)),80),32)}

def entry_dropped(reader: Maybe<&1,R.Reader>, bytes: Maybe<&1,Bytes.OwnedBytes>, rest: String, +p: Progress, pair: B.Budget & Maybe<&1,R.ProvisionalEntry> & Maybe<&2,E.Error>) -> Harness:
  (budget,entry,error) = pair
  match entry error:
    case None{} None{}: Harness{budget,reader,bytes,None{},None{},None{},rest,set_phase(p,get_after(p))}
    case other _: Harness{budget,reader,bytes,other,None{},None{},rest,fatal(p)}

def document_progress(+p: Progress, params: X.ParamsMeta, count: U32, okay: Bool) -> Progress:
  match okay:
    case True{}: set_phase(set_digest(p,params_hash(get_digest(p),params,count)),41)
    case False{}: fatal(p)

def document_metadata(budget: B.Budget, rest: String, +p: Progress, pair: R.ValidatedDocument & X.ParamsMeta & U32) -> Harness:
  (document,params,count0) = pair
  +count = {count0: U32}
  Harness{budget,None{},None{},None{},Some{document},None{},rest,document_progress(p,params,count,U32.is_eq(count,get_count(p)))}

def document_scalar(rest: String, p: Progress, pair: B.Budget & R.ValidatedDocument & Result<&2,&2,E.Error,Maybe<&2,U32>>) -> Harness:
  (budget,document,result) = pair
  match result:
    case Done{Some{value}}: Harness{budget,None{},None{},None{},Some{document},None{},rest,bump_hash(p,value)}
    case Done{None{}}: Harness{budget,None{},None{},None{},Some{document},None{},rest,set_phase(bump_hash(p,53251),42)}
    case Fail{error}: Harness{budget,None{},None{},None{},Some{document},None{},rest,set_phase(reject(p,X.core_error(5,2,X.zero_position(),error)),42)}

def document_dropped(rest: String, p: Progress, pair: B.Budget & Maybe<&1,R.ValidatedDocument> & Maybe<&2,E.Error>) -> Harness:
  (budget,document,error) = pair
  match document error:
    case None{} None{}: Harness{budget,None{},None{},None{},None{},None{},rest,set_phase(p,9)}
    case other _: Harness{budget,None{},None{},None{},other,None{},rest,fatal(p)}

def reader_dropped(bytes: Maybe<&1,Bytes.OwnedBytes>, rest: String, p: Progress, pair: B.Budget & Maybe<&1,R.Reader> & Maybe<&2,E.Error>) -> Harness:
  (budget,reader,error) = pair
  match reader error:
    case None{} None{}: Harness{budget,None{},bytes,None{},None{},None{},rest,set_phase(p,81)}
    case other _: Harness{budget,other,bytes,None{},None{},None{},rest,fatal(p)}

def step(harness: Harness) -> Running:
  match harness:
    case Harness{budget,Some{reader},None{},None{},None{},None{},rest,+p}:
      match p:
        case Progress{length,size,start,end,fill,digest,count,0,after,error}: Run{allocate_chunk(budget,reader,rest,p,U32.is_eq(start,length))}
        case Progress{length,size,start,end,fill,digest,count,4,after,error}: Run{finished_input(rest,p,R.finish(budget,reader))}
        case Progress{length,size,start,end,fill,digest,count,80,after,error}: Run{reader_dropped(None{},rest,p,R.drop(budget,reader))}
        case _: Stop{Harness{budget,Some{reader},None{},None{},None{},None{},rest,fatal(p)}}
    case Harness{budget,Some{reader},Some{bytes},None{},None{},None{},rest,+p}:
      match p:
        case Progress{length,size,start,end,fill,digest,count,1,after,error}: Run{fill_chunk(budget,reader,bytes,rest,p,U32.is_eq(fill,U32.sub(end,start)))}
        case Progress{length,size,start,end,fill,digest,count,2,after,error}: Run{resumed(rest,p,R.resume(budget,reader,C.Range{1,42,start,end},bytes))}
        case Progress{length,size,start,end,fill,digest,count,7,after,error}: Run{bytes_dropped(Some{reader},rest,p,0,Bytes.drop(budget,bytes))}
        case Progress{length,size,start,end,fill,digest,count,80,after,error}: Run{reader_dropped(Some{bytes},rest,p,R.drop(budget,reader))}
        case _: Stop{Harness{budget,Some{reader},Some{bytes},None{},None{},None{},rest,fatal(p)}}
    case Harness{budget,reader,bytes,Some{entry},None{},None{},rest,+p}:
      match p:
        case Progress{length,size,start,end,fill,digest,count,30,after,error}: Run{entry_metadata(budget,reader,bytes,rest,p,R.entry_metadata(entry))}
        case Progress{length,size,start,end,fill,digest,count,31,after,error}: Run{entry_scalar(reader,bytes,rest,p,R.entry_next(budget,entry))}
        case Progress{length,size,start,end,fill,digest,count,32,after,error}: Run{entry_dropped(reader,bytes,rest,p,R.drop_entry(budget,entry))}
        case _: Stop{Harness{budget,reader,bytes,Some{entry},None{},None{},rest,fatal(p)}}
    case Harness{budget,None{},None{},None{},Some{document},None{},rest,+p}:
      match p:
        case Progress{length,size,start,end,fill,digest,count,40,after,error}: Run{document_metadata(budget,rest,p,R.document_metadata(document))}
        case Progress{length,size,start,end,fill,digest,count,41,after,error}: Run{document_scalar(rest,p,R.document_next(budget,document))}
        case Progress{length,size,start,end,fill,digest,count,42,after,error}: Run{document_dropped(rest,p,R.drop_document(budget,document))}
        case _: Stop{Harness{budget,None{},None{},None{},Some{document},None{},rest,fatal(p)}}
    case Harness{budget,None{},Some{bytes},None{},None{},None{},rest,+p}:
      match p:
        case Progress{length,size,start,end,fill,digest,count,81,after,error}: Run{bytes_dropped(None{},rest,p,9,Bytes.drop(budget,bytes))}
        case _: Stop{Harness{budget,None{},Some{bytes},None{},None{},None{},rest,fatal(p)}}
    case Harness{budget,None{},None{},None{},None{},None{},rest,+p}:
      match p:
        case Progress{length,size,start,end,fill,digest,count,80,after,error}: Run{Harness{budget,None{},None{},None{},None{},None{},rest,set_phase(p,9)}}
        case Progress{length,size,start,end,fill,digest,count,81,after,error}: Run{Harness{budget,None{},None{},None{},None{},None{},rest,set_phase(p,9)}}
        case _: Stop{Harness{budget,None{},None{},None{},None{},None{},rest,p}}
    case other: Stop{other}

def loop(fuel: Nat, running: Running) -> Harness:
  match fuel running:
    case _ Stop{harness}: harness
    case 0n Run{harness}: harness
    case 1n+left Run{harness}: loop(left,step(harness))

def report_error(error: X.Diagnostic, logical: U32, work: U32) -> IO(Unit):
  match error:
    case X.Diagnostic{phase,reason,X.Position{byte,line,column},entry,entryStart,expected,observed,core,source}:
      IO.print("error " ++ U32.show(phase) ++ " " ++ U32.show(reason) ++ " " ++ U32.show(entry) ++ " " ++ U32.show(byte) ++ " " ++ U32.show(line) ++ " " ++ U32.show(column) ++ " " ++ U32.show(logical) ++ " " ++ U32.show(work) ++ " balanced")

def report(p: Progress, logical: U32, work: U32) -> IO(Unit):
  match p:
    case Progress{length,size,start,end,fill,digest,count,phase,after,None{}}: IO.print("ok " ++ U32.show(digest) ++ " " ++ U32.show(count) ++ " " ++ U32.show(logical) ++ " " ++ U32.show(work) ++ " balanced")
    case Progress{length,size,start,end,fill,digest,count,phase,after,Some{error}}: report_error(error,logical,work)

def budget_finished(p: Progress, result: Result<&1,&2,E.Error & B.Budget,B.Six>) -> IO(Unit):
  match result:
    case Done{B.Six{input,inflate,output,logical,0,work}}: report(p,logical,work)
    case _: IO.die(Unit,70,"budget not balanced")

def checked(harness: Harness) -> IO(Unit):
  match harness:
    case Harness{budget,None{},None{},None{},None{},None{},rest,+p}:
      match p:
        case Progress{length,size,start,end,fill,digest,count,9,after,error}: budget_finished(p,B.finish(budget))
        case _: IO.die(Unit,70,"driver invariant/fuel failure")
    case _: IO.die(Unit,70,"driver retained owner or cleanup failure")

def began(rest: String, +p: Progress, pair: B.Budget & R.BeginResult) -> IO(Unit):
  (budget,result) = pair
  match result:
    case R.ReaderReady{reader}: checked(loop(U32.to_nat(U32.add(U32.mul(get_length(p),8),1000)),Run{Harness{budget,Some{reader},None{},None{},None{},None{},rest,p}}))
    case R.ReaderInitFailed{error,residual}: checked(loop(100n,Run{Harness{budget,residual,None{},None{},None{},None{},rest,reject(p,error)}}))

def charged(rest: String, +p: Progress, limits: X.Limits, pair: B.Budget & Result<&2,&2,E.Error,Unit>) -> IO(Unit):
  (budget,result) = pair
  match result:
    case Done{u}: began(rest,p,R.begin(budget,C.Range{1,42,0,get_length(p)},limits))
    case Fail{error}: budget_finished(set_phase(reject(p,X.core_error(5,5,X.zero_position(),error)),9),B.finish(budget))

def started(rest: String, +p: Progress, limits: X.Limits, result: Result<&2,&1,E.Error,B.Budget>) -> IO(Unit):
  match result:
    case Done{budget}: charged(rest,p,limits,B.consume(budget,B.Six{get_length(p),0,0,0,0,0}))
    case Fail{error}: IO.die(Unit,70,"driver budget start failed")

def size_number(text: String, number: N.Number) -> Result<&2,&2,U32,U32>:
  match text:
    case SNil{}: N.finish(number,1,6,131072)
    case SCon{Chr{value},tail}: size_number(tail,N.push(number,value))

def budget_defaults() -> B.Six:
  B.Six{67108864,0,0,536870912,268435456,1073741824}

def limits_override(limits: X.Limits, field: U32, value: U32) -> X.Limits:
  match limits:
    case X.Limits{source,depth,entries,entryText,paramsText,names,references,fuzCount,fuzText}:
      match field:
        case 0: X.Limits{value,depth,entries,entryText,paramsText,names,references,fuzCount,fuzText}
        case 1: X.Limits{source,value,entries,entryText,paramsText,names,references,fuzCount,fuzText}
        case 2: X.Limits{source,depth,value,entryText,paramsText,names,references,fuzCount,fuzText}
        case 3: X.Limits{source,depth,entries,value,paramsText,names,references,fuzCount,fuzText}
        case 4: X.Limits{source,depth,entries,entryText,value,names,references,fuzCount,fuzText}
        case 5: X.Limits{source,depth,entries,entryText,paramsText,value,references,fuzCount,fuzText}
        case 6: X.Limits{source,depth,entries,entryText,paramsText,names,value,fuzCount,fuzText}
        case 7: X.Limits{source,depth,entries,entryText,paramsText,names,references,value,fuzText}
        case 8: X.Limits{source,depth,entries,entryText,paramsText,names,references,fuzCount,value}
        case _: X.Limits{source,depth,entries,entryText,paramsText,names,references,fuzCount,fuzText}

def budget_override(costs: B.Six, field: U32, value: U32) -> B.Six:
  match costs:
    case B.Six{input,inflate,output,logical,live,work}:
      match field:
        case 9: B.Six{input,inflate,output,value,live,work}
        case 10: B.Six{input,inflate,output,logical,live,value}
        case 11: B.Six{input,inflate,output,logical,value,work}
        case _: B.Six{input,inflate,output,logical,live,work}

def command_valid(hex: String, length: U32, size: U32, limits: X.Limits, costs: B.Six, okay: Bool) -> IO(Unit):
  match okay:
    case False{}: IO.die(Unit,64,"hex length or chunk size out of range")
    case True{}: started(hex,Progress{length,size,0,0,0,2166136261,0,0,0,None{}},limits,B.start(1,costs))

def sized(hex: String, +length: U32, limits: X.Limits, costs: B.Six, result: Result<&2,&2,U32,U32>) -> IO(Unit):
  match result:
    case Fail{reason}: IO.die(Unit,64,"chunk size must be decimal 1..131072")
    case Done{+size}: command_valid(hex,U32.div(length,2),size,limits,costs,Bool.and(U32.is_gt(size,0),Bool.and(U32.is_le(length,134217728),U32.is_eq(U32.mod(length,2),0))))

def uint_number(text: String, number: N.Number) -> Result<&2,&2,U32,U32>:
  match text:
    case SNil{}: N.finish(number,1,10,4294967295)
    case SCon{Chr{value},tail}: uint_number(tail,N.push(number,value))

def override_value(+hex: String, size: String, +field: U32, result: Result<&2,&2,U32,U32>) -> IO(Unit):
  match result:
    case Fail{reason}: IO.die(Unit,64,"limit value must be decimal U32")
    case Done{+value}: sized(hex,U32.from_nat(String.length(hex)),limits_override(X.defaults(),field,value),budget_override(budget_defaults(),field,value),size_number(size,N.begin(False{})))

def override_valid(hex: String, size: String, value: String, field: U32, valid: Bool) -> IO(Unit):
  match valid:
    case False{}: IO.die(Unit,64,"limit field must be 0..11")
    case True{}: override_value(hex,size,field,uint_number(value,N.begin(False{})))

def override_field(hex: String, size: String, value: String, result: Result<&2,&2,U32,U32>) -> IO(Unit):
  match result:
    case Fail{reason}: IO.die(Unit,64,"limit field must be 0..11")
    case Done{+field}: override_valid(hex,size,value,field,U32.is_le(field,11))

def command(args: List<String>) -> IO(Unit):
  match args:
    case _ <> +hex <> size <> Nil{}: sized(hex,U32.from_nat(String.length(hex)),X.defaults(),budget_defaults(),size_number(size,N.begin(False{})))
    case _ <> hex <> size <> field <> value <> Nil{}: override_field(hex,size,value,uint_number(field,N.begin(False{})))
    case _: IO.die(Unit,64,"usage: XML_DRIVER HEX_BYTES CHUNK_SIZE [FIELD VALUE]")

def main() -> IO(Unit):
  do IO<Unit>:
    args : List<String> <- IO.args()
    command(args)
