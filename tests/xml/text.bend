import Base
import ../../core/budget.bend as B
import ../../core/error.bend as E
import ../../xml/text.bend as T

# Three complete 4096-scalar linked pages plus a one-scalar current page.
# Adjacent pages begin at different pattern phases (4096 % 53 = 15), so
# reversal, repetition, loss, or replacement of pages cannot pass by reading
# an identical value everywhere.
def pattern(index: U32) -> U32:
  U32.add(65,U32.mod(index,53))

# Four payload allocations charge 4*4096 work and appends charge 12289.
# Each ASCII read adds one work; seal, exhaustion and disposal add none.
def expected_work(reads: U32) -> U32:
  U32.add(28673,reads)

def finished(okay: Bool, expected: U32, r: Result<&1,&2,E.Error & B.Budget,B.Six>) -> Bool:
  match r:
    case Done{B.Six{0,0,0,0,0,work}}: Bool.and(okay,U32.is_eq(work,expected))
    case _: False{}

def dropped(okay: Bool, expected: U32, p: B.Budget & Maybe<&1,T.Arena> & Maybe<&2,E.Error>) -> Bool:
  (budget,arena,error) = p
  match arena error:
    case None{} None{}: finished(okay,expected,B.finish(budget))
    case _ _: False{}

def cleanup(budget: B.Budget, arena: T.Arena, okay: Bool, reads: U32) -> Bool:
  dropped(okay,expected_work(reads),T.drop(budget,arena))

# Live = budget 65536 + four (131072+4096) scalar owners + three
# (4096+4096) link owners = 630784. Iteration must not add/drop allocations.
def accounting(used: B.Six, held: B.Six, expected: U32) -> Bool:
  match used held:
    case B.Six{0,0,0,0,630784,work} B.Six{0,0,0,0,0,0}: U32.is_eq(work,expected)
    case _ _: False{}

def inspected(arena: T.Arena, okay: Bool, +reads: U32, p: B.Budget & B.Six & B.Six) -> Bool:
  (budget,used,held) = p
  cleanup(budget,arena,Bool.and(okay,accounting(used,held,expected_work(reads))),reads)

def exhausted(reads: U32, p: B.Budget & T.Arena & Result<&2,&2,E.Error,Maybe<&2,U32>>) -> Bool:
  (budget,arena,result) = p
  match result:
    case Done{None{}}: inspected(arena,True{},reads,B.inspect(budget))
    case _: cleanup(budget,arena,False{},reads)

def stop_read(budget: B.Budget, arena: T.Arena, +reads: U32, full: Bool) -> Bool:
  match full:
    case True{}: exhausted(reads,T.next(budget,arena))
    case False{}: inspected(arena,True{},reads,B.inspect(budget))

def read_value(+index: U32, p: B.Budget & T.Arena & Result<&2,&2,E.Error,Maybe<&2,U32>>) -> B.Budget & T.Arena & Bool:
  (budget,arena,result) = p
  match result:
    case Done{Some{value}}: (budget,arena,U32.is_eq(value,pattern(index)))
    case _: (budget,arena,False{})

def read_loop(fuel: Nat, +index: U32, +reads: U32, p: B.Budget & T.Arena & Bool) -> Bool:
  match fuel:
    case 0n:
      (budget,arena,okay) = p
      match okay:
        case False{}: cleanup(budget,arena,False{},reads)
        case True{}: stop_read(budget,arena,reads,U32.is_eq(reads,12289))
    case 1n+rest:
      (budget,arena,okay) = p
      match okay:
        case False{}: cleanup(budget,arena,False{},reads)
        case True{}: read_loop(rest,U32.inc(index),reads,read_value(index,T.next(budget,arena)))

def before_read(arena: T.Arena, +reads: U32, p: B.Budget & B.Six & B.Six) -> Bool:
  (budget,used,held) = p
  read_loop(U32.to_nat(reads),0,reads,(budget,arena,accounting(used,held,28673)))

def sealed(reads: U32, p: B.Budget & T.Arena & Result<&2,&2,E.Error,Unit>) -> Bool:
  (budget,arena,result) = p
  match result:
    case Done{u}: before_read(arena,reads,B.inspect(budget))
    case _: cleanup(budget,arena,False{},reads)

def measured(budget: B.Budget, reads: U32, p: T.Arena & U32 & U32) -> Bool:
  (arena,length,bytes) = p
  match length bytes:
    case 12289 12289: sealed(reads,T.seal(budget,arena))
    case _ _: cleanup(budget,arena,False{},reads)

def fill(fuel: Nat, +index: U32, +reads: U32, p: B.Budget & T.Arena & Result<&2,&2,E.Error,Unit>) -> Bool:
  match fuel:
    case 0n:
      (budget,arena,result) = p
      match result:
        case Fail{error}: cleanup(budget,arena,False{},reads)
        case Done{u}: measured(budget,reads,T.metadata(arena))
    case 1n+rest:
      (budget,arena,result) = p
      match result:
        case Fail{error}: cleanup(budget,arena,False{},reads)
        case Done{u}: fill(rest,U32.inc(index),reads,T.append(budget,arena,pattern(index)))

def started(reads: U32, result: Result<&2,&1,E.Error,B.Budget>) -> Bool:
  match result:
    case Done{budget}: fill(12289n,0,reads,(budget,T.empty(),Done{Unit{}}))
    case _: False{}

def run(reads: U32) -> Bool:
  started(reads,B.start(1,B.Six{1000000,1000000,1000000,1000000,10485760,1000000}))

def reads_for_case(index: U32) -> U32:
  match index:
    case 0: 12289
    case 1: 0
    case 2: 1
    case 3: 4096
    case _: 4097

def cases(fuel: Nat, +index: U32, okay: Bool) -> Bool:
  match fuel:
    case 0n: okay
    case 1n+rest: cases(rest,U32.inc(index),Bool.and(okay,run(reads_for_case(index))))

def report(okay: Bool) -> IO(Unit):
  match okay:
    case True{}: IO.print("text-balanced")
    case False{}: IO.die(Unit,70,"text ordering, accounting or cleanup failed")

def main() -> IO(Unit):
  report(cases(5n,0,True{}))
