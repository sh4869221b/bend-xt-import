import Base
import ./Support.bend as T

def write(f: File, data: List<&2, U32>) -> IO(Unit):
  do IO<Unit>:
    r : File & Result<&1, &1, U32 & String, Unit> <- File.write_bytes(f, data)
    f : File <- T.wrote(r)
    File.close(f)

def command(args: List<String>) -> IO(Unit):
  match args:
    case _ <> "missing" <> Nil{}:
      do IO<Unit>:
        f : File <- IO.try(File, File.open("missing.bin", "r"))
        File.close(f)
    case _ <> "denied" <> Nil{}:
      do IO<Unit>:
        f : File <- IO.try(File, File.open("denied.bin", "r"))
        File.close(f)
    case _ <> "mode" <> Nil{}:
      do IO<Unit>:
        f : File <- IO.try(File, File.open("output.bin", "not-a-mode"))
        File.close(f)
    case _ <> "invalid-byte" <> Nil{}:
      do IO<Unit>:
        f : File <- IO.try(File, File.open("output.bin", "x"))
        write(f, [1, 256, 2])
    case _ <> "readonly" <> Nil{}:
      do IO<Unit>:
        f : File <- IO.try(File, File.open("input.bin", "r"))
        write(f, [1])
    case _ <> "full" <> Nil{}:
      do IO<Unit>:
        f : File <- IO.try(File, File.open("/dev/full", "w"))
        write(f, [1])
    case _: IO.die(Unit, 2, "unknown experiment")

def main() -> IO(Unit):
  do IO<Unit>:
    args : List<String> <- IO.args()
    command(args)
