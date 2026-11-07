import Base
import ./error.bend as E

def scalar(+value: U32) -> Bool:
  Bool.and(U32.is_le(value,1114111),Bool.or(U32.is_lt(value,55296),U32.is_gt(value,57343)))

def width_four(value: U32, small: Bool) -> U32:
  match small:
    case True{}: 3
    case False{}: 4

def width_three(+value: U32, small: Bool) -> U32:
  match small:
    case True{}: 2
    case False{}: width_four(value,U32.is_lt(value,65536))

# Only call for a validated Unicode scalar.
def width_two(+value: U32, small: Bool) -> U32:
  match small:
    case True{}: 1
    case False{}: width_three(value,U32.is_lt(value,2048))

def width(+value: U32) -> U32:
  width_two(value,U32.is_lt(value,128))
