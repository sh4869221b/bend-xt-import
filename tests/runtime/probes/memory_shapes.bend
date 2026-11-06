# Measurement payloads only. No representation has a calibrated charge yet.
import Base

type Index is Data:
  Entry{offset: U32, size: U32, flags: U32}

def parsed(r: Maybe<&2, U32>) -> IO(U32):
  match r:
    case Some{n}: IO.pure(U32, n)
    case None{}: IO.die(U32, 2, "invalid-u32")

def fill(n: Nat, a: Array<U32>) -> Array<U32>:
  match n:
    case 0n: a
    case 1n+left0:
      +left = {left0 : Nat}
      +i = U32.from_nat(left)
      fill(left, Array.set(U32, a, i, U32.and(i, 255)))

def sum_array(n: Nat, p: Array<U32> & U32, sum: U32) -> U32:
  match n:
    case 0n:
      (a, value) = p
      U32.add(sum, value)
    case 1n+left0:
      (a, value) = p
      +left = {left0 : Nat}
      sum_array(left, Array.get(U32, a, U32.from_nat(left)), U32.add(sum, value))

def list_data(n: Nat, acc: List<&2, U32>) -> List<&2, U32>:
  match n:
    case 0n: acc
    case 1n+left0:
      +left = {left0 : Nat}
      list_data(left, U32.and(U32.from_nat(left), 255) <> acc)

def sum_list(xs: List<&2, U32>, sum: U32) -> U32:
  match xs:
    case Nil{}: sum
    case x <> tail: sum_list(tail, U32.add(sum, x))

def index_fill(n: Nat, a: Array<Index>) -> Array<Index>:
  match n:
    case 0n: a
    case 1n+left0:
      +left = {left0 : Nat}
      +i = U32.from_nat(left)
      index_fill(left, Array.set(Index, a, i, Entry{i, U32.and(i, 255), 1}))

def index_value(x: Index) -> U32:
  match x:
    case Entry{off, size, flags}: U32.add(off, U32.add(size, flags))

def sum_index(n: Nat, p: Array<Index> & Index, sum: U32) -> U32:
  match n:
    case 0n:
      (a, value) = p
      U32.add(sum, index_value(value))
    case 1n+left0:
      (a, value) = p
      +left = {left0 : Nat}
      sum_index(left, Array.get(Index, a, U32.from_nat(left)), U32.add(sum, index_value(value)))

def hold_array(a: Array<U32>, n: Nat, ms: U32) -> IO(U32):
  do IO<U32>:
    IO.print("live=array-u32")
    IO.sleep(ms)
    return sum_array(n, (a, 0), 0)

def hold_list(xs: List<&2, U32>, ms: U32) -> IO(U32):
  do IO<U32>:
    IO.print("live=list-u32")
    IO.sleep(ms)
    return sum_list(xs, 0)

def hold_index(a: Array<Index>, n: Nat, ms: U32) -> IO(U32):
  do IO<U32>:
    IO.print("live=index-array")
    IO.sleep(ms)
    return sum_index(n, (a, Entry{0, 0, 0}), 0)

def hold_text(s: String, ms: U32) -> IO(U32):
  do IO<U32>:
    IO.print("live=string")
    IO.sleep(ms)
    return U32.from_nat(String.length(s))

def to_array(xs: List<&2, U32>, a: Array<U32>, +i: U32) -> Array<U32>:
  match xs:
    case Nil{}: a
    case x <> tail: to_array(tail, Array.set(U32, a, i, x), U32.inc(i))

# Reconstruct quantity &1 returned by Array.to_list into copyable byte list.
def copy_list(xs: List<&1, U32>) -> List<&2, U32>:
  match xs:
    case Nil{}: Nil{}
    case x <> tail: x <> copy_list(tail)

def hold_conversion(+xs: List<&2, U32>, a: Array<U32>, ys: List<&2, U32>, n: Nat, ms: U32) -> IO(U32):
  do IO<U32>:
    IO.print("live=input-list+array+output-list")
    IO.sleep(ms)
    return U32.add(sum_list(xs, 0), U32.add(sum_array(n, (a, 0), 0), sum_list(ys, 0)))

def conversion_clone(+xs: List<&2, U32>, p: Array<U32> & Array<U32>, n: Nat, ms: U32) -> IO(U32):
  (a, b) = p
  hold_conversion(xs, a, copy_list(Array.to_list(U32, b)), n, ms)

def conversion(+xs: List<&2, U32>, depth: Nat, n: Nat, ms: U32) -> IO(U32):
  conversion_clone(xs, Array.clone(U32, to_array(xs, Array.new(U32, depth, 0), 0)), n, ms)

def shape(mode: U32, +depth: U32, +count: U32, ms: U32) -> IO(U32):
  match mode:
    case 0: IO.pure(U32, 0)
    case 1: hold_array(fill(U32.to_nat(count), Array.new(U32, U32.to_nat(depth), 0)), U32.to_nat(count), ms)
    case 2: hold_list(list_data(U32.to_nat(count), Nil{}), ms)
    case 3: hold_index(index_fill(U32.to_nat(count), Array.new(Index, U32.to_nat(depth), Entry{0, 0, 0})), U32.to_nat(count), ms)
    case 4: hold_text(String.repeat("a", U32.to_nat(count)), ms)
    case 5: hold_text(String.repeat("日", U32.to_nat(count)), ms)
    case 6: hold_text(String.repeat("😀", U32.to_nat(count)), ms)
    case 7: conversion(list_data(U32.to_nat(count), Nil{}), U32.to_nat(depth), U32.to_nat(count), ms)
    case _: IO.die(U32, 2, "unknown-mode")

def cycles(n: Nat, +mode: U32, +depth: U32, +count: U32, +ms: U32) -> IO(Unit):
  match n:
    case 0n: IO.print("complete")
    case 1n+left:
      do IO<Unit>:
        sum : U32 <- shape(mode, depth, count, ms)
        IO.print("released-checksum=" ++ U32.show(sum))
        IO.sleep(ms)
        cycles(left, mode, depth, count, ms)

def guard(mode: U32, +depth: U32, n: U32, ms: U32, ok: Bool) -> IO(Unit):
  match ok:
    case False{}: IO.die(Unit, 2, "bounds: mode<=7 depth<=24 cycles<=1000 hold-ms<=10000")
    case True{}: cycles(U32.to_nat(n), mode, depth, U32.shln(1, U32.to_nat(depth)), ms)

def command(args: List<String>) -> IO(Unit):
  match args:
    case _ <> a <> b <> c <> d <> Nil{}:
      do IO<Unit>:
        +mode : U32 <- parsed(U32.read(a))
        +depth : U32 <- parsed(U32.read(b))
        +n : U32 <- parsed(U32.read(c))
        +ms : U32 <- parsed(U32.read(d))
        guard(mode, depth, n, ms, Bool.and(Bool.and(U32.is_le(mode, 7), U32.is_le(depth, 24)), Bool.and(U32.is_le(n, 1000), U32.is_le(ms, 10000))))
    case _: IO.die(Unit, 2, "usage: MODE DEPTH CYCLES HOLD_MS (mode 0 baseline,1 array,2 list,3 index,4 ASCII,5 Japanese,6 nonBMP,7 conversion)")

def main() -> IO(Unit):
  do IO<Unit>:
    args : List<String> <- IO.args()
    command(args)
