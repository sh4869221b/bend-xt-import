import Base
import ../core/budget.bend as B
import ../core/error.bend as E
import ../core/bytes.bend as Bytes
import ../core/scalars.bend as S
import ../core/cursor.bend as C
import ../core/codec.bend as Codec
import ../core/utf8.bend as U8
import ./types.bend as X
import ./text.bend as Text

type Chunk is Data:
  Chunk{range: C.Range, allocation: U32, length: U32, index: U32}

type Meta is Data:
  Meta{root: C.Range, position: X.Position, active: Maybe<&2,Chunk>, decoder: U8.State, cr: Maybe<&2,X.Scalar>, pending: Maybe<&2,X.Scalar>, lastCR: Bool, ended: Bool, error: Maybe<&2,X.Diagnostic>}

type Input is Type:
  Input{scratch: Maybe<&1,S.ScalarChunk>, residual: Maybe<&1,B.Allocation>, meta: Meta}

type BeginResult is Type:
  InputReady{input: Input}
  InitFailed{diagnostic: X.Diagnostic, residual: Maybe<&1,Input>}

type InputResult is Data:
  ScalarReady{scalar: X.Scalar}
  NeedInput{}
  InputFailed{diagnostic: X.Diagnostic}
  ContinueInput{}

type EndResult is Data:
  EndScalar{scalar: X.Scalar}
  EndDone{position: X.Position}
  EndFailed{diagnostic: X.Diagnostic}

def byte(position: X.Position) -> U32:
  match position:
    case X.Position{byte,line,column}: byte

def index(meta: Meta) -> U32:
  match meta:
    case Meta{root,position,None{},decoder,cr,pending,lastCR,ended,error}: 0
    case Meta{root,position,Some{Chunk{range,allocation,length,index}},decoder,cr,pending,lastCR,ended,error}: index

def position(meta: Meta) -> X.Position:
  match meta:
    case Meta{root,position,active,decoder,cr,pending,lastCR,ended,error}: position

def diagnostic(meta: Meta, reason: U32, expected: U32, observed: U32) -> X.Diagnostic:
  X.error(1,reason,position(meta),expected,observed)

def remember(meta: Meta, error: X.Diagnostic) -> Meta:
  match meta:
    case Meta{root,position,active,decoder,cr,pending,lastCR,ended,None{}}: Meta{root,position,active,decoder,cr,pending,lastCR,ended,Some{error}}
    case Meta{root,position,active,decoder,cr,pending,lastCR,ended,Some{old}}: Meta{root,position,active,decoder,cr,pending,lastCR,ended,Some{old}}

def failed(budget: B.Budget, scratch: Maybe<&1,S.ScalarChunk>, residual: Maybe<&1,B.Allocation>, +meta: Meta, bytes: Bytes.OwnedBytes, +error: X.Diagnostic) -> B.Budget & Input & Bytes.OwnedBytes & U32 & InputResult:
  (budget,Input{scratch,residual,remember(meta,error)},bytes,index(meta),InputFailed{error})

def init_meta(root: C.Range) -> Meta:
  Meta{root,X.zero_position(),None{},U8.init(),None{},None{},False{},False{},None{}}

def begin_run(root: C.Range, budget: B.Budget, scratch: S.ScalarChunk, +run: U32, okay: Bool) -> B.Budget & BeginResult:
  match okay:
    case True{}: (budget,InputReady{Input{Some{S.clear(scratch)},None{},init_meta(root)}})
    case False{}: (budget,InitFailed{X.error(1,2,X.zero_position(),0,run),Some{Input{Some{scratch},None{},remember(init_meta(root),X.error(1,2,X.zero_position(),0,run))}}})

def begin_metadata(+root: C.Range, budget: B.Budget, p: S.ScalarChunk & U32 & U32 & U32 & U32) -> B.Budget & BeginResult:
  match root:
    case C.Range{+sourceRun,source,start,end}:
      (scratch,length,capacity,+run,origin) = p
      begin_run(root,budget,scratch,run,U32.is_eq(run,sourceRun))

def begin_allocated(root: C.Range, p: B.Budget & Result<&2,&1,E.Error,S.ScalarChunk>) -> B.Budget & BeginResult:
  (budget,result) = p
  match result:
    case Fail{error}: (budget,InitFailed{X.core_error(1,10,X.zero_position(),error),None{}})
    case Done{scratch}: begin_metadata(root,budget,S.metadata(scratch))

