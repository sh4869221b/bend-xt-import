# Test-only immutable fixture transport. No FO4 parsing or repair happens here.
import Base
import ../../core/budget.bend as B
import ../../core/bytes.bend as Bytes
import ../../core/cursor.bend as C
import ../../core/error.bend as E

type Run is Data:
  Run{length: U32, value: U32}

type Fixture is Data:
  Small{runs: List<&2, Run>, size: U32}
  Synthetic{kind: U32, count: U32, size: U32}

def parsed_number(r: Maybe<&2, U32>) -> IO(U32):
  match r:
    case Some{n}: IO.pure(U32,n)
    case None{}: IO.die(U32,2,"invalid numeric argument")

def number(s: String) -> IO(U32):
  parsed_number(U32.read(s))

def nibble_code(+code: U32, decimal: Bool, lower: Bool) -> Maybe<&2, U32>:
  match decimal lower:
    case True{} _: Some{U32.sub(code,48)}
    case _ True{}: Some{U32.sub(code,87)}
    case _ _: None{}

def nibble(c: Char) -> Maybe<&2, U32>:
  match c:
    case Chr{+code}: nibble_code(code,Bool.and(U32.is_le(48,code),U32.is_le(code,57)),Bool.and(U32.is_le(97,code),U32.is_le(code,102)))

def hex_nibbles(a: Maybe<&2, U32>, b: Maybe<&2, U32>) -> IO(U32):
  match a b:
    case Some{x} Some{y}: IO.pure(U32,U32.add(U32.mul(x,16),y))
    case _ _: IO.die(U32,2,"invalid lowercase hex")

def hex_pair(a: Char, b: Char) -> IO(U32):
  hex_nibbles(nibble(a),nibble(b))

def reverse_runs(xs: List<&2, Run>, acc: List<&2, Run>) -> List<&2, Run>:
  match xs:
    case Nil{}: acc
    case x <> tail: reverse_runs(tail,x <> acc)

def hex_runs(s: String, +count: U32, acc: List<&2, Run>) -> IO(Fixture):
  match s:
    case SNil{}: IO.pure(Fixture,Small{reverse_runs(acc,Nil{}),count})
    case SCon{a,SCon{b,tail}}:
      do IO<Fixture>:
        value : U32 <- hex_pair(a,b)
        hex_runs(tail,U32.inc(count),Run{1,value} <> acc)
    case _: IO.die(Fixture,2,"odd hex length")

def fixture(s: String) -> IO(Fixture):
  match s:
    case "-": IO.pure(Fixture,Small{Nil{},0})
    case _: hex_runs(s,0,Nil{})

def size(fixture: Fixture) -> U32:
  match fixture:
    case Small{runs,size}: size
    case Synthetic{kind,count,size}: size

def selected_run(r: Maybe<&2, Run>) -> U32:
  match r:
    case None{}: 0
    case Some{Run{length,value}}: value

def run_byte(runs: List<&2, Run>, index: U32) -> U32:
  selected_run(List.get(&2,Run,runs,U32.to_nat(index)))

def word_byte(word: U32, index: U32) -> U32:
  U32.and(U32.shrn(word,U32.to_nat(U32.mul(index,8))),255)

# Synthetic kinds: 0=empty records (count includes TES4), 1=zero-byte
# subrecords in one TES4, 2=nested empty groups after TES4, 3=ordinary
# payload, 4=XXXX payload, 5=opaque compressed stored bytes, 6=source-only.
def header_tail(index: U32) -> U32:
  match index:
    case 20: 131
    case _: 0

def header_fields(signature: U32, length: U32, flags: U32, +index: U32, first: Bool, second: Bool, third: Bool) -> U32:
  match first second third:
    case True{} _ _: word_byte(signature,index)
    case _ True{} _: word_byte(length,U32.sub(index,4))
    case _ _ True{}: word_byte(flags,U32.sub(index,8))
    case _ _ _: header_tail(index)

def header_byte(signature: U32, length: U32, flags: U32, +index: U32) -> U32:
  header_fields(signature,length,flags,index,U32.is_lt(index,4),U32.is_lt(index,8),U32.is_lt(index,12))

def field_selected(signature: U32, length: U32, +index: U32, first: Bool) -> U32:
  match first:
    case True{}: word_byte(signature,index)
    case False{}: word_byte(length,U32.sub(index,4))

def field_byte(signature: U32, length: U32, +index: U32) -> U32:
  field_selected(signature,length,index,U32.is_lt(index,4))

def repeated_selected(index: U32, first: Bool) -> U32:
  match first:
    case True{}: header_byte(877872468,0,0,index)
    case False{}: header_byte(1346454871,0,0,U32.mod(index,24))

def repeated_record(+index: U32) -> U32:
  repeated_selected(index,U32.is_lt(index,24))

