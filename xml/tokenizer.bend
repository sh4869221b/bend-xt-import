import Base
import ./types.bend as T
import ./names.bend as Names
import ./numbers.bend as N

# All state is fixed size and covered by the enclosing Reader's live charge.
# Reasons: 1 syntax,2 unknown name,3 unsupported markup,4 reference,5 context,
# 6 unexpected EOF,7 token limit,8 declaration value,9 duplicate/late declaration.
type Context is Data:
  Context{depth: U32, root: Bool, declaration: Bool, canDeclare: Bool}

type RefTarget is Data:
  RefText{}
  RefAttribute{tag: U32, name: U32, quote: U32}

type Mode is Data:
  MText{brackets: U32}
  MMarkup{at: T.Position}
  MOpen{name: Names.Name}
  MTag{tag: U32}
  MAfterAttribute{tag: U32}
  MAttrName{tag: U32, name: Names.Name}
  MAttrEquals{tag: U32, name: U32}
  MAttrQuote{tag: U32, name: U32}
  MAttrValue{tag: U32, name: U32, quote: U32}
  MSelfClose{tag: U32}
  MClose{name: Names.Name, at: T.Position}
  MCloseSpace{name: U32, at: T.Position}
  MBang{at: T.Position}
  MCommentOpen{at: T.Position}
  MComment{at: T.Position, hyphens: U32}
  MCdataPrefix{at: T.Position, index: U32}
  MCdata{held: U32, first: T.Span, second: T.Span}
  MReference{target: RefTarget, at: T.Position, length: U32, kind: U32, name: Names.Name, number: N.Number}
  MDeclXml{at: T.Position, index: U32}
  MDeclSpace{at: T.Position, stage: U32}
  MDeclName{at: T.Position, stage: U32, name: Names.Name}
  MDeclEquals{at: T.Position, stage: U32, name: U32}
  MDeclQuote{at: T.Position, stage: U32, name: U32}
  MDeclValue{at: T.Position, stage: U32, name: U32, quote: U32, index: U32, variant: U32}
  MDeclAfter{at: T.Position, stage: U32}
  MDeclClose{at: T.Position}

type State is Data:
  LexReady{context: Context, mode: Mode, nameLimit: U32, referenceLimit: U32}
  LexBroken{diagnostic: T.Diagnostic}

def init(+nameLimit: U32, +referenceLimit: U32) -> State:
  LexReady{Context{0,False{},False{},True{}},MText{0},nameLimit,referenceLimit}

def fail_diagnostic(+diagnostic: T.Diagnostic) -> State & T.LexResult:
  (LexBroken{diagnostic},T.LexFailed{diagnostic})

def failed(+reason: U32, +at: T.Position, +expected: U32, +observed: U32) -> State & T.LexResult:
  fail_diagnostic(T.error(2,reason,at,expected,observed))

def next(+context: Context, +mode: Mode, +nl: U32, +rl: U32) -> State & T.LexResult:
  (LexReady{context,mode,nl,rl},T.no_events())

def emit(+context: Context, +mode: Mode, +nl: U32, +rl: U32, +result: T.LexResult) -> State & T.LexResult:
  (LexReady{context,mode,nl,rl},result)

def dirty(+context: Context) -> Context:
  match context:
    case Context{+depth,+root,+decl,+allowed}: Context{depth,root,decl,False{}}

def brackets(+value: U32, +previous: U32) -> U32:
  match value:
    case 93: U32.min(2,U32.inc(previous))
    case _: 0

def ordinary_valid(+context: Context, +nl: U32, +rl: U32, +previous: U32, +value: U32, +span: T.Span, +forbidden: Bool) -> State & T.LexResult:
  match forbidden:
    case True{}: failed(1,T.start(span),0,value)
    case False{}: emit(context,MText{brackets(value,previous)},nl,rl,T.one(T.EvText{value,T.Literal{},span}))

def outside(+context: Context, +nl: U32, +rl: U32, +value: U32, +span: T.Span, +valid: Bool) -> State & T.LexResult:
  match valid:
    case True{}: next(dirty(context),MText{0},nl,rl)
    case False{}: failed(5,T.start(span),32,value)

def reference(+context: Context, +nl: U32, +rl: U32, +target: RefTarget, +at: T.Position) -> State & T.LexResult:
  next(context,MReference{target,at,1,0,Names.start(65011712,at),N.begin(False{})},nl,rl)

def text_inside(+context: Context, +nl: U32, +rl: U32, +previous: U32, +value: U32, +span: T.Span) -> State & T.LexResult:
  match value:
    case 38: reference(context,nl,rl,RefText{},T.start(span))
    case _: ordinary_valid(context,nl,rl,previous,value,span,Bool.and(U32.is_eq(value,62),U32.is_eq(previous,2)))

def text_context(+context: Context, +nl: U32, +rl: U32, +previous: U32, +value: U32, +span: T.Span) -> State & T.LexResult:
  match context:
    case Context{0,+root,+decl,+allowed}: outside(Context{0,root,decl,allowed},nl,rl,value,span,T.whitespace(value))
    case Context{+depth,+root,+decl,+allowed}: text_inside(Context{depth,root,decl,allowed},nl,rl,previous,value,span)

def text(+context: Context, +nl: U32, +rl: U32, +previous: U32, +value: U32, +span: T.Span) -> State & T.LexResult:
  match value:
    case 60: next(context,MMarkup{T.start(span)},nl,rl)
    case _: text_context(context,nl,rl,previous,value,span)

def name_mode(+context: Context, +nl: U32, +rl: U32, +at: T.Position, +kind: U32, +tag: U32, +name: Names.Name) -> State & T.LexResult:
  match kind:
    case 0: next(context,MOpen{name},nl,rl)
    case 1: next(context,MAttrName{tag,name},nl,rl)
    case 2: next(context,MClose{name,at},nl,rl)
    case _: failed(1,at,0,kind)

def name_ready(+context: Context, +nl: U32, +rl: U32, +at: T.Position, +kind: U32, +tag: U32, +result: Result<&2, &2, U32, Names.Name>) -> State & T.LexResult:
  match result:
    case Fail{+reason}: failed(reason,at,0,0)
    case Done{+name}: name_mode(context,nl,rl,at,kind,tag,name)

def declaration_start(+context: Context, +nl: U32, +rl: U32, +at: T.Position) -> State & T.LexResult:
  match context:
    case Context{0,False{},False{},True{}}: next(context,MDeclXml{at,0},nl,rl)
    case _: failed(9,at,0,0)

def markup(+context: Context, +nl: U32, +rl: U32, +at: T.Position, +value: U32, +span: T.Span) -> State & T.LexResult:
  match value:
    case 47: next(dirty(context),MClose{Names.start(8191,T.start(span)),at},nl,rl)
    case 33: next(dirty(context),MBang{at},nl,rl)
    case 63: declaration_start(context,nl,rl,at)
    case _: name_ready(dirty(context),nl,rl,at,0,0,Names.push(Names.start(8191,at),value,nl))

def started(+context: Context, +empty: Bool) -> Context:
  match context empty:
    case Context{+depth,+root,+decl,+allowed} True{}: Context{depth,True{},decl,False{}}
    case Context{+depth,+root,+decl,+allowed} False{}: Context{U32.inc(depth),True{},decl,False{}}

