import Base
import ../../core/error.bend as E
import ../../core/budget.bend as B
import ../../core/bytes.bend as Bytes
import ../../core/scalars.bend as Scalars
import ../../core/codec.bend as Codec
import ../../core/utf8.bend as U8

type Session is Type:
  Session{budget: B.Budget, input: Bytes.OwnedBytes, scalars: Scalars.ScalarChunk, output: Bytes.OwnedBytes}

def sum_read(sum: U32, p: B.Budget & Bytes.OwnedBytes & Result<&2, &2, E.Error, U32>) -> B.Budget & Bytes.OwnedBytes & U32 & Result<&2, &2, E.Error, Unit>:
  (budget,output,result) = p
  match result:
    case Fail{error}: (budget,output,sum,Fail{error})
    case Done{value}: (budget,output,U32.add(sum,value),Done{Unit{}})

def sum_loop(fuel: Nat, +index: U32, p: B.Budget & Bytes.OwnedBytes & U32 & Result<&2, &2, E.Error, Unit>) -> B.Budget & Bytes.OwnedBytes & U32 & Result<&2, &2, E.Error, Unit>:
  match fuel:
    case 0n: p
    case 1n+rest:
      (budget,output,sum,result) = p
      match result:
        case Fail{error}: (budget,output,sum,Fail{error})
        case Done{u}: sum_loop(rest,U32.inc(index),sum_read(sum,Bytes.get(budget,output,index)))

def sum_valid(session: Session, valid: Bool) -> IO(Session):
  match valid:
    case False{}: IO.die(Session,70,"roundtrip bytes mismatch")
    case True{}: IO.pure(Session,session)

def summed(input: Bytes.OwnedBytes, scalars: Scalars.ScalarChunk, expected: U32, p: B.Budget & Bytes.OwnedBytes & U32 & Result<&2, &2, E.Error, Unit>) -> IO(Session):
  (budget,output,sum,result) = p
  match result:
    case Fail{error}: IO.die(Session,70,"roundtrip checksum read")
    case Done{u}: sum_valid(Session{budget,input,scalars,output},U32.is_eq(sum,expected))

def encoded_valid(input: Bytes.OwnedBytes, budget: B.Budget, scalars: Scalars.ScalarChunk, output: Bytes.OwnedBytes, +length: U32, valid: Bool) -> IO(Session):
  match valid:
    case False{}: IO.die(Session,70,"roundtrip encode progress")
    case True{}: summed(input,scalars,U32.mul(length,97),sum_loop(U32.to_nat(length),0,(budget,output,0,Done{Unit{}})))

def encoded(input: Bytes.OwnedBytes, +length: U32, p: B.Budget & Scalars.ScalarChunk & Bytes.OwnedBytes & Codec.EncodeProgress) -> IO(Session):
  (budget,scalars,output,progress) = p
  match progress:
    case Codec.EncodeProgress{Codec.EncodeReady{},next,produced,0}: encoded_valid(input,budget,scalars,output,length,Bool.and(U32.is_eq(next,length),U32.is_eq(produced,length)))
    case _: IO.die(Session,70,"roundtrip encode failed")

def decoded_valid(output: Bytes.OwnedBytes, budget: B.Budget, input: Bytes.OwnedBytes, scalars: Scalars.ScalarChunk, length: U32, valid: Bool) -> IO(Session):
  match valid:
    case False{}: IO.die(Session,70,"roundtrip decode progress")
    case True{}: encoded(input,length,Codec.encode(0,budget,scalars,Bytes.clear(output),Codec.EncodeReady{},0))

def decoded(output: Bytes.OwnedBytes, +length: U32, p: B.Budget & Bytes.OwnedBytes & Scalars.ScalarChunk & Codec.Progress) -> IO(Session):
  (budget,input,scalars,progress) = p
  match progress:
    case Codec.Progress{U8.State{0,a,b,c,next_offset},next,produced,0}: decoded_valid(output,budget,input,scalars,length,Bool.and(U32.is_eq(next,length),Bool.and(U32.is_eq(produced,length),U32.is_eq(next_offset,length))))
    case _: IO.die(Session,70,"roundtrip decode failed")

def round(session: Session, length: U32) -> IO(Session):
  match session:
    case Session{budget,input,scalars,output}: decoded(output,length,Codec.decode(0,budget,input,Scalars.clear(scalars),U8.init(),0))

def cycles(fuel: Nat, +length: U32, session: Session) -> IO(Session):
  match fuel:
    case 0n: IO.pure(Session,session)
    case 1n+rest:
      do IO<Session>:
        next : Session <- round(session,length)
        cycles(rest,length,next)