def begin_valid(budget: B.Budget, root: C.Range, limit: U32, okay: Bool) -> B.Budget & BeginResult:
  match okay:
    case False{}: (budget,InitFailed{X.error(1,1,X.zero_position(),67108864,limit),None{}})
    case True{}: begin_allocated(root,S.new(budget,1))

def begin(budget: B.Budget, +root: C.Range, +limit: U32) -> B.Budget & BeginResult:
  match root:
    case C.Range{run,source,+start,+end}:
      begin_valid(budget,root,limit,Bool.and(U32.is_zero(start),Bool.and(U32.is_le(end,limit),U32.is_le(limit,67108864))))

def key(root: C.Range) -> X.SourceKey:
  match root:
    case C.Range{run,origin,start,end}: X.SourceKey{run,origin}

def metadata(input: Input) -> Input & X.Position & X.SourceKey:
  match input:
    case Input{scratch,residual,Meta{+root,+position,active,decoder,cr,pending,lastCR,ended,error}}:
      (Input{scratch,residual,Meta{root,position,active,decoder,cr,pending,lastCR,ended,error}},position,key(root))

# Source lines are counted from literal bytes. A BOM occupies bytes but no XML
# character column. Character references are still syntax here, not newlines.
def advance_other(line: U32, column: U32, end: U32, value: U32, lastCR: Bool) -> X.Position & Bool:
  match value lastCR:
    case 13 _: (X.Position{end,U32.inc(line),1},True{})
    case 10 True{}: (X.Position{end,line,1},False{})
    case 10 False{}: (X.Position{end,U32.inc(line),1},False{})
    case _ _: (X.Position{end,line,U32.inc(column)},False{})

def advance_bom(line: U32, column: U32, end: U32, value: U32, lastCR: Bool, bom: Bool) -> X.Position & Bool:
  match bom:
    case True{}: (X.Position{end,line,column},False{})
    case False{}: advance_other(line,column,end,value,lastCR)

def advance(start: X.Position, end: U32, +value: U32, lastCR: Bool) -> X.Position & Bool:
  match start:
    case X.Position{+begin,line,column}: advance_bom(line,column,end,value,lastCR,Bool.and(U32.is_zero(begin),U32.is_eq(value,65279)))

def source_start(position: X.Position, end: U32, value: U32) -> X.Position:
  match position:
    case X.Position{old,line,column}: X.Position{U32.sub(end,Text.width(value)),line,column}

def set_pending(meta: Meta, cr: Maybe<&2,X.Scalar>, pending: Maybe<&2,X.Scalar>) -> Meta:
  match meta:
    case Meta{root,position,active,decoder,oldCR,oldPending,lastCR,ended,error}: Meta{root,position,active,decoder,cr,pending,lastCR,ended,error}

def normalized_none(meta: Meta, +scalar: X.Scalar, value: U32, bom: Bool) -> Meta & InputResult:
  match value bom:
    case _ True{}: (meta,ContinueInput{})
    case 13 False{}: (set_pending(meta,Some{scalar},None{}),ContinueInput{})
    case _ False{}: (meta,ScalarReady{scalar})

def normalized_after_cr(meta: Meta, old: X.Scalar, +scalar: X.Scalar, isLF: Bool) -> Meta & InputResult:
  match old scalar isLF:
    case X.Scalar{oldValue,X.Span{start,oldEnd}} X.Scalar{value,X.Span{newStart,end}} True{}:
      (set_pending(meta,None{},None{}),ScalarReady{X.Scalar{10,X.Span{start,end}}})
    case X.Scalar{oldValue,oldSpan} other False{}:
      (set_pending(meta,None{},Some{other}),ScalarReady{X.Scalar{10,oldSpan}})

def normalized(meta: Meta, +scalar: X.Scalar, pendingCR: Maybe<&2,X.Scalar>) -> Meta & InputResult:
  match scalar pendingCR:
    case X.Scalar{+value,+span} None{}:
      normalized_none(meta,scalar,value,Bool.and(U32.is_zero(byte(X.start(span))),U32.is_eq(value,65279)))
    case X.Scalar{+value,span} Some{old}: normalized_after_cr(meta,old,scalar,U32.is_eq(value,10))

