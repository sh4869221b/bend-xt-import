import Base
import ../../core/error.bend as E
import ../../core/budget.bend as B
import ../../core/bytes.bend as Bytes
import ../../hash/sha256.bend as SHA
import ./sha.bend as T

def updated(p: B.Budget & Bytes.OwnedBytes & SHA.ShaState & Result<&2, &2, E.Error, Unit>) -> IO(Unit):
  (budget,bytes,state,result) = p
  match result:
    case Done{u}: T.input_dropped(state,Bytes.drop(budget,bytes))
    case _: IO.die(Unit,70,"NIST update failed")

def initialized(bytes: Bytes.OwnedBytes, length: U32, p: B.Budget & Result<&2, &1, E.Error, SHA.ShaState>) -> IO(Unit):
  (budget,result) = p
  match result:
    case Done{state}: updated(SHA.update(budget,state,bytes,0,length))
    case _: IO.die(Unit,70,"NIST init failed")

def fill(text: String, +index: U32, p: B.Budget & Bytes.OwnedBytes & Result<&2, &2, E.Error, Unit>) -> IO(Unit):
  match text:
    case SNil{}:
      (budget,bytes,result) = p
      match result:
        case Done{u}: initialized(bytes,index,SHA.init(budget))
        case _: IO.die(Unit,70,"NIST fill failed")
    case SCon{Chr{value},rest}:
      (budget,bytes,result) = p
      match result:
        case Done{u}: fill(rest,U32.inc(index),Bytes.put(budget,bytes,index,value))
        case _: IO.die(Unit,70,"NIST fill failed")

def created(text: String, p: B.Budget & Result<&2, &1, E.Error, Bytes.OwnedBytes>) -> IO(Unit):
  (budget,result) = p
  match result:
    case Done{bytes}: fill(text,0,(budget,bytes,Done{Unit{}}))
    case _: IO.die(Unit,70,"NIST new failed")

def started(text: String, length: U32, result: Result<&2, &1, E.Error, B.Budget>) -> IO(Unit):
  match result:
    case Done{budget}: created(text,Bytes.new(budget,length))
    case _: IO.die(Unit,70,"NIST budget failed")

def run(text: String, length: U32) -> IO(Unit):
  started(text,length,B.start(1,B.Six{0,0,0,0,1048576,10000}))

def main() -> IO(Unit):
  do IO<Unit>:
    run("abc",3)
    run("abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq",56)
    run("abcdefghbcdefghicdefghijdefghijkefghijklfghijklmghijklmnhijklmnoijklmnopjklmnopqklmnopqrlmnopqrsmnopqrstnopqrstu",112)
