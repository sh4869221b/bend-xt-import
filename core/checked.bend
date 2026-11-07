import Base
import ./error.bend as E

def add_fit(a: U32, b: U32, ok: Bool) -> Result<&2, &2, E.Error, U32>:
  match ok:
    case True{}: Done{U32.add(a, b)}
    case False{}: Fail{E.Overflow{0, a, b}}

def add(+a: U32, +b: U32) -> Result<&2, &2, E.Error, U32>:
  add_fit(a, b, U32.is_le(b, U32.sub(4294967295, a)))

def sub_fit(a: U32, b: U32, ok: Bool) -> Result<&2, &2, E.Error, U32>:
  match ok:
    case True{}: Done{U32.sub(a, b)}
    case False{}: Fail{E.Overflow{1, a, b}}

def sub(+a: U32, +b: U32) -> Result<&2, &2, E.Error, U32>:
  sub_fit(a, b, U32.is_le(b, a))

def mul_fit(a: U32, b: U32, ok: Bool) -> Result<&2, &2, E.Error, U32>:
  match ok:
    case True{}: Done{U32.mul(a, b)}
    case False{}: Fail{E.Overflow{2, a, b}}

def mul_nonzero(+a: U32, +b: U32, zero: Bool) -> Result<&2, &2, E.Error, U32>:
  match zero:
    case True{}: Done{0}
    case False{}: mul_fit(a, b, U32.is_le(a, U32.div(4294967295, b)))

def mul(a: U32, +b: U32) -> Result<&2, &2, E.Error, U32>:
  mul_nonzero(a, b, U32.is_zero(b))

def byte_fit(value: U32, ok: Bool) -> Result<&2, &2, E.Error, U32>:
  match ok:
    case True{}: Done{value}
    case False{}: Fail{E.InvalidByte{value}}

def byte(+value: U32) -> Result<&2, &2, E.Error, U32>:
  byte_fit(value, U32.is_le(value, 255))

# All shifts are bounded by the finite recursion; no arbitrary Nat depth.
def capacity_go(fuel: Nat, +wanted: U32, +size: U32, depth: U32, fits: Bool) -> Result<&2, &1, E.Error, U32 & U32>:
  match fuel fits:
    case 0n True{}: Done{(size, depth)}
    case 0n False{}: Fail{E.Bounds{0, wanted, 65536}}
    case 1n+rest True{}: Done{(size, depth)}
    case 1n+rest False{}:
      capacity_go(rest, wanted, U32.shl(size), U32.inc(depth), U32.is_le(wanted, U32.shl(size)))

def ceil_capacity(+wanted: U32) -> Result<&2, &1, E.Error, U32 & U32>:
  capacity_go(16n, wanted, 1, 0, U32.is_le(wanted, 1))
