# Test-only bounded source generator. No source String, file, or byte list.
import Base
import ../../core/budget.bend as B
import ../../core/error.bend as E
import ../../core/bytes.bend as Bytes
import ../../core/cursor.bend as C
import ../../xml/types.bend as X
import ../../xml/numbers.bend as N
import ../../xml/reader.bend as R
import ./driver.bend as D

type Profile is Data:
  Profile{total: U32, payload: U32, width: U32, count: U32, entrySize: U32, suffixStart: U32, suffixEnd: U32}

def prefix_length() -> U32:
  118

def prefix_byte(index: U32) -> U32:
  match index:
    case 0: 60
    case 1: 83
    case 2: 83
    case 3: 84
    case 4: 88
    case 5: 77
    case 6: 76
    case 7: 82
    case 8: 101
    case 9: 115
    case 10: 115
    case 11: 111
    case 12: 117
    case 13: 114
    case 14: 99
    case 15: 101
    case 16: 115
    case 17: 62
    case 18: 60
    case 19: 80
    case 20: 97
    case 21: 114
    case 22: 97
    case 23: 109
    case 24: 115
    case 25: 62
    case 26: 60
    case 27: 65
    case 28: 100
    case 29: 100
    case 30: 111
    case 31: 110
    case 32: 62
    case 33: 65
    case 34: 46
    case 35: 101
    case 36: 115
    case 37: 112
    case 38: 60
    case 39: 47
    case 40: 65
    case 41: 100
    case 42: 100
    case 43: 111
    case 44: 110
    case 45: 62
    case 46: 60
    case 47: 83
    case 48: 111
    case 49: 117
    case 50: 114
    case 51: 99
    case 52: 101
    case 53: 62
    case 54: 101
    case 55: 110
    case 56: 60
    case 57: 47
    case 58: 83
    case 59: 111
    case 60: 117
    case 61: 114
    case 62: 99
    case 63: 101
    case 64: 62
    case 65: 60
    case 66: 68
    case 67: 101
    case 68: 115
    case 69: 116
    case 70: 62
    case 71: 106
    case 72: 97
    case 73: 60
    case 74: 47
    case 75: 68
    case 76: 101
    case 77: 115
    case 78: 116
    case 79: 62
    case 80: 60
    case 81: 86
    case 82: 101
    case 83: 114
    case 84: 115
    case 85: 105
    case 86: 111
    case 87: 110
    case 88: 62
    case 89: 50
    case 90: 60
    case 91: 47
    case 92: 86
    case 93: 101
    case 94: 114
    case 95: 115
    case 96: 105
    case 97: 111
    case 98: 110
    case 99: 62
    case 100: 60
    case 101: 47
    case 102: 80
    case 103: 97
    case 104: 114
    case 105: 97
    case 106: 109
    case 107: 115
    case 108: 62
    case 109: 60
    case 110: 67
    case 111: 111
    case 112: 110
    case 113: 116
    case 114: 101
    case 115: 110
    case 116: 116
    case 117: 62
    case _: 32

def entry_open_length() -> U32:
  59

def entry_open_byte(index: U32) -> U32:
  match index:
    case 0: 60
    case 1: 83
    case 2: 116
    case 3: 114
    case 4: 105
    case 5: 110
    case 6: 103
    case 7: 32
    case 8: 76
    case 9: 105
    case 10: 115
    case 11: 116
    case 12: 61
    case 13: 34
    case 14: 48
    case 15: 34
    case 16: 62
    case 17: 60
    case 18: 69
    case 19: 68
    case 20: 73
    case 21: 68
    case 22: 62
    case 23: 65
    case 24: 60
    case 25: 47
    case 26: 69
    case 27: 68
    case 28: 73
    case 29: 68
    case 30: 62
    case 31: 60
    case 32: 82
    case 33: 69
    case 34: 67
    case 35: 62
    case 36: 87
    case 37: 69
    case 38: 65
    case 39: 80
    case 40: 58
    case 41: 70
    case 42: 85
    case 43: 76
    case 44: 76
    case 45: 60
    case 46: 47
    case 47: 82
    case 48: 69
    case 49: 67
    case 50: 62
    case 51: 60
    case 52: 83
    case 53: 111
    case 54: 117
    case 55: 114
    case 56: 99
    case 57: 101
    case 58: 62
    case _: 32

def entry_close_length() -> U32:
  25

def entry_close_byte(index: U32) -> U32:
  match index:
    case 0: 60
    case 1: 47
    case 2: 83
    case 3: 111
    case 4: 117
    case 5: 114
    case 6: 99
    case 7: 101
    case 8: 62
    case 9: 60
    case 10: 68
    case 11: 101
    case 12: 115
    case 13: 116
    case 14: 47
    case 15: 62
    case 16: 60
    case 17: 47
    case 18: 83
    case 19: 116
    case 20: 114
    case 21: 105
    case 22: 110
    case 23: 103
    case 24: 62
    case _: 32