def start_events(+context: Context, +nl: U32, +rl: U32, +empty: Bool, +end: T.Position, +leading: T.EventSlot) -> State & T.LexResult:
  match leading:
    case T.NoEvent{}: emit(context,MText{0},nl,rl,T.one(T.EvStartEnd{empty,end}))
    case T.SomeEvent{+event}: emit(context,MText{0},nl,rl,T.two(event,T.EvStartEnd{empty,end}))

def start_end(+context: Context, +nl: U32, +rl: U32, +empty: Bool, +span: T.Span, +leading: T.EventSlot) -> State & T.LexResult:
  match context:
    case Context{0,True{},+decl,+allowed}: failed(5,T.start(span),0,0)
    case _: start_events(started(context,empty),nl,rl,empty,T.end(span),leading)

def open_delimiter_case2(+context: Context, +nl: U32, +rl: U32, +at: T.Position, +id: U32, +value: U32, +span: T.Span, +hit: Bool) -> State & T.LexResult:
  match hit:
    case True{}: emit(context,MSelfClose{id},nl,rl,T.one(T.EvOpen{id,at}))
    case False{}: emit(context,MTag{id},nl,rl,T.one(T.EvOpen{id,at}))

def open_delimiter_case1(+context: Context, +nl: U32, +rl: U32, +at: T.Position, +id: U32, +value: U32, +span: T.Span, +hit: Bool) -> State & T.LexResult:
  match hit:
    case True{}: start_end(context,nl,rl,False{},span,T.SomeEvent{T.EvOpen{id,at}})
    case False{}: open_delimiter_case2(context,nl,rl,at,id,value,span,U32.is_eq(value,47))

def open_delimiter_case0(+context: Context, +nl: U32, +rl: U32, +at: T.Position, +id: U32, +value: U32, +span: T.Span, +hit: Bool) -> State & T.LexResult:
  match hit:
    case True{}: failed(2,at,0,value)
    case False{}: open_delimiter_case1(context,nl,rl,at,id,value,span,U32.is_eq(value,62))

def open_delimiter(+context: Context, +nl: U32, +rl: U32, +at: T.Position, +id: U32, +value: U32, +span: T.Span) -> State & T.LexResult:
  open_delimiter_case0(context,nl,rl,at,id,value,span,U32.is_eq(id,0))

def open_name(+context: Context, +nl: U32, +rl: U32, +name: Names.Name, +value: U32, +span: T.Span, +delimiter: Bool) -> State & T.LexResult:
  match delimiter:
    case True{}: open_delimiter(context,nl,rl,Names.position(name),Names.finish(name),value,span)
    case False{}: name_ready(context,nl,rl,Names.position(name),0,0,Names.push(name,value,nl))

def attr_selected_case1(+context: Context, +nl: U32, +rl: U32, +tag: U32, +id: U32, +at: T.Position, +value: U32, +hit: Bool) -> State & T.LexResult:
  match hit:
    case True{}: emit(context,MAttrQuote{tag,id},nl,rl,T.one(T.EvAttribute{id,at}))
    case False{}: emit(context,MAttrEquals{tag,id},nl,rl,T.one(T.EvAttribute{id,at}))

def attr_selected_case0(+context: Context, +nl: U32, +rl: U32, +tag: U32, +id: U32, +at: T.Position, +value: U32, +hit: Bool) -> State & T.LexResult:
  match hit:
    case True{}: failed(2,at,0,value)
    case False{}: attr_selected_case1(context,nl,rl,tag,id,at,value,U32.is_eq(value,61))

def attr_selected(+context: Context, +nl: U32, +rl: U32, +tag: U32, +id: U32, +at: T.Position, +value: U32) -> State & T.LexResult:
  attr_selected_case0(context,nl,rl,tag,id,at,value,U32.is_eq(id,0))

def attr_name(+context: Context, +nl: U32, +rl: U32, +tag: U32, +name: Names.Name, +value: U32, +delimiter: Bool) -> State & T.LexResult:
  match delimiter:
    case True{}: attr_selected(context,nl,rl,tag,Names.finish(name),Names.position(name),value)
    case False{}: name_ready(context,nl,rl,Names.position(name),1,tag,Names.push(name,value,nl))

def tag_space(+context: Context, +nl: U32, +rl: U32, +tag: U32, +value: U32, +span: T.Span, +ws: Bool) -> State & T.LexResult:
  match ws:
    case True{}: next(context,MTag{tag},nl,rl)
    case False{}: name_ready(context,nl,rl,T.start(span),1,tag,Names.push(Names.start(253952,T.start(span)),value,nl))

def tag_input(+context: Context, +nl: U32, +rl: U32, +tag: U32, +value: U32, +span: T.Span) -> State & T.LexResult:
  match value:
    case 62: start_end(context,nl,rl,False{},span,T.NoEvent{})
    case 47: next(context,MSelfClose{tag},nl,rl)
    case _: tag_space(context,nl,rl,tag,value,span,T.whitespace(value))

def after_attribute(+context: Context, +nl: U32, +rl: U32, +tag: U32, +value: U32, +span: T.Span, +valid: Bool) -> State & T.LexResult:
  match valid:
    case False{}: failed(1,T.start(span),32,value)
    case True{}: tag_input(context,nl,rl,tag,value,span)

def attr_equals_case1(+context: Context, +nl: U32, +rl: U32, +tag: U32, +name: U32, +value: U32, +span: T.Span, +ws: Bool, +hit: Bool) -> State & T.LexResult:
  match hit:
    case True{}: next(context,MAttrEquals{tag,name},nl,rl)
    case False{}: failed(1,T.start(span),61,value)

def attr_equals_case0(+context: Context, +nl: U32, +rl: U32, +tag: U32, +name: U32, +value: U32, +span: T.Span, +ws: Bool, +hit: Bool) -> State & T.LexResult:
  match hit:
    case True{}: next(context,MAttrQuote{tag,name},nl,rl)
    case False{}: attr_equals_case1(context,nl,rl,tag,name,value,span,ws,ws)

def attr_equals(+context: Context, +nl: U32, +rl: U32, +tag: U32, +name: U32, +value: U32, +span: T.Span, +ws: Bool) -> State & T.LexResult:
  attr_equals_case0(context,nl,rl,tag,name,value,span,ws,U32.is_eq(value,61))

def attr_quote_case2(+context: Context, +nl: U32, +rl: U32, +tag: U32, +name: U32, +value: U32, +span: T.Span, +ws: Bool, +hit: Bool) -> State & T.LexResult:
  match hit:
    case True{}: next(context,MAttrQuote{tag,name},nl,rl)
    case False{}: failed(1,T.start(span),34,value)

def attr_quote_case1(+context: Context, +nl: U32, +rl: U32, +tag: U32, +name: U32, +value: U32, +span: T.Span, +ws: Bool, +hit: Bool) -> State & T.LexResult:
  match hit:
    case True{}: next(context,MAttrValue{tag,name,39},nl,rl)
    case False{}: attr_quote_case2(context,nl,rl,tag,name,value,span,ws,ws)

