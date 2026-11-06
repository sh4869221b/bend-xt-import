import Base
import ./Support.bend as T

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
          +count = List.length(&2, U32, data)
          do IO<Unit>:
            r : File & Result<&1, &1, U32 & String, Unit> <- File.write_bytes(output, data)
            output : File <- T.wrote(r)
            r : File & Result<&1, &1, U32 & String, List<&2, U32>> <- File.read_bytes(input, 65536)
            p : File & List<&2, U32> <- T.bytes(r)
            next(left, p, output, U32.add(total, U32.from_nat(count)))

def main() -> IO(Unit):
  do IO<Unit>:
    input : File <- IO.try(File, File.open("input.bin", "r"))
    output : File <- IO.try(File, File.open("output.bin", "x"))
    r : File & Result<&1, &1, U32 & String, List<&2, U32>> <- File.read_bytes(input, 65536)
    p : File & List<&2, U32> <- T.bytes(r)
    next(16385n, p, output, 0)
