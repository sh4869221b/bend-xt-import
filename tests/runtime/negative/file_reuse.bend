# EXPECT check rejection: an affine File is closed twice.
import Base
def close_twice(f: File) -> IO(Unit):
  do IO<Unit>:
    File.close(f)
    File.close(f)
def main() -> IO(Unit):
  do IO<Unit>:
    f : File <- IO.try(File, File.open("input.bin", "r"))
    close_twice(f)