def normalized_input(budget: B.Budget, scratch: Maybe<&1,S.ScalarChunk>, residual: Maybe<&1,B.Allocation>, bytes: Bytes.OwnedBytes, p: Meta & InputResult) -> B.Budget & Input & Bytes.OwnedBytes & U32 & InputResult:
  (+meta,result) = p
  (budget,Input{scratch,residual,meta},bytes,index(meta),result)

def raw_advanced(budget: B.Budget, scratch: S.ScalarChunk, residual: Maybe<&1,B.Allocation>, bytes: Bytes.OwnedBytes, root: C.Range, active: Maybe<&2,Chunk>, decoder: U8.State, +cr: Maybe<&2,X.Scalar>, ended: Bool, error: Maybe<&2,X.Diagnostic>, start: X.Position, value: U32, p: X.Position & Bool) -> B.Budget & Input & Bytes.OwnedBytes & U32 & InputResult:
  (+end,lastCR) = p
  normalized_input(budget,Some{S.clear(scratch)},residual,bytes,normalized(Meta{root,end,active,decoder,cr,None{},lastCR,ended,error},X.Scalar{value,X.Span{start,end}},cr))

def raw_valid(budget: B.Budget, scratch: S.ScalarChunk, residual: Maybe<&1,B.Allocation>, bytes: Bytes.OwnedBytes, +meta: Meta, +value: U32, okay: Bool) -> B.Budget & Input & Bytes.OwnedBytes & U32 & InputResult:
  match meta okay:
    case _ False{}: failed(budget,Some{scratch},residual,meta,bytes,X.error(1,6,source_start(position(meta),byte(position(meta)),value),0,value))
    case Meta{root,+position,active,decoder,cr,pending,+lastCR,ended,error} True{}:
      raw_advanced(budget,scratch,residual,bytes,root,active,decoder,cr,ended,error,source_start(position,byte(position),value),value,advance(source_start(position,byte(position),value),byte(position),value,lastCR))

def inspected(residual: Maybe<&1,B.Allocation>, bytes: Bytes.OwnedBytes, +meta: Meta, p: B.Budget & S.ScalarChunk & Result<&2,&2,E.Error,U32>) -> B.Budget & Input & Bytes.OwnedBytes & U32 & InputResult:
  (budget,scratch,result) = p
  match result:
    case Fail{error}: failed(budget,Some{scratch},residual,meta,bytes,X.core_error(1,10,position(meta),error))
    case Done{+value}: raw_valid(budget,scratch,residual,bytes,meta,value,X.xml_character(value))

def progressed(meta: Meta, decoder: U8.State, +next: U32) -> Meta:
  match meta:
    case Meta{root,X.Position{old,line,column},Some{Chunk{+range,allocation,length,index}},oldDecoder,cr,pending,lastCR,ended,error}:
      match range:
        case C.Range{run,origin,start,end}: Meta{root,X.Position{U32.add(start,next),line,column},Some{Chunk{range,allocation,length,next}},decoder,cr,pending,lastCR,ended,error}
    case Meta{root,position,None{},oldDecoder,cr,pending,lastCR,ended,error}: Meta{root,position,None{},decoder,cr,pending,lastCR,ended,error}

def input_end(meta: Meta) -> Meta:
  match meta:
    case Meta{root,position,active,decoder,cr,pending,lastCR,ended,error}: Meta{root,position,None{},decoder,cr,pending,lastCR,ended,error}

def with_byte(position: X.Position, offset: U32) -> X.Position:
  match position:
    case X.Position{old,line,column}: X.Position{offset,line,column}

def encoding_position(meta: Meta, error: E.Error) -> X.Position:
  match error:
    case E.InvalidEncoding{codec,offset,reason}: with_byte(position(meta),offset)
    case _: position(meta)

def decoded_state(residual: Maybe<&1,B.Allocation>, +meta: Meta, budget: B.Budget, bytes: Bytes.OwnedBytes, scratch: S.ScalarChunk, decoder: U8.State, produced: U32, status: U32) -> B.Budget & Input & Bytes.OwnedBytes & U32 & InputResult:
  match decoder produced status:
    case U8.Broken{+error} _ _: failed(budget,Some{scratch},residual,meta,bytes,X.core_error(1,5,encoding_position(meta,error),error))
    case _ 0 0: (budget,Input{Some{scratch},residual,input_end(meta)},bytes,index(meta),NeedInput{})
    case _ 1 _: inspected(residual,bytes,meta,S.get(budget,scratch,0))
    case _ _ _: failed(budget,Some{scratch},residual,meta,bytes,diagnostic(meta,9,1,produced))