def suffix_length() -> U32:
  29

def suffix_byte(index: U32) -> U32:
  match index:
    case 0: 60
    case 1: 47
    case 2: 67
    case 3: 111
    case 4: 110
    case 5: 116
    case 6: 101
    case 7: 110
    case 8: 116
    case 9: 62
    case 10: 60
    case 11: 47
    case 12: 83
    case 13: 83
    case 14: 84
    case 15: 88
    case 16: 77
    case 17: 76
    case 18: 82
    case 19: 101
    case 20: 115
    case 21: 115
    case 22: 111
    case 23: 117
    case 24: 114
    case 25: 99
    case 26: 101
    case 27: 115
    case 28: 62
    case _: 32

def unit_japanese(index: U32) -> U32:
  match index:
    case 0: 230
    case 1: 151
    case _: 165

def unit_nonbmp(index: U32) -> U32:
  match index:
    case 0: 240
    case 1: 159
    case 2: 152
    case _: 128

def unit_byte(width: U32, index: U32) -> U32:
  match width:
    case 1: 97
    case 3: unit_japanese(index)
    case _: unit_nonbmp(index)

def payload_or_close(+payload: U32, +width: U32, +offset: U32, inside: Bool) -> U32:
  match inside:
    case True{}: unit_byte(width,U32.mod(offset,width))
    case False{}: entry_close_byte(U32.sub(offset,payload))

def entry_byte(+payload: U32, width: U32, +offset: U32, opening: Bool) -> U32:
  match opening:
    case True{}: entry_open_byte(offset)
    case False{}:
      +inside = {U32.sub(offset,entry_open_length()): U32}
      payload_or_close(payload,width,inside,U32.is_lt(inside,payload))

def suffix_or_padding(suffixStart: U32, offset: U32, inside: Bool) -> U32:
  match inside:
    case True{}: suffix_byte(U32.sub(offset,suffixStart))
    case False{}: 32

def entry_or_suffix(payload: U32, width: U32, entrySize: U32, suffixStart: U32, suffixEnd: U32, +offset: U32, inEntry: Bool) -> U32:
  match inEntry:
    case True{}:
      +local = {U32.mod(U32.sub(offset,prefix_length()),entrySize): U32}
      entry_byte(payload,width,local,U32.is_lt(local,entry_open_length()))
    case False{}: suffix_or_padding(suffixStart,offset,U32.is_lt(offset,suffixEnd))

def source_byte(profile: Profile, +offset: U32, inPrefix: Bool) -> U32:
  match profile:
    case Profile{total,payload,width,count,entrySize,+suffixStart,suffixEnd}:
      match inPrefix:
        case True{}: prefix_byte(offset)
        case False{}: entry_or_suffix(payload,width,entrySize,suffixStart,suffixEnd,offset,U32.is_lt(offset,suffixStart))

def generated_byte(profile: Profile, +offset: U32) -> U32:
  source_byte(profile,offset,U32.is_lt(offset,prefix_length()))

def generated_write(profile: Profile, budget: B.Budget, reader: R.Reader, bytes: Bytes.OwnedBytes, rest: String, +p: D.Progress, done: Bool) -> D.Running:
  match done:
    case True{}: D.Run{D.Harness{budget,Some{reader},Some{bytes},None{},None{},None{},rest,D.set_phase(p,2)}}
    case False{}: D.Run{D.written(reader,rest,p,Bytes.put(budget,bytes,D.get_fill(p),generated_byte(profile,U32.add(D.get_start(p),D.get_fill(p)))))}

# Only phase 1 differs from the small-corpus driver. Every owning branch is
# reconstructed or passed to the shared lifecycle, never copied or abandoned.
def step(profile: Profile, harness: D.Harness) -> D.Running:
  match harness:
    case D.Harness{budget,Some{reader},Some{bytes},None{},None{},None{},rest,+p}:
      match p:
        case D.Progress{length,size,start,end,fill,digest,count,1,after,error}: generated_write(profile,budget,reader,bytes,rest,p,U32.is_eq(fill,U32.sub(end,start)))
        case _: D.step(D.Harness{budget,Some{reader},Some{bytes},None{},None{},None{},rest,p})
    case other: D.step(other)

def loop(fuel: Nat, +profile: Profile, running: D.Running) -> D.Harness:
  match fuel running:
    case _ D.Stop{harness}: harness
    case 0n D.Run{harness}: harness
    case 1n+left D.Run{harness}: loop(left,profile,step(profile,harness))

