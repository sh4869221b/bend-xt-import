# EXPECT check success: matching control closes the File once.
import Base
def close_once(f: File) -> IO(Unit):
  File.close(f)
def main() -> IO(Unit):
  do IO<Unit>:
    f : File <- IO.try(File, File.open("input.bin", "r"))
    close_once(f)