def decoded(residual: Maybe<&1,B.Allocation>, meta: Meta, p: B.Budget & Bytes.OwnedBytes & S.ScalarChunk & Codec.Progress) -> B.Budget & Input & Bytes.OwnedBytes & U32 & InputResult:
  (budget,bytes,scratch,progress) = p
  match progress:
    case Codec.Progress{+decoder,next,produced,status}: decoded_state(residual,progressed(meta,decoder,next),budget,bytes,scratch,decoder,produced,status)

def step_available(budget: B.Budget, scratch: S.ScalarChunk, residual: Maybe<&1,B.Allocation>, +meta: Meta, bytes: Bytes.OwnedBytes, decoder: U8.State, index: U32, atEnd: Bool) -> B.Budget & Input & Bytes.OwnedBytes & U32 & InputResult:
  match atEnd:
    case True{}: (budget,Input{Some{scratch},residual,input_end(meta)},bytes,index,NeedInput{})
    case False{}: decoded(residual,meta,Codec.decode(0,budget,bytes,S.clear(scratch),decoder,index))

def step(budget: B.Budget, input: Input, bytes: Bytes.OwnedBytes) -> B.Budget & Input & Bytes.OwnedBytes & U32 & InputResult:
  match input:
    case Input{scratch,residual,Meta{root,position,active,decoder,+cr,Some{scalar},lastCR,ended,error}}:
      normalized_input(budget,scratch,residual,bytes,normalized(Meta{root,position,active,decoder,cr,None{},lastCR,ended,error},scalar,cr))
    case Input{Some{scratch},residual,Meta{root,position,Some{Chunk{range,allocation,+length,+index}},+decoder,cr,None{},lastCR,ended,error}}:
      step_available(budget,scratch,residual,Meta{root,position,Some{Chunk{range,allocation,length,index}},decoder,cr,None{},lastCR,ended,error},bytes,decoder,index,U32.is_eq(index,length))
    case Input{scratch,residual,+meta}: failed(budget,scratch,residual,meta,bytes,diagnostic(meta,9,0,0))

def exhausted(budget: B.Budget, input: Input, bytes: Bytes.OwnedBytes) -> B.Budget & Input & Bytes.OwnedBytes & U32 & InputResult:
  match input:
    case Input{scratch,residual,+meta}: failed(budget,scratch,residual,meta,bytes,diagnostic(meta,9,0,0))

def exhausted_result(p: B.Budget & Input & Bytes.OwnedBytes & U32 & InputResult) -> B.Budget & Input & Bytes.OwnedBytes & U32 & InputResult:
  (budget,input,bytes,index,result) = p
  match result:
    case ContinueInput{}: exhausted(budget,input,bytes)
    case other: (budget,input,bytes,index,other)

def next_loop(fuel: Nat, p: B.Budget & Input & Bytes.OwnedBytes & U32 & InputResult) -> B.Budget & Input & Bytes.OwnedBytes & U32 & InputResult:
  match fuel:
    case 0n: exhausted_result(p)
    case 1n+rest:
      (budget,input,bytes,index,result) = p
      match result:
        case ContinueInput{}: next_loop(rest,step(budget,input,bytes))
        case other: (budget,input,bytes,index,other)

# The range's bytes are attested by the trusted adapter. Identity checks detect
# accidental skipped/replayed/replaced chunks, not a malicious caller's mutation.
# At index == length the next contiguous owner may replace the exhausted chunk;
# pending decoded scalars contain no reference to its storage.
def same_range(left: C.Range, right: C.Range) -> Bool:
  match left right:
    case C.Range{a,b,c,d} C.Range{e,f,g,h}: Bool.and(U32.is_eq(a,e),Bool.and(U32.is_eq(b,f),Bool.and(U32.is_eq(c,g),U32.is_eq(d,h))))

def replacement_range(range: C.Range, offset: U32) -> Bool:
  match range:
    case C.Range{run,origin,start,end}: U32.is_eq(start,offset)