def attr_quote_case0(+context: Context, +nl: U32, +rl: U32, +tag: U32, +name: U32, +value: U32, +span: T.Span, +ws: Bool, +hit: Bool) -> State & T.LexResult:
  match hit:
    case True{}: next(context,MAttrValue{tag,name,34},nl,rl)
    case False{}: attr_quote_case1(context,nl,rl,tag,name,value,span,ws,U32.is_eq(value,39))

def attr_quote(+context: Context, +nl: U32, +rl: U32, +tag: U32, +name: U32, +value: U32, +span: T.Span, +ws: Bool) -> State & T.LexResult:
  attr_quote_case0(context,nl,rl,tag,name,value,span,ws,U32.is_eq(value,34))

def attr_normalized(+value: U32, +ws: Bool) -> U32:
  match ws:
    case True{}: 32
    case False{}: value

def attr_literal(+context: Context, +nl: U32, +rl: U32, +tag: U32, +name: U32, +quote: U32, +value: U32, +span: T.Span) -> State & T.LexResult:
  match value:
    case 60: failed(1,T.start(span),0,60)
    case 38: reference(context,nl,rl,RefAttribute{tag,name,quote},T.start(span))
    case _: emit(context,MAttrValue{tag,name,quote},nl,rl,T.one(T.EvAttributeScalar{attr_normalized(value,T.whitespace(value)),T.Literal{},span}))

def attr_value(+context: Context, +nl: U32, +rl: U32, +tag: U32, +name: U32, +quote: U32, +value: U32, +span: T.Span, +end: Bool) -> State & T.LexResult:
  match end:
    case True{}: emit(context,MAfterAttribute{tag},nl,rl,T.one(T.EvAttributeEnd{T.end(span)}))
    case False{}: attr_literal(context,nl,rl,tag,name,quote,value,span)

def close_emit(+context: Context, +nl: U32, +rl: U32, +name: U32, +at: T.Position, +end: T.Position) -> State & T.LexResult:
  match context:
    case Context{+depth,+root,+decl,+allowed}: emit(Context{U32.sub(depth,1),root,decl,False{}},MText{0},nl,rl,T.one(T.EvClose{name,T.Span{at,end}}))

def close_known(+context: Context, +nl: U32, +rl: U32, +name: U32, +at: T.Position, +end: T.Position, +valid: Bool) -> State & T.LexResult:
  match valid:
    case False{}: failed(2,at,0,0)
    case True{}: close_emit(context,nl,rl,name,at,end)

def close_nonzero(+context: Context, +nl: U32, +rl: U32, +name: U32, +at: T.Position, +end: T.Position, +valid: Bool) -> State & T.LexResult:
  match valid:
    case False{}: failed(5,at,0,name)
    case True{}: close_known(context,nl,rl,name,at,end,U32.is_gt(name,0))

def close_end(+context: Context, +nl: U32, +rl: U32, +name: U32, +at: T.Position, +end: T.Position) -> State & T.LexResult:
  match context:
    case Context{+depth,+root,+decl,+allowed}: close_nonzero(context,nl,rl,name,at,end,U32.is_gt(depth,0))

def close_resolved(+context: Context, +nl: U32, +rl: U32, +at: T.Position, +id: U32) -> State & T.LexResult:
  match id:
    case 0: failed(2,at,0,0)
    case _: next(context,MCloseSpace{id,at},nl,rl)

def close_delimiter(+context: Context, +nl: U32, +rl: U32, +name: Names.Name, +at: T.Position, +value: U32, +span: T.Span) -> State & T.LexResult:
  match value:
    case 62: close_end(context,nl,rl,Names.finish(name),at,T.end(span))
    case _: close_resolved(context,nl,rl,at,Names.finish(name))

def close_name(+context: Context, +nl: U32, +rl: U32, +name: Names.Name, +at: T.Position, +value: U32, +span: T.Span, +delimiter: Bool) -> State & T.LexResult:
  match delimiter:
    case True{}: close_delimiter(context,nl,rl,name,at,value,span)
    case False{}: name_ready(context,nl,rl,at,2,0,Names.push(name,value,nl))

def close_space_case1(+context: Context, +nl: U32, +rl: U32, +name: U32, +at: T.Position, +value: U32, +span: T.Span, +ws: Bool, +hit: Bool) -> State & T.LexResult:
  match hit:
    case True{}: next(context,MCloseSpace{name,at},nl,rl)
    case False{}: failed(1,T.start(span),62,value)

def close_space_case0(+context: Context, +nl: U32, +rl: U32, +name: U32, +at: T.Position, +value: U32, +span: T.Span, +ws: Bool, +hit: Bool) -> State & T.LexResult:
  match hit:
    case True{}: close_end(context,nl,rl,name,at,T.end(span))
    case False{}: close_space_case1(context,nl,rl,name,at,value,span,ws,ws)

def close_space(+context: Context, +nl: U32, +rl: U32, +name: U32, +at: T.Position, +value: U32, +span: T.Span, +ws: Bool) -> State & T.LexResult:
  close_space_case0(context,nl,rl,name,at,value,span,ws,U32.is_eq(value,62))

def cdata_begin(+context: Context, +nl: U32, +rl: U32, +at: T.Position) -> State & T.LexResult:
  match context:
    case Context{0,+root,+decl,+allowed}: failed(5,at,0,0)
    case _: next(context,MCdataPrefix{at,0},nl,rl)

def bang(+context: Context, +nl: U32, +rl: U32, +at: T.Position, +value: U32) -> State & T.LexResult:
  match value:
    case 45: next(context,MCommentOpen{at},nl,rl)
    case 91: cdata_begin(context,nl,rl,at)
    case _: failed(3,at,0,value)

def comment_open(+context: Context, +nl: U32, +rl: U32, +at: T.Position, +value: U32) -> State & T.LexResult:
  match value:
    case 45: next(context,MComment{at,0},nl,rl)
    case _: failed(1,at,45,value)

def comment_case2(+context: Context, +nl: U32, +rl: U32, +at: T.Position, +hyphens: U32, +value: U32, +span: T.Span, +hit: Bool) -> State & T.LexResult:
  match hit:
    case True{}: next(context,MComment{at,U32.inc(hyphens)},nl,rl)
    case False{}: next(context,MComment{at,0},nl,rl)

def comment_case1(+context: Context, +nl: U32, +rl: U32, +at: T.Position, +hyphens: U32, +value: U32, +span: T.Span, +hit: Bool) -> State & T.LexResult:
  match hit:
    case True{}: failed(1,T.start(span),62,value)
    case False{}: comment_case2(context,nl,rl,at,hyphens,value,span,U32.is_eq(value,45))

def comment_case0(+context: Context, +nl: U32, +rl: U32, +at: T.Position, +hyphens: U32, +value: U32, +span: T.Span, +hit: Bool) -> State & T.LexResult:
  match hit:
    case True{}: next(context,MText{0},nl,rl)
    case False{}: comment_case1(context,nl,rl,at,hyphens,value,span,U32.is_eq(hyphens,2))

def comment(+context: Context, +nl: U32, +rl: U32, +at: T.Position, +hyphens: U32, +value: U32, +span: T.Span) -> State & T.LexResult:
  comment_case0(context,nl,rl,at,hyphens,value,span,Bool.and(U32.is_eq(hyphens,2),U32.is_eq(value,62)))