def fixture_signature(first: Bool) -> U32:
  match first:
    case True{}: 877872468
    case False{}: 1346454871

def fields_segment(count: U32, +index: U32, signature: U32, header: Bool) -> U32:
  match header:
    case True{}: header_byte(signature,U32.mul(count,6),0,index)
    case False{}: field_byte(1096040772,0,U32.mod(U32.sub(index,24),6))

def fields_block(count: U32, +block: U32, +index: U32) -> U32:
  fields_segment(U32.min(U32.sub(count,U32.mul(block,1000000)),1000000),index,fixture_signature(U32.is_zero(block)),U32.is_lt(index,24))

def repeated_field(count: U32, +index: U32) -> U32:
  fields_block(count,U32.div(index,6000024),U32.mod(index,6000024))

def group_selected(+count: U32, +index: U32, first: Bool) -> U32:
  match first:
    case True{}: header_byte(877872468,0,0,index)
    case False{}: header_byte(1347768903,U32.mul(U32.sub(U32.inc(count),U32.div(index,24)),24),0,U32.mod(index,24))

def group_byte(count: U32, +index: U32) -> U32:
  group_selected(count,index,U32.is_lt(index,24))

def ordinary_body(count: U32, index: U32, header: Bool) -> U32:
  match header:
    case True{}: field_byte(1280070982,count,index)
    case False{}: 129

def extended_body(count: U32, +index: U32, escape: Bool, length: Bool, header: Bool) -> U32:
  match escape length header:
    case True{} _ _: field_byte(1482184792,4,index)
    case _ True{} _: word_byte(count,U32.sub(index,6))
    case _ _ True{}: field_byte(1280070982,123,U32.sub(index,10))
    case _ _ _: 167

def body_byte(kind: U32, count: U32, +index: U32) -> U32:
  match kind:
    case 3: ordinary_body(count,index,U32.is_lt(index,6))
    case 4: extended_body(count,index,U32.is_lt(index,6),U32.is_lt(index,10),U32.is_lt(index,16))
    case _: U32.and(index,255)

def payload_header(kind: U32, count: U32, index: U32) -> U32:
  match kind:
    case 3: header_byte(1346454871,U32.add(count,6),0,U32.sub(index,24))
    case 4: header_byte(1346454871,U32.add(count,16),0,U32.sub(index,24))
    case _: header_byte(1346454871,count,262144,U32.sub(index,24))

def payload_selected(kind: U32, count: U32, +index: U32, first: Bool, header: Bool) -> U32:
  match first header:
    case True{} _: header_byte(877872468,0,0,index)
    case _ True{}: payload_header(kind,count,index)
    case _ _: body_byte(kind,count,U32.sub(index,48))

def payload_byte(kind: U32, count: U32, +index: U32) -> U32:
  payload_selected(kind,count,index,U32.is_lt(index,24),U32.is_lt(index,48))

def stream_final_start(full: U32, remainder: U32, small: Bool) -> U32:
  match small:
    case True{}: U32.mul(U32.sub(full,1),16777216)
    case False{}: U32.mul(full,16777216)

def stream_boundary(+total: U32) -> U32:
  stream_final_start(U32.div(total,16777216),U32.mod(total,16777216),Bool.and(U32.is_le(16777216,total),U32.is_lt(U32.mod(total,16777216),24)))

def stream_segment(length: U32, +index: U32, header: Bool) -> U32:
  match header:
    case True{}: header_byte(1346454871,U32.sub(length,24),262144,index)
    case False{}: U32.and(index,255)

def stream_offset(length: U32, +index: U32) -> U32:
  stream_segment(length,index,U32.is_lt(index,24))

def stream_last(total: U32, +start: U32, index: U32, before: Bool) -> U32:
  match before:
    case True{}: stream_offset(16777216,U32.mod(index,16777216))
    case False{}: stream_offset(U32.sub(total,start),U32.sub(index,start))

def stream_blocks(+total: U32, +index: U32, +start: U32) -> U32:
  stream_last(total,start,index,U32.is_lt(index,start))

def stream_selected(+size: U32, index: U32, initial: Bool) -> U32:
  match initial:
    case True{}: header_byte(877872468,0,0,index)
    case False{}: stream_blocks(U32.sub(size,24),U32.sub(index,24),stream_boundary(U32.sub(size,24)))

def stream_byte(size: U32, +index: U32) -> U32:
  stream_selected(size,index,U32.is_lt(index,24))

def byte(fixture: Fixture, index: U32) -> U32:
  match fixture:
    case Small{runs,size}: run_byte(runs,index)
    case Synthetic{kind,count,size}:
      match kind:
        case 0: repeated_record(index)
        case 1: repeated_field(count,index)
        case 2: group_byte(count,index)
        case 6: 0
        case 7: stream_byte(size,index)
        case _: payload_byte(kind,count,index)

