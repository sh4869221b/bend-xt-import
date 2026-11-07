import Base
import ../../core/budget.bend as B
import ../../core/bytes.bend as Bytes
import ../../core/error.bend as E
import ../../hash/sha256.bend as SHA

def finish(r: Result<&1, &2, E.Error & B.Budget, B.Six>) -> IO(Unit):
  match r:
    case Fail{error}: IO.die(Unit,70,"live/held imbalance")
    case Done{used}: IO.print("done")

def disposed(p: B.Budget & Result<&1, &2, E.Error & B.Allocation, Unit>) -> IO(Unit):
  (budget,result) = p
  match result:
    case Fail{error}: IO.die(Unit,70,"dispose failed")
    case Done{u}: finish(B.finish(budget))

def one_print(p: B.Budget & Bytes.OwnedBytes & Result<&2, &2, E.Error, U32>) -> IO(B.Budget & Bytes.OwnedBytes):
  (budget,bytes,result) = p
  match result:
    case Fail{error}: IO.die(B.Budget & Bytes.OwnedBytes,70,"digest read failed")
    case Done{value}:
      do IO<B.Budget & Bytes.OwnedBytes>:
        IO.print(U32.show(value))
        IO.pure(B.Budget & Bytes.OwnedBytes,(budget,bytes))

def printed(fuel: Nat, +index: U32, p: B.Budget & Bytes.OwnedBytes) -> IO(Unit):
  match fuel:
    case 0n:
      (budget,bytes) = p
      disposed(Bytes.drop(budget,bytes))
    case 1n+rest:
      (budget,bytes) = p
      do IO<Unit>:
        pair : B.Budget & Bytes.OwnedBytes <- one_print(Bytes.get(budget,bytes,index))
        printed(rest,U32.inc(index),pair)

def finalized(p: B.Budget & SHA.FinalResult) -> IO(Unit):
  (budget,result) = p
  match result:
    case SHA.HashFailed{error,state,digest}: IO.die(Unit,70,"finalization failed")
    case SHA.ReleaseFailed{error,allocation,digest}: IO.die(Unit,70,"release failed")
    case SHA.HashDone{digest}: printed(32n,0,(budget,digest))

def input_dropped(state: SHA.ShaState, p: B.Budget & Result<&1, &2, E.Error & B.Allocation, Unit>) -> IO(Unit):
  (budget,result) = p
  match result:
    case Fail{error}: IO.die(Unit,70,"input disposal failed")
    case Done{u}: finalized(SHA.finalize(budget,state))

def chunks(fuel: Nat, +remaining: U32, +chunk: U32, p: B.Budget & Bytes.OwnedBytes & SHA.ShaState & Result<&2, &2, E.Error, Unit>) -> IO(Unit):
  match fuel:
    case 0n:
      (budget,bytes,state,result) = p
      match result:
        case Fail{error}: IO.die(Unit,70,"hash update failed")
        case Done{u}: input_dropped(state,Bytes.drop(budget,bytes))
    case 1n+rest:
      (budget,bytes,state,result) = p
      match result:
        case Fail{error}: IO.die(Unit,70,"hash update failed")
        case Done{u}: chunks(rest,U32.sub(remaining,U32.min(remaining,chunk)),chunk,SHA.update(budget,state,bytes,0,U32.min(remaining,chunk)))

def initialized(bytes: Bytes.OwnedBytes, +total: U32, +chunk: U32, p: B.Budget & Result<&2, &1, E.Error, SHA.ShaState>) -> IO(Unit):
  (budget,result) = p
  match result:
    case Fail{error}: IO.die(Unit,70,"init failed")
    case Done{state}: chunks(U32.to_nat(U32.div(U32.add(total,U32.sub(chunk,1)),chunk)),total,chunk,(budget,bytes,state,Done{Unit{}}))

def fill(fuel: Nat, +index: U32, +byte: U32, total: U32, chunk: U32, p: B.Budget & Bytes.OwnedBytes & Result<&2, &2, E.Error, Unit>) -> IO(Unit):
  match fuel:
    case 0n:
      (budget,bytes,result) = p
      match result:
        case Fail{error}: IO.die(Unit,70,"fill failed")
        case Done{u}: initialized(bytes,total,chunk,SHA.init(budget))
    case 1n+rest:
      (budget,bytes,result) = p
      match result:
        case Fail{error}: IO.die(Unit,70,"fill failed")
        case Done{u}: fill(rest,U32.inc(index),byte,total,chunk,Bytes.put(budget,bytes,index,byte))

def created(byte: U32, total: U32, +chunk: U32, p: B.Budget & Result<&2, &1, E.Error, Bytes.OwnedBytes>) -> IO(Unit):
  (budget,result) = p
  match result:
    case Fail{error}: IO.die(Unit,70,"buffer failed")
    case Done{bytes}: fill(U32.to_nat(chunk),0,byte,total,chunk,(budget,bytes,Done{Unit{}}))

def started(byte: U32, total: U32, +chunk: U32, result: Result<&2, &1, E.Error, B.Budget>) -> IO(Unit):
  match result:
    case Fail{error}: IO.die(Unit,70,"budget failed")
    case Done{budget}: created(byte,total,chunk,Bytes.new(budget,chunk))

def valid(byte: U32, total: U32, chunk: U32, ok: Bool) -> IO(Unit):
  match ok:
    case False{}: IO.die(Unit,2,"test bounds")
    case True{}: started(byte,total,chunk,B.start(1,B.Six{100000000,100000000,100000000,100000000,268435456,1073741824}))

def parsed(r: Maybe<&2, U32>) -> IO(U32):
  match r:
    case None{}: IO.die(U32,2,"invalid test number")
    case Some{value}: IO.pure(U32,value)

def command(args: List<String>) -> IO(Unit):
  match args:
    case _ <> b <> n <> c <> Nil{}:
      do IO<Unit>:
        +byte : U32 <- parsed(U32.read(b))
        +total : U32 <- parsed(U32.read(n))
        +chunk : U32 <- parsed(U32.read(c))
        valid(byte,total,chunk,Bool.and(U32.is_le(byte,255),Bool.and(U32.is_le(total,67108864),Bool.and(U32.is_gt(chunk,0),U32.is_le(chunk,65536)))))
    case _: IO.die(Unit,2,"BYTE TOTAL CHUNK")

def main() -> IO(Unit):
  do IO<Unit>:
    args : List<String> <- IO.args()
    command(args)
