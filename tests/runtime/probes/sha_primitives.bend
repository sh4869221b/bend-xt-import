# SHA-256 prerequisites only: this program does not compute a hash.
import Base
import ./Support.bend as T

def rotate(+x: U32, +n: U32) -> U32:
  U32.or(U32.shrn(x, U32.to_nat(n)), U32.shln(x, U32.to_nat(U32.sub(32, n))))

def fill(n: Nat, a: Array<U32>, +seed: U32) -> Array<U32>:
  match n:
    case 0n: a
    case 1n+left0:
      +left = {left0 : Nat}
      +i = U32.from_nat(left)
      fill(left, Array.set(U32, a, i, U32.xor(seed, U32.mul(i, i))), seed)

def fold(n: Nat, p: Array<U32> & U32, +sum: U32) -> U32:
  match n:
    case 0n:
      (a, x) = p
      U32.add(sum, x)
    case 1n+left0:
      (a, x) = p
      +left = {left0 : Nat}
      fold(left, Array.get(U32, a, U32.from_nat(left)), U32.add(sum, x))

def vector(+a: U32, +b: U32, +shift: U32) -> IO(Unit):
  +lo = U32.add(a, b)
  +carry = Bool.to_u32(U32.is_lt(lo, a))
  +b0 = U32.and(U32.shrn(a, 24n), 255)
  +b1 = U32.and(U32.shrn(a, 16n), 255)
  +b2 = U32.and(U32.shrn(a, 8n), 255)
  +b3 = U32.and(a, 255)
  +packed = U32.or(U32.shln(b0, 24n), U32.or(U32.shln(b1, 16n), U32.or(U32.shln(b2, 8n), b3)))
  do IO<Unit>:
    IO.print(T.line([lo, U32.xor(a, b), U32.and(a, b), U32.or(a, b), U32.not(a), U32.shrn(a, U32.to_nat(shift)), U32.shln(a, U32.to_nat(shift)), rotate(a, shift), b0, b1, b2, b3, packed, carry, U32.shln(b, 3n), U32.shrn(b, 29n)]))
    IO.print(U32.show(fold(16n, (fill(16n, Array.new(U32, 4n, 0), a), 0), 0)))
    IO.print(U32.show(fold(64n, (fill(64n, Array.new(U32, 6n, 0), b), 0), 0)))

def command(args: List<String>) -> IO(Unit):
  match args:
    case _ <> a <> b <> shift <> Nil{}: vector(T.number(a), T.number(b), T.number(shift))
    case _: IO.die(Unit, 2, "expected a b shift")

def main() -> IO(Unit):
  do IO<Unit>:
    args : List<String> <- IO.args()
    command(args)
