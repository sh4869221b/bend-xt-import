import Base
import ../../xml/tokenizer.bend as L
import ../../xml/types.bend as T

def report(p: L.State & T.LexResult) -> IO(Unit):
  (state,result) = p
  match result:
    case T.Events{count,a,b,c}: IO.print(U32.show(count))
    case T.LexFailed{d}: IO.print("failed")

def command(args: List<String>) -> IO(Unit):
  match args:
    case _ <> SCon{Chr{value},tail} <> Nil{}: report(L.text(L.Context{1,True{},False{},False{}},64,64,0,value,T.Span{T.Position{0,1,1},T.Position{1,1,2}}))
    case _: IO.die(Unit,64,"argument")

def main() -> IO(Unit):
  do IO<Unit>:
    args : List<String> <- IO.args()
    command(args)
