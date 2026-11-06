import Base
import ./Support.bend as T

def read_handle(f: File, at: Bool) -> IO(Unit):
  match at:
    case True{}:
      do IO<Unit>:
        r : File & Result<&1, &1, U32 & String, List<&2, U32>> <- File.read_at(f, 0, 8192)
        f : File <- T.show_read(r)
        File.close(f)
    case False{}:
      do IO<Unit>:
        r : File & Result<&1, &1, U32 & String, List<&2, U32>> <- File.read_bytes(f, 8192)
        f : File <- T.show_read(r)
        File.close(f)

def write_handle(f: File, at: Bool) -> IO(Unit):
  match at:
    case True{}:
      do IO<Unit>:
        r : File & Result<&1, &1, U32 & String, Unit> <- File.write_at(f, 0, [0, 1, 2, 3, 4, 255, 0, 33])
        f : File <- T.wrote(r)
        File.close(f)
        IO.print("complete")
    case False{}:
      do IO<Unit>:
        r : File & Result<&1, &1, U32 & String, Unit> <- File.write_bytes(f, [0, 1, 2, 3, 4, 255, 0, 33])
        f : File <- T.wrote(r)
        File.close(f)
        IO.print("complete")

def read_file(at: Bool) -> IO(Unit):
  do IO<Unit>:
    f : File <- IO.try(File, File.open("input.bin", "r"))
    read_handle(f, at)

def write_file(at: Bool) -> IO(Unit):
  do IO<Unit>:
    f : File <- IO.try(File, File.open("output.bin", "x"))
    write_handle(f, at)


def read_twice() -> IO(Unit):
  do IO<Unit>:
    f : File <- IO.try(File, File.open("input.bin", "r"))
    r : File & Result<&1, &1, U32 & String, List<&2, U32>> <- File.read_bytes(f, 8192)
    f : File <- T.show_read(r)
    r : File & Result<&1, &1, U32 & String, List<&2, U32>> <- File.read_bytes(f, 8192)
    f : File <- T.show_read(r)
    File.close(f)

def zeros(n: Nat) -> List<&2, U32>:
  match n:
    case 0n: Nil{}
    case 1n+left: 0 <> zeros(left)

def long_handle(f: File, at: Bool) -> IO(Unit):
  match at:
    case False{}:
      do IO<Unit>:
        r : File & Result<&1, &1, U32 & String, Unit> <- File.write_bytes(f, zeros(8192n))
        f : File <- T.wrote(r)
        File.close(f)
        IO.print("complete")
    case True{}:
      do IO<Unit>:
        r : File & Result<&1, &1, U32 & String, Unit> <- File.write_at(f, 0, zeros(8192n))
        f : File <- T.wrote(r)
        File.close(f)
        IO.print("complete")

def write_long(at: Bool) -> IO(Unit):
  do IO<Unit>:
    f : File <- IO.try(File, File.open("output.bin", "x"))
    long_handle(f, at)

def command(args: List<String>) -> IO(Unit):
  match args:
    case _ <> "read-twice" <> Nil{}: read_twice()
    case _ <> "write-long" <> Nil{}: write_long(False{})
    case _ <> "pwrite-long" <> Nil{}: write_long(True{})
    case _ <> "read" <> Nil{}: read_file(False{})
    case _ <> "pread" <> Nil{}: read_file(True{})
    case _ <> "write" <> Nil{}: write_file(False{})
    case _ <> "pwrite" <> Nil{}: write_file(True{})
    case _: IO.die(Unit, 2, "unknown experiment")

def main() -> IO(Unit):
  do IO<Unit>:
    args : List<String> <- IO.args()
    command(args)
