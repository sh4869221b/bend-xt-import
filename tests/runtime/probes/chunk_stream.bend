import Base
import ./Support.bend as T

def fill(xs: List<&2, U32>, a: Array<U32>, +i: U32) -> Array<U32>:
  match xs:
    case Nil{}: a
    case x <> tail: fill(tail, Array.set(U32, a, i, x), U32.inc(i))

def to_bytes(xs: List<U32>) -> List<&2, U32>:
  match xs:
    case Nil{}: Nil{}
    case x <> tail: x <> to_bytes(tail)

def convert(+xs: List<&2, U32>) -> List<&2, U32>:
  +count = List.length(&2, U32, xs)
  a = fill(xs, Array.new(U32, 16n, 0), 0)
  to_bytes(List.take(&1, U32, Array.to_list(U32, a), count))

def next(fuel: Nat, p: File & List<&2, U32>, output: File, +total: U32) -> IO(Unit):
  match fuel:
    case 0n: IO.die(Unit, 5, "experiment chunk limit")
    case 1n+left:
      (input, data) = p
      match data:
        case Nil{}:
          do IO<Unit>:
            File.close(input)
            File.close(output)
            IO.print(U32.show(total))
        case x <> tail:
          +data = {x <> tail : List<&2, U32>}
          +count = U32.from_nat(List.length(&2, U32, data))
          do IO<Unit>:
            r : File & Result<&1, &1, U32 & String, Unit> <- File.write_bytes(output, convert(data))
            output : File <- T.wrote(r)
            r : File & Result<&1, &1, U32 & String, List<&2, U32>> <- File.read_bytes(input, 65536)
            p : File & List<&2, U32> <- T.bytes(r)
            next(left, p, output, U32.add(total, count))

def main() -> IO(Unit):
  do IO<Unit>:
    input : File <- IO.try(File, File.open("input.bin", "r"))
    output : File <- IO.try(File, File.open("output.bin", "x"))
    r : File & Result<&1, &1, U32 & String, List<&2, U32>> <- File.read_bytes(input, 65536)
    p : File & List<&2, U32> <- T.bytes(r)
    next(16385n, p, output, 0)
