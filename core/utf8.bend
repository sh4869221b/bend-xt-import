import Base
import ./error.bend as E
import ./unicode.bend as U

type State is Data:
  State{remaining: U32, value: U32, minimum: U32, start: U32, next: U32}
  Broken{error: E.Error}

type Step is Data:
  Step{state: State, scalar: Maybe<&2, U32>}

type Encoded is Data:
  Encoded{count: U32, b0: U32, b1: U32, b2: U32, b3: U32}

def init() -> State:
  State{0,0,0,0,0}

def failed(error: E.Error) -> Step:
  Step{Broken{error},None{}}

def lead_four(byte: U32, +offset: U32, valid: Bool) -> Step:
  match valid:
    case False{}: failed(E.InvalidEncoding{0,offset,1})
    case True{}: Step{State{3,U32.and(byte,7),65536,offset,U32.inc(offset)},None{}}

def lead_three(+byte: U32, +offset: U32, valid: Bool) -> Step:
  match valid:
    case False{}: lead_four(byte,offset,Bool.and(U32.is_ge(byte,240),U32.is_le(byte,244)))
    case True{}: Step{State{2,U32.and(byte,15),2048,offset,U32.inc(offset)},None{}}

def lead_two(+byte: U32, +offset: U32, valid: Bool) -> Step:
  match valid:
    case False{}: lead_three(byte,offset,Bool.and(U32.is_ge(byte,224),U32.is_le(byte,239)))
    case True{}: Step{State{1,U32.and(byte,31),128,offset,U32.inc(offset)},None{}}

def lead(+byte: U32, +offset: U32, ascii: Bool) -> Step:
  match ascii:
    case True{}: Step{State{0,0,0,0,U32.inc(offset)},Some{byte}}
    case False{}: lead_two(byte,offset,Bool.and(U32.is_ge(byte,194),U32.is_le(byte,223)))

def completed(value: U32, start: U32, offset: U32, valid: Bool) -> Step:
  match valid:
    case False{}: failed(E.InvalidEncoding{0,start,2})
    case True{}: Step{State{0,0,0,0,U32.inc(offset)},Some{value}}

def continuation_value(remaining: U32, +value: U32, +minimum: U32, start: U32, offset: U32, last: Bool) -> Step:
  match last:
    case True{}: completed(value,start,offset,Bool.and(U32.is_ge(value,minimum),U.scalar(value)))
    case False{}: Step{State{U32.sub(remaining,1),value,minimum,start,U32.inc(offset)},None{}}

# Enforce E0/ED/F0/F4 second-byte constraints at the offending byte.
def second_byte(remaining: U32, value: U32, byte: U32) -> Bool:
  match remaining value:
    case 2 0: U32.is_ge(byte,160)
    case 2 13: U32.is_le(byte,159)
    case 3 0: U32.is_ge(byte,144)
    case 3 4: U32.is_le(byte,143)
    case _ _: True{}

def continuation(+remaining: U32, value: U32, minimum: U32, start: U32, +offset: U32, byte: U32, valid: Bool) -> Step:
  match valid:
    case False{}: failed(E.InvalidEncoding{0,offset,3})
    case True{}: continuation_value(remaining,U32.or(U32.shln(value,6n),U32.and(byte,63)),minimum,start,offset,U32.is_eq(remaining,1))

def byte_state(remaining: U32, +value: U32, minimum: U32, start: U32, +offset: U32, +byte: U32) -> Step:
  match remaining:
    case 0: lead(byte,offset,U32.is_lt(byte,128))
    case +n: continuation(n,value,minimum,start,offset,byte,Bool.and(Bool.and(U32.is_ge(byte,128),U32.is_le(byte,191)),second_byte(n,value,byte)))

# Internal transition: the adapter charges the byte read before calling this.
def byte_valid(remaining: U32, value: U32, minimum: U32, start: U32, offset: U32, byte: U32, valid: Bool) -> Step:
  match valid:
    case False{}: failed(E.Overflow{0,offset,1})
    case True{}: byte_state(remaining,value,minimum,start,offset,byte)

def step(state: State, byte: U32) -> Step:
  match state:
    case Broken{error}: failed(error)
    case State{remaining,value,minimum,start,+offset}:
      byte_valid(remaining,value,minimum,start,offset,byte,U32.is_lt(offset,4294967295))

def finish(state: State) -> Result<&2, &2, E.Error, Unit>:
  match state:
    case Broken{error}: Fail{error}
    case State{0,value,minimum,start,next}: Done{Unit{}}
    case State{remaining,value,minimum,start,next}: Fail{E.InvalidEncoding{0,start,4}}

def encode_four(+value: U32, small: Bool) -> Encoded:
  match small:
    case True{}: Encoded{3,U32.or(224,U32.shrn(value,12n)),U32.or(128,U32.and(U32.shrn(value,6n),63)),U32.or(128,U32.and(value,63)),0}
    case False{}: Encoded{4,U32.or(240,U32.shrn(value,18n)),U32.or(128,U32.and(U32.shrn(value,12n),63)),U32.or(128,U32.and(U32.shrn(value,6n),63)),U32.or(128,U32.and(value,63))}

def encode_three(+value: U32, small: Bool) -> Encoded:
  match small:
    case True{}: Encoded{2,U32.or(192,U32.shrn(value,6n)),U32.or(128,U32.and(value,63)),0,0}
    case False{}: encode_four(value,U32.is_lt(value,65536))

def encode_two(+value: U32, small: Bool) -> Encoded:
  match small:
    case True{}: Encoded{1,value,0,0,0}
    case False{}: encode_three(value,U32.is_lt(value,2048))

def encode_valid(+value: U32, offset: U32, valid: Bool) -> Result<&2, &2, E.Error, Encoded>:
  match valid:
    case False{}: Fail{E.InvalidEncoding{0,offset,5}}
    case True{}: Done{encode_two(value,U32.is_lt(value,128))}

def encode(+value: U32, offset: U32) -> Result<&2, &2, E.Error, Encoded>:
  encode_valid(value,offset,U.scalar(value))
