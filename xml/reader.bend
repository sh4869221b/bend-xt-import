import Base
import ../core/budget.bend as B
import ../core/error.bend as E
import ../core/bytes.bend as Bytes
import ../core/cursor.bend as C
import ./types.bend as X
import ./input.bend as I
import ./text.bend as Text
import ./ownership.bend as O
import ./charges.bend as Charges
import ./tokenizer.bend as L
import ./xtranslator_v2.bend as Schema

type Stores is Type:
  Stores{params: Text.Arena, entry: Text.Arena}

type Info is Data:
  Info{lexer: L.State, schema: Schema.State, events: X.LexResult, eventIndex: U32, chunkIndex: U32, eof: X.Position, stage: U32, error: Maybe<&2,X.Diagnostic>}

type Reader is Type:
  Reader{claim: O.Claim, input: Maybe<&1,I.Input>, stores: Stores, spare: Maybe<&1,O.Claim>, +info: Info}

type ProvisionalEntry is Type:
  ProvisionalEntry{meta: X.EntryMeta, text: Text.Arena, claim: O.Claim}

type ValidatedDocument is Type:
  ValidatedDocument{params: X.ParamsMeta, count: U32, text: Text.Arena, claim: O.Claim}

type BeginResult is Type:
  ReaderReady{reader: Reader}
  ReaderInitFailed{diagnostic: X.Diagnostic, residual: Maybe<&1,Reader>}

type ReadResult is Type:
  ContinueRead{}
  WantScalar{}
  ReadMore{}
  EntryReady{entry: ProvisionalEntry}
  ReadFailed{diagnostic: X.Diagnostic}

type FinishResult is Type:
  Finishing{reader: Reader}
  Finished{document: ValidatedDocument}
  FinishEntry{reader: Reader, entry: ProvisionalEntry}
  FinishFailed{reader: Reader, diagnostic: X.Diagnostic}

def logical(width: U32) -> B.Six:
  B.Six{0,0,0,width,0,0}

def source(root: C.Range) -> X.SourceKey:
  match root:
    case C.Range{run,origin,start,end}: X.SourceKey{run,origin}

def initial(root: C.Range, +limits: X.Limits) -> Info:
  match limits:
    case X.Limits{sourceBytes,depth,entries,entryTextBytes,paramsTextBytes,names,references,fuzCount,fuzTextBytes}:
      Info{L.init(names,references),Schema.init(source(root),limits),X.no_events(),0,0,X.zero_position(),0,None{}}

def context(+info: Info, diagnostic: X.Diagnostic) -> X.Diagnostic:
  match info:
    case Info{lexer,schema,events,eventIndex,chunkIndex,eof,stage,error}: Schema.context(schema,diagnostic)

def set_error(+info: Info, diagnostic: X.Diagnostic) -> Info:
  match info:
    case Info{lexer,schema,events,eventIndex,chunkIndex,eof,stage,None{}}: Info{lexer,schema,events,eventIndex,chunkIndex,eof,stage,Some{diagnostic}}
    case old: old

def set_info(reader: Reader, +info: Info) -> Reader:
  match reader:
    case Reader{claim,input,stores,spare,old}: Reader{claim,input,stores,spare,info}

def first_error(info: Info, diagnostic: X.Diagnostic) -> X.Diagnostic:
  match info:
    case Info{lexer,schema,events,eventIndex,chunkIndex,eof,stage,Some{error}}: error
    case Info{lexer,schema,events,eventIndex,chunkIndex,eof,stage,None{}}: Schema.context(schema,diagnostic)

def failure(budget: B.Budget, reader: Reader, diagnostic: X.Diagnostic) -> B.Budget & Reader & ReadResult:
  match reader:
    case Reader{claim,input,stores,spare,+info}:
      +error = {first_error(info,diagnostic): X.Diagnostic}
      (budget,Reader{claim,input,stores,spare,set_error(info,error)},ReadFailed{error})

def schema_info(+info: Info, schema: Schema.State) -> Info:
  match info:
    case Info{lexer,old,events,eventIndex,chunkIndex,eof,stage,error}: Info{lexer,schema,events,U32.inc(eventIndex),chunkIndex,eof,stage,error}

def lexer_info(+info: Info, lexer: L.State, events: X.LexResult, index: U32) -> Info:
  match info:
    case Info{old,schema,oldEvents,eventIndex,chunkIndex,eof,stage,error}: Info{lexer,schema,events,0,index,eof,stage,error}

def set_index(+info: Info, index: U32) -> Info:
  match info:
    case Info{lexer,schema,events,eventIndex,old,eof,stage,error}: Info{lexer,schema,events,eventIndex,index,eof,stage,error}

