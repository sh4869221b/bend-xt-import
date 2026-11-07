import Base
import ../../core/error.bend as E
import ../../core/budget.bend as B
import ../../core/bytes.bend as Bytes
import ../../core/scalars.bend as S
import ../../core/codec.bend as Codec

# Width-specific expected sums are independent encoded-byte fixtures.
def expected_sum(width: U32) -> U32:
  match width:
    case 1: 97
    case 2: 364
    case 3: 546
    case _: 679

def finish_check(expected: U32, work: U32, okay: Bool) -> IO(Unit):
  match okay:
    case True{}: IO.print("pending-balanced")
    case False{}: IO.die(Unit,70,"pending work mismatch")

def finished(+expected: U32, r: Result<&1, &2, E.Error & B.Budget, B.Six>) -> IO(Unit):
  match r:
    case Done{B.Six{0,0,0,0,0,+work}}: finish_check(expected,work,U32.is_eq(expected,work))
    case _: IO.die(Unit,70,"pending owner imbalance")

def output_dropped(work: U32, p: B.Budget & Result<&1, &2, E.Error & B.Allocation, Unit>) -> IO(Unit):
  (budget,r) = p
  match r:
    case Done{u}: finished(work,B.finish(budget))
    case _: IO.die(Unit,70,"output drop failed")

def scalars_dropped(output: Bytes.OwnedBytes, work: U32, p: B.Budget & Result<&1, &2, E.Error & B.Allocation, Unit>) -> IO(Unit):
  (budget,r) = p
  match r:
    case Done{u}: output_dropped(work,Bytes.drop(budget,output))
    case _: IO.die(Unit,70,"scalar drop failed")

def checksum_done(scalars: S.ScalarChunk, budget: B.Budget, output: Bytes.OwnedBytes, work: U32, valid: Bool) -> IO(Unit):
  match valid:
    case True{}: scalars_dropped(output,work,S.drop(budget,scalars))
    case False{}: IO.die(Unit,70,"pending output mismatch")

def accumulated(sum: U32, p: B.Budget & Bytes.OwnedBytes & Result<&2, &2, E.Error, U32>) -> B.Budget & Bytes.OwnedBytes & U32 & Result<&2, &2, E.Error, Unit>:
  (budget,output,result) = p
  match result:
    case Done{byte}: (budget,output,U32.add(sum,byte),Done{Unit{}})
    case Fail{error}: (budget,output,sum,Fail{error})

def scan(fuel: Nat, +index: U32, scalars: S.ScalarChunk, width: U32, work: U32, p: B.Budget & Bytes.OwnedBytes & U32 & Result<&2, &2, E.Error, Unit>) -> IO(Unit):
  match fuel:
    case 0n:
      (budget,output,sum,result) = p
      match result:
        case Done{u}: checksum_done(scalars,budget,output,work,U32.is_eq(sum,expected_sum(width)))
        case _: IO.die(Unit,70,"pending read failed")
    case 1n+rest:
      (budget,output,sum,result) = p
      match result:
        case Done{u}: scan(rest,U32.inc(index),scalars,width,work,accumulated(sum,Bytes.get(budget,output,index)))
        case _: IO.die(Unit,70,"pending read failed")

def resumed_valid(budget: B.Budget, scalars: S.ScalarChunk, output: Bytes.OwnedBytes, +width: U32, work: U32, valid: Bool) -> IO(Unit):
  match valid:
    case False{}: IO.die(Unit,70,"pending consumed/produced mismatch")
    case True{}: scan(U32.to_nat(width),0,scalars,width,work,(budget,output,0,Done{Unit{}}))

def resumed(+width: U32, work: U32, p: B.Budget & S.ScalarChunk & Bytes.OwnedBytes & Codec.EncodeProgress) -> IO(Unit):
  (budget,scalars,output,progress) = p
  match progress:
    case Codec.EncodeProgress{Codec.EncodeReady{},1,produced,0}: resumed_valid(budget,scalars,output,width,work,U32.is_eq(width,produced))
    case _: IO.die(Unit,70,"pending resume failed")

def replacement(scalars: S.ScalarChunk, state: Codec.EncodeState, width: U32, work: U32, p: B.Budget & Result<&2, &1, E.Error, Bytes.OwnedBytes>) -> IO(Unit):
  (budget,r) = p
  match r:
    case Done{output}: resumed(width,work,Codec.encode(0,budget,scalars,Bytes.clear(output),state,0))
    case _: IO.die(Unit,70,"replacement output new")

def full_dropped(scalars: S.ScalarChunk, state: Codec.EncodeState, +width: U32, work: U32, p: B.Budget & Result<&1, &2, E.Error & B.Allocation, Unit>) -> IO(Unit):
  (budget,r) = p
  match r:
    case Done{u}: replacement(scalars,state,width,work,Bytes.new(budget,width))
    case _: IO.die(Unit,70,"full output drop")

def pending(width: U32, work: U32, p: B.Budget & S.ScalarChunk & Bytes.OwnedBytes & Codec.EncodeProgress) -> IO(Unit):
  (budget,scalars,output,progress) = p
  match progress:
    case Codec.EncodeProgress{Codec.Pending{value,packet},0,0,1}: full_dropped(scalars,Codec.Pending{value,packet},width,work,Bytes.drop(budget,output))
    case _: IO.die(Unit,70,"expected pending output-full")

def full_created(scalars: S.ScalarChunk, width: U32, work: U32, p: B.Budget & Result<&2, &1, E.Error, Bytes.OwnedBytes>) -> IO(Unit):
  (budget,r) = p
  match r:
    case Done{output}: pending(width,work,Codec.encode(0,budget,scalars,output,Codec.encoder_init(),0))
    case _: IO.die(Unit,70,"output new")

def scalar_written(width: U32, work: U32, p: B.Budget & S.ScalarChunk & Result<&2, &2, E.Error, Unit>) -> IO(Unit):
  (budget,scalars,r) = p
  match r:
    case Done{u}: full_created(scalars,width,work,Bytes.new(budget,1))
    case _: IO.die(Unit,70,"scalar write")

def scalar_created(value: U32, width: U32, work: U32, p: B.Budget & Result<&2, &1, E.Error, S.ScalarChunk>) -> IO(Unit):
  (budget,r) = p
  match r:
    case Done{scalars}: scalar_written(width,work,S.put(budget,scalars,0,value))
    case _: IO.die(Unit,70,"scalar new")

def started(value: U32, width: U32, work: U32, r: Result<&2, &1, E.Error, B.Budget>) -> IO(Unit):
  match r:
    case Done{budget}: scalar_created(value,width,work,S.new(budget,1))
    case _: IO.die(Unit,70,"start")

def run(value: U32, width: U32, +work: U32) -> IO(Unit):
  started(value,width,work,B.start(1,B.Six{0,0,0,0,1048576,work}))

def main() -> IO(Unit):
  do IO<Unit>:
    run(97,1,7)
    run(233,2,12)
    run(26085,3,18)
    run(128512,4,22)
