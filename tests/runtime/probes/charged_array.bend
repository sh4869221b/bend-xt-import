# One measured experiment profile, not a general-purpose memory allocator.
# Charge=max(65536,16*capacity): U32 BUF payload=4*capacity, plus margin.
import Base
import ./memory_shapes.bend as M

def cycles(n: Nat, +depth: U32, +count: U32, +cost: U32) -> IO(Unit):
  match n:
    case 0n: IO.print("complete")
    case 1n+left:
      do IO<Unit>:
        IO.print("reserved=" ++ U32.show(cost))
        checksum : U32 <- M.shape(1, depth, count, 100)
        IO.print("checksum=" ++ U32.show(checksum))
        IO.print("released=0")
        cycles(left, depth, count, cost)

def fit(depth: U32, count: U32, cost: U32, n: U32, ok: Bool) -> IO(Unit):
  match ok:
    case False{}: IO.die(Unit, 5, "charge-rejected-before-array")
    case True{}: cycles(U32.to_nat(n), depth, count, cost)

def charged(depth: U32, count: U32, +cost: U32, n: U32, limit: U32) -> IO(Unit):
  fit(depth, count, cost, n, U32.is_le(cost, limit))

def cost(depth: U32, +count: U32, n: U32, limit: U32, small: Bool) -> IO(Unit):
  match small:
    case True{}: charged(depth, count, 65536, n, limit)
    case False{}: charged(depth, count, U32.mul(count, 16), n, limit)

def count(+depth: U32, n: U32, limit: U32, +size: U32) -> IO(Unit):
  cost(depth, size, n, limit, U32.is_le(size, 4096))

def guard(+depth: U32, n: U32, limit: U32, ok: Bool) -> IO(Unit):
  match ok:
    case False{}: IO.die(Unit, 2, "depth<=24 cycles<=1000 limit<=268435456")
    case True{}: count(depth, n, limit, U32.shln(1, U32.to_nat(depth)))

def command(args: List<String>) -> IO(Unit):
  match args:
    case _ <> a <> b <> c <> Nil{}:
      do IO<Unit>:
        +depth : U32 <- M.parsed(U32.read(a))
        +limit : U32 <- M.parsed(U32.read(b))
        +n : U32 <- M.parsed(U32.read(c))
        guard(depth, n, limit, Bool.and(U32.is_le(depth, 24), Bool.and(U32.is_le(n, 1000), U32.is_le(limit, 268435456))))
    case _: IO.die(Unit, 2, "usage: DEPTH LIMIT CYCLES")

def main() -> IO(Unit):
  do IO<Unit>:
    args : List<String> <- IO.args()
    command(args)