def current_index(+info: Info) -> U32:
  match info:
    case Info{lexer,schema,events,eventIndex,chunkIndex,eof,stage,error}: chunkIndex

def current_error(+info: Info) -> Maybe<&2,X.Diagnostic>:
  match info:
    case Info{lexer,schema,events,eventIndex,chunkIndex,eof,stage,error}: error

def limits_valid(limits: X.Limits) -> Bool:
  match limits:
    case X.Limits{a,+b,c,d,e,f,g,h,i}:
      Bool.and(U32.is_le(a,67108864),Bool.and(Bool.and(U32.is_gt(b,0),U32.is_le(b,64)),Bool.and(U32.is_le(c,200000),Bool.and(U32.is_le(d,1048576),Bool.and(U32.is_le(e,4096),Bool.and(U32.is_le(f,64),Bool.and(U32.is_le(g,64),Bool.and(U32.is_le(h,4096),U32.is_le(i,4096)))))))))

def input_init_failure(claim: O.Claim,+info: Info,input: Maybe<&1,I.Input>,budget: B.Budget,+diagnostic: X.Diagnostic) -> B.Budget & BeginResult:
  (budget,ReaderInitFailed{diagnostic,Some{Reader{claim,input,Stores{Text.empty(),Text.empty()},None{},set_error(info,diagnostic)}}})

def init_input(claim: O.Claim, +info: Info, p: B.Budget & I.BeginResult) -> B.Budget & BeginResult:
  (budget,result) = p
  match result:
    case I.InputReady{input}: (budget,ReaderReady{Reader{claim,Some{input},Stores{Text.empty(),Text.empty()},None{},info}})
    case I.InitFailed{diagnostic,input}: input_init_failure(claim,info,input,budget,context(info,diagnostic))

def init_claim(+root: C.Range, +limits: X.Limits, p: B.Budget & O.Outcome) -> B.Budget & BeginResult:
  match limits:
    case X.Limits{sourceBytes,depth,entries,entryTextBytes,paramsTextBytes,names,references,fuzCount,fuzTextBytes}:
      (budget,result) = p
      match result:
        case O.ClaimReady{claim}: init_input(claim,initial(root,limits),I.begin(budget,root,sourceBytes))
        case O.ClaimFailed{error,None{}}: (budget,ReaderInitFailed{context(initial(root,limits),X.core_error(4,1,X.zero_position(),error)),None{}})
        case O.ClaimFailed{+error,Some{claim}}: (budget,ReaderInitFailed{context(initial(root,limits),X.core_error(4,1,X.zero_position(),error)),Some{Reader{claim,None{},Stores{Text.empty(),Text.empty()},None{},set_error(initial(root,limits),context(initial(root,limits),X.core_error(4,1,X.zero_position(),error)))}}})

def begin_valid(budget: B.Budget, root: C.Range, limits: X.Limits, okay: Bool) -> B.Budget & BeginResult:
  match okay:
    case False{}: (budget,ReaderInitFailed{X.with_source(X.error(4,2,X.zero_position(),0,0),source(root)),None{}})
    case True{}: init_claim(root,limits,O.acquire(budget,Charges.reader()))

def begin(budget: B.Budget, root: C.Range, +limits: X.Limits) -> B.Budget & BeginResult:
  begin_valid(budget,root,limits,limits_valid(limits))

def store_written(other: Text.Arena, target: U32, p: B.Budget & Text.Arena & Result<&2,&2,E.Error,Unit>) -> B.Budget & Stores & Result<&2,&2,E.Error,Unit>:
  match target:
    case 0:
      (budget,text,result) = p
      (budget,Stores{text,other},result)
    case _:
      (budget,text,result) = p
      (budget,Stores{other,text},result)

def store_append(budget: B.Budget, stores: Stores, target: U32, value: U32) -> B.Budget & Stores & Result<&2,&2,E.Error,Unit>:
  match stores target:
    case Stores{params,entry} 0: store_written(entry,0,Text.append(budget,params,value))
    case Stores{params,entry} _: store_written(params,1,Text.append(budget,entry,value))

def action_written(claim: O.Claim, input: Maybe<&1,I.Input>, spare: Maybe<&1,O.Claim>, +old: Info, +next: Info, at: X.Position, p: B.Budget & Stores & Result<&2,&2,E.Error,Unit>) -> B.Budget & Reader & ReadResult:
  (budget,stores,result) = p
  match result:
    case Done{u}: (budget,Reader{claim,input,stores,spare,next},ContinueRead{})
    case Fail{error}: failure(budget,Reader{claim,input,stores,spare,old},X.core_error(4,3,at,error))

