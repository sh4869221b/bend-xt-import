# Test-only checked bounds before masked Array API / U32 addition.
import Base
import ./memory_shapes.bend as M

def accept(ok: Bool) -> IO(Unit):
  match ok:
    case True{}: IO.print("accepted")
    case False{}: IO.die(Unit, 5, "range-rejected")

def remaining(+pos: U32, len: U32, +end: U32, ok: Bool) -> IO(Unit):
  match ok:
    case False{}: accept(False{})
    case True{}: accept(U32.is_le(len, U32.sub(end, pos)))

def access(p: Array<U32> & U32) -> IO(Unit):
  (a, value) = p
  IO.print(U32.show(value))

def index_read(i: U32, ok: Bool) -> IO(Unit):
  match ok:
    case False{}: IO.die(Unit, 5, "index-rejected-before-array")
    case True{}: access(Array.get(U32, Array.new(U32, 16n, 123), i))

def command(args: List<String>) -> IO(Unit):
  match args:
    case _ <> "range" <> a <> b <> c <> Nil{}:
      do IO<Unit>:
        +pos : U32 <- M.parsed(U32.read(a))
        len : U32 <- M.parsed(U32.read(b))
        +end : U32 <- M.parsed(U32.read(c))
        remaining(pos, len, end, U32.is_le(pos, end))
    case _ <> "index" <> a <> b <> c <> Nil{}:
      do IO<Unit>:
        +i : U32 <- M.parsed(U32.read(a))
        +len : U32 <- M.parsed(U32.read(b))
        +capacity : U32 <- M.parsed(U32.read(c))
        index_read(i, Bool.and(U32.is_eq(capacity, 65536), Bool.and(U32.is_le(len, capacity), U32.is_lt(i, len))))
    case _: IO.die(Unit, 2, "usage: range POSITION LENGTH END | index INDEX LOGICAL_LENGTH CAPACITY")

def main() -> IO(Unit):
  do IO<Unit>:
    args : List<String> <- IO.args()
    command(args)
