# Run ONLY under an externally verified dedicated memory limit.
# Finite count/depth are workload bounds, not sufficient isolation.
import Base

def parsed(r: Maybe<&2, U32>) -> IO(U32):
  match r:
    case Some{n}: IO.pure(U32, n)
    case None{}: IO.die(U32, 2, "invalid-u32")

def fill(n: Nat, a: Array<U32>, +seed: U32) -> Array<U32>:
  match n:
    case 0n: a
    case 1n+left0:
      +left = {left0 : Nat}
      +i = U32.from_nat(left)
      fill(left, Array.set(U32, a, i, U32.xor(i, seed)), seed)

def sum_array(n: Nat, p: Array<U32> & U32, sum: U32) -> U32:
  match n:
    case 0n:
      (a, value) = p
      U32.add(sum, value)
    case 1n+left0:
      (a, value) = p
      +left = {left0 : Nat}
      sum_array(left, Array.get(U32, a, U32.from_nat(left)), U32.add(sum, value))

def consume(xs: List<&1, Array<U32>>, +count: U32, sum: U32) -> U32:
  match xs:
    case Nil{}: sum
    case a <> tail: consume(tail, count, U32.add(sum, sum_array(U32.to_nat(count), (a, 0), 0)))

def retain(n: Nat, +depth: U32, +count: U32, +ms: U32, xs: List<&1, Array<U32>>, +made: U32) -> IO(Unit):
  match n:
    case 0n:
      do IO<Unit>:
        IO.print("all-live=" ++ U32.show(made))
        IO.sleep(ms)
        IO.print("released-checksum=" ++ U32.show(consume(xs, count, 0)))
        IO.print("complete")
    case 1n+left:
      a = fill(U32.to_nat(count), Array.new(U32, U32.to_nat(depth), 0), made)
      do IO<Unit>:
        IO.print("retained=" ++ U32.show(U32.inc(made)))
        IO.sleep(ms)
        retain(left, depth, count, ms, a <> xs, U32.inc(made))

def guard(n: U32, +depth: U32, ms: U32, ok: Bool) -> IO(Unit):
  match ok:
    case False{}: IO.die(Unit, 2, "bounds: arrays<=512 depth<=24 hold-ms<=10000")
    case True{}: retain(U32.to_nat(n), depth, U32.shln(1, U32.to_nat(depth)), ms, Nil{}, 0)

def command(args: List<String>) -> IO(Unit):
  match args:
    case _ <> a <> b <> c <> Nil{}:
      do IO<Unit>:
        +n : U32 <- parsed(U32.read(a))
        +depth : U32 <- parsed(U32.read(b))
        +ms : U32 <- parsed(U32.read(c))
        guard(n, depth, ms, Bool.and(U32.is_le(n, 512), Bool.and(U32.is_le(depth, 24), U32.is_le(ms, 10000))))
    case _: IO.die(Unit, 2, "usage: ARRAY_COUNT DEPTH HOLD_MS; dedicated 1GiB memory.max/swap.max=0 REQUIRED")

def main() -> IO(Unit):
  do IO<Unit>:
    args : List<String> <- IO.args()
    command(args)
