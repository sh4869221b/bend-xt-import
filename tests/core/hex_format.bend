# Normative cost: source initialization32 + fixture writes32 + destination
# initialization64 + 32 reads + 64 writes =224; ASCII verification adds64.
# Literal expected ASCII covers every nibble, including 00 and ff.
import Base
import ../../core/error.bend as E
import ../../core/budget.bend as B
import ../../core/bytes.bend as Bytes
import ./lib/buffer_assert.bend as A

import ../../hash/hex.bend as Hex

def fill(values: List<U32>, +index: U32, p: B.Budget & Bytes.OwnedBytes) -> IO(B.Budget & Bytes.OwnedBytes):
  match values:
    case Nil{}: IO.pure(B.Budget & Bytes.OwnedBytes,p)
    case value <> tail:
      (budget,bytes) = p
      do IO<B.Budget & Bytes.OwnedBytes>:
        next : B.Budget & Bytes.OwnedBytes <- A.changed(Bytes.put(budget,bytes,index,value))
        fill(tail,U32.inc(index),next)

def verify(chars: String, +index: U32, p: B.Budget & Bytes.OwnedBytes) -> IO(B.Budget & Bytes.OwnedBytes):
  match chars:
    case SNil{}: IO.pure(B.Budget & Bytes.OwnedBytes,p)
    case SCon{Chr{expected},tail}:
      (budget,bytes) = p
      do IO<B.Budget & Bytes.OwnedBytes>:
        next : B.Budget & Bytes.OwnedBytes <- A.read(expected,Bytes.get(budget,bytes,index))
        verify(tail,U32.inc(index),next)

def format32_step_4(sourcem: Bytes.OwnedBytes, p8: B.Budget & Bytes.OwnedBytes) -> IO(Unit):
  (b5,d5) = p8
  do IO<Unit>:
    b6 : B.Budget <- A.dropped(Bytes.drop(b5,d5))
    b7 : B.Budget <- A.usage(B.Six{0,0,0,0,135168,288},B.zero(),B.inspect(b6))
    end : B.Budget <- A.dropped(Bytes.drop(b7,sourcem))
    A.finished("hex-32-raw-to-64-lowercase-ascii",B.Six{0,0,0,0,0,288},B.finish(end))

def format32_step_3(p4: B.Budget & Bytes.OwnedBytes & Bytes.OwnedBytes) -> IO(Unit):
  (b3,source,dest) = p4
  do IO<Unit>:
    sourcem : Bytes.OwnedBytes <- A.metadata(32,32,1,1,Bytes.metadata(source))
    destm : Bytes.OwnedBytes <- A.metadata(64,64,1,2,Bytes.metadata(dest))
    b4 : B.Budget <- A.usage(B.Six{0,0,0,0,204800,224},B.zero(),B.inspect(b3))
    p8 : B.Budget & Bytes.OwnedBytes <- verify("00112233445566778899aabbccddeeff000102030405060708090a0b0c0d0e0f",0,(b4,destm))
    format32_step_4(sourcem,p8)

def format32_step_2(p3: B.Budget & Bytes.OwnedBytes) -> IO(Unit):
  (b2,x2) = p3
  do IO<Unit>:
    p4 : B.Budget & Bytes.OwnedBytes & Bytes.OwnedBytes <- A.copy_done(Hex.format(b2,x2))
    format32_step_3(p4)

def format32_step_1(p2: B.Budget & Bytes.OwnedBytes) -> IO(Unit):
  (b1,x1) = p2
  do IO<Unit>:
    p3 : B.Budget & Bytes.OwnedBytes <- fill(0 <> 17 <> 34 <> 51 <> 68 <> 85 <> 102 <> 119 <> 136 <> 153 <> 170 <> 187 <> 204 <> 221 <> 238 <> 255 <> 0 <> 1 <> 2 <> 3 <> 4 <> 5 <> 6 <> 7 <> 8 <> 9 <> 10 <> 11 <> 12 <> 13 <> 14 <> 15 <> Nil{},0,(b1,x1))
    format32_step_2(p3)

def format32() -> IO(Unit):
  do IO<Unit>:
    b0 : B.Budget <- A.start(B.start(1,B.Six{0,0,0,0,204800,288}))
    p2 : B.Budget & Bytes.OwnedBytes <- A.created(Bytes.new(b0,32))
    format32_step_1(p2)

def reject_length_step_2(+length: U32, +capacity: U32, p3: B.Budget & Bytes.OwnedBytes) -> IO(Unit):
  (b2,x2) = p3
  do IO<Unit>:
    x2m : Bytes.OwnedBytes <- A.metadata(length,capacity,1,1,Bytes.metadata(x2))
    b3 : B.Budget <- A.usage(B.Six{0,0,0,0,135168,capacity},B.zero(),B.inspect(b2))
    end : B.Budget <- A.dropped(Bytes.drop(b3,x2m))
    A.finished("hex-non32-preflight-no-allocation",B.Six{0,0,0,0,0,capacity},B.finish(end))

def reject_length_step_1(+length: U32, +capacity: U32, p2: B.Budget & Bytes.OwnedBytes) -> IO(Unit):
  (b1,x1) = p2
  do IO<Unit>:
    p3 : B.Budget & Bytes.OwnedBytes <- A.copy_failed(E.Bounds{0,length,32},Hex.format(b1,x1))
    reject_length_step_2(length,capacity,p3)