def charged(reader: Reader, +next: Info, target: U32, value: U32, at: X.Position, p: B.Budget & Result<&2,&2,E.Error,Unit>) -> B.Budget & Reader & ReadResult:
  match reader:
    case Reader{claim,input,stores,spare,old}:
      match target:
        case 2:
          (budget,result) = p
          match result:
            case Done{u}: (budget,Reader{claim,input,stores,spare,next},ContinueRead{})
            case Fail{error}: failure(budget,Reader{claim,input,stores,spare,old},X.core_error(4,4,at,error))
        case _:
          (budget,result) = p
          match result:
            case Done{u}: action_written(claim,input,spare,old,next,at,store_append(budget,stores,target,value))
            case Fail{error}: failure(budget,Reader{claim,input,stores,spare,old},X.core_error(4,4,at,error))

def entry_sealed(at: X.Position, claim: O.Claim, input: Maybe<&1,I.Input>, params: Text.Arena, wrapper: O.Claim, +old: Info, +next: Info, +meta: X.EntryMeta, p: B.Budget & Text.Arena & Result<&2,&2,E.Error,Unit>) -> B.Budget & Reader & ReadResult:
  (budget,entry,result) = p
  match result:
    case Done{u}: (budget,Reader{claim,input,Stores{params,Text.empty()},None{},next},EntryReady{ProvisionalEntry{meta,entry,wrapper}})
    case Fail{error}: failure(budget,Reader{claim,input,Stores{params,entry},Some{wrapper},old},X.core_error(4,5,at,error))

def yield_claim(at: X.Position, claim: O.Claim, input: Maybe<&1,I.Input>, stores: Stores, +old: Info, +next: Info, meta: X.EntryMeta, p: B.Budget & O.Outcome) -> B.Budget & Reader & ReadResult:
  match stores:
    case Stores{params,entry}:
      (budget,result) = p
      match result:
        case O.ClaimFailed{error,residual}: failure(budget,Reader{claim,input,Stores{params,entry},residual,old},X.core_error(4,6,at,error))
        case O.ClaimReady{wrapper}: entry_sealed(at,claim,input,params,wrapper,old,next,meta,Text.seal(budget,entry))

def yield_entry(at: X.Position, budget: B.Budget, reader: Reader, +next: Info, meta: X.EntryMeta) -> B.Budget & Reader & ReadResult:
  match reader:
    case Reader{claim,input,stores,None{},old}: yield_claim(at,claim,input,stores,old,next,meta,O.acquire(budget,Charges.entry()))
    case other: failure(budget,other,X.error(4,7,X.zero_position(),0,0))

def event_at(event: X.XmlEvent) -> X.Position:
  match event:
    case X.EvOpen{name,at}: at
    case X.EvAttribute{name,at}: at
    case X.EvAttributeScalar{value,origin,span}: X.start(span)
    case X.EvAttributeEnd{end}: end
    case X.EvStartEnd{empty,end}: end
    case X.EvClose{name,span}: X.start(span)
    case X.EvText{value,origin,span}: X.start(span)

def execute_action(budget: B.Budget, reader: Reader, +next: Info, at: X.Position, action: Schema.Action) -> B.Budget & Reader & ReadResult:
  match action:
    case Schema.NoAction{}: (budget,set_info(reader,next),ContinueRead{})
    case Schema.AppendParams{value,width}: charged(reader,next,0,value,at,B.consume(budget,logical(width)))
    case Schema.AppendEntry{value,width}: charged(reader,next,1,value,at,B.consume(budget,logical(width)))
    case Schema.ChargeText{width}: charged(reader,next,2,0,at,B.consume(budget,logical(width)))
    case Schema.YieldEntry{meta}: yield_entry(at,budget,reader,next,meta)

def applied(budget: B.Budget, reader: Reader, +info: Info, at: X.Position, result: Schema.Step) -> B.Budget & Reader & ReadResult:
  match result:
    case Schema.Advance{state,operation}: execute_action(budget,reader,schema_info(info,state),at,operation)
    case Schema.Rejected{state,diagnostic}: failure(budget,reader,diagnostic)

def apply_event(budget: B.Budget, reader: Reader, +event: X.XmlEvent) -> B.Budget & Reader & ReadResult:
  match reader:
    case Reader{claim,input,stores,spare,Info{lexer,+schema,events,eventIndex,chunkIndex,eof,stage,error}}:
      +info = {Info{lexer,schema,events,eventIndex,chunkIndex,eof,stage,error}: Info}
      applied(budget,Reader{claim,input,stores,spare,info},info,event_at(event),Schema.apply(schema,event))

