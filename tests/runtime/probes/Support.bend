# Helpers for experiments only; this is not the importer's core library.
import Base

def number_result(r: Maybe<&2, U32>) -> U32:
  match r:
    case Some{n}: n
    case None{}: 0

def number(s: String) -> U32:
  number_result(U32.read(s))

def line(xs: List<&2, U32>) -> String:
  match xs:
    case Nil{}: ""
    case x <> tail: U32.show(x) ++ "," ++ line(tail)

def check(ok: Bool, message: String) -> IO(Unit):
  match ok:
    case True{}: IO.pure(Unit, Unit{})
    case False{}: IO.die(Unit, 70, message)

def wrote(p: File & Result<&1, &1, U32 & String, Unit>) -> IO(File):
  (f, r) = p
  do IO<File>:
    Unit <- IO.pass(Unit, r)
    return f

def bytes(p: File & Result<&1, &1, U32 & String, List<&2, U32>>) -> IO(File & List<&2, U32>):
  (f, r) = p
  do IO<File & List<&2, U32>>:
    xs : List<&2, U32> <- IO.pass(List<&2, U32>, r)
    return (f, xs)

def show_read(p: File & Result<&1, &1, U32 & String, List<&2, U32>>) -> IO(File):
  (f, r) = p
  do IO<File>:
    xs : List<&2, U32> <- IO.pass(List<&2, U32>, r)
    IO.print(line(xs))
    return f
