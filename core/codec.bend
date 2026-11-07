import Base
import ./error.bend as E
import ./budget.bend as B
import ./bytes.bend as Bytes
import ./scalars.bend as Scalars
import ./storage.bend as S
import ./unicode.bend as U
import ./utf8.bend as U8
import ./cp1252.bend as CP

type Progress is Data:
  Progress{state: U8.State, next: U32, produced: U32, status: U32}
# status 0: input exhausted, 1: output full, 2: sticky error, 3: internal continue.

def transition(kind: U32, state: U8.State, byte: U32) -> U8.Step:
  match kind:
    case 0: U8.step(state,byte)
    case 1: CP.step(state,byte)
    case _: U8.failed(E.Unsupported{40})

def scalar_written(input: Bytes.OwnedBytes, state: U8.State, next: U32, produced: U32, p: B.Budget & Scalars.ScalarChunk & Result<&2, &2, E.Error, Unit>) -> B.Budget & Bytes.OwnedBytes & Scalars.ScalarChunk & Progress:
  (budget,output,result) = p
  match result:
    case Fail{error}: (budget,input,output,Progress{U8.Broken{error},next,produced,2})
    case Done{u}: (budget,input,output,Progress{state,next,U32.inc(produced),3})

def scalar_charged(input: Bytes.OwnedBytes, output: Scalars.ScalarChunk, state: U8.State, next: U32, produced: U32, scalar: U32, p: B.Budget & Result<&2, &2, E.Error, Unit>) -> B.Budget & Bytes.OwnedBytes & Scalars.ScalarChunk & Progress:
  (budget,result) = p
  match result:
    case Fail{error}: (budget,input,output,Progress{U8.Broken{error},next,produced,2})
    case Done{u}: scalar_written(input,state,next,produced,Scalars.append_precharged(budget,output,scalar))

def decoded(budget: B.Budget, input: Bytes.OwnedBytes, output: Scalars.ScalarChunk, index: U32, produced: U32, step: U8.Step) -> B.Budget & Bytes.OwnedBytes & Scalars.ScalarChunk & Progress:
  match step:
    case U8.Step{U8.Broken{error},scalar}: (budget,input,output,Progress{U8.Broken{error},U32.inc(index),produced,2})
    case U8.Step{state,None{}}: (budget,input,output,Progress{state,U32.inc(index),produced,3})
    case U8.Step{state,Some{+scalar}}: scalar_charged(input,output,state,U32.inc(index),produced,scalar,B.consume(budget,B.work(U.width(scalar))))

def decode_read(kind: U32, output: Scalars.ScalarChunk, state: U8.State, index: U32, produced: U32, p: B.Budget & Bytes.OwnedBytes & Result<&2, &2, E.Error, U32>) -> B.Budget & Bytes.OwnedBytes & Scalars.ScalarChunk & Progress:
  (budget,input,result) = p
  match result:
    case Fail{error}: (budget,input,output,Progress{U8.Broken{error},index,produced,2})
    case Done{byte}: decoded(budget,input,output,index,produced,transition(kind,state,byte))

def decode_space(kind: U32, budget: B.Budget, input: Bytes.OwnedBytes, output: Scalars.ScalarChunk, state: U8.State, +index: U32, produced: U32, space: Bool) -> B.Budget & Bytes.OwnedBytes & Scalars.ScalarChunk & Progress:
  match space:
    case False{}: (budget,input,output,Progress{state,index,produced,1})
    case True{}: decode_read(kind,output,state,index,produced,Bytes.get(budget,input,index))

def decode_meta(kind: U32, budget: B.Budget, input: Bytes.OwnedBytes, state: U8.State, index: U32, produced: U32, p: Scalars.ScalarChunk & U32 & U32 & U32 & U32) -> B.Budget & Bytes.OwnedBytes & Scalars.ScalarChunk & Progress:
  (output,length,capacity,run,origin) = p
  decode_space(kind,budget,input,output,state,index,produced,U32.is_lt(length,capacity))

def decode_end(kind: U32, budget: B.Budget, input: Bytes.OwnedBytes, output: Scalars.ScalarChunk, state: U8.State, index: U32, produced: U32, end: Bool) -> B.Budget & Bytes.OwnedBytes & Scalars.ScalarChunk & Progress:
  match end:
    case True{}: (budget,input,output,Progress{state,index,produced,0})
    case False{}: decode_meta(kind,budget,input,state,index,produced,Scalars.metadata(output))

def decode_one(kind: U32, budget: B.Budget, input: Bytes.OwnedBytes, output: Scalars.ScalarChunk, state: U8.State, +index: U32, produced: U32, size: U32) -> B.Budget & Bytes.OwnedBytes & Scalars.ScalarChunk & Progress:
  match state:
    case U8.Broken{error}: (budget,input,output,Progress{U8.Broken{error},index,produced,2})
    case U8.State{remaining,value,minimum,start,next}: decode_end(kind,budget,input,output,U8.State{remaining,value,minimum,start,next},index,produced,U32.is_eq(index,size))

