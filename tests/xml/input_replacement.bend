import Base
import ../../core/budget.bend as B
import ../../core/error.bend as E
import ../../core/bytes.bend as Bytes
import ../../core/cursor.bend as C
import ../../xml/input.bend as I
import ../../xml/types.bend as X

# Negative handoffs: unfinished replacement, replay, gap, overlap, source, run.
def old_length(caseId: U32) -> U32:
  match caseId:
    case 0: 2
    case _: 1

def new_length(caseId: U32) -> U32:
  match caseId:
    case 0: 2
    case 3: 2
    case _: 1

def new_range(caseId: U32) -> C.Range:
  match caseId:
    case 0: C.Range{1,42,0,2}
    case 1: C.Range{1,42,0,1}
    case 2: C.Range{1,42,2,3}
    case 3: C.Range{1,42,0,2}
    case 4: C.Range{1,43,1,2}
    case _: C.Range{2,42,1,2}

def finish(okay: Bool,result: Result<&1,&2,E.Error & B.Budget,B.Six>) -> Bool:
  match result:
    case Done{B.Six{0,0,0,0,0,work}}: okay
    case _: False{}

def bytes_dropped(okay: Bool,p: B.Budget & Result<&1,&2,E.Error & B.Allocation,Unit>) -> Bool:
  (budget,result) = p
  match result:
    case Done{u}: finish(okay,B.finish(budget))
    case _: False{}

def input_dropped(bytes: Bytes.OwnedBytes,okay: Bool,p: B.Budget & Maybe<&1,I.Input> & Maybe<&2,E.Error>) -> Bool:
  (budget,input,error) = p
  match input error:
    case None{} None{}: bytes_dropped(okay,Bytes.drop(budget,bytes))
    case _ _: False{}

def checked(p: B.Budget & I.Input & Bytes.OwnedBytes & U32 & I.InputResult) -> Bool:
  (budget,input,bytes,index,result) = p
  match result:
    case I.InputFailed{X.Diagnostic{1,3,X.Position{1,line,column},entry,start,expected,observed,core,source}}: input_dropped(bytes,True{},I.drop(budget,input))
    case _: input_dropped(bytes,False{},I.drop(budget,input))

def replacement(caseId: U32,input: I.Input,p: B.Budget & Result<&2,&1,E.Error,Bytes.OwnedBytes>) -> Bool:
  (budget,result) = p
  match result:
    case Done{bytes}: checked(I.next(budget,input,new_range(caseId),bytes))
    case _: False{}

def old_dropped(+caseId: U32,input: I.Input,p: B.Budget & Result<&1,&2,E.Error & B.Allocation,Unit>) -> Bool:
  (budget,result) = p
  match result:
    case Done{u}: replacement(caseId,input,Bytes.new(budget,new_length(caseId)))
    case _: False{}

def first(caseId: U32,p: B.Budget & I.Input & Bytes.OwnedBytes & U32 & I.InputResult) -> Bool:
  (budget,input,bytes,index,result) = p
  match result:
    case I.ScalarReady{X.Scalar{65,span}}: old_dropped(caseId,input,Bytes.drop(budget,bytes))
    case _: input_dropped(bytes,False{},I.drop(budget,input))

def begun(+caseId: U32,bytes: Bytes.OwnedBytes,p: B.Budget & I.BeginResult) -> Bool:
  (budget,result) = p
  match result:
    case I.InputReady{input}: first(caseId,I.next(budget,input,C.Range{1,42,0,old_length(caseId)},bytes))
    case _: False{}

def written(caseId: U32,p: B.Budget & Bytes.OwnedBytes & Result<&2,&2,E.Error,Unit>) -> Bool:
  (budget,bytes,result) = p
  match result:
    case Done{u}: begun(caseId,bytes,I.begin(budget,C.Range{1,42,0,3},67108864))
    case _: False{}

def allocated(caseId: U32,p: B.Budget & Result<&2,&1,E.Error,Bytes.OwnedBytes>) -> Bool:
  (budget,result) = p
  match result:
    case Done{bytes}: written(caseId,Bytes.put(budget,bytes,0,65))
    case _: False{}

def started(+caseId: U32,result: Result<&2,&1,E.Error,B.Budget>) -> Bool:
  match result:
    case Done{budget}: allocated(caseId,Bytes.new(budget,old_length(caseId)))
    case _: False{}

def all_cases(fuel: Nat,+caseId: U32,okay: Bool) -> Bool:
  match fuel:
    case 0n: okay
    case 1n+rest: all_cases(rest,U32.inc(caseId),Bool.and(okay,started(caseId,B.start(1,B.Six{1000,1000,1000,1000,1048576,1000}))))

def report(okay: Bool) -> IO(Unit):
  match okay:
    case True{}: IO.print("input-replacement-rejected")
    case False{}: IO.die(Unit,70,"invalid input replacement accepted or leaked")

def main() -> IO(Unit):
  report(all_cases(6n,0,True{}))
