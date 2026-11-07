import Base
import ../../core/error.bend as E
import ../../core/utf8.bend as U8
import ../../core/cp1252.bend as CP
import ../../core/codec.bend as Codec

def invalid(error: E.Error) -> IO(Unit):
  match error:
    case E.InvalidEncoding{codec,offset,reason}:
      IO.die(Unit,3,U32.show(codec) ++ ":" ++ U32.show(offset) ++ ":" ++ U32.show(reason))
    case _: IO.die(Unit,4,"unexpected error")

def nibble_other(+c: U32, valid: Bool) -> Maybe<&2, U32>:
  match valid:
    case False{}: None{}
    case True{}: Some{U32.add(U32.sub(c,97),10)}

def nibble_digit(+c: U32, valid: Bool) -> Maybe<&2, U32>:
  match valid:
    case False{}: nibble_other(c,Bool.and(U32.is_ge(c,97),U32.is_le(c,102)))
    case True{}: Some{U32.sub(c,48)}

def nibble(c: Char) -> Maybe<&2, U32>:
  match c:
    case Chr{+n}: nibble_digit(n,Bool.and(U32.is_ge(n,48),U32.is_le(n,57)))

def combine(a: Maybe<&2, U32>, b: Maybe<&2, U32>) -> Maybe<&2, U32>:
  match a b:
    case Some{x} Some{y}: Some{U32.add(U32.mul(x,16),y)}
    case _ _: None{}

def step_output(step: U8.Step) -> IO(U8.State):
  match step:
    case U8.Step{state,None{}}: IO.pure(U8.State,state)
    case U8.Step{state,Some{scalar}}:
      do IO<U8.State>:
        IO.print(U32.show(scalar))
        IO.pure(U8.State,state)

def process(kind: U32, state: U8.State, byte: Maybe<&2, U32>) -> IO(U8.State):
  match byte:
    case None{}: IO.die(U8.State,2,"bad test hex")
    case Some{value}: step_output(Codec.transition(kind,state,value))

def finished(result: Result<&2, &2, E.Error, Unit>) -> IO(Unit):
  match result:
    case Fail{error}: invalid(error)
    case Done{u}: IO.print("done")

def decode(hex: String, +kind: U32, state: U8.State) -> IO(Unit):
  match hex:
    case SNil{}: finished(U8.finish(state))
    case SCon{a,SCon{b,rest}}:
      do IO<Unit>:
        next : U8.State <- process(kind,state,combine(nibble(a),nibble(b)))
        decode(rest,kind,next)
    case _: IO.die(Unit,2,"odd test hex")

def encoded(result: Result<&2, &2, E.Error, U8.Encoded>) -> IO(Unit):
  match result:
    case Fail{error}: invalid(error)
    case Done{U8.Encoded{count,a,b,c,d}}:
      do IO<Unit>:
        IO.print(U32.show(count))
        IO.print(U32.show(a))
        IO.print(U32.show(b))
        IO.print(U32.show(c))
        IO.print(U32.show(d))

def parsed(r: Maybe<&2, U32>) -> IO(U32):
  match r:
    case None{}: IO.die(U32,2,"bad test integer")
    case Some{value}: IO.pure(U32,value)

def command(args: List<String>) -> IO(Unit):
  match args:
    case _ <> "decode" <> k <> hex <> Nil{}:
      do IO<Unit>:
        kind : U32 <- parsed(U32.read(k))
        decode(hex,kind,U8.init())
    case _ <> "encode" <> k <> value <> Nil{}:
      do IO<Unit>:
        kind : U32 <- parsed(U32.read(k))
        scalar : U32 <- parsed(U32.read(value))
        encoded(Codec.packet(kind,scalar,0))
    case _: IO.die(Unit,2,"decode KIND HEX | encode KIND SCALAR")

def main() -> IO(Unit):
  do IO<Unit>:
    args : List<String> <- IO.args()
    command(args)
