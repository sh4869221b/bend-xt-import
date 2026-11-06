# Experiment only: charges are synthetic bytes, not calibrated runtime costs.
import Base

def parsed(r: Maybe<&2, U32>) -> IO(U32):
  match r:
    case Some{n}: IO.pure(U32, n)
    case None{}: IO.die(U32, 2, "invalid-u32")

def add_fit(+used: U32, +cost: U32, ok: Bool) -> Maybe<&2, U32>:
  match ok:
    case True{}: Some{U32.add(used, cost)}
    case False{}: None{}

def reserve_valid(+limit: U32, +used: U32, +cost: U32, ok: Bool) -> Maybe<&2, U32>:
  match ok:
    case False{}: None{}
    case True{}: add_fit(used, cost, U32.is_le(cost, U32.sub(limit, used)))

def reserve(+limit: U32, +used: U32, cost: U32) -> Maybe<&2, U32>:
  reserve_valid(limit, used, cost, U32.is_le(used, limit))

def release_fit(+used: U32, +cost: U32, ok: Bool) -> Maybe<&2, U32>:
  match ok:
    case False{}: None{}
    case True{}: Some{U32.sub(used, cost)}

def release(+used: U32, +cost: U32) -> Maybe<&2, U32>:
  release_fit(used, cost, U32.is_le(cost, used))

def multiply_nonzero(+n: U32, +stride: U32, ok: Bool) -> Maybe<&2, U32>:
  match ok:
    case False{}: None{}
    case True{}: Some{U32.mul(n, stride)}

def multiply_zero(+limit: U32, +n: U32, +stride: U32, zero: Bool) -> Maybe<&2, U32>:
  match zero:
    case True{}: Some{0}
    case False{}: multiply_nonzero(n, stride, U32.is_le(n, U32.div(limit, stride)))

def multiply(limit: U32, n: U32, +stride: U32) -> Maybe<&2, U32>:
  multiply_zero(limit, n, stride, U32.is_zero(stride))

def check(label: String, ok: Bool) -> IO(Unit):
  match ok:
    case True{}: IO.print(label)
    case False{}: IO.die(Unit, 70, label)

def expect(label: String, actual: Maybe<&2, U32>, expected: Maybe<&2, U32>) -> IO(Unit):
  match actual expected:
    case None{} None{}: IO.print(label)
    case Some{x} Some{y}:
      check(label, U32.is_eq(x, y))
    case _ _: IO.die(Unit, 70, label)

def selftest() -> IO(Unit):
  do IO<Unit>:
    expect("reserve-exact", reserve(268435456, 268435455, 1), Some{268435456})
    expect("reserve-over", reserve(268435456, 268435456, 1), None{})
    expect("reserve-invalid-used", reserve(7, 8, 0), None{})
    expect("reserve-wrap", reserve(4294967295, 4294967295, 1), None{})
    expect("reserve-max-exact", reserve(4294967295, 4294967294, 1), Some{4294967295})
    expect("release-exact", release(268435456, 268435456), Some{0})
    expect("release-underflow", release(0, 1), None{})
    expect("multiply-exact", multiply(268435456, 65536, 4096), Some{268435456})
    expect("multiply-over", multiply(268435456, 65537, 4096), None{})
    expect("multiply-wrap", multiply(4294967295, 65536, 65536), None{})
    expect("multiply-zero", multiply(0, 4294967295, 0), Some{0})
    expect("work-exact-synthetic", reserve(1073741824, 1073741823, 1), Some{1073741824})
    expect("work-over-synthetic", reserve(1073741824, 1073741824, 1), None{})

def output(r: Maybe<&2, U32>) -> IO(Unit):
  match r:
    case None{}: IO.die(Unit, 5, "budget-rejected-before-allocation")
    case Some{n}: IO.print(U32.show(n))

def data(n: Nat, acc: List<&2, U32>) -> List<&2, U32>:
  match n:
    case 0n: acc
    case 1n+left0:
      +left = {left0 : Nat}
      data(left, U32.and(U32.from_nat(left), 255) <> acc)

# Every visited element first consumes one unit. Work never resets per pass.
def scan(xs: List<&2, U32>, remaining: U32, sum: U32) -> IO(U32 & U32):
  match xs remaining:
    case Nil{} _ : IO.pure(U32 & U32, (remaining, sum))
    case _ 0: IO.die(U32 & U32, 5, "work-exhausted-before-visit")
    case x <> tail _ : scan(tail, U32.sub(remaining, 1), U32.add(sum, x))

