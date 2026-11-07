import Base
import ../../core/error.bend as E
import ../../core/budget.bend as B
import ../../core/bytes.bend as Bytes

def filled(fuel: Nat, +index: U32, p: B.Budget & Bytes.OwnedBytes & Result<&2, &2, E.Error, Unit>) -> B.Budget & Bytes.OwnedBytes & Result<&2, &2, E.Error, Unit>:
  match fuel:
    case 0n: p
    case 1n+rest:
      (budget,bytes,result) = p
      match result:
        case Fail{error}: (budget,bytes,Fail{error})
        case Done{u}: filled(rest,U32.inc(index),Bytes.put(budget,bytes,index,U32.and(index,255)))

def retained(held: List<&1, Bytes.OwnedBytes>, p: B.Budget & Bytes.OwnedBytes & Result<&2, &2, E.Error, Unit>) -> B.Budget & List<&1, Bytes.OwnedBytes> & Maybe<&2, E.Error>:
  (budget,bytes,result) = p
  match result:
    case Fail{error}: (budget,bytes <> held,Some{error})
    case Done{u}: (budget,bytes <> held,None{})

def allocated(length: U32, held: List<&1, Bytes.OwnedBytes>, p: B.Budget & Result<&2, &1, E.Error, Bytes.OwnedBytes>) -> B.Budget & List<&1, Bytes.OwnedBytes> & Maybe<&2, E.Error>:
  (budget,result) = p
  match result:
    case Fail{error}: (budget,held,Some{error})
    case Done{bytes}: retained(held,filled(U32.to_nat(length),0,(budget,bytes,Done{Unit{}})))

def allocate_many(fuel: Nat, +length: U32, p: B.Budget & List<&1, Bytes.OwnedBytes> & Maybe<&2, E.Error>) -> B.Budget & List<&1, Bytes.OwnedBytes> & Maybe<&2, E.Error>:
  match fuel:
    case 0n: p
    case 1n+rest:
      (budget,held,error) = p
      match error:
        case Some{error}: (budget,held,Some{error})
        case None{}: allocate_many(rest,length,allocated(length,held,Bytes.new(budget,length)))

def scanned(p: B.Budget & Bytes.OwnedBytes & Result<&2, &2, E.Error, U32>, sum: U32) -> B.Budget & Bytes.OwnedBytes & U32 & Result<&2, &2, E.Error, Unit>:
  (budget,bytes,result) = p
  match result:
    case Fail{error}: (budget,bytes,sum,Fail{error})
    case Done{value}: (budget,bytes,U32.add(sum,value),Done{Unit{}})

def scan(fuel: Nat, +index: U32, p: B.Budget & Bytes.OwnedBytes & U32 & Result<&2, &2, E.Error, Unit>) -> B.Budget & Bytes.OwnedBytes & U32 & Result<&2, &2, E.Error, Unit>:
  match fuel:
    case 0n: p
    case 1n+rest:
      (budget,bytes,sum,result) = p
      match result:
        case Fail{error}: (budget,bytes,sum,Fail{error})
        case Done{u}: scan(rest,U32.inc(index),scanned(Bytes.get(budget,bytes,index),sum))

def dropped(sum: U32, p: B.Budget & Result<&1, &2, E.Error & B.Allocation, Unit>) -> IO(B.Budget & U32):
  (budget,result) = p
  match result:
    case Fail{error}: IO.die(B.Budget & U32,70,"drop failed")
    case Done{u}: IO.pure(B.Budget & U32,(budget,sum))

def scan_done(p: B.Budget & Bytes.OwnedBytes & U32 & Result<&2, &2, E.Error, Unit>) -> IO(B.Budget & U32):
  (budget,bytes,sum,result) = p
  match result:
    case Fail{error}: IO.die(B.Budget & U32,70,"scan failed")
    case Done{u}: dropped(sum,Bytes.drop(budget,bytes))

