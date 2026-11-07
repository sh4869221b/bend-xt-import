import Base
import ../../xml/types.bend as T

def show(limits: T.Limits) -> IO(Unit):
  match limits:
    case T.Limits{a,b,c,d,e,f,g,h,i}: IO.print(U32.show(a))

def main() -> IO(Unit):
  show(T.defaults())