def active_valid(active: Maybe<&2,Chunk>, +range: C.Range, allocation: U32, +length: U32, offset: U32) -> Bool:
  match active:
    case None{}: replacement_range(range,offset)
    case Some{Chunk{oldRange,oldAllocation,+oldLength,+index}}:
      Bool.or(Bool.and(same_range(oldRange,range),Bool.and(U32.is_eq(allocation,oldAllocation),Bool.and(U32.is_eq(length,oldLength),U32.is_le(index,oldLength)))),Bool.and(U32.is_eq(index,oldLength),replacement_range(range,offset)))

def replacement_chunk(old: Chunk, range: C.Range, allocation: U32, length: U32, same: Bool) -> Maybe<&2,Chunk>:
  match same:
    case True{}: Some{old}
    case False{}: Some{Chunk{range,allocation,length,0}}

def current_chunk(active: Maybe<&2,Chunk>, +range: C.Range, allocation: U32, length: U32) -> Maybe<&2,Chunk>:
  match active:
    case None{}: Some{Chunk{range,allocation,length,0}}
    case Some{Chunk{+oldRange,oldAllocation,oldLength,index}}:
      replacement_chunk(Chunk{oldRange,oldAllocation,oldLength,index},range,allocation,length,same_range(oldRange,range))

def bind_valid(budget: B.Budget, scratch: Maybe<&1,S.ScalarChunk>, residual: Maybe<&1,B.Allocation>, meta: Meta, bytes: Bytes.OwnedBytes, range: C.Range, allocation: U32, length: U32, okay: Bool) -> B.Budget & Input & Bytes.OwnedBytes & U32 & InputResult:
  match meta okay:
    case +meta False{}: failed(budget,scratch,residual,meta,bytes,diagnostic(meta,3,0,0))
    case Meta{root,position,active,decoder,cr,pending,lastCR,ended,error} True{}:
      next_loop(4n,(budget,Input{scratch,residual,Meta{root,position,current_chunk(active,range,allocation,length),decoder,cr,pending,lastCR,ended,error}},bytes,0,ContinueInput{}))

def chunk_valid(+root: C.Range, +range: C.Range, +run: U32, +length: U32) -> Bool:
  match root range:
    case C.Range{+rootRun,+rootOrigin,rootStart,+rootEnd} C.Range{+rangeRun,+rangeOrigin,+start,+end}:
      Bool.and(U32.is_eq(run,rootRun),Bool.and(U32.is_eq(rangeRun,rootRun),Bool.and(U32.is_eq(rangeOrigin,rootOrigin),Bool.and(U32.is_le(start,end),Bool.and(U32.is_le(end,rootEnd),Bool.and(U32.is_eq(length,U32.sub(end,start)),U32.is_gt(length,0)))))))

def next_checked(budget: B.Budget, scratch: Maybe<&1,S.ScalarChunk>, residual: Maybe<&1,B.Allocation>, +meta: Meta, bytes: Bytes.OwnedBytes, +range: C.Range, run: U32, +allocation: U32, +length: U32) -> B.Budget & Input & Bytes.OwnedBytes & U32 & InputResult:
  match meta:
    case Meta{root,position,active,decoder,cr,pending,lastCR,ended,Some{error}}: (budget,Input{scratch,residual,meta},bytes,index(meta),InputFailed{error})
    case Meta{root,position,active,decoder,cr,pending,lastCR,True{},None{}}: failed(budget,scratch,residual,meta,bytes,diagnostic(meta,8,0,0))
    case Meta{root,position,active,decoder,cr,pending,lastCR,False{},None{}}:
      bind_valid(budget,scratch,residual,meta,bytes,range,allocation,length,Bool.and(chunk_valid(root,range,run,length),active_valid(active,range,allocation,length,byte(position))))

def next_metadata(budget: B.Budget, input: Input, range: C.Range, p: Bytes.OwnedBytes & U32 & U32 & U32 & U32) -> B.Budget & Input & Bytes.OwnedBytes & U32 & InputResult:
  match input:
    case Input{scratch,residual,meta}:
      (bytes,length,capacity,run,allocation) = p
      next_checked(budget,scratch,residual,meta,bytes,range,run,allocation,length)

def next(budget: B.Budget, input: Input, range: C.Range, bytes: Bytes.OwnedBytes) -> B.Budget & Input & Bytes.OwnedBytes & U32 & InputResult:
  next_metadata(budget,input,range,Bytes.metadata(bytes))

# EOF is explicit: first finish UTF-8, then process finite lookahead and flush CR.
def ended_meta(meta: Meta) -> Meta:
  match meta:
    case Meta{root,position,active,decoder,cr,pending,lastCR,ended,error}: Meta{root,position,None{},decoder,None{},None{},lastCR,True{},error}