def event_slot(events: X.LexResult, index: U32) -> X.EventSlot:
  match events index:
    case X.Events{count,a,b,c} 0: a
    case X.Events{count,a,b,c} 1: b
    case X.Events{count,a,b,c} 2: c
    case _ _: X.NoEvent{}

def pending_slot(budget: B.Budget, reader: Reader, slot: X.EventSlot) -> B.Budget & Reader & ReadResult:
  match slot:
    case X.NoEvent{}: (budget,reader,WantScalar{})
    case X.SomeEvent{event}: apply_event(budget,reader,event)

def pending_checked(budget: B.Budget, reader: Reader, events: X.LexResult, index: U32, error: Maybe<&2,X.Diagnostic>) -> B.Budget & Reader & ReadResult:
  match error:
    case Some{diagnostic}: (budget,reader,ReadFailed{diagnostic})
    case None{}: pending_slot(budget,reader,event_slot(events,index))

def pending(budget: B.Budget, reader: Reader) -> B.Budget & Reader & ReadResult:
  match reader:
    case Reader{claim,input,stores,spare,Info{lexer,schema,+events,+eventIndex,chunkIndex,eof,stage,+error}}:
      pending_checked(budget,Reader{claim,input,stores,spare,Info{lexer,schema,events,eventIndex,chunkIndex,eof,stage,error}},events,eventIndex,error)

def lexed(claim: O.Claim, input: I.Input, stores: Stores, spare: Maybe<&1,O.Claim>, +info: Info, index: U32, budget: B.Budget, p: L.State & X.LexResult) -> B.Budget & Reader & ReadResult:
  (lexer,+events) = p
  match events:
    case X.LexFailed{diagnostic}: failure(budget,Reader{claim,Some{input},stores,spare,lexer_info(info,lexer,events,index)},diagnostic)
    case _: (budget,Reader{claim,Some{input},stores,spare,lexer_info(info,lexer,events,index)},ContinueRead{})


def attach_bytes(bytes: Bytes.OwnedBytes, p: B.Budget & Reader & ReadResult) -> B.Budget & Reader & Bytes.OwnedBytes & U32 & ReadResult:
  (budget,reader,result) = p
  match reader:
    case Reader{claim,input,stores,spare,+info}: (budget,Reader{claim,input,stores,spare,info},bytes,current_index(info),result)

def current_lexer(+info: Info) -> L.State:
  match info:
    case Info{lexer,schema,events,eventIndex,chunkIndex,eof,stage,error}: lexer

def input_progress(claim: O.Claim, stores: Stores, spare: Maybe<&1,O.Claim>, +info: Info, p: B.Budget & I.Input & Bytes.OwnedBytes & U32 & I.InputResult) -> B.Budget & Reader & Bytes.OwnedBytes & U32 & ReadResult:
  (budget,input,bytes,+index,result) = p
  match result:
    case I.ScalarReady{scalar}: attach_bytes(bytes,lexed(claim,input,stores,spare,info,index,budget,L.push(current_lexer(info),scalar)))
    case I.NeedInput{}: (budget,Reader{claim,Some{input},stores,spare,set_index(info,index)},bytes,index,ReadMore{})
    case I.InputFailed{diagnostic}: attach_bytes(bytes,failure(budget,Reader{claim,Some{input},stores,spare,set_index(info,index)},diagnostic))
    case I.ContinueInput{}: attach_bytes(bytes,failure(budget,Reader{claim,Some{input},stores,spare,set_index(info,index)},X.error(4,8,X.zero_position(),0,0)))

def request_scalar(budget: B.Budget, reader: Reader, range: C.Range, bytes: Bytes.OwnedBytes) -> B.Budget & Reader & Bytes.OwnedBytes & U32 & ReadResult:
  match reader:
    case Reader{claim,Some{input},stores,spare,info}: input_progress(claim,stores,spare,info,I.next(budget,input,range,bytes))
    case other: attach_bytes(bytes,failure(budget,other,X.error(4,9,X.zero_position(),0,0)))

def resume_one(range: C.Range, bytes: Bytes.OwnedBytes, p: B.Budget & Reader & ReadResult) -> B.Budget & Reader & Bytes.OwnedBytes & U32 & ReadResult:
  (budget,reader,result) = p
  match result:
    case WantScalar{}: request_scalar(budget,reader,range,bytes)
    case other: attach_bytes(bytes,(budget,reader,other))