def cdata_char(+index: U32) -> U32:
  match index:
    case 0: 67
    case 1: 68
    case 2: 65
    case 3: 84
    case 4: 65
    case 5: 91
    case _: 0

def cdata_prefix_case1(+context: Context, +nl: U32, +rl: U32, +at: T.Position, +index: U32, +value: U32, +valid: Bool, +hit: Bool) -> State & T.LexResult:
  match hit:
    case True{}: next(context,MCdata{0,T.empty_span(),T.empty_span()},nl,rl)
    case False{}: next(context,MCdataPrefix{at,U32.inc(index)},nl,rl)

def cdata_prefix_case0(+context: Context, +nl: U32, +rl: U32, +at: T.Position, +index: U32, +value: U32, +valid: Bool, +hit: Bool) -> State & T.LexResult:
  match hit:
    case True{}: failed(3,at,cdata_char(index),value)
    case False{}: cdata_prefix_case1(context,nl,rl,at,index,value,valid,Bool.and(U32.is_eq(index,5),valid))

def cdata_prefix(+context: Context, +nl: U32, +rl: U32, +at: T.Position, +index: U32, +value: U32, +valid: Bool) -> State & T.LexResult:
  cdata_prefix_case0(context,nl,rl,at,index,value,valid,Bool.not(valid))

def cdata_case5(+context: Context, +nl: U32, +rl: U32, +held: U32, +first: T.Span, +second: T.Span, +value: U32, +span: T.Span, +hit: Bool) -> State & T.LexResult:
  match hit:
    case True{}: emit(context,MCdata{0,first,second},nl,rl,T.two(T.EvText{93,T.Cdata{},first},T.EvText{value,T.Cdata{},span}))
    case False{}: emit(context,MCdata{0,first,second},nl,rl,T.three(T.EvText{93,T.Cdata{},first},T.EvText{93,T.Cdata{},second},T.EvText{value,T.Cdata{},span}))

def cdata_case4(+context: Context, +nl: U32, +rl: U32, +held: U32, +first: T.Span, +second: T.Span, +value: U32, +span: T.Span, +hit: Bool) -> State & T.LexResult:
  match hit:
    case True{}: emit(context,MCdata{0,first,second},nl,rl,T.one(T.EvText{value,T.Cdata{},span}))
    case False{}: cdata_case5(context,nl,rl,held,first,second,value,span,U32.is_eq(held,1))

def cdata_case3(+context: Context, +nl: U32, +rl: U32, +held: U32, +first: T.Span, +second: T.Span, +value: U32, +span: T.Span, +hit: Bool) -> State & T.LexResult:
  match hit:
    case True{}: next(context,MText{0},nl,rl)
    case False{}: cdata_case4(context,nl,rl,held,first,second,value,span,U32.is_eq(held,0))

def cdata_case2(+context: Context, +nl: U32, +rl: U32, +held: U32, +first: T.Span, +second: T.Span, +value: U32, +span: T.Span, +hit: Bool) -> State & T.LexResult:
  match hit:
    case True{}: emit(context,MCdata{2,second,span},nl,rl,T.one(T.EvText{93,T.Cdata{},first}))
    case False{}: cdata_case3(context,nl,rl,held,first,second,value,span,Bool.and(U32.is_eq(held,2),U32.is_eq(value,62)))

def cdata_case1(+context: Context, +nl: U32, +rl: U32, +held: U32, +first: T.Span, +second: T.Span, +value: U32, +span: T.Span, +hit: Bool) -> State & T.LexResult:
  match hit:
    case True{}: next(context,MCdata{2,first,span},nl,rl)
    case False{}: cdata_case2(context,nl,rl,held,first,second,value,span,Bool.and(U32.is_eq(held,2),U32.is_eq(value,93)))

def cdata_case0(+context: Context, +nl: U32, +rl: U32, +held: U32, +first: T.Span, +second: T.Span, +value: U32, +span: T.Span, +hit: Bool) -> State & T.LexResult:
  match hit:
    case True{}: next(context,MCdata{1,span,second},nl,rl)
    case False{}: cdata_case1(context,nl,rl,held,first,second,value,span,Bool.and(U32.is_eq(held,1),U32.is_eq(value,93)))

def cdata(+context: Context, +nl: U32, +rl: U32, +held: U32, +first: T.Span, +second: T.Span, +value: U32, +span: T.Span) -> State & T.LexResult:
  cdata_case0(context,nl,rl,held,first,second,value,span,Bool.and(U32.is_eq(held,0),U32.is_eq(value,93)))

def reference_named(+id: U32) -> Result<&2, &2, U32, U32>:
  match id:
    case 301: Done{38}
    case 302: Done{60}
    case 303: Done{62}
    case 304: Done{39}
    case 305: Done{34}
    case _: Fail{4}

def reference_emit(+context: Context, +nl: U32, +rl: U32, +target: RefTarget, +value: U32, +span: T.Span) -> State & T.LexResult:
  match target:
    case RefText{}: emit(context,MText{0},nl,rl,T.one(T.EvText{value,T.Reference{},span}))
    case RefAttribute{+tag,+name,+quote}: emit(context,MAttrValue{tag,name,quote},nl,rl,T.one(T.EvAttributeScalar{value,T.Reference{},span}))

def reference_result(+context: Context, +nl: U32, +rl: U32, +target: RefTarget, +at: T.Position, +end: T.Position, +result: Result<&2, &2, U32, U32>) -> State & T.LexResult:
  match result:
    case Fail{+reason}: failed(4,at,0,reason)
    case Done{+value}: reference_emit(context,nl,rl,target,value,T.Span{at,end})

def reference_end(+context: Context, +nl: U32, +rl: U32, +target: RefTarget, +at: T.Position, +kind: U32, +name: Names.Name, +number: N.Number, +end: T.Position) -> State & T.LexResult:
  match kind:
    case 4: reference_result(context,nl,rl,target,at,end,reference_named(Names.finish(name)))
    case 2: reference_result(context,nl,rl,target,at,end,N.character(number))
    case 3: reference_result(context,nl,rl,target,at,end,N.character(number))
    case _: failed(4,at,0,kind)

def reference_name(+context: Context, +nl: U32, +rl: U32, +target: RefTarget, +at: T.Position, +length: U32, +number: N.Number, +result: Result<&2, &2, U32, Names.Name>) -> State & T.LexResult:
  match result:
    case Fail{+reason}: failed(4,at,0,reason)
    case Done{+name}: next(context,MReference{target,at,length,4,name,number},nl,rl)

def reference_digits(+context: Context, +nl: U32, +rl: U32, +target: RefTarget, +at: T.Position, +length: U32, +kind: U32, +name: Names.Name, +number: N.Number) -> State & T.LexResult:
  match number:
    case N.NumberBroken{+reason}: failed(4,at,0,reason)
    case _: next(context,MReference{target,at,length,kind,name,number},nl,rl)

def reference_body_case5(+context: Context, +nl: U32, +rl: U32, +target: RefTarget, +at: T.Position, +length: U32, +kind: U32, +name: Names.Name, +number: N.Number, +value: U32, +hit: Bool) -> State & T.LexResult:
  match hit:
    case True{}: reference_digits(context,nl,rl,target,at,length,3,name,N.push(number,value))
    case False{}: reference_name(context,nl,rl,target,at,length,number,Names.push(name,value,rl))