def end_continued(meta: Meta) -> Meta & EndResult:
  match meta:
    case Meta{root,position,active,decoder,Some{X.Scalar{value,span}},pending,lastCR,ended,error}:
      (Meta{root,position,active,decoder,None{},pending,lastCR,ended,error},EndScalar{X.Scalar{10,span}})
    case other: (other,EndFailed{X.error(1,9,X.zero_position(),0,0)})

def end_normalized(p: Meta & InputResult) -> Meta & EndResult:
  (meta,result) = p
  match result:
    case ScalarReady{scalar}: (meta,EndScalar{scalar})
    case ContinueInput{}: end_continued(meta)
    case InputFailed{error}: (meta,EndFailed{error})
    case NeedInput{}: (meta,EndFailed{X.error(1,9,X.zero_position(),0,0)})

def end_pending(meta: Meta) -> Meta & EndResult:
  match meta:
    case Meta{root,position,active,decoder,+cr,Some{scalar},lastCR,ended,error}:
      end_normalized(normalized(Meta{root,position,active,decoder,cr,None{},lastCR,ended,error},scalar,cr))
    case Meta{root,position,active,decoder,Some{X.Scalar{value,span}},None{},lastCR,ended,error}:
      (Meta{root,position,active,decoder,None{},None{},lastCR,ended,error},EndScalar{X.Scalar{10,span}})
    case +other: (ended_meta(other),EndDone{position(other)})

def end_utf8(+meta: Meta, result: Result<&2,&2,E.Error,Unit>) -> Meta & EndResult:
  match result:
    case Done{u}: end_pending(meta)
    case Fail{+error}: (remember(meta,X.core_error(1,5,encoding_position(meta,error),error)),EndFailed{X.core_error(1,5,encoding_position(meta,error),error)})

def end_exact(+meta: Meta, decoder: U8.State, +expected: U32, +actual: U32, exact: Bool) -> Meta & EndResult:
  match exact:
    case True{}: end_utf8(meta,U8.finish(decoder))
    case False{}: (remember(meta,diagnostic(meta,7,expected,actual)),EndFailed{diagnostic(meta,7,expected,actual)})

def end_checked(+meta: Meta) -> Meta & EndResult:
  match meta:
    case Meta{root,position,active,decoder,cr,pending,lastCR,ended,Some{error}}: (meta,EndFailed{error})
    case Meta{root,position,active,decoder,cr,pending,lastCR,True{},None{}}: (remember(meta,diagnostic(meta,8,0,0)),EndFailed{diagnostic(meta,8,0,0)})
    case Meta{C.Range{run,origin,start,+end},+position,active,decoder,cr,pending,lastCR,False{},None{}}:
      end_exact(meta,decoder,end,byte(position),U32.is_eq(end,byte(position)))

def end_result(budget: B.Budget, scratch: Maybe<&1,S.ScalarChunk>, residual: Maybe<&1,B.Allocation>, p: Meta & EndResult) -> B.Budget & Input & EndResult:
  (meta,result) = p
  (budget,Input{scratch,residual,meta},result)

def end(budget: B.Budget, input: Input) -> B.Budget & Input & EndResult:
  match input:
    case Input{scratch,residual,meta}: end_result(budget,scratch,residual,end_checked(meta))

def dropped(meta: Meta, p: B.Budget & Result<&1,&2,E.Error & B.Allocation,Unit>) -> B.Budget & Maybe<&1,Input> & Maybe<&2,E.Error>:
  (budget,result) = p
  match result:
    case Done{u}: (budget,None{},None{})
    case Fail{pair}:
      (error,allocation) = pair
      (budget,Some{Input{None{},Some{allocation},meta}},Some{error})

def drop(budget: B.Budget, input: Input) -> B.Budget & Maybe<&1,Input> & Maybe<&2,E.Error>:
  match input:
    case Input{Some{scratch},None{},meta}: dropped(meta,S.drop(budget,scratch))
    case Input{None{},Some{allocation},meta}: dropped(meta,B.release(budget,allocation))
    case Input{None{},None{},meta}: (budget,None{},None{})
    case Input{scratch,residual,meta}: (budget,Some{Input{scratch,residual,meta}},Some{E.InternalInvariant{520}})