def pump_exhausted(p: B.Budget & Reader & Bytes.OwnedBytes & U32 & ReadResult) -> B.Budget & Reader & Bytes.OwnedBytes & U32 & ReadResult:
  (budget,reader,bytes,index,result) = p
  match result:
    case ContinueRead{}: attach_bytes(bytes,failure(budget,reader,X.error(4,10,X.zero_position(),0,0)))
    case other: (budget,reader,bytes,index,other)

def pump(fuel: Nat, +range: C.Range, p: B.Budget & Reader & Bytes.OwnedBytes & U32 & ReadResult) -> B.Budget & Reader & Bytes.OwnedBytes & U32 & ReadResult:
  match fuel:
    case 0n: pump_exhausted(p)
    case 1n+rest:
      (budget,reader,bytes,index,result) = p
      match result:
        case ContinueRead{}: pump(rest,range,resume_one(range,bytes,pending(budget,reader)))
        case other: (budget,reader,bytes,index,other)

def resume_valid(budget: B.Budget, reader: Reader, range: C.Range, bytes: Bytes.OwnedBytes, length: U32, okay: Bool) -> B.Budget & Reader & Bytes.OwnedBytes & U32 & ReadResult:
  match okay:
    case False{}: attach_bytes(bytes,failure(budget,reader,X.error(4,11,X.zero_position(),65536,length)))
    case True{}: pump(U32.to_nat(U32.add(U32.mul(length,4),32)),range,(budget,reader,bytes,0,ContinueRead{}))

def resume_meta(budget: B.Budget, reader: Reader, range: C.Range, p: Bytes.OwnedBytes & U32 & U32 & U32 & U32) -> B.Budget & Reader & Bytes.OwnedBytes & U32 & ReadResult:
  (bytes,+length,capacity,run,origin) = p
  resume_valid(budget,reader,range,bytes,length,U32.is_le(length,65536))

def resume(budget: B.Budget, reader: Reader, range: C.Range, bytes: Bytes.OwnedBytes) -> B.Budget & Reader & Bytes.OwnedBytes & U32 & ReadResult:
  match reader:
    case Reader{claim,input,stores,spare,Info{lexer,schema,events,eventIndex,chunkIndex,eof,0,error}}:
      resume_meta(budget,Reader{claim,input,stores,spare,Info{lexer,schema,events,eventIndex,chunkIndex,eof,0,error}},range,Bytes.metadata(bytes))
    case other: attach_bytes(bytes,failure(budget,other,X.error(4,20,X.zero_position(),0,0)))

# All cleanup operations return the remaining owner when a release fails.
def residual_text(arena: Maybe<&1,Text.Arena>) -> Text.Arena:
  match arena:
    case None{}: Text.empty()
    case Some{arena}: arena

def root_released(+info: Info, p: B.Budget & Result<&1,&2,E.Error & O.Claim,Unit>) -> B.Budget & Maybe<&1,Reader> & Maybe<&2,E.Error>:
  (budget,result) = p
  match result:
    case Done{u}: (budget,None{},None{})
    case Fail{pair}:
      (error,claim) = pair
      (budget,Some{Reader{claim,None{},Stores{Text.empty(),Text.empty()},None{},info}},Some{error})

def spare_released(claim: O.Claim, +info: Info, p: B.Budget & Result<&1,&2,E.Error & O.Claim,Unit>) -> B.Budget & Maybe<&1,Reader> & Maybe<&2,E.Error>:
  (budget,result) = p
  match result:
    case Done{u}: root_released(info,O.release(budget,claim))
    case Fail{pair}:
      (error,spare) = pair
      (budget,Some{Reader{claim,None{},Stores{Text.empty(),Text.empty()},Some{spare},info}},Some{error})

def drop_claims(budget: B.Budget, claim: O.Claim, spare: Maybe<&1,O.Claim>, +info: Info) -> B.Budget & Maybe<&1,Reader> & Maybe<&2,E.Error>:
  match spare:
    case None{}: root_released(info,O.release(budget,claim))
    case Some{spare}: spare_released(claim,info,O.release(budget,spare))

def params_dropped(claim: O.Claim, spare: Maybe<&1,O.Claim>, +info: Info, p: B.Budget & Maybe<&1,Text.Arena> & Maybe<&2,E.Error>) -> B.Budget & Maybe<&1,Reader> & Maybe<&2,E.Error>:
  (budget,params,error) = p
  match params error:
    case None{} None{}: drop_claims(budget,claim,spare,info)
    case other error: (budget,Some{Reader{claim,None{},Stores{residual_text(other),Text.empty()},spare,info}},error)

