import Base
import ./Support.bend as T

def show_args(xs: List<List<&2, U32>>) -> IO(Unit):
  match xs:
    case Nil{}: IO.pure(Unit, Unit{})
    case x <> tail:
      do IO<Unit>:
        IO.print(T.line(x))
        show_args(tail)

def command(args: List<String>) -> IO(Unit):
  match args:
    case _ <> "exit" <> code <> Nil{}: IO.exit(T.number(code))
    case _ <> "die" <> Nil{}: IO.die(Unit, 7, "deliberate-die")
    case _:
      do IO<Unit>:
        raw : List<List<&2, U32>> <- IO.args_bytes()
        show_args(raw)

def main() -> IO(Unit):
  do IO<Unit>:
    args : List<String> <- IO.args()
    command(args)