def synthetic(kind: U32, +count: U32) -> Fixture:
  match kind:
    case 0: Synthetic{0,count,U32.mul(count,24)}
    case 1: Synthetic{1,count,U32.add(U32.mul(U32.max(1,U32.div(U32.add(count,999999),1000000)),24),U32.mul(count,6))}
    case 2: Synthetic{2,count,U32.mul(U32.inc(count),24)}
    case 3: Synthetic{3,count,U32.add(54,count)}
    case 4: Synthetic{4,count,U32.add(64,count)}
    case 5: Synthetic{5,count,U32.add(48,count)}
    case 7: Synthetic{7,count,count}
    case _: Synthetic{6,count,count}

def fill(fuel: Nat, +fixture: Fixture, +index: U32, +base: U32, p: B.Budget & Bytes.OwnedBytes & Result<&2, &2, E.Error, Unit>) -> B.Budget & Bytes.OwnedBytes & Result<&2, &2, E.Error, Unit>:
  match fuel:
    case 0n: p
    case 1n+rest:
      (budget,bytes,result) = p
      match result:
        case Fail{error}: (budget,bytes,Fail{error})
        case Done{u}: fill(rest,fixture,U32.inc(index),base,Bytes.append(budget,bytes,byte(fixture,U32.add(base,index))))

def bound(budget: B.Budget, r: Result<&1, &1, E.Error & C.SourceOwner & Bytes.OwnedBytes, C.ByteWindow>) -> IO(B.Budget & C.ByteWindow):
  match r:
    case Done{window}: IO.pure(B.Budget & C.ByteWindow,(budget,window))
    case Fail{error}: IO.die(B.Budget & C.ByteWindow,70,"synthetic window bind failed")

def filled(source: C.SourceOwner, base: U32, p: B.Budget & Bytes.OwnedBytes & Result<&2, &2, E.Error, Unit>) -> IO(B.Budget & C.ByteWindow):
  (budget,bytes,result) = p
  match result:
    case Fail{error}: IO.die(B.Budget & C.ByteWindow,70,"synthetic input fill failed")
    case Done{u}: bound(budget,C.bind(source,bytes,base))

def window(budget: B.Budget, source: C.SourceOwner, bytes: Bytes.OwnedBytes, +fixture: Fixture, chunk: U32, +base: U32) -> IO(B.Budget & C.ByteWindow):
  filled(source,base,fill(U32.to_nat(U32.min(chunk,U32.sub(size(fixture),base))),fixture,0,base,(budget,Bytes.clear(bytes),Done{Unit{}})))

def refilled(budget: B.Budget, fixture: Fixture, chunk: U32, base: U32, p: C.SourceOwner & Bytes.OwnedBytes) -> IO(B.Budget & C.ByteWindow):
  (source,bytes) = p
  window(budget,source,bytes,fixture,chunk,base)

def refill(budget: B.Budget, current: C.ByteWindow, fixture: Fixture, chunk: U32, base: U32) -> IO(B.Budget & C.ByteWindow):
  refilled(budget,fixture,chunk,base,C.unbind(current))

def dropped(p: B.Budget & Result<&1, &2, E.Error & B.Allocation, Unit>) -> IO(B.Budget):
  (budget,result) = p
  match result:
    case Done{u}: IO.pure(B.Budget,budget)
    case Fail{error}: IO.die(B.Budget,70,"owner release failed")

def drop_unbound(budget: B.Budget, p: C.SourceOwner & Bytes.OwnedBytes) -> IO(B.Budget):
  (source,bytes) = p
  do IO<B.Budget>:
    budget : B.Budget <- dropped(Bytes.drop(budget,bytes))
    dropped(C.drop_source(budget,source))

def drop_window(budget: B.Budget, window: C.ByteWindow) -> IO(B.Budget):
  drop_unbound(budget,C.unbind(window))

def bool(b: Bool) -> String:
  match b:
    case True{}: "1"
    case False{}: "0"

def range(r: C.Range) -> String:
  match r:
    case C.Range{run,origin,start,end}: U32.show(run) ++ " " ++ U32.show(origin) ++ " " ++ U32.show(start) ++ " " ++ U32.show(end)

def usage(r: Result<&1, &2, E.Error & B.Budget, B.Six>) -> IO(Unit):
  match r:
    case Fail{error}: IO.die(Unit,70,"unbalanced budget.finish")
    case Done{B.Six{input,expanded,output,logical,live,work}}:
      IO.print("USAGE " ++ U32.show(input) ++ " " ++ U32.show(expanded) ++ " " ++ U32.show(output) ++ " " ++ U32.show(logical) ++ " " ++ U32.show(live) ++ " " ++ U32.show(work))