def began(+profile: Profile, +p: D.Progress, pair: B.Budget & R.BeginResult) -> IO(Unit):
  (budget,result) = pair
  match result:
    case R.ReaderReady{reader}: D.checked(loop(U32.to_nat(U32.add(U32.mul(D.get_length(p),8),1000)),profile,D.Run{D.Harness{budget,Some{reader},None{},None{},None{},None{},"",p}}))
    case R.ReaderInitFailed{error,residual}: D.checked(loop(100n,profile,D.Run{D.Harness{budget,residual,None{},None{},None{},None{},"",D.reject(p,error)}}))

def charged(profile: Profile, +p: D.Progress, pair: B.Budget & Result<&2,&2,E.Error,Unit>) -> IO(Unit):
  (budget,result) = pair
  match result:
    case Done{u}: began(profile,p,R.begin(budget,C.Range{1,42,0,D.get_length(p)},X.defaults()))
    case Fail{error}: D.budget_finished(D.set_phase(D.reject(p,X.core_error(5,5,X.zero_position(),error)),9),B.finish(budget))

def started(profile: Profile, +p: D.Progress, result: Result<&2,&1,E.Error,B.Budget>) -> IO(Unit):
  match result:
    case Done{budget}: charged(profile,p,B.consume(budget,B.Six{D.get_length(p),0,0,0,0,0}))
    case Fail{error}: IO.die(Unit,70,"stream budget start failed")

def launch(+profile: Profile) -> IO(Unit):
  match profile:
    case Profile{total,payload,width,count,entrySize,suffixStart,suffixEnd}:
      started(profile,D.Progress{total,65536,0,0,0,2166136261,0,0,0,None{}},B.start(1,D.budget_defaults()))

def profile_count(+total: U32, payload: U32, width: U32, +entrySize: U32, +count: U32) -> Profile:
  +suffixStart = {U32.add(prefix_length(),U32.mul(count,entrySize)): U32}
  Profile{total,payload,width,count,entrySize,suffixStart,U32.add(suffixStart,suffix_length())}

def profile_size(+total: U32, payload: U32, width: U32, +entrySize: U32) -> Profile:
  profile_count(total,payload,width,entrySize,U32.min(200000,U32.div(U32.sub(total,U32.add(prefix_length(),suffix_length())),entrySize)))

def make_profile(total: U32, +payload: U32, width: U32) -> Profile:
  profile_size(total,payload,width,U32.add(payload,U32.add(entry_open_length(),entry_close_length())))

def bounded(total: U32, payload: U32, width: U32, okay: Bool) -> IO(Unit):
  match okay:
    case False{}: IO.die(Unit,64,"stream size/payload bounds or UTF-8 divisibility invalid")
    case True{}: launch(make_profile(total,payload,width))

def width_checked(+total: U32, +payload: U32, +width: U32, okay: Bool) -> IO(Unit):
  match okay:
    case False{}: IO.die(Unit,64,"UTF-8 mode must be 1, 3, or 4")
    case True{}: bounded(total,payload,width,Bool.and(Bool.and(U32.is_ge(total,U32.add(prefix_length(),suffix_length())),U32.is_le(total,67108864)),Bool.and(U32.is_le(payload,1048565),U32.is_zero(U32.mod(payload,width)))))

def width_parsed(total: U32, payload: U32, result: Result<&2,&2,U32,U32>) -> IO(Unit):
  match result:
    case Fail{reason}: IO.die(Unit,64,"invalid UTF-8 mode")
    case Done{+width}: width_checked(total,payload,width,Bool.or(U32.is_eq(width,1),Bool.or(U32.is_eq(width,3),U32.is_eq(width,4))))

def payload_parsed(total: U32, width: String, result: Result<&2,&2,U32,U32>) -> IO(Unit):
  match result:
    case Fail{reason}: IO.die(Unit,64,"invalid payload byte count")
    case Done{payload}: width_parsed(total,payload,D.uint_number(width,N.begin(False{})))

def total_parsed(payload: String, width: String, result: Result<&2,&2,U32,U32>) -> IO(Unit):
  match result:
    case Fail{reason}: IO.die(Unit,64,"invalid total byte count")
    case Done{total}: payload_parsed(total,width,D.uint_number(payload,N.begin(False{})))

def command(args: List<String>) -> IO(Unit):
  match args:
    case _ <> total <> payload <> width <> Nil{}: total_parsed(payload,width,D.uint_number(total,N.begin(False{})))
    case _: IO.die(Unit,64,"usage: XML_STREAM TOTAL_BYTES PAYLOAD_BYTES UTF8_MODE")

def main() -> IO(Unit):
  do IO<Unit>:
    args : List<String> <- IO.args()
    command(args)