def entry_dropped(claim: O.Claim, params: Text.Arena, spare: Maybe<&1,O.Claim>, +info: Info, p: B.Budget & Maybe<&1,Text.Arena> & Maybe<&2,E.Error>) -> B.Budget & Maybe<&1,Reader> & Maybe<&2,E.Error>:
  (budget,entry,error) = p
  match entry error:
    case None{} None{}: params_dropped(claim,spare,info,Text.drop(budget,params))
    case other error: (budget,Some{Reader{claim,None{},Stores{params,residual_text(other)},spare,info}},error)

def drop_stores(budget: B.Budget, claim: O.Claim, stores: Stores, spare: Maybe<&1,O.Claim>, +info: Info) -> B.Budget & Maybe<&1,Reader> & Maybe<&2,E.Error>:
  match stores:
    case Stores{params,entry}: entry_dropped(claim,params,spare,info,Text.drop(budget,entry))

def input_dropped(claim: O.Claim, stores: Stores, spare: Maybe<&1,O.Claim>, +info: Info, p: B.Budget & Maybe<&1,I.Input> & Maybe<&2,E.Error>) -> B.Budget & Maybe<&1,Reader> & Maybe<&2,E.Error>:
  (budget,input,error) = p
  match input error:
    case None{} None{}: drop_stores(budget,claim,stores,spare,info)
    case other error: (budget,Some{Reader{claim,other,stores,spare,info}},error)

def drop(budget: B.Budget, reader: Reader) -> B.Budget & Maybe<&1,Reader> & Maybe<&2,E.Error>:
  match reader:
    case Reader{claim,None{},stores,spare,info}: drop_stores(budget,claim,stores,spare,info)
    case Reader{claim,Some{input},stores,spare,info}: input_dropped(claim,stores,spare,info,I.drop(budget,input))

def entry_claim_dropped(meta: X.EntryMeta, p: B.Budget & Result<&1,&2,E.Error & O.Claim,Unit>) -> B.Budget & Maybe<&1,ProvisionalEntry> & Maybe<&2,E.Error>:
  (budget,result) = p
  match result:
    case Done{u}: (budget,None{},None{})
    case Fail{pair}:
      (error,claim) = pair
      (budget,Some{ProvisionalEntry{meta,Text.empty(),claim}},Some{error})

def entry_text_dropped(meta: X.EntryMeta, claim: O.Claim, p: B.Budget & Maybe<&1,Text.Arena> & Maybe<&2,E.Error>) -> B.Budget & Maybe<&1,ProvisionalEntry> & Maybe<&2,E.Error>:
  (budget,text,error) = p
  match text error:
    case None{} None{}: entry_claim_dropped(meta,O.release(budget,claim))
    case other error: (budget,Some{ProvisionalEntry{meta,residual_text(other),claim}},error)

def drop_entry(budget: B.Budget, entry: ProvisionalEntry) -> B.Budget & Maybe<&1,ProvisionalEntry> & Maybe<&2,E.Error>:
  match entry:
    case ProvisionalEntry{meta,text,claim}: entry_text_dropped(meta,claim,Text.drop(budget,text))

def entry_next_result(meta: X.EntryMeta, claim: O.Claim, p: B.Budget & Text.Arena & Result<&2,&2,E.Error,Maybe<&2,U32>>) -> B.Budget & ProvisionalEntry & Result<&2,&2,E.Error,Maybe<&2,U32>>:
  (budget,text,result) = p
  (budget,ProvisionalEntry{meta,text,claim},result)

def entry_next(budget: B.Budget, entry: ProvisionalEntry) -> B.Budget & ProvisionalEntry & Result<&2,&2,E.Error,Maybe<&2,U32>>:
  match entry:
    case ProvisionalEntry{meta,text,claim}: entry_next_result(meta,claim,Text.next(budget,text))

def entry_metadata(entry: ProvisionalEntry) -> ProvisionalEntry & X.EntryMeta:
  match entry:
    case ProvisionalEntry{+meta,text,claim}: (ProvisionalEntry{meta,text,claim},meta)

def document_claim_dropped(params: X.ParamsMeta, count: U32, p: B.Budget & Result<&1,&2,E.Error & O.Claim,Unit>) -> B.Budget & Maybe<&1,ValidatedDocument> & Maybe<&2,E.Error>:
  (budget,result) = p
  match result:
    case Done{u}: (budget,None{},None{})
    case Fail{pair}:
      (error,claim) = pair
      (budget,Some{ValidatedDocument{params,count,Text.empty(),claim}},Some{error})

