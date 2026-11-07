import Base
import ../../core/budget.bend as B
import ../../core/error.bend as E
import ../../core/bytes.bend as Bytes
import ../../core/cursor.bend as C
import ../../xml/input.bend as I
import ../../xml/types.bend as X

type Harness is Type:
  Harness{budget: B.Budget, input: Maybe<&1,I.Input>, bytes: Maybe<&1,Bytes.OwnedBytes>, start: U32, end: U32, fill: U32, seen: U32, okay: Bool, phase: U32}

def fixture(index: U32) -> U32:
  match index:
    case 0: 239
    case 1: 187
    case 2: 191
    case 3: 65
    case 4: 13
    case 5: 10
    case 6: 230
    case 7: 151
    case 8: 165
    case 9: 13
    case 10: 66
    case 11: 10
    case _: 13

def expected(index: U32) -> X.Scalar:
  match index:
    case 0: X.Scalar{65,X.Span{X.Position{3,1,1},X.Position{4,1,2}}}
    case 1: X.Scalar{10,X.Span{X.Position{4,1,2},X.Position{6,2,1}}}
    case 2: X.Scalar{26085,X.Span{X.Position{6,2,1},X.Position{9,2,2}}}
    case 3: X.Scalar{10,X.Span{X.Position{9,2,2},X.Position{10,3,1}}}
    case 4: X.Scalar{66,X.Span{X.Position{10,3,1},X.Position{11,3,2}}}
    case 5: X.Scalar{10,X.Span{X.Position{11,3,2},X.Position{12,4,1}}}
    case _: X.Scalar{10,X.Span{X.Position{12,4,1},X.Position{13,5,1}}}

def pos_eq(a: X.Position,b: X.Position) -> Bool:
  match a b:
    case X.Position{a,b,c} X.Position{d,e,f}: Bool.and(U32.is_eq(a,d),Bool.and(U32.is_eq(b,e),U32.is_eq(c,f)))

def scalar_eq(a: X.Scalar,b: X.Scalar) -> Bool:
  match a b:
    case X.Scalar{a,X.Span{b,c}} X.Scalar{d,X.Span{e,f}}: Bool.and(U32.is_eq(a,d),Bool.and(pos_eq(b,e),pos_eq(c,f)))

def allocated(input: I.Input, start: U32, end: U32, seen: U32, okay: Bool, p: B.Budget & Result<&2,&1,E.Error,Bytes.OwnedBytes>) -> Harness:
  (budget,result) = p
  match result:
    case Done{bytes}: Harness{budget,Some{input},Some{bytes},start,end,0,seen,okay,1}
    case _: Harness{budget,Some{input},None{},start,end,0,seen,False{},99}

def chunk_new(budget: B.Budget,input: I.Input,+start: U32,+size: U32,seen: U32,okay: Bool,atEnd: Bool) -> Harness:
  match atEnd:
    case True{}: Harness{budget,Some{input},None{},start,start,0,seen,okay,4}
    case False{}: allocated(input,start,U32.add(start,U32.min(size,U32.sub(13,start))),seen,okay,Bytes.new(budget,U32.min(size,U32.sub(13,start))))

def written(input: I.Input,start: U32,end: U32,fill: U32,seen: U32,okay: Bool,p: B.Budget & Bytes.OwnedBytes & Result<&2,&2,E.Error,Unit>) -> Harness:
  (budget,bytes,result) = p
  match result:
    case Done{u}: Harness{budget,Some{input},Some{bytes},start,end,U32.inc(fill),seen,okay,1}
    case _: Harness{budget,Some{input},Some{bytes},start,end,fill,seen,False{},99}

def write_next(budget: B.Budget,input: I.Input,bytes: Bytes.OwnedBytes,+start: U32,end: U32,+fill: U32,seen: U32,okay: Bool,done: Bool) -> Harness:
  match done:
    case True{}: Harness{budget,Some{input},Some{bytes},start,end,fill,seen,okay,2}
    case False{}: written(input,start,end,fill,seen,okay,Bytes.put(budget,bytes,fill,fixture(U32.add(start,fill))))

def read_result(+start: U32,+end: U32,+seen: U32,okay: Bool,p: B.Budget & I.Input & Bytes.OwnedBytes & U32 & I.InputResult) -> Harness:
  (budget,input,bytes,index,result) = p
  match result:
    case I.ScalarReady{scalar}: Harness{budget,Some{input},Some{bytes},start,end,0,U32.inc(seen),Bool.and(okay,scalar_eq(scalar,expected(seen))),2}
    case I.NeedInput{}: Harness{budget,Some{input},Some{bytes},start,end,0,seen,Bool.and(okay,U32.is_eq(index,U32.sub(end,start))),3}
    case _: Harness{budget,Some{input},Some{bytes},start,end,0,seen,False{},99}