def reference_body_case4(+context: Context, +nl: U32, +rl: U32, +target: RefTarget, +at: T.Position, +length: U32, +kind: U32, +name: Names.Name, +number: N.Number, +value: U32, +hit: Bool) -> State & T.LexResult:
  match hit:
    case True{}: reference_digits(context,nl,rl,target,at,length,2,name,N.push(number,value))
    case False{}: reference_body_case5(context,nl,rl,target,at,length,kind,name,number,value,U32.is_eq(kind,3))

def reference_body_case3(+context: Context, +nl: U32, +rl: U32, +target: RefTarget, +at: T.Position, +length: U32, +kind: U32, +name: Names.Name, +number: N.Number, +value: U32, +hit: Bool) -> State & T.LexResult:
  match hit:
    case True{}: reference_digits(context,nl,rl,target,at,length,3,name,N.push(number,value))
    case False{}: reference_body_case4(context,nl,rl,target,at,length,kind,name,number,value,U32.is_eq(kind,2))

def reference_body_case2(+context: Context, +nl: U32, +rl: U32, +target: RefTarget, +at: T.Position, +length: U32, +kind: U32, +name: Names.Name, +number: N.Number, +value: U32, +hit: Bool) -> State & T.LexResult:
  match hit:
    case True{}: next(context,MReference{target,at,length,2,name,N.begin(True{})},nl,rl)
    case False{}: reference_body_case3(context,nl,rl,target,at,length,kind,name,number,value,U32.is_eq(kind,1))

def reference_body_case1(+context: Context, +nl: U32, +rl: U32, +target: RefTarget, +at: T.Position, +length: U32, +kind: U32, +name: Names.Name, +number: N.Number, +value: U32, +hit: Bool) -> State & T.LexResult:
  match hit:
    case True{}: reference_name(context,nl,rl,target,at,length,number,Names.push(name,value,rl))
    case False{}: reference_body_case2(context,nl,rl,target,at,length,kind,name,number,value,Bool.and(U32.is_eq(kind,1),U32.is_eq(value,120)))

def reference_body_case0(+context: Context, +nl: U32, +rl: U32, +target: RefTarget, +at: T.Position, +length: U32, +kind: U32, +name: Names.Name, +number: N.Number, +value: U32, +hit: Bool) -> State & T.LexResult:
  match hit:
    case True{}: next(context,MReference{target,at,length,1,name,number},nl,rl)
    case False{}: reference_body_case1(context,nl,rl,target,at,length,kind,name,number,value,U32.is_eq(kind,0))

def reference_body(+context: Context, +nl: U32, +rl: U32, +target: RefTarget, +at: T.Position, +length: U32, +kind: U32, +name: Names.Name, +number: N.Number, +value: U32) -> State & T.LexResult:
  reference_body_case0(context,nl,rl,target,at,length,kind,name,number,value,Bool.and(U32.is_eq(kind,0),U32.is_eq(value,35)))

def reference_valid_case1(+context: Context, +nl: U32, +rl: U32, +target: RefTarget, +at: T.Position, +length: U32, +kind: U32, +name: Names.Name, +number: N.Number, +value: U32, +span: T.Span, +valid: Bool, +hit: Bool) -> State & T.LexResult:
  match hit:
    case True{}: reference_end(context,nl,rl,target,at,kind,name,number,T.end(span))
    case False{}: reference_body(context,nl,rl,target,at,U32.inc(length),kind,name,number,value)

def reference_valid_case0(+context: Context, +nl: U32, +rl: U32, +target: RefTarget, +at: T.Position, +length: U32, +kind: U32, +name: Names.Name, +number: N.Number, +value: U32, +span: T.Span, +valid: Bool, +hit: Bool) -> State & T.LexResult:
  match hit:
    case True{}: failed(7,at,rl,length)
    case False{}: reference_valid_case1(context,nl,rl,target,at,length,kind,name,number,value,span,valid,Bool.and(U32.is_eq(value,59),valid))

def reference_valid(+context: Context, +nl: U32, +rl: U32, +target: RefTarget, +at: T.Position, +length: U32, +kind: U32, +name: Names.Name, +number: N.Number, +value: U32, +span: T.Span, +valid: Bool) -> State & T.LexResult:
  reference_valid_case0(context,nl,rl,target,at,length,kind,name,number,value,span,valid,Bool.not(valid))

def decl_xml_char(+index: U32) -> U32:
  match index:
    case 0: 120
    case 1: 109
    case 2: 108
    case _: 0

def decl_xml_valid(+context: Context, +nl: U32, +rl: U32, +at: T.Position, +index: U32, +value: U32, +valid: Bool) -> State & T.LexResult:
  match valid:
    case True{}: next(context,MDeclXml{at,U32.inc(index)},nl,rl)
    case False{}: failed(3,at,decl_xml_char(index),value)

def decl_xml_case1(+context: Context, +nl: U32, +rl: U32, +at: T.Position, +index: U32, +value: U32, +ws: Bool, +hit: Bool) -> State & T.LexResult:
  match hit:
    case True{}: failed(1,at,32,value)
    case False{}: decl_xml_valid(context,nl,rl,at,index,value,U32.is_eq(value,decl_xml_char(index)))

def decl_xml_case0(+context: Context, +nl: U32, +rl: U32, +at: T.Position, +index: U32, +value: U32, +ws: Bool, +hit: Bool) -> State & T.LexResult:
  match hit:
    case True{}: next(context,MDeclSpace{at,0},nl,rl)
    case False{}: decl_xml_case1(context,nl,rl,at,index,value,ws,Bool.and(U32.is_eq(index,3),Bool.not(ws)))

def decl_xml(+context: Context, +nl: U32, +rl: U32, +at: T.Position, +index: U32, +value: U32, +ws: Bool) -> State & T.LexResult:
  decl_xml_case0(context,nl,rl,at,index,value,ws,Bool.and(U32.is_eq(index,3),ws))

def decl_name_ready(+context: Context, +nl: U32, +rl: U32, +at: T.Position, +stage: U32, +result: Result<&2, &2, U32, Names.Name>) -> State & T.LexResult:
  match result:
    case Fail{+reason}: failed(reason,at,0,0)
    case Done{+name}: next(context,MDeclName{at,stage,name},nl,rl)

def decl_space_case3(+context: Context, +nl: U32, +rl: U32, +at: T.Position, +stage: U32, +value: U32, +span: T.Span, +ws: Bool, +hit: Bool) -> State & T.LexResult:
  match hit:
    case True{}: failed(1,T.start(span),63,value)
    case False{}: decl_name_ready(context,nl,rl,at,stage,Names.push(Names.start(1835008,T.start(span)),value,nl))

def decl_space_case2(+context: Context, +nl: U32, +rl: U32, +at: T.Position, +stage: U32, +value: U32, +span: T.Span, +ws: Bool, +hit: Bool) -> State & T.LexResult:
  match hit:
    case True{}: next(context,MDeclClose{at},nl,rl)
    case False{}: decl_space_case3(context,nl,rl,at,stage,value,span,ws,U32.is_eq(stage,3))

