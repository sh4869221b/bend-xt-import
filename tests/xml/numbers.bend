import Base
import ../../xml/numbers.bend as N

def check(result: Result<&2, &2, U32, U32>) -> IO(Unit):
  match result:
    case Done{1114111}: IO.print("numbers-ok")
    case _: IO.die(Unit,70,"numeric boundary")

def main() -> IO(Unit):
  check(N.character(N.push(N.push(N.push(N.push(N.push(N.push(N.begin(True{}),49),48),102),102),102),102)))
