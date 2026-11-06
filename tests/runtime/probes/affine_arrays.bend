import Base
import ./Support.bend as T

def fold(n: Nat, p: Array<U32> & U32, +sum: U32) -> U32:
  match n:
    case 0n:
      (a, value) = p
      U32.add(sum, value)
    case 1n+left0:
      (a, value) = p
      +left = {left0 : Nat}
      fold(left, Array.get(U32, a, U32.from_nat(left)), U32.add(sum, value))

def fill(n: Nat, a: Array<U32>) -> Array<U32>:
  match n:
    case 0n: a
    case 1n+left0:
      +left = {left0 : Nat}
      +i = U32.from_nat(left)
      fill(left, Array.set(U32, a, i, U32.xor(i, 21930)))

def display(p: Array<U32> & U32) -> IO(Unit):
  (a, wrapped) = p
  do IO<Unit>:
    IO.print(U32.show(wrapped))
    IO.print(U32.show(fold(65536n, (a, 0), 0)))

def swapped(p: Array<U32> & U32) -> IO(Unit):
  (a, old) = p
  do IO<Unit>:
    IO.print(U32.show(old))
    display(Array.get(U32, a, 65536))

def main() -> IO(Unit):
  a = fill(65536n, Array.new(U32, 16n, 0))
  swapped(Array.swap(U32, a, 12, 99))
