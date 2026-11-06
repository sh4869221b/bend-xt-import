# EXPECT check rejection: the affine array a is used twice.
import Base
def duplicate(a: Array<U32>) -> Array<U32> & Array<U32>:
  (a, a)
def main() -> Array<U32> & Array<U32>:
  duplicate(Array.new(U32, 2n, 0))
