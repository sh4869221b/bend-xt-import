import Base
import ../core/error.bend as E

# Fixed-size public metadata. All offsets refer to original source bytes.
type Position is Data:
  Position{byte: U32, line: U32, column: U32}

type Span is Data:
  Span{start: Position, end: Position}

type SourceKey is Data:
  SourceKey{run: U32, origin: U32}

type Diagnostic is Data:
  Diagnostic{phase: U32, reason: U32, at: Position, entry: U32, entryStart: Position, expected: U32, observed: U32, core: Maybe<&2, E.Error>, source: SourceKey}

type Limits is Data:
  Limits{sourceBytes: U32, depth: U32, entries: U32, entryTextBytes: U32, paramsTextBytes: U32, nameBytes: U32, referenceBytes: U32, fuzCount: U32, fuzTextBytes: U32}

type Scalar is Data:
  Scalar{value: U32, span: Span}

type Origin is Data:
  Literal{}
  Reference{}
  Cdata{}

type FieldRef is Data:
  FieldRef{present: Bool, scalarStart: U32, scalarLength: U32, utf8Bytes: U32, element: Span}

type Occurrence is Data:
  Unspecified{}
  Explicit{index: U32, maxIndex: U32}

type Sid is Data:
  Sid{value: U32, width: U32}

type Partial is Data:
  TranslatedAbsent{}
  Incomplete{}
  Locked{}

type Rec is Data:
  Rec{record: U32, field: U32, occurrence: Occurrence}

type Identity is Data:
  LiteralEdid{}
  BracketFormId{value: U32}
  UnsupportedIdentity{reason: U32}

type Fuz is Data:
  Fuz{present: Bool, responseId: U32, count: U32, span: Span}

type EntryMeta is Data:
  EntryMeta{source: SourceKey, number: U32, span: Span, list: U32, partial: Partial, sid: Maybe<&2, Sid>, rec: Rec, identity: Identity, edid: FieldRef, sourceText: FieldRef, destText: FieldRef, fuz: Fuz}

type ParamsMeta is Data:
  ParamsMeta{source: SourceKey, addon: FieldRef, sourceLanguage: FieldRef, destLanguage: FieldRef, span: Span}

type XmlEvent is Data:
  EvOpen{name: U32, at: Position}
  EvAttribute{name: U32, at: Position}
  EvAttributeScalar{value: U32, origin: Origin, span: Span}
  EvAttributeEnd{end: Position}
  EvStartEnd{empty: Bool, end: Position}
  EvClose{name: U32, span: Span}
  EvText{value: U32, origin: Origin, span: Span}

type EventSlot is Data:
  NoEvent{}
  SomeEvent{event: XmlEvent}

type LexResult is Data:
  Events{count: U32, e0: EventSlot, e1: EventSlot, e2: EventSlot}
  LexFailed{diagnostic: Diagnostic}

def zero_position() -> Position:
  Position{0,1,1}

def empty_span() -> Span:
  Span{zero_position(),zero_position()}

def missing_field() -> FieldRef:
  FieldRef{False{},0,0,0,empty_span()}

def defaults() -> Limits:
  Limits{67108864,64,200000,1048576,4096,64,64,4096,4096}

def error(phase: U32, reason: U32, at: Position, expected: U32, observed: U32) -> Diagnostic:
  Diagnostic{phase,reason,at,0,zero_position(),expected,observed,None{},SourceKey{0,0}}

def core_error(phase: U32, reason: U32, at: Position, core: E.Error) -> Diagnostic:
  Diagnostic{phase,reason,at,0,zero_position(),0,0,Some{core},SourceKey{0,0}}

# Internal lexer/input errors are source-neutral. The public Reader attaches its
# trusted root identity at every boundary, including failures during begin.
def with_source(error: Diagnostic, source: SourceKey) -> Diagnostic:
  match error:
    case Diagnostic{phase,reason,at,entry,start,expected,observed,core,old}: Diagnostic{phase,reason,at,entry,start,expected,observed,core,source}

def no_events() -> LexResult:
  Events{0,NoEvent{},NoEvent{},NoEvent{}}

def one(event: XmlEvent) -> LexResult:
  Events{1,SomeEvent{event},NoEvent{},NoEvent{}}

def two(first: XmlEvent, second: XmlEvent) -> LexResult:
  Events{2,SomeEvent{first},SomeEvent{second},NoEvent{}}

def three(first: XmlEvent, second: XmlEvent, third: XmlEvent) -> LexResult:
  Events{3,SomeEvent{first},SomeEvent{second},SomeEvent{third}}

def start(span: Span) -> Position:
  match span:
    case Span{start,end}: start

def end(span: Span) -> Position:
  match span:
    case Span{start,end}: end

def whitespace(+value: U32) -> Bool:
  Bool.or(U32.is_eq(value,32),Bool.or(U32.is_eq(value,9),Bool.or(U32.is_eq(value,10),U32.is_eq(value,13))))

def xml_character(+value: U32) -> Bool:
  Bool.or(Bool.or(U32.is_eq(value,9),Bool.or(U32.is_eq(value,10),U32.is_eq(value,13))),Bool.or(Bool.and(U32.is_ge(value,32),U32.is_le(value,55295)),Bool.or(Bool.and(U32.is_ge(value,57344),U32.is_le(value,65533)),Bool.and(U32.is_ge(value,65536),U32.is_le(value,1114111)))))

# Canonical UTF-8 width for already validated XML scalar values.
def width_three(value: U32, yes: Bool) -> U32:
  match yes:
    case True{}: 3
    case False{}: 4

def width_two(+value: U32, yes: Bool) -> U32:
  match yes:
    case True{}: 2
    case False{}: width_three(value,U32.is_le(value,65535))

def utf8_width_more(+value: U32, yes: Bool) -> U32:
  match yes:
    case True{}: 1
    case False{}: width_two(value,U32.is_le(value,2047))

def utf8_width(+value: U32) -> U32:
  utf8_width_more(value,U32.is_le(value,127))