def bytes_dropped(input: I.Input,+end: U32,seen: U32,okay: Bool,p: B.Budget & Result<&1,&2,E.Error & B.Allocation,Unit>) -> Harness:
  (budget,result) = p
  match result:
    case Done{u}: Harness{budget,Some{input},None{},end,end,0,seen,okay,0}
    case _: Harness{budget,Some{input},None{},end,end,0,seen,False{},99}

def ended(+seen: U32,okay: Bool,p: B.Budget & I.Input & I.EndResult) -> Harness:
  (budget,input,result) = p
  match result:
    case I.EndScalar{scalar}: Harness{budget,Some{input},None{},13,13,0,U32.inc(seen),Bool.and(okay,scalar_eq(scalar,expected(seen))),4}
    case I.EndDone{position}: Harness{budget,Some{input},None{},13,13,0,seen,Bool.and(okay,Bool.and(U32.is_eq(seen,7),pos_eq(position,X.Position{13,5,1}))),5}
    case _: Harness{budget,Some{input},None{},13,13,0,seen,False{},99}

def input_dropped(okay: Bool,p: B.Budget & Maybe<&1,I.Input> & Maybe<&2,E.Error>) -> Harness:
  (budget,input,error) = p
  match input error:
    case None{} None{}: Harness{budget,None{},None{},13,13,0,7,okay,6}
    case other _: Harness{budget,other,None{},13,13,0,7,False{},99}

def step(size: U32,harness: Harness) -> Harness:
  match harness:
    case Harness{budget,Some{input},None{},+start,end,fill,seen,okay,0}: chunk_new(budget,input,start,size,seen,okay,U32.is_eq(start,13))
    case Harness{budget,Some{input},Some{bytes},+start,+end,+fill,seen,okay,1}: write_next(budget,input,bytes,start,end,fill,seen,okay,U32.is_eq(fill,U32.sub(end,start)))
    case Harness{budget,Some{input},Some{bytes},+start,+end,fill,seen,okay,2}: read_result(start,end,seen,okay,I.next(budget,input,C.Range{1,42,start,end},bytes))
    case Harness{budget,Some{input},Some{bytes},start,end,fill,seen,okay,3}: bytes_dropped(input,end,seen,okay,Bytes.drop(budget,bytes))
    case Harness{budget,Some{input},None{},start,end,fill,seen,okay,4}: ended(seen,okay,I.end(budget,input))
    case Harness{budget,Some{input},None{},start,end,fill,seen,okay,5}: input_dropped(okay,I.drop(budget,input))
    case other: other

def loop(fuel: Nat,+size: U32,harness: Harness) -> Harness:
  match fuel:
    case 0n: harness
    case 1n+rest: loop(rest,size,step(size,harness))

def finished(okay: Bool,r: Result<&1,&2,E.Error & B.Budget,B.Six>) -> Bool:
  match r:
    case Done{B.Six{0,0,0,0,0,work}}: okay
    case _: False{}

def checked(harness: Harness) -> Bool:
  match harness:
    case Harness{budget,None{},None{},start,end,fill,seen,okay,6}: finished(okay,B.finish(budget))
    case _: False{}

def began(size: U32,p: B.Budget & I.BeginResult) -> Bool:
  (budget,result) = p
  match result:
    case I.InputReady{input}: checked(loop(200n,size,Harness{budget,Some{input},None{},0,0,0,0,True{},0}))
    case _: False{}

def started(size: U32,result: Result<&2,&1,E.Error,B.Budget>) -> Bool:
  match result:
    case Done{budget}: began(size,I.begin(budget,C.Range{1,42,0,13},67108864))
    case _: False{}

def all_sizes(fuel: Nat,+size: U32,okay: Bool) -> Bool:
  match fuel:
    case 0n: okay
    case 1n+rest: all_sizes(rest,U32.inc(size),Bool.and(okay,started(size,B.start(1,B.Six{1000000,1000000,1000000,1000000,10485760,1000000}))))

def report(okay: Bool) -> IO(Unit):
  match okay:
    case True{}: IO.print("input-splits-balanced")
    case False{}: IO.die(Unit,70,"input split/location/ownership failed")

def main() -> IO(Unit):
  report(all_sizes(13n,1,True{}))
