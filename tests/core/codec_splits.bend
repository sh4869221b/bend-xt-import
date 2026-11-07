import Base
import ../../core/error.bend as E
import ../../core/budget.bend as B
import ../../core/bytes.bend as Bytes
import ../../core/scalars.bend as S
import ../../core/codec.bend as Codec
import ../../core/utf8.bend as U8

def fixture(width: U32, index: U32) -> U32:
  match width index:
    case 1 0: 97
    case 2 0: 195
    case 2 1: 169
    case 3 0: 230
    case 3 1: 151
    case 3 2: 165
    case 4 0: 240
    case 4 1: 159
    case 4 2: 152
    case 4 3: 128
    case _ _: 0

def scalar(width: U32) -> U32:
  match width:
    case 1: 97
    case 2: 233
    case 3: 26085
    case _: 128512

def capacity(n: U32) -> U32:
  match n:
    case 0: 1
    case 1: 1
    case 2: 2
    case _: 4

def check(okay: Bool) -> IO(Unit):
  match okay:
    case True{}: IO.print("split-balanced")
    case False{}: IO.die(Unit,70,"split work mismatch")

def finished(expected: U32, r: Result<&1, &2, E.Error & B.Budget, B.Six>) -> IO(Unit):
  match r:
    case Done{B.Six{0,0,0,0,0,work}}: check(U32.is_eq(expected,work))
    case _: IO.die(Unit,70,"split imbalance")

def scalar_dropped(work: U32, p: B.Budget & Result<&1, &2, E.Error & B.Allocation, Unit>) -> IO(Unit):
  (budget,r) = p
  match r:
    case Done{u}: finished(work,B.finish(budget))
    case _: IO.die(Unit,70,"scalar drop")

def suffix_dropped(scalars: S.ScalarChunk, work: U32, p: B.Budget & Result<&1, &2, E.Error & B.Allocation, Unit>) -> IO(Unit):
  (budget,r) = p
  match r:
    case Done{u}: scalar_dropped(work,S.drop(budget,scalars))
    case _: IO.die(Unit,70,"suffix drop")

def checked_scalar(budget: B.Budget, input: Bytes.OwnedBytes, scalars: S.ScalarChunk, work: U32, valid: Bool) -> IO(Unit):
  match valid:
    case False{}: IO.die(Unit,70,"split scalar mismatch")
    case True{}: suffix_dropped(scalars,work,Bytes.drop(budget,input))

def got_scalar(input: Bytes.OwnedBytes, width: U32, work: U32, p: B.Budget & S.ScalarChunk & Result<&2, &2, E.Error, U32>) -> IO(Unit):
  (budget,scalars,r) = p
  match r:
    case Done{value}: checked_scalar(budget,input,scalars,work,U32.is_eq(value,scalar(width)))
    case _: IO.die(Unit,70,"split missing scalar")

def finished_state(input: Bytes.OwnedBytes, budget: B.Budget, scalars: S.ScalarChunk, width: U32, work: U32, result: Result<&2, &2, E.Error, Unit>) -> IO(Unit):
  match result:
    case Fail{error}: IO.die(Unit,70,"split incomplete sequence")
    case Done{u}: got_scalar(input,width,work,S.get(budget,scalars,0))

def suffix_progress(input: Bytes.OwnedBytes, budget: B.Budget, scalars: S.ScalarChunk, width: U32, work: U32, state: U8.State, okay: Bool) -> IO(Unit):
  match okay:
    case False{}: IO.die(Unit,70,"suffix consumed mismatch")
    case True{}: finished_state(input,budget,scalars,width,work,U8.finish(state))

def decoded_suffix(+width: U32, +split: U32, work: U32, p: B.Budget & Bytes.OwnedBytes & S.ScalarChunk & Codec.Progress) -> IO(Unit):
  (budget,input,scalars,progress) = p
  match progress:
    case Codec.Progress{state,next,produced,0}: suffix_progress(input,budget,scalars,width,work,state,U32.is_eq(next,U32.sub(width,split)))
    case _: IO.die(Unit,70,"suffix decode failed")