def final_usage(result: Result<&1, &2, E.Error & B.Budget, B.Six>) -> IO(Unit):
  match result:
    case Fail{error}: IO.die(Unit,70,"roundtrip imbalance")
    case Done{B.Six{a,b,c,d,live,work}}:
      do IO<Unit>:
        IO.print("work=" ++ U32.show(work))
        IO.print("balanced")

def output_dropped(p: B.Budget & Result<&1, &2, E.Error & B.Allocation, Unit>) -> IO(Unit):
  (budget,result) = p
  match result:
    case Fail{error}: IO.die(Unit,70,"output drop")
    case Done{u}: final_usage(B.finish(budget))

def scalars_dropped(output: Bytes.OwnedBytes, p: B.Budget & Result<&1, &2, E.Error & B.Allocation, Unit>) -> IO(Unit):
  (budget,result) = p
  match result:
    case Fail{error}: IO.die(Unit,70,"scalar drop")
    case Done{u}: output_dropped(Bytes.drop(budget,output))

def input_dropped(scalars: Scalars.ScalarChunk, output: Bytes.OwnedBytes, p: B.Budget & Result<&1, &2, E.Error & B.Allocation, Unit>) -> IO(Unit):
  (budget,result) = p
  match result:
    case Fail{error}: IO.die(Unit,70,"input drop")
    case Done{u}: scalars_dropped(output,Scalars.drop(budget,scalars))

def hold_done(session: Session) -> IO(Unit):
  match session:
    case Session{budget,input,scalars,output}:
      do IO<Unit>:
        IO.print("live=codec-source-scalars-output")
        IO.sleep(100)
        input_dropped(scalars,output,Bytes.drop(budget,input))

def output_created(input: Bytes.OwnedBytes, scalars: Scalars.ScalarChunk, +length: U32, repeats: U32, p: B.Budget & Result<&2, &1, E.Error, Bytes.OwnedBytes>) -> IO(Unit):
  (budget,result) = p
  match result:
    case Fail{error}: IO.die(Unit,70,"output new")
    case Done{output}:
      do IO<Unit>:
        session : Session <- cycles(U32.to_nat(repeats),length,Session{budget,input,scalars,output})
        hold_done(session)

def scalar_created(input: Bytes.OwnedBytes, +length: U32, repeats: U32, p: B.Budget & Result<&2, &1, E.Error, Scalars.ScalarChunk>) -> IO(Unit):
  (budget,result) = p
  match result:
    case Fail{error}: IO.die(Unit,70,"scalar new")
    case Done{scalars}: output_created(input,scalars,length,repeats,Bytes.new(budget,length))

def fill(fuel: Nat, +index: U32, +length: U32, repeats: U32, p: B.Budget & Bytes.OwnedBytes & Result<&2, &2, E.Error, Unit>) -> IO(Unit):
  match fuel:
    case 0n:
      (budget,input,result) = p
      match result:
        case Fail{error}: IO.die(Unit,70,"input fill")
        case Done{u}: scalar_created(input,length,repeats,Scalars.new(budget,length))
    case 1n+rest:
      (budget,input,result) = p
      match result:
        case Fail{error}: IO.die(Unit,70,"input fill")
        case Done{u}: fill(rest,U32.inc(index),length,repeats,Bytes.put(budget,input,index,97))

def input_created(+length: U32, repeats: U32, p: B.Budget & Result<&2, &1, E.Error, Bytes.OwnedBytes>) -> IO(Unit):
  (budget,result) = p
  match result:
    case Fail{error}: IO.die(Unit,70,"input new")
    case Done{input}: fill(U32.to_nat(length),0,length,repeats,(budget,input,Done{Unit{}}))

def started(+length: U32, repeats: U32, r: Result<&2, &1, E.Error, B.Budget>) -> IO(Unit):
  match r:
    case Fail{error}: IO.die(Unit,70,"start")
    case Done{budget}: input_created(length,repeats,Bytes.new(budget,length))

def valid(length: U32, repeats: U32, okay: Bool) -> IO(Unit):
  match okay:
    case False{}: IO.die(Unit,2,"test limits")
    case True{}: started(length,repeats,B.start(1,B.Six{0,0,0,0,268435456,1073741824}))

def parsed(r: Maybe<&2, U32>) -> IO(U32):
  match r:
    case None{}: IO.die(U32,2,"bad number")
    case Some{n}: IO.pure(U32,n)

def command(args: List<String>) -> IO(Unit):
  match args:
    case _ <> n <> r <> Nil{}:
      do IO<Unit>:
        +length : U32 <- parsed(U32.read(n))
        +repeats : U32 <- parsed(U32.read(r))
        valid(length,repeats,Bool.and(U32.is_le(length,65536),U32.is_le(repeats,1024)))
    case _: IO.die(Unit,2,"LENGTH CYCLES")

def main() -> IO(Unit):
  do IO<Unit>:
    args : List<String> <- IO.args()
    command(args)