def document_text_dropped(params: X.ParamsMeta, count: U32, claim: O.Claim, p: B.Budget & Maybe<&1,Text.Arena> & Maybe<&2,E.Error>) -> B.Budget & Maybe<&1,ValidatedDocument> & Maybe<&2,E.Error>:
  (budget,text,error) = p
  match text error:
    case None{} None{}: document_claim_dropped(params,count,O.release(budget,claim))
    case other error: (budget,Some{ValidatedDocument{params,count,residual_text(other),claim}},error)

def drop_document(budget: B.Budget, document: ValidatedDocument) -> B.Budget & Maybe<&1,ValidatedDocument> & Maybe<&2,E.Error>:
  match document:
    case ValidatedDocument{params,count,text,claim}: document_text_dropped(params,count,claim,Text.drop(budget,text))

def document_next_result(params: X.ParamsMeta, count: U32, claim: O.Claim, p: B.Budget & Text.Arena & Result<&2,&2,E.Error,Maybe<&2,U32>>) -> B.Budget & ValidatedDocument & Result<&2,&2,E.Error,Maybe<&2,U32>>:
  (budget,text,result) = p
  (budget,ValidatedDocument{params,count,text,claim},result)

def document_next(budget: B.Budget, document: ValidatedDocument) -> B.Budget & ValidatedDocument & Result<&2,&2,E.Error,Maybe<&2,U32>>:
  match document:
    case ValidatedDocument{params,count,text,claim}: document_next_result(params,count,claim,Text.next(budget,text))

def document_metadata(document: ValidatedDocument) -> ValidatedDocument & X.ParamsMeta & U32:
  match document:
    case ValidatedDocument{+params,+count,text,claim}: (ValidatedDocument{params,count,text,claim},params,count)

# EOF is an affine transition: provisional entries remain explicitly owned,
# and only this successful terminal result authorizes use of the whole document.
def stage_info(+info: Info, stage: U32, eof: X.Position) -> Info:
  match info:
    case Info{lexer,schema,events,eventIndex,chunkIndex,oldEof,oldStage,error}: Info{lexer,schema,events,eventIndex,chunkIndex,eof,stage,error}

def eof_info(+info: Info) -> X.Position:
  match info:
    case Info{lexer,schema,events,eventIndex,chunkIndex,eof,stage,error}: eof

def finish_failure(p: B.Budget & Reader & ReadResult) -> B.Budget & FinishResult:
  (budget,reader,result) = p
  match result:
    case ReadFailed{diagnostic}: (budget,FinishFailed{reader,diagnostic})
    case EntryReady{entry}: (budget,FinishEntry{reader,entry})
    case _: (budget,Finishing{reader})

def final_params(claim: O.Claim, +info: Info, summary: Schema.Summary, p: B.Budget & Text.Arena & Result<&2,&2,E.Error,Unit>) -> B.Budget & FinishResult:
  match summary:
    case Schema.Summary{meta,count}:
      (budget,params,result) = p
      match result:
        case Done{u}: (budget,Finished{ValidatedDocument{meta,count,params,claim}})
        case Fail{error}: finish_failure(failure(budget,Reader{claim,None{},Stores{params,Text.empty()},None{},info},X.core_error(4,12,eof_info(info),error)))

def final_entry(claim: O.Claim, params: Text.Arena, +info: Info, summary: Schema.Summary, p: B.Budget & Maybe<&1,Text.Arena> & Maybe<&2,E.Error>) -> B.Budget & FinishResult:
  (budget,entry,error) = p
  match entry error:
    case None{} None{}: final_params(claim,info,summary,Text.seal(budget,params))
    case other Some{error}: finish_failure(failure(budget,Reader{claim,None{},Stores{params,residual_text(other)},None{},info},X.core_error(4,13,eof_info(info),error)))
    case other None{}: finish_failure(failure(budget,Reader{claim,None{},Stores{params,residual_text(other)},None{},info},X.error(4,14,eof_info(info),0,0)))

def final_stores(budget: B.Budget, claim: O.Claim, stores: Stores, +info: Info, summary: Schema.Summary) -> B.Budget & FinishResult:
  match stores:
    case Stores{params,entry}: final_entry(claim,params,info,summary,Text.drop(budget,entry))