def decl_space_case1(+context: Context, +nl: U32, +rl: U32, +at: T.Position, +stage: U32, +value: U32, +span: T.Span, +ws: Bool, +hit: Bool) -> State & T.LexResult:
  match hit:
    case True{}: failed(1,at,201,value)
    case False{}: decl_space_case2(context,nl,rl,at,stage,value,span,ws,U32.is_eq(value,63))

def decl_space_case0(+context: Context, +nl: U32, +rl: U32, +at: T.Position, +stage: U32, +value: U32, +span: T.Span, +ws: Bool, +hit: Bool) -> State & T.LexResult:
  match hit:
    case True{}: next(context,MDeclSpace{at,stage},nl,rl)
    case False{}: decl_space_case1(context,nl,rl,at,stage,value,span,ws,Bool.and(U32.is_eq(stage,0),U32.is_eq(value,63)))

def decl_space(+context: Context, +nl: U32, +rl: U32, +at: T.Position, +stage: U32, +value: U32, +span: T.Span, +ws: Bool) -> State & T.LexResult:
  decl_space_case0(context,nl,rl,at,stage,value,span,ws,ws)

def decl_allowed_case3(+stage: U32, +name: U32, +hit: Bool) -> Bool:
  match hit:
    case True{}: True{}
    case False{}: False{}

def decl_allowed_case2(+stage: U32, +name: U32, +hit: Bool) -> Bool:
  match hit:
    case True{}: True{}
    case False{}: decl_allowed_case3(stage,name,Bool.and(U32.is_eq(stage,2),U32.is_eq(name,203)))

def decl_allowed_case1(+stage: U32, +name: U32, +hit: Bool) -> Bool:
  match hit:
    case True{}: True{}
    case False{}: decl_allowed_case2(stage,name,Bool.and(U32.is_eq(stage,1),U32.is_eq(name,203)))

def decl_allowed_case0(+stage: U32, +name: U32, +hit: Bool) -> Bool:
  match hit:
    case True{}: True{}
    case False{}: decl_allowed_case1(stage,name,Bool.and(U32.is_eq(stage,1),U32.is_eq(name,202)))

def decl_allowed(+stage: U32, +name: U32) -> Bool:
  decl_allowed_case0(stage,name,Bool.and(U32.is_eq(stage,0),U32.is_eq(name,201)))

def decl_selected_case1(+context: Context, +nl: U32, +rl: U32, +at: T.Position, +stage: U32, +name: U32, +value: U32, +valid: Bool, +hit: Bool) -> State & T.LexResult:
  match hit:
    case True{}: next(context,MDeclQuote{at,stage,name},nl,rl)
    case False{}: next(context,MDeclEquals{at,stage,name},nl,rl)

def decl_selected_case0(+context: Context, +nl: U32, +rl: U32, +at: T.Position, +stage: U32, +name: U32, +value: U32, +valid: Bool, +hit: Bool) -> State & T.LexResult:
  match hit:
    case True{}: failed(8,at,stage,name)
    case False{}: decl_selected_case1(context,nl,rl,at,stage,name,value,valid,Bool.and(U32.is_eq(value,61),valid))

def decl_selected(+context: Context, +nl: U32, +rl: U32, +at: T.Position, +stage: U32, +name: U32, +value: U32, +valid: Bool) -> State & T.LexResult:
  decl_selected_case0(context,nl,rl,at,stage,name,value,valid,Bool.not(valid))

def decl_resolved(+context: Context, +nl: U32, +rl: U32, +at: T.Position, +stage: U32, +name: U32, +value: U32) -> State & T.LexResult:
  decl_selected(context,nl,rl,at,stage,name,value,decl_allowed(stage,name))

def decl_name(+context: Context, +nl: U32, +rl: U32, +at: T.Position, +stage: U32, +name: Names.Name, +value: U32, +delimiter: Bool) -> State & T.LexResult:
  match delimiter:
    case True{}: decl_resolved(context,nl,rl,at,stage,Names.finish(name),value)
    case False{}: decl_name_ready(context,nl,rl,at,stage,Names.push(name,value,nl))

def decl_equals_case1(+context: Context, +nl: U32, +rl: U32, +at: T.Position, +stage: U32, +name: U32, +value: U32, +span: T.Span, +ws: Bool, +hit: Bool) -> State & T.LexResult:
  match hit:
    case True{}: next(context,MDeclEquals{at,stage,name},nl,rl)
    case False{}: failed(1,T.start(span),61,value)

def decl_equals_case0(+context: Context, +nl: U32, +rl: U32, +at: T.Position, +stage: U32, +name: U32, +value: U32, +span: T.Span, +ws: Bool, +hit: Bool) -> State & T.LexResult:
  match hit:
    case True{}: next(context,MDeclQuote{at,stage,name},nl,rl)
    case False{}: decl_equals_case1(context,nl,rl,at,stage,name,value,span,ws,ws)

def decl_equals(+context: Context, +nl: U32, +rl: U32, +at: T.Position, +stage: U32, +name: U32, +value: U32, +span: T.Span, +ws: Bool) -> State & T.LexResult:
  decl_equals_case0(context,nl,rl,at,stage,name,value,span,ws,U32.is_eq(value,61))

def decl_quote_case2(+context: Context, +nl: U32, +rl: U32, +at: T.Position, +stage: U32, +name: U32, +value: U32, +span: T.Span, +ws: Bool, +hit: Bool) -> State & T.LexResult:
  match hit:
    case True{}: next(context,MDeclQuote{at,stage,name},nl,rl)
    case False{}: failed(1,T.start(span),34,value)

def decl_quote_case1(+context: Context, +nl: U32, +rl: U32, +at: T.Position, +stage: U32, +name: U32, +value: U32, +span: T.Span, +ws: Bool, +hit: Bool) -> State & T.LexResult:
  match hit:
    case True{}: next(context,MDeclValue{at,stage,name,39,0,0},nl,rl)
    case False{}: decl_quote_case2(context,nl,rl,at,stage,name,value,span,ws,ws)

def decl_quote_case0(+context: Context, +nl: U32, +rl: U32, +at: T.Position, +stage: U32, +name: U32, +value: U32, +span: T.Span, +ws: Bool, +hit: Bool) -> State & T.LexResult:
  match hit:
    case True{}: next(context,MDeclValue{at,stage,name,34,0,0},nl,rl)
    case False{}: decl_quote_case1(context,nl,rl,at,stage,name,value,span,ws,U32.is_eq(value,39))

def decl_quote(+context: Context, +nl: U32, +rl: U32, +at: T.Position, +stage: U32, +name: U32, +value: U32, +span: T.Span, +ws: Bool) -> State & T.LexResult:
  decl_quote_case0(context,nl,rl,at,stage,name,value,span,ws,U32.is_eq(value,34))

def lower(+value: U32, +upper: Bool) -> U32:
  match upper:
    case True{}: U32.add(value,32)
    case False{}: value

def decl_char_case12(+name: U32, +index: U32, +variant: U32, +hit: Bool) -> U32:
  match hit:
    case True{}: 111
    case False{}: 0