def passes(n: Nat, +xs: List<&2, U32>, state: U32 & U32) -> IO(Unit):
  match n:
    case 0n:
      (remaining, sum) = state
      do IO<Unit>:
        IO.print("remaining=" ++ U32.show(remaining))
        IO.print("checksum=" ++ U32.show(sum))
    case 1n+left:
      (remaining, sum) = state
      do IO<Unit>:
        next : U32 & U32 <- scan(xs, remaining, sum)
        passes(left, xs, next)

def work_guard(n: U32, bytes: U32, limit: U32, ok: Bool) -> IO(Unit):
  match ok:
    case False{}: IO.die(Unit, 2, "work bounds: passes<=65536 bytes<=65536")
    case True{}: passes(U32.to_nat(n), data(U32.to_nat(bytes), Nil{}), (limit, 0))

def array_sum(n: Nat, p: Array<U32> & U32, sum: U32) -> U32:
  match n:
    case 0n:
      (a, value) = p
      U32.add(sum, value)
    case 1n+left0:
      (a, value) = p
      +left = {left0 : Nat}
      array_sum(left, Array.get(U32, a, U32.from_nat(left)), U32.add(sum, value))

# Fixed small real allocation, with caller-supplied SYNTHETIC charge.
# This tests reserve-before-allocation sequencing, not the cost of 1024 cells.
def allocate(r: Maybe<&2, U32>, +cost: U32) -> IO(Unit):
  match r:
    case None{}: IO.die(Unit, 5, "budget-rejected-before-allocation")
    case Some{+used}:
      do IO<Unit>:
        IO.print("reserved=" ++ U32.show(used))
        IO.print("allocated-checksum=" ++ U32.show(array_sum(1024n, (Array.new(U32, 10n, cost), 0), 0)))
        output(release(used, cost))

def allocation_cycles(n: Nat, +limit: U32, +cost: U32) -> IO(Unit):
  match n:
    case 0n: IO.print("complete")
    case 1n+left:
      do IO<Unit>:
        allocate(reserve(limit, 0, cost), cost)
        allocation_cycles(left, limit, cost)

def cycle_guard(n: U32, limit: U32, cost: U32, ok: Bool) -> IO(Unit):
  match ok:
    case False{}: IO.die(Unit, 2, "cycles<=1000")
    case True{}: allocation_cycles(U32.to_nat(n), limit, cost)

def command(args: List<String>) -> IO(Unit):
  match args:
    case _ <> "selftest" <> Nil{}: selftest()
    case _ <> "reserve" <> a <> b <> c <> Nil{}:
      do IO<Unit>:
        limit : U32 <- parsed(U32.read(a))
        used : U32 <- parsed(U32.read(b))
        cost : U32 <- parsed(U32.read(c))
        output(reserve(limit, used, cost))
    case _ <> "release" <> a <> b <> Nil{}:
      do IO<Unit>:
        used : U32 <- parsed(U32.read(a))
        cost : U32 <- parsed(U32.read(b))
        output(release(used, cost))
    case _ <> "multiply" <> a <> b <> c <> Nil{}:
      do IO<Unit>:
        limit : U32 <- parsed(U32.read(a))
        n : U32 <- parsed(U32.read(b))
        stride : U32 <- parsed(U32.read(c))
        output(multiply(limit, n, stride))
    case _ <> "work" <> a <> b <> c <> Nil{}:
      do IO<Unit>:
        +n : U32 <- parsed(U32.read(a))
        +bytes : U32 <- parsed(U32.read(b))
        limit : U32 <- parsed(U32.read(c))
        work_guard(n, bytes, limit, Bool.and(U32.is_le(n, 65536), U32.is_le(bytes, 65536)))
    case _ <> "allocation" <> a <> b <> c <> Nil{}:
      do IO<Unit>:
        limit : U32 <- parsed(U32.read(a))
        cost : U32 <- parsed(U32.read(b))
        +n : U32 <- parsed(U32.read(c))
        cycle_guard(n, limit, cost, U32.is_le(n, 1000))
    case _: IO.die(Unit, 2, "usage: selftest | reserve LIMIT USED COST | release USED COST | multiply LIMIT COUNT STRIDE | work PASSES BYTES LIMIT | allocation LIMIT COST CYCLES")

def main() -> IO(Unit):
  do IO<Unit>:
    args : List<String> <- IO.args()
    command(args)