def drain(held: List<&1, Bytes.OwnedBytes>, +length: U32, p: B.Budget & U32) -> IO(B.Budget & U32):
  match held:
    case Nil{}: IO.pure(B.Budget & U32,p)
    case bytes <> tail:
      (budget,sum) = p
      do IO<B.Budget & U32>:
        next : B.Budget & U32 <- scan_done(scan(U32.to_nat(length),0,(budget,bytes,sum,Done{Unit{}})))
        drain(tail,length,next)

def printed_error(error: Maybe<&2, E.Error>) -> IO(Unit):
  match error:
    case None{}: IO.print("allocation-complete")
    case Some{E.ResourceLimit{dimension,limit,used,requested}}:
      do IO<Unit>:
        IO.print("allocation-rejected")
        IO.print(U32.show(dimension))
        IO.print(U32.show(used))
        IO.print(U32.show(requested))
    case Some{error}: IO.die(Unit,70,"unexpected allocation error")

def held_usage(held: List<&1, Bytes.OwnedBytes>, length: U32, error: Maybe<&2, E.Error>, p: B.Budget & B.Six & B.Six) -> IO(B.Budget & U32):
  (budget,used,held_charge) = p
  do IO<B.Budget & U32>:
    printed_error(error)
    IO.print("live=" ++ U32.show(B.get_live(used)))
    IO.sleep(100)
    drain(held,length,(budget,0))

def hold(length: U32, p: B.Budget & List<&1, Bytes.OwnedBytes> & Maybe<&2, E.Error>) -> IO(B.Budget & U32):
  (budget,held,error) = p
  held_usage(held,length,error,B.inspect(budget))

def cycles(fuel: Nat, +count: U32, +length: U32, p: B.Budget & U32) -> IO(B.Budget & U32):
  match fuel:
    case 0n: IO.pure(B.Budget & U32,p)
    case 1n+rest:
      (budget,prior) = p
      do IO<B.Budget & U32>:
        IO.print("previous-sum=" ++ U32.show(prior))
        next : B.Budget & U32 <- hold(length,allocate_many(U32.to_nat(count),length,(budget,Nil{},None{})))
        cycles(rest,count,length,next)

def finished(sum: U32, result: Result<&1, &2, E.Error & B.Budget, B.Six>) -> IO(Unit):
  match result:
    case Fail{error}: IO.die(Unit,70,"unbalanced")
    case Done{B.Six{input,expanded,output,logical,live,work}}:
      do IO<Unit>:
        IO.print("sum=" ++ U32.show(sum))
        IO.print("work=" ++ U32.show(work))
        IO.print("balanced")

def complete(p: B.Budget & U32) -> IO(Unit):
  (budget,sum) = p
  finished(sum,B.finish(budget))

def started(count: U32, length: U32, repeats: U32, result: Result<&2, &1, E.Error, B.Budget>) -> IO(Unit):
  match result:
    case Fail{error}: IO.die(Unit,70,"start failed")
    case Done{budget}:
      do IO<Unit>:
        p : B.Budget & U32 <- cycles(U32.to_nat(repeats),count,length,(budget,0))
        complete(p)

def valid(count: U32, length: U32, repeats: U32, okay: Bool) -> IO(Unit):
  match okay:
    case False{}: IO.die(Unit,2,"test bounds")
    case True{}: started(count,length,repeats,B.start(1,B.Six{0,0,0,0,268435456,1073741824}))

def parsed(r: Maybe<&2, U32>) -> IO(U32):
  match r:
    case None{}: IO.die(U32,2,"bad test number")
    case Some{n}: IO.pure(U32,n)

def command(args: List<String>) -> IO(Unit):
  match args:
    case _ <> c <> n <> r <> Nil{}:
      do IO<Unit>:
        +count : U32 <- parsed(U32.read(c))
        +length : U32 <- parsed(U32.read(n))
        +repeats : U32 <- parsed(U32.read(r))
        valid(count,length,repeats,Bool.and(U32.is_le(count,4096),Bool.and(U32.is_le(length,65536),U32.is_le(repeats,3))))
    case _: IO.die(Unit,2,"COUNT LENGTH CYCLES")

def main() -> IO(Unit):
  do IO<Unit>:
    args : List<String> <- IO.args()
    command(args)