def decl_char_case11(+name: U32, +index: U32, +variant: U32, +hit: Bool) -> U32:
  match hit:
    case True{}: 110
    case False{}: decl_char_case12(name,index,variant,Bool.and(U32.is_eq(name,203),Bool.and(U32.is_eq(index,1),U32.is_eq(variant,2))))

def decl_char_case10(+name: U32, +index: U32, +variant: U32, +hit: Bool) -> U32:
  match hit:
    case True{}: 115
    case False{}: decl_char_case11(name,index,variant,Bool.and(U32.is_eq(name,203),Bool.and(U32.is_eq(index,0),U32.is_eq(variant,2))))

def decl_char_case9(+name: U32, +index: U32, +variant: U32, +hit: Bool) -> U32:
  match hit:
    case True{}: 101
    case False{}: decl_char_case10(name,index,variant,Bool.and(U32.is_eq(name,203),Bool.and(U32.is_eq(index,2),U32.is_eq(variant,1))))

def decl_char_case8(+name: U32, +index: U32, +variant: U32, +hit: Bool) -> U32:
  match hit:
    case True{}: 121
    case False{}: decl_char_case9(name,index,variant,Bool.and(U32.is_eq(name,203),Bool.and(U32.is_eq(index,1),U32.is_eq(variant,1))))

def decl_char_case7(+name: U32, +index: U32, +variant: U32, +hit: Bool) -> U32:
  match hit:
    case True{}: 56
    case False{}: decl_char_case8(name,index,variant,Bool.and(U32.is_eq(name,203),Bool.and(U32.is_eq(index,0),U32.is_eq(variant,1))))

def decl_char_case6(+name: U32, +index: U32, +variant: U32, +hit: Bool) -> U32:
  match hit:
    case True{}: 45
    case False{}: decl_char_case7(name,index,variant,Bool.and(U32.is_eq(name,202),U32.is_eq(index,4)))

def decl_char_case5(+name: U32, +index: U32, +variant: U32, +hit: Bool) -> U32:
  match hit:
    case True{}: 102
    case False{}: decl_char_case6(name,index,variant,Bool.and(U32.is_eq(name,202),U32.is_eq(index,3)))

def decl_char_case4(+name: U32, +index: U32, +variant: U32, +hit: Bool) -> U32:
  match hit:
    case True{}: 116
    case False{}: decl_char_case5(name,index,variant,Bool.and(U32.is_eq(name,202),U32.is_eq(index,2)))

def decl_char_case3(+name: U32, +index: U32, +variant: U32, +hit: Bool) -> U32:
  match hit:
    case True{}: 117
    case False{}: decl_char_case4(name,index,variant,Bool.and(U32.is_eq(name,202),U32.is_eq(index,1)))

def decl_char_case2(+name: U32, +index: U32, +variant: U32, +hit: Bool) -> U32:
  match hit:
    case True{}: 48
    case False{}: decl_char_case3(name,index,variant,Bool.and(U32.is_eq(name,202),U32.is_eq(index,0)))

def decl_char_case1(+name: U32, +index: U32, +variant: U32, +hit: Bool) -> U32:
  match hit:
    case True{}: 46
    case False{}: decl_char_case2(name,index,variant,Bool.and(U32.is_eq(name,201),U32.is_eq(index,2)))

def decl_char_case0(+name: U32, +index: U32, +variant: U32, +hit: Bool) -> U32:
  match hit:
    case True{}: 49
    case False{}: decl_char_case1(name,index,variant,Bool.and(U32.is_eq(name,201),U32.is_eq(index,1)))

def decl_char(+name: U32, +index: U32, +variant: U32) -> U32:
  decl_char_case0(name,index,variant,Bool.and(U32.is_eq(name,201),U32.is_eq(index,0)))

def decl_variant_case1(+name: U32, +index: U32, +variant: U32, +value: U32, +hit: Bool) -> U32:
  match hit:
    case True{}: 2
    case False{}: variant

def decl_variant_case0(+name: U32, +index: U32, +variant: U32, +value: U32, +hit: Bool) -> U32:
  match hit:
    case True{}: 1
    case False{}: decl_variant_case1(name,index,variant,value,Bool.and(U32.is_eq(name,203),Bool.and(U32.is_eq(index,0),U32.is_eq(value,110))))

def decl_variant(+name: U32, +index: U32, +variant: U32, +value: U32) -> U32:
  decl_variant_case0(name,index,variant,value,Bool.and(U32.is_eq(name,203),Bool.and(U32.is_eq(index,0),U32.is_eq(value,121))))

def decl_expected(+name: U32, +index: U32, +variant: U32, +value: U32) -> Bool:
  match name:
    case 202: U32.is_eq(decl_char(name,index,variant),lower(value,Bool.and(U32.is_ge(value,65),U32.is_le(value,90))))
    case _: U32.is_eq(decl_char(name,index,variant),value)

def decl_length_case3(+name: U32, +variant: U32, +hit: Bool) -> U32:
  match hit:
    case True{}: 2
    case False{}: 0

def decl_length_case2(+name: U32, +variant: U32, +hit: Bool) -> U32:
  match hit:
    case True{}: 3
    case False{}: decl_length_case3(name,variant,Bool.and(U32.is_eq(name,203),U32.is_eq(variant,2)))

def decl_length_case1(+name: U32, +variant: U32, +hit: Bool) -> U32:
  match hit:
    case True{}: 5
    case False{}: decl_length_case2(name,variant,Bool.and(U32.is_eq(name,203),U32.is_eq(variant,1)))

def decl_length_case0(+name: U32, +variant: U32, +hit: Bool) -> U32:
  match hit:
    case True{}: 3
    case False{}: decl_length_case1(name,variant,U32.is_eq(name,202))

def decl_length(+name: U32, +variant: U32) -> U32:
  decl_length_case0(name,variant,U32.is_eq(name,201))

def decl_value_valid(+context: Context, +nl: U32, +rl: U32, +at: T.Position, +stage: U32, +name: U32, +quote: U32, +index: U32, +variant: U32, +value: U32, +span: T.Span, +valid: Bool) -> State & T.LexResult:
  match valid:
    case True{}: next(context,MDeclValue{at,stage,name,quote,U32.inc(index),variant},nl,rl)
    case False{}: failed(8,T.start(span),decl_char(name,index,variant),value)

def decl_value_char(+context: Context, +nl: U32, +rl: U32, +at: T.Position, +stage: U32, +name: U32, +quote: U32, +index: U32, +variant: U32, +value: U32, +span: T.Span) -> State & T.LexResult:
  decl_value_valid(context,nl,rl,at,stage,name,quote,index,variant,value,span,Bool.and(U32.is_lt(index,decl_length(name,variant)),decl_expected(name,index,variant,value)))

def decl_value_end(+context: Context, +nl: U32, +rl: U32, +at: T.Position, +name: U32, +index: U32, +variant: U32, +span: T.Span, +valid: Bool) -> State & T.LexResult:
  match valid:
    case True{}: next(context,MDeclAfter{at,U32.sub(name,200)},nl,rl)
    case False{}: failed(8,T.start(span),decl_length(name,variant),index)