def final_input(claim: O.Claim, stores: Stores, +info: Info, summary: Schema.Summary, p: B.Budget & Maybe<&1,I.Input> & Maybe<&2,E.Error>) -> B.Budget & FinishResult:
  (budget,input,error) = p
  match input error:
    case None{} None{}: final_stores(budget,claim,stores,info,summary)
    case other Some{error}: finish_failure(failure(budget,Reader{claim,other,stores,None{},info},X.core_error(4,15,eof_info(info),error)))
    case other None{}: finish_failure(failure(budget,Reader{claim,other,stores,None{},info},X.error(4,16,eof_info(info),0,0)))

def final_schema(budget: B.Budget, reader: Reader, result: Result<&2,&2,X.Diagnostic,Schema.Summary>) -> B.Budget & FinishResult:
  match reader result:
    case Reader{claim,Some{input},stores,None{},info} Done{summary}: final_input(claim,stores,info,summary,I.drop(budget,input))
    case other Fail{diagnostic}: finish_failure(failure(budget,other,diagnostic))
    case other Done{summary}: finish_failure(failure(budget,other,X.error(4,17,X.zero_position(),0,0)))

def finish_lexed(claim: O.Claim, input: Maybe<&1,I.Input>, stores: Stores, spare: Maybe<&1,O.Claim>, +info: Info, budget: B.Budget, p: L.State & X.LexResult) -> B.Budget & FinishResult:
  (lexer,+events) = p
  match events:
    case X.LexFailed{diagnostic}: finish_failure(failure(budget,Reader{claim,input,stores,spare,stage_info(lexer_info(info,lexer,events,current_index(info)),3,eof_info(info))},diagnostic))
    case _: (budget,Finishing{Reader{claim,input,stores,spare,stage_info(lexer_info(info,lexer,events,current_index(info)),3,eof_info(info))}})

def ended_input(claim: O.Claim, stores: Stores, spare: Maybe<&1,O.Claim>, +info: Info, p: B.Budget & I.Input & I.EndResult) -> B.Budget & FinishResult:
  (budget,input,result) = p
  match result:
    case I.EndScalar{scalar}: finish_failure(lexed(claim,input,stores,spare,info,current_index(info),budget,L.push(current_lexer(info),scalar)))
    case I.EndDone{at}: (budget,Finishing{Reader{claim,Some{input},stores,spare,stage_info(info,2,at)}})
    case I.EndFailed{diagnostic}: finish_failure(failure(budget,Reader{claim,Some{input},stores,spare,info},diagnostic))

def finish_stage(budget: B.Budget, reader: Reader) -> B.Budget & FinishResult:
  match reader:
    case Reader{claim,Some{input},stores,spare,Info{lexer,schema,events,eventIndex,chunkIndex,eof,1,error}}:
      ended_input(claim,stores,spare,Info{lexer,schema,events,eventIndex,chunkIndex,eof,1,error},I.end(budget,input))
    case Reader{claim,input,stores,spare,Info{+lexer,schema,events,eventIndex,chunkIndex,+eof,2,error}}:
      finish_lexed(claim,input,stores,spare,Info{lexer,schema,events,eventIndex,chunkIndex,eof,2,error},budget,L.finish(lexer,eof))
    case Reader{claim,input,stores,spare,Info{lexer,+schema,events,eventIndex,chunkIndex,+eof,3,error}}:
      final_schema(budget,Reader{claim,input,stores,spare,Info{lexer,schema,events,eventIndex,chunkIndex,eof,3,error}},Schema.finish(schema,eof))
    case other: finish_failure(failure(budget,other,X.error(4,18,X.zero_position(),0,0)))

def finish_pending(p: B.Budget & Reader & ReadResult) -> B.Budget & FinishResult:
  (budget,reader,result) = p
  match result:
    case WantScalar{}: finish_stage(budget,reader)
    case other: finish_failure((budget,reader,other))

def finish_loop(fuel: Nat, p: B.Budget & FinishResult) -> B.Budget & FinishResult:
  match fuel:
    case 0n:
      (budget,result) = p
      match result:
        case Finishing{reader}: finish_failure(failure(budget,reader,X.error(4,19,X.zero_position(),0,0)))
        case other: (budget,other)
    case 1n+rest:
      (budget,result) = p
      match result:
        case Finishing{reader}: finish_loop(rest,finish_pending(pending(budget,reader)))
        case other: (budget,other)

def finish(budget: B.Budget, reader: Reader) -> B.Budget & FinishResult:
  match reader:
    case Reader{claim,input,stores,spare,Info{lexer,schema,events,eventIndex,chunkIndex,eof,0,error}}:
      finish_loop(32n,(budget,Finishing{Reader{claim,input,stores,spare,Info{lexer,schema,events,eventIndex,chunkIndex,eof,1,error}}}))
    case other: finish_loop(32n,(budget,Finishing{other}))