def reject_length(+length: U32, +capacity: U32) -> IO(Unit):
  do IO<Unit>:
    b0 : B.Budget <- A.start(B.start(1,B.Six{0,0,0,0,135168,capacity}))
    p2 : B.Budget & Bytes.OwnedBytes <- A.created(Bytes.new(b0,length))
    reject_length_step_1(length,capacity,p2)

def partial_format_step_8(+edge: U32, s7: Bytes.OwnedBytes, p13: B.Budget & Bytes.OwnedBytes) -> IO(Unit):
  (b10,d10) = p13
  do IO<Unit>:
    b11 : B.Budget <- A.dropped(Bytes.drop(b10,d10))
    end : B.Budget <- A.dropped(Bytes.drop(b11,s7))
    A.finished("hex-partial-owner-content-work",B.Six{0,0,0,0,0,U32.add(edge,4)},B.finish(end))

def partial_format_step_7(+edge: U32, s7: Bytes.OwnedBytes, p12: B.Budget & Bytes.OwnedBytes) -> IO(Unit):
  (b9,d9) = p12
  do IO<Unit>:
    p13 : B.Budget & Bytes.OwnedBytes <- A.read(0,Bytes.get(b9,d9,2))
    partial_format_step_8(edge,s7,p13)

def partial_format_step_6(+edge: U32, +low: U32, s7: Bytes.OwnedBytes, p11: B.Budget & Bytes.OwnedBytes) -> IO(Unit):
  (b8,d8) = p11
  do IO<Unit>:
    p12 : B.Budget & Bytes.OwnedBytes <- A.read(low,Bytes.get(b8,d8,1))
    partial_format_step_7(edge,s7,p12)

def partial_format_step_5(+edge: U32, +high: U32, +low: U32, destm: Bytes.OwnedBytes, p10: B.Budget & Bytes.OwnedBytes) -> IO(Unit):
  (b7,s7) = p10
  do IO<Unit>:
    p11 : B.Budget & Bytes.OwnedBytes <- A.read(high,Bytes.get(b7,destm,0))
    partial_format_step_6(edge,low,s7,p11)

def partial_format_step_4(+edge: U32, +high: U32, +low: U32, ticket: B.Reservation, p5: B.Budget & Bytes.OwnedBytes & Bytes.OwnedBytes) -> IO(Unit):
  (b4,source,dest) = p5
  do IO<Unit>:
    sourcem : Bytes.OwnedBytes <- A.metadata(32,32,1,1,Bytes.metadata(source))
    destm : Bytes.OwnedBytes <- A.metadata(64,64,1,3,Bytes.metadata(dest))
    b5 : B.Budget <- A.usage(B.Six{0,0,0,0,204800,edge},B.Six{0,0,0,0,4096,4},B.inspect(b4))
    b6 : B.Budget <- A.cancelled(B.cancel(b5,ticket))
    p10 : B.Budget & Bytes.OwnedBytes <- A.read(171,Bytes.get(b6,sourcem,0))
    partial_format_step_5(edge,high,low,destm,p10)

def partial_format_step_3(+edge: U32, +high: U32, +low: U32, x2: Bytes.OwnedBytes, p4: B.Budget & B.Reservation) -> IO(Unit):
  (b3,ticket) = p4
  do IO<Unit>:
    p5 : B.Budget & Bytes.OwnedBytes & Bytes.OwnedBytes <- A.copy_partial(E.ResourceLimit{5,U32.add(edge,4),U32.add(edge,4),1},Hex.format(b3,x2))
    partial_format_step_4(edge,high,low,ticket,p5)

def partial_format_step_2(+edge: U32, +high: U32, +low: U32, p3: B.Budget & Bytes.OwnedBytes) -> IO(Unit):
  (b2,x2) = p3
  do IO<Unit>:
    p4 : B.Budget & B.Reservation <- A.reserved(B.reserve_many(b2,B.work(4)))
    partial_format_step_3(edge,high,low,x2,p4)

def partial_format_step_1(+edge: U32, +high: U32, +low: U32, p2: B.Budget & Bytes.OwnedBytes) -> IO(Unit):
  (b1,x1) = p2
  do IO<Unit>:
    p3 : B.Budget & Bytes.OwnedBytes <- A.changed(Bytes.put(b1,x1,0,171))
    partial_format_step_2(edge,high,low,p3)

def partial_format(+edge: U32, high: U32, low: U32) -> IO(Unit):
  do IO<Unit>:
    b0 : B.Budget <- A.start(B.start(1,B.Six{0,0,0,0,208896,U32.add(edge,4)}))
    p2 : B.Budget & Bytes.OwnedBytes <- A.created(Bytes.new(b0,32))
    partial_format_step_1(edge,high,low,p2)

def main() -> IO(Unit):
  do IO<Unit>:
    format32()
    reject_length(0,1)
    reject_length(1,1)
    reject_length(31,32)
    reject_length(33,64)
    partial_format(97,0,0)
    partial_format(98,0,0)
    partial_format(99,97,0)
    partial_format(100,97,98)
    IO.print("hex-format-ok")