def fill_suffix(fuel: Nat, +index: U32, +absolute: U32, +width: U32, split: U32, work: U32, scalars: S.ScalarChunk, state: U8.State, p: B.Budget & Bytes.OwnedBytes & Result<&2, &2, E.Error, Unit>) -> IO(Unit):
  match fuel:
    case 0n:
      (budget,input,r) = p
      match r:
        case Done{u}: decoded_suffix(width,split,work,Codec.decode(0,budget,input,scalars,state,0))
        case _: IO.die(Unit,70,"suffix fill")
    case 1n+rest:
      (budget,input,r) = p
      match r:
        case Done{u}: fill_suffix(rest,U32.inc(index),U32.inc(absolute),width,split,work,scalars,state,Bytes.put(budget,input,index,fixture(width,absolute)))
        case _: IO.die(Unit,70,"suffix fill")

def suffix_created(+width: U32, +split: U32, work: U32, scalars: S.ScalarChunk, state: U8.State, p: B.Budget & Result<&2, &1, E.Error, Bytes.OwnedBytes>) -> IO(Unit):
  (budget,r) = p
  match r:
    case Done{input}: fill_suffix(U32.to_nat(U32.sub(width,split)),0,split,width,split,work,scalars,state,(budget,input,Done{Unit{}}))
    case _: IO.die(Unit,70,"suffix new")

def prefix_dropped(+width: U32, +split: U32, work: U32, scalars: S.ScalarChunk, state: U8.State, p: B.Budget & Result<&1, &2, E.Error & B.Allocation, Unit>) -> IO(Unit):
  (budget,r) = p
  match r:
    case Done{u}: suffix_created(width,split,work,scalars,state,Bytes.new(budget,U32.sub(width,split)))
    case _: IO.die(Unit,70,"prefix drop")

def prefix_progress(budget: B.Budget, input: Bytes.OwnedBytes, scalars: S.ScalarChunk, width: U32, split: U32, work: U32, state: U8.State, okay: Bool) -> IO(Unit):
  match okay:
    case False{}: IO.die(Unit,70,"prefix consumed mismatch")
    case True{}: prefix_dropped(width,split,work,scalars,state,Bytes.drop(budget,input))

def decoded_prefix(width: U32, +split: U32, work: U32, p: B.Budget & Bytes.OwnedBytes & S.ScalarChunk & Codec.Progress) -> IO(Unit):
  (budget,input,scalars,progress) = p
  match progress:
    case Codec.Progress{state,next,produced,0}: prefix_progress(budget,input,scalars,width,split,work,state,U32.is_eq(next,split))
    case _: IO.die(Unit,70,"prefix decode failed")

def scalar_created(input: Bytes.OwnedBytes, width: U32, split: U32, work: U32, p: B.Budget & Result<&2, &1, E.Error, S.ScalarChunk>) -> IO(Unit):
  (budget,r) = p
  match r:
    case Done{scalars}: decoded_prefix(width,split,work,Codec.decode(0,budget,input,S.clear(scalars),U8.init(),0))
    case _: IO.die(Unit,70,"scalar new")

def fill_prefix(fuel: Nat, +index: U32, +width: U32, split: U32, work: U32, p: B.Budget & Bytes.OwnedBytes & Result<&2, &2, E.Error, Unit>) -> IO(Unit):
  match fuel:
    case 0n:
      (budget,input,r) = p
      match r:
        case Done{u}: scalar_created(input,width,split,work,S.new(budget,1))
        case _: IO.die(Unit,70,"prefix fill")
    case 1n+rest:
      (budget,input,r) = p
      match r:
        case Done{u}: fill_prefix(rest,U32.inc(index),width,split,work,Bytes.put(budget,input,index,fixture(width,index)))
        case _: IO.die(Unit,70,"prefix fill")

def prefix_created(width: U32, +split: U32, work: U32, p: B.Budget & Result<&2, &1, E.Error, Bytes.OwnedBytes>) -> IO(Unit):
  (budget,r) = p
  match r:
    case Done{input}: fill_prefix(U32.to_nat(split),0,width,split,work,(budget,input,Done{Unit{}}))
    case _: IO.die(Unit,70,"prefix new")

