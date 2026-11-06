import Base
import ./Support.bend as T

def size_done(p: File & Result<&1, &1, U32 & String, U32>) -> IO(Unit):
  (f, r) = p
  do IO<Unit>:
    n : U32 <- IO.pass(U32, r)
    IO.print(U32.show(n))
    File.close(f)

def basic() -> IO(Unit):
  do IO<Unit>:
    f : File <- IO.try(File, File.open("input.bin", "r+"))
    r : File & Result<&1, &1, U32 & String, List<&2, U32>> <- File.read_bytes(f, 1)
    f : File <- T.show_read(r)
    w : File & Result<&1, &1, U32 & String, Unit> <- File.write_at(f, 3, [0, 255])
    f : File <- T.wrote(w)
    r : File & Result<&1, &1, U32 & String, List<&2, U32>> <- File.read_at(f, 3, 2)
    f : File <- T.show_read(r)
    r : File & Result<&1, &1, U32 & String, List<&2, U32>> <- File.read_bytes(f, 1)
    f : File <- T.show_read(r)
    r : File & Result<&1, &1, U32 & String, List<&2, U32>> <- File.read_at(f, 4294967295, 0)
    f : File <- T.show_read(r)
    File.close(f)

def command(args: List<String>) -> IO(Unit):
  match args:
    case _ <> "size" <> Nil{}:
      do IO<Unit>:
        f : File <- IO.try(File, File.open("input.bin", "r"))
        p : File & Result<&1, &1, U32 & String, U32> <- File.size(f)
        size_done(p)
    case _ <> "last" <> Nil{}:
      do IO<Unit>:
        f : File <- IO.try(File, File.open("input.bin", "r"))
        r : File & Result<&1, &1, U32 & String, List<&2, U32>> <- File.read_at(f, 4294967294, 1)
        f : File <- T.show_read(r)
        File.close(f)
    case _ <> "basic" <> Nil{}: basic()
    case _: IO.die(Unit, 2, "unknown experiment")

def main() -> IO(Unit):
  do IO<Unit>:
    args : List<String> <- IO.args()
    command(args)
