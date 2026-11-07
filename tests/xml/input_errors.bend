import Base
import ../../core/budget.bend as B
import ../../core/error.bend as E
import ../../core/bytes.bend as Bytes
import ../../core/cursor.bend as C
import ../../xml/input.bend as I
import ../../xml/types.bend as X

def size(caseId: U32) -> U32:
  match caseId:
    case 1: 3
    case 3: 3
    case 4: 2
    case 7: 0
    case _: 1

def value(caseId: U32,index: U32) -> U32:
  match caseId index:
    case 0 _: 255
    case 1 0: 237
    case 1 1: 160
    case 1 _: 128
    case 2 _: 0
    case 3 0: 239
    case 3 1: 191
    case 3 _: 190
    case 4 0: 230
    case 4 _: 151
    case _ _: 65

def root(caseId: U32) -> C.Range:
  match caseId:
    case 5: C.Range{1,42,0,2}
    case 7: C.Range{1,42,0,1}
    case 8: C.Range{2,42,0,1}
    case other: C.Range{1,42,0,size(other)}

def chunk(+caseId: U32) -> C.Range:
  match caseId:
    case 6: C.Range{1,43,0,1}
    case _: C.Range{1,42,0,size(caseId)}

def reason(caseId: U32) -> U32:
  match caseId:
    case 2: 6
    case 3: 6
    case 5: 7
    case 6: 3
    case 7: 3
    case 8: 2
    case _: 5

def offset(caseId: U32) -> U32:
  match caseId:
    case 1: 1
    case 5: 1
    case _: 0

def check_diag(+caseId: U32,diagnostic: X.Diagnostic) -> Bool:
  match diagnostic:
    case X.Diagnostic{phase,why,X.Position{byte,line,column},entry,start,expected,observed,core,source}:
      Bool.and(U32.is_eq(phase,1),Bool.and(U32.is_eq(why,reason(caseId)),U32.is_eq(byte,offset(caseId))))

def finished(okay: Bool,result: Result<&1,&2,E.Error & B.Budget,B.Six>) -> Bool:
  match result:
    case Done{B.Six{0,0,0,0,0,work}}: okay
    case _: False{}

def bytes_dropped(okay: Bool,p: B.Budget & Result<&1,&2,E.Error & B.Allocation,Unit>) -> Bool:
  (budget,result) = p
  match result:
    case Done{u}: finished(okay,B.finish(budget))
    case _: False{}

def input_dropped(bytes: Bytes.OwnedBytes,okay: Bool,p: B.Budget & Maybe<&1,I.Input> & Maybe<&2,E.Error>) -> Bool:
  (budget,input,error) = p
  match input error:
    case None{} None{}: bytes_dropped(okay,Bytes.drop(budget,bytes))
    case _ _: False{}

def sticky(caseId: U32,okay: Bool,p: B.Budget & I.Input & Bytes.OwnedBytes & U32 & I.InputResult) -> Bool:
  (budget,input,bytes,index,result) = p
  match result:
    case I.InputFailed{diagnostic}: input_dropped(bytes,Bool.and(okay,check_diag(caseId,diagnostic)),I.drop(budget,input))
    case _: input_dropped(bytes,False{},I.drop(budget,input))

def end_checked(+caseId: U32,bytes: Bytes.OwnedBytes,p: B.Budget & I.Input & I.EndResult) -> Bool:
  (budget,input,result) = p
  match result:
    case I.EndFailed{diagnostic}: sticky(caseId,check_diag(caseId,diagnostic),I.next(budget,input,chunk(caseId),bytes))
    case _: input_dropped(bytes,False{},I.drop(budget,input))

def drive(fuel: Nat,+caseId: U32,p: B.Budget & I.Input & Bytes.OwnedBytes & U32 & I.InputResult) -> Bool:
  match fuel:
    case 0n:
      (budget,input,bytes,index,result) = p
      input_dropped(bytes,False{},I.drop(budget,input))
    case 1n+rest:
      (budget,input,bytes,index,result) = p
      match result:
        case I.InputFailed{diagnostic}: sticky(caseId,check_diag(caseId,diagnostic),I.next(budget,input,chunk(caseId),bytes))
        case I.NeedInput{}: end_checked(caseId,bytes,I.end(budget,input))
        case I.ScalarReady{scalar}: drive(rest,caseId,I.next(budget,input,chunk(caseId),bytes))
        case I.ContinueInput{}: input_dropped(bytes,False{},I.drop(budget,input))

def began(+caseId: U32,bytes: Bytes.OwnedBytes,p: B.Budget & I.BeginResult) -> Bool:
  (budget,result) = p
  match result:
    case I.InputReady{input}: drive(8n,caseId,I.next(budget,input,chunk(caseId),bytes))
    case I.InitFailed{diagnostic,Some{input}}: sticky(caseId,check_diag(caseId,diagnostic),I.next(budget,input,chunk(caseId),bytes))
    case _: False{}

def fill(fuel: Nat,+caseId: U32,+index: U32,p: B.Budget & Bytes.OwnedBytes & Result<&2,&2,E.Error,Unit>) -> Bool:
  match fuel:
    case 0n:
      (budget,bytes,result) = p
      match result:
        case Done{u}: began(caseId,bytes,I.begin(budget,root(caseId),67108864))
        case _: False{}
    case 1n+rest:
      (budget,bytes,result) = p
      match result:
        case Done{u}: fill(rest,caseId,U32.inc(index),Bytes.put(budget,bytes,index,value(caseId,index)))
        case _: False{}

def allocated(+caseId: U32,p: B.Budget & Result<&2,&1,E.Error,Bytes.OwnedBytes>) -> Bool:
  (budget,result) = p
  match result:
    case Done{bytes}: fill(U32.to_nat(size(caseId)),caseId,0,(budget,bytes,Done{Unit{}}))
    case _: False{}

def started(+caseId: U32,result: Result<&2,&1,E.Error,B.Budget>) -> Bool:
  match result:
    case Done{budget}: allocated(caseId,Bytes.new(budget,size(caseId)))
    case _: False{}

def all_cases(fuel: Nat,+caseId: U32,okay: Bool) -> Bool:
  match fuel:
    case 0n: okay
    case 1n+rest: all_cases(rest,U32.inc(caseId),Bool.and(okay,started(caseId,B.start(1,B.Six{1000,1000,1000,1000,1048576,1000}))))

def report(okay: Bool) -> IO(Unit):
  match okay:
    case True{}: IO.print("input-errors-balanced")
    case False{}: IO.die(Unit,70,"input error/sticky/cleanup failed")

def main() -> IO(Unit):
  report(all_cases(9n,0,True{}))