def decl_value(+context: Context, +nl: U32, +rl: U32, +at: T.Position, +stage: U32, +name: U32, +quote: U32, +index: U32, +variant: U32, +value: U32, +span: T.Span, +ending: Bool) -> State & T.LexResult:
  match ending:
    case True{}: decl_value_end(context,nl,rl,at,name,index,variant,span,Bool.and(U32.is_gt(index,0),U32.is_eq(index,decl_length(name,variant))))
    case False{}: decl_value_char(context,nl,rl,at,stage,name,quote,index,decl_variant(name,index,variant,value),value,span)

def decl_after_case1(+context: Context, +nl: U32, +rl: U32, +at: T.Position, +stage: U32, +value: U32, +span: T.Span, +ws: Bool, +hit: Bool) -> State & T.LexResult:
  match hit:
    case True{}: next(context,MDeclSpace{at,stage},nl,rl)
    case False{}: failed(1,T.start(span),32,value)

def decl_after_case0(+context: Context, +nl: U32, +rl: U32, +at: T.Position, +stage: U32, +value: U32, +span: T.Span, +ws: Bool, +hit: Bool) -> State & T.LexResult:
  match hit:
    case True{}: next(context,MDeclClose{at},nl,rl)
    case False{}: decl_after_case1(context,nl,rl,at,stage,value,span,ws,ws)

def decl_after(+context: Context, +nl: U32, +rl: U32, +at: T.Position, +stage: U32, +value: U32, +span: T.Span, +ws: Bool) -> State & T.LexResult:
  decl_after_case0(context,nl,rl,at,stage,value,span,ws,U32.is_eq(value,63))

def declared(+context: Context) -> Context:
  match context:
    case Context{+depth,+root,+decl,+allowed}: Context{depth,root,True{},False{}}

def decl_close(+context: Context, +nl: U32, +rl: U32, +at: T.Position, +value: U32, +span: T.Span) -> State & T.LexResult:
  match value:
    case 62: next(declared(context),MText{0},nl,rl)
    case _: failed(1,T.start(span),62,value)

def self_close(+context: Context, +nl: U32, +rl: U32, +value: U32, +span: T.Span) -> State & T.LexResult:
  match value:
    case 62: start_end(context,nl,rl,True{},span,T.NoEvent{})
    case _: failed(1,T.start(span),62,value)

def push_mode_3(+context: Context, +mode: Mode, +nl: U32, +rl: U32, +value: U32, +span: T.Span) -> State & T.LexResult:
  match mode:
    case MDeclEquals{+at,+stage,+name}: decl_equals(context,nl,rl,at,stage,name,value,span,T.whitespace(value))
    case MDeclQuote{+at,+stage,+name}: decl_quote(context,nl,rl,at,stage,name,value,span,T.whitespace(value))
    case MDeclValue{+at,+stage,+name,+quote,+index,+variant}: decl_value(context,nl,rl,at,stage,name,quote,index,variant,value,span,U32.is_eq(value,quote))
    case MDeclAfter{+at,+stage}: decl_after(context,nl,rl,at,stage,value,span,T.whitespace(value))
    case MDeclClose{+at}: decl_close(context,nl,rl,at,value,span)
    case _: failed(1,T.start(span),0,value)

def push_mode_2(+context: Context, +mode: Mode, +nl: U32, +rl: U32, +value: U32, +span: T.Span) -> State & T.LexResult:
  match mode:
    case MComment{+at,+hyphens}: comment(context,nl,rl,at,hyphens,value,span)
    case MCdataPrefix{+at,+index}: cdata_prefix(context,nl,rl,at,index,value,U32.is_eq(value,cdata_char(index)))
    case MCdata{+held,+first,+second}: cdata(context,nl,rl,held,first,second,value,span)
    case MReference{+target,+at,+length,+kind,+name,+number}: reference_valid(context,nl,rl,target,at,length,kind,name,number,value,span,U32.is_lt(length,rl))
    case MDeclXml{+at,+index}: decl_xml(context,nl,rl,at,index,value,T.whitespace(value))
    case MDeclSpace{+at,+stage}: decl_space(context,nl,rl,at,stage,value,span,T.whitespace(value))
    case MDeclName{+at,+stage,+name}: decl_name(context,nl,rl,at,stage,name,value,Bool.or(T.whitespace(value),U32.is_eq(value,61)))
    case _: push_mode_3(context,mode,nl,rl,value,span)

def push_mode_1(+context: Context, +mode: Mode, +nl: U32, +rl: U32, +value: U32, +span: T.Span) -> State & T.LexResult:
  match mode:
    case MAttrQuote{+tag,+name}: attr_quote(context,nl,rl,tag,name,value,span,T.whitespace(value))
    case MAttrValue{+tag,+name,+quote}: attr_value(context,nl,rl,tag,name,quote,value,span,U32.is_eq(value,quote))
    case MSelfClose{+tag}: self_close(context,nl,rl,value,span)
    case MClose{+name,+at}: close_name(context,nl,rl,name,at,value,span,Bool.or(T.whitespace(value),U32.is_eq(value,62)))
    case MCloseSpace{+name,+at}: close_space(context,nl,rl,name,at,value,span,T.whitespace(value))
    case MBang{+at}: bang(context,nl,rl,at,value)
    case MCommentOpen{+at}: comment_open(context,nl,rl,at,value)
    case _: push_mode_2(context,mode,nl,rl,value,span)

def push_mode(+context: Context, +mode: Mode, +nl: U32, +rl: U32, +value: U32, +span: T.Span) -> State & T.LexResult:
  match mode:
    case MText{+previous}: text(context,nl,rl,previous,value,span)
    case MMarkup{+at}: markup(context,nl,rl,at,value,span)
    case MOpen{+name}: open_name(context,nl,rl,name,value,span,Bool.or(T.whitespace(value),Bool.or(U32.is_eq(value,47),U32.is_eq(value,62))))
    case MTag{+tag}: tag_input(context,nl,rl,tag,value,span)
    case MAfterAttribute{+tag}: after_attribute(context,nl,rl,tag,value,span,Bool.or(T.whitespace(value),Bool.or(U32.is_eq(value,47),U32.is_eq(value,62))))
    case MAttrName{+tag,+name}: attr_name(context,nl,rl,tag,name,value,Bool.or(T.whitespace(value),U32.is_eq(value,61)))
    case MAttrEquals{+tag,+name}: attr_equals(context,nl,rl,tag,name,value,span,T.whitespace(value))
    case _: push_mode_1(context,mode,nl,rl,value,span)

def push(+state: State, +scalar: T.Scalar) -> State & T.LexResult:
  match state scalar:
    case LexBroken{+diagnostic} _: fail_diagnostic(diagnostic)
    case LexReady{+context,+mode,+nl,+rl} T.Scalar{+value,+span}: push_mode(context,mode,nl,rl,value,span)

def finish(+state: State, +at: T.Position) -> State & T.LexResult:
  match state:
    case LexBroken{+diagnostic}: fail_diagnostic(diagnostic)
    case LexReady{Context{0,True{},+decl,+allowed},MText{+previous},+nl,+rl}: next(Context{0,True{},decl,allowed},MText{previous},nl,rl)
    case LexReady{+context,MReference{+target,+opening,+length,+kind,+name,+number},+nl,+rl}: failed(6,opening,0,0)
    case _: failed(6,at,0,0)
