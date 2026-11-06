import Base
import ./Support.bend as T

def main() -> IO(Unit):
  do IO<Unit>:
    f : File <- IO.try(File, File.open("output.bin", "x"))
    r : File & Result<&1, &1, U32 & String, Unit> <- File.write_bytes(f, [0, 17, 255, 0])
    f : File <- T.wrote(r)
    File.close(f)
    IO.print("created")
