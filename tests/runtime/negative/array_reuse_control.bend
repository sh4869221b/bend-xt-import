# EXPECT check success: matching control, explicit supported clone.
import Base
def duplicate(a: Array<U32>) -> Array<U32> & Array<U32>:
  Array.clone(U32, a)
def main() -> Array<U32> & Array<U32>:
  duplicate(Array.new(U32, 2n, 0))