def decode_loop(fuel: Nat, +kind: U32, +size: U32, p: B.Budget & Bytes.OwnedBytes & Scalars.ScalarChunk & Progress) -> B.Budget & Bytes.OwnedBytes & Scalars.ScalarChunk & Progress:
  match fuel:
    case 0n: p
    case 1n+rest:
      (budget,input,output,progress) = p
      match progress:
        case Progress{state,index,produced,3}: decode_loop(rest,kind,size,decode_one(kind,budget,input,output,state,index,produced,size))
        case Progress{state,index,produced,status}: (budget,input,output,Progress{state,index,produced,status})

def decode_valid(+kind: U32, budget: B.Budget, input: Bytes.OwnedBytes, output: Scalars.ScalarChunk, state: U8.State, +start: U32, +size: U32, valid: Bool) -> B.Budget & Bytes.OwnedBytes & Scalars.ScalarChunk & Progress:
  match valid:
    case False{}: (budget,input,output,Progress{U8.Broken{E.Bounds{start,0,size}},start,0,2})
    case True{}: decode_loop(U32.to_nat(U32.inc(U32.sub(size,start))),kind,size,(budget,input,output,Progress{state,start,0,3}))

def decode_input(kind: U32, budget: B.Budget, output: Scalars.ScalarChunk, state: U8.State, +start: U32, p: Bytes.OwnedBytes & U32 & U32 & U32 & U32) -> B.Budget & Bytes.OwnedBytes & Scalars.ScalarChunk & Progress:
  (input,size0,capacity,run,origin) = p
  +size = {size0: U32}
  decode_valid(kind,budget,input,output,state,start,size,U32.is_le(start,size))

def decode(kind: U32, budget: B.Budget, input: Bytes.OwnedBytes, output: Scalars.ScalarChunk, state: U8.State, start: U32) -> B.Budget & Bytes.OwnedBytes & Scalars.ScalarChunk & Progress:
  decode_input(kind,budget,output,state,start,Bytes.metadata(input))

# Encoding keeps an inspected scalar pending when the destination is full.
# Resumption does not reread/recharge that scalar.
type EncodeState is Data:
  EncodeReady{}
  Pending{scalar: U32, packet: U8.Encoded}
  EncodeBroken{error: E.Error}

type EncodeProgress is Data:
  EncodeProgress{state: EncodeState, next: U32, produced: U32, status: U32}

def packet(kind: U32, scalar: U32, offset: U32) -> Result<&2, &2, E.Error, U8.Encoded>:
  match kind:
    case 0: U8.encode(scalar,offset)
    case 1: CP.encode_packet(scalar,offset)
    case _: Fail{E.Unsupported{40}}

# Internal emission after capacity check and precharge. count is 1..4.
def emit_array(data: Array<U32>, +index: U32, packet: U8.Encoded) -> Array<U32>:
  match packet:
    case U8.Encoded{1,a,b,c,d}: Array.set(U32,data,index,a)
    case U8.Encoded{2,a,b,c,d}: Array.set(U32,Array.set(U32,data,index,a),U32.add(index,1),b)
    case U8.Encoded{3,a,b,c,d}: Array.set(U32,Array.set(U32,Array.set(U32,data,index,a),U32.add(index,1),b),U32.add(index,2),c)
    case U8.Encoded{4,a,b,c,d}: Array.set(U32,Array.set(U32,Array.set(U32,Array.set(U32,data,index,a),U32.add(index,1),b),U32.add(index,2),c),U32.add(index,3),d)
    case U8.Encoded{count,a,b,c,d}: data

def emit(output: Bytes.OwnedBytes, +packet: U8.Encoded, count: U32) -> Bytes.OwnedBytes:
  match output:
    case Bytes.Bytes{S.Storage{data,+length,capacity,run,origin,allocation}}:
      Bytes.Bytes{S.Storage{emit_array(data,length,packet),U32.add(length,count),capacity,run,origin,allocation}}

def encode_charged(input: Scalars.ScalarChunk, output: Bytes.OwnedBytes, scalar: U32, packet: U8.Encoded, index: U32, produced: U32, +count: U32, p: B.Budget & Result<&2, &2, E.Error, Unit>) -> B.Budget & Scalars.ScalarChunk & Bytes.OwnedBytes & EncodeProgress:
  (budget,result) = p
  match result:
    case Fail{error}: (budget,input,output,EncodeProgress{EncodeBroken{error},index,produced,2})
    case Done{u}: (budget,input,emit(output,packet,count),EncodeProgress{EncodeReady{},U32.inc(index),U32.add(produced,count),3})

def encode_space(budget: B.Budget, input: Scalars.ScalarChunk, output: Bytes.OwnedBytes, scalar: U32, packet: U8.Encoded, index: U32, produced: U32, +count: U32, space: Bool) -> B.Budget & Scalars.ScalarChunk & Bytes.OwnedBytes & EncodeProgress:
  match space:
    case False{}: (budget,input,output,EncodeProgress{Pending{scalar,packet},index,produced,1})
    case True{}: encode_charged(input,output,scalar,packet,index,produced,count,B.consume(budget,B.work(count)))