def started(width: U32, +split: U32, work: U32, r: Result<&2, &1, E.Error, B.Budget>) -> IO(Unit):
  match r:
    case Done{budget}: prefix_created(width,split,work,Bytes.new(budget,split))
    case _: IO.die(Unit,70,"start")

def run_limit(width: U32, split: U32, +work: U32) -> IO(Unit):
  started(width,split,work,B.start(1,B.Six{0,0,0,0,1048576,work}))

def run(+width: U32, +split: U32) -> IO(Unit):
  run_limit(width,split,U32.add(U32.add(capacity(split),capacity(U32.sub(width,split))),U32.inc(U32.mul(width,4))))

def full_second_read(input: Bytes.OwnedBytes, p: B.Budget & S.ScalarChunk & Result<&2, &2, E.Error, U32>) -> IO(Unit):
  (budget,scalars,r) = p
  match r:
    case Done{98}: suffix_dropped(scalars,11,Bytes.drop(budget,input))
    case _: IO.die(Unit,70,"output-full second scalar")

def full_second(p: B.Budget & Bytes.OwnedBytes & S.ScalarChunk & Codec.Progress) -> IO(Unit):
  (budget,input,scalars,progress) = p
  match progress:
    case Codec.Progress{U8.State{0,0,0,0,2},2,1,0}: full_second_read(input,S.get(budget,scalars,0))
    case _: IO.die(Unit,70,"output-full resume progress")

def full_first_read(input: Bytes.OwnedBytes, state: U8.State, p: B.Budget & S.ScalarChunk & Result<&2, &2, E.Error, U32>) -> IO(Unit):
  (budget,scalars,r) = p
  match r:
    case Done{97}: full_second(Codec.decode(0,budget,input,S.clear(scalars),state,1))
    case _: IO.die(Unit,70,"output-full first scalar")

def full_first(p: B.Budget & Bytes.OwnedBytes & S.ScalarChunk & Codec.Progress) -> IO(Unit):
  (budget,input,scalars,progress) = p
  match progress:
    case Codec.Progress{U8.State{0,0,0,0,1},1,1,1}: full_first_read(input,U8.State{0,0,0,0,1},S.get(budget,scalars,0))
    case _: IO.die(Unit,70,"expected decoder output-full")

def full_scalars(input: Bytes.OwnedBytes, p: B.Budget & Result<&2, &1, E.Error, S.ScalarChunk>) -> IO(Unit):
  (budget,r) = p
  match r:
    case Done{scalars}: full_first(Codec.decode(0,budget,input,S.clear(scalars),U8.init(),0))
    case _: IO.die(Unit,70,"output-full scalar allocation")

def full_byte_two(p: B.Budget & Bytes.OwnedBytes & Result<&2, &2, E.Error, Unit>) -> IO(Unit):
  (budget,input,r) = p
  match r:
    case Done{u}: full_scalars(input,S.new(budget,1))
    case _: IO.die(Unit,70,"output-full byte2")

def full_byte_one(p: B.Budget & Bytes.OwnedBytes & Result<&2, &2, E.Error, Unit>) -> IO(Unit):
  (budget,input,r) = p
  match r:
    case Done{u}: full_byte_two(Bytes.put(budget,input,1,98))
    case _: IO.die(Unit,70,"output-full byte1")

def full_created(p: B.Budget & Result<&2, &1, E.Error, Bytes.OwnedBytes>) -> IO(Unit):
  (budget,r) = p
  match r:
    case Done{input}: full_byte_one(Bytes.put(budget,input,0,97))
    case _: IO.die(Unit,70,"output-full byte allocation")

def full_start(r: Result<&2, &1, E.Error, B.Budget>) -> IO(Unit):
  match r:
    case Done{budget}: full_created(Bytes.new(budget,2))
    case _: IO.die(Unit,70,"output-full budget")
def main() -> IO(Unit):
  do IO<Unit>:
    run(1,0)
    run(1,1)
    run(2,0)
    run(2,1)
    run(2,2)
    run(3,0)
    run(3,1)
    run(3,2)
    run(3,3)
    run(4,0)
    run(4,1)
    run(4,2)
    run(4,3)
    run(4,4)
    full_start(B.start(1,B.Six{0,0,0,0,1048576,11}))

# Two scalars through one output slot; consumed prefixes are never reread.
