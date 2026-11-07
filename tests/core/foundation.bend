import Base
import ../../core/checked.bend as C
import ../../core/error.bend as E
import ../../core/budget.bend as B
import ../../core/bytes.bend as Bytes
import ../../core/scalars.bend as Scalars
import ../../core/cursor.bend as Cursor
import ../../core/utf8.bend as Utf8
import ../../core/cp1252.bend as Cp
import ../../hash/sha256.bend as SHA
import ../../core/codec.bend as Codec

type Affine is Type:
  Owner{value: U32}

def value(x: Affine) -> U32:
  match x:
    case Owner{n}: n

def check(r: Result<&2, &2, E.Error, U32>) -> IO(Unit):
  match r:
    case Done{x}: IO.print(U32.show(x))
    case Fail{e}: IO.die(Unit, 70, "unexpected error")

def main() -> IO(Unit):
  do IO<Unit>:
    check(C.add(4294967294, 1))
    check(C.mul(0, 4294967295))
    IO.print(U32.show(value(Owner{7})))