def encode_output(budget: B.Budget, input: Scalars.ScalarChunk, scalar: U32, packet: U8.Encoded, index: U32, produced: U32, p: Bytes.OwnedBytes & U32 & U32 & U32 & U32) -> B.Budget & Scalars.ScalarChunk & Bytes.OwnedBytes & EncodeProgress:
  match packet:
    case U8.Encoded{+count,+a,+b,+c,+d}:
      (output,length,capacity,run,origin) = p
      encode_space(budget,input,output,scalar,U8.Encoded{count,a,b,c,d},index,produced,count,U32.is_le(count,U32.sub(capacity,length)))

def encoded_packet(budget: B.Budget, input: Scalars.ScalarChunk, output: Bytes.OwnedBytes, scalar: U32, index: U32, produced: U32, result: Result<&2, &2, E.Error, U8.Encoded>) -> B.Budget & Scalars.ScalarChunk & Bytes.OwnedBytes & EncodeProgress:
  match result:
    case Fail{error}: (budget,input,output,EncodeProgress{EncodeBroken{error},index,produced,2})
    case Done{packet}: encode_output(budget,input,scalar,packet,index,produced,Bytes.metadata(output))

def encode_read(kind: U32, output: Bytes.OwnedBytes, +index: U32, produced: U32, p: B.Budget & Scalars.ScalarChunk & Result<&2, &2, E.Error, U32>) -> B.Budget & Scalars.ScalarChunk & Bytes.OwnedBytes & EncodeProgress:
  (budget,input,result) = p
  match result:
    case Fail{error}: (budget,input,output,EncodeProgress{EncodeBroken{error},index,produced,2})
    case Done{+scalar}: encoded_packet(budget,input,output,scalar,index,produced,packet(kind,scalar,index))

def encode_end(kind: U32, budget: B.Budget, input: Scalars.ScalarChunk, output: Bytes.OwnedBytes, +index: U32, produced: U32, end: Bool) -> B.Budget & Scalars.ScalarChunk & Bytes.OwnedBytes & EncodeProgress:
  match end:
    case True{}: (budget,input,output,EncodeProgress{EncodeReady{},index,produced,0})
    case False{}: encode_read(kind,output,index,produced,Scalars.get(budget,input,index))

def encode_one(kind: U32, budget: B.Budget, input: Scalars.ScalarChunk, output: Bytes.OwnedBytes, state: EncodeState, +index: U32, produced: U32, size: U32) -> B.Budget & Scalars.ScalarChunk & Bytes.OwnedBytes & EncodeProgress:
  match state:
    case EncodeReady{}: encode_end(kind,budget,input,output,index,produced,U32.is_eq(index,size))
    case Pending{scalar,packet}: encode_output(budget,input,scalar,packet,index,produced,Bytes.metadata(output))
    case EncodeBroken{error}: (budget,input,output,EncodeProgress{EncodeBroken{error},index,produced,2})

def encode_loop(fuel: Nat, +kind: U32, +size: U32, p: B.Budget & Scalars.ScalarChunk & Bytes.OwnedBytes & EncodeProgress) -> B.Budget & Scalars.ScalarChunk & Bytes.OwnedBytes & EncodeProgress:
  match fuel:
    case 0n: p
    case 1n+rest:
      (budget,input,output,progress) = p
      match progress:
        case EncodeProgress{state,index,produced,3}: encode_loop(rest,kind,size,encode_one(kind,budget,input,output,state,index,produced,size))
        case EncodeProgress{state,index,produced,status}: (budget,input,output,EncodeProgress{state,index,produced,status})

def encode_valid(+kind: U32, budget: B.Budget, input: Scalars.ScalarChunk, output: Bytes.OwnedBytes, state: EncodeState, +start: U32, +size: U32, valid: Bool) -> B.Budget & Scalars.ScalarChunk & Bytes.OwnedBytes & EncodeProgress:
  match valid:
    case False{}: (budget,input,output,EncodeProgress{EncodeBroken{E.Bounds{start,0,size}},start,0,2})
    case True{}: encode_loop(U32.to_nat(U32.inc(U32.sub(size,start))),kind,size,(budget,input,output,EncodeProgress{state,start,0,3}))

def encode_input(kind: U32, budget: B.Budget, output: Bytes.OwnedBytes, state: EncodeState, +start: U32, p: Scalars.ScalarChunk & U32 & U32 & U32 & U32) -> B.Budget & Scalars.ScalarChunk & Bytes.OwnedBytes & EncodeProgress:
  (input,size0,capacity,run,origin) = p
  +size = {size0: U32}
  encode_valid(kind,budget,input,output,state,start,size,U32.is_le(start,size))

def encode(kind: U32, budget: B.Budget, input: Scalars.ScalarChunk, output: Bytes.OwnedBytes, state: EncodeState, start: U32) -> B.Budget & Scalars.ScalarChunk & Bytes.OwnedBytes & EncodeProgress:
  encode_input(kind,budget,output,state,start,Scalars.metadata(input))

def encoder_init() -> EncodeState:
  EncodeReady{}
