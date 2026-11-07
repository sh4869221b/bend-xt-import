import Base
import ../core/error.bend as E
import ../core/budget.bend as B
import ../core/bytes.bend as Bytes
import ../core/storage.bend as S
import ../core/charges.bend as Charges

type Words is Data:
  Words{a: U32, b: U32, c: U32, d: U32, e: U32, f: U32, g: U32, h: U32}

type ShaState is Type:
  Sha{words: Words, schedule: Array<U32>, pending: U32, high: U32, low: U32, allocation: B.Allocation}

type FinalResult is Type:
  HashDone{digest: Bytes.OwnedBytes}
  HashFailed{error: E.Error, state: ShaState, digest: Maybe<&1, Bytes.OwnedBytes>}
  ReleaseFailed{error: E.Error, allocation: B.Allocation, digest: Bytes.OwnedBytes}

# Fixed rotations only; all additions in compression are deliberately modular.
def r2(+x: U32) -> U32:
  U32.or(U32.shrn(x,2n),U32.shln(x,30n))
def r13(+x: U32) -> U32:
  U32.or(U32.shrn(x,13n),U32.shln(x,19n))
def r22(+x: U32) -> U32:
  U32.or(U32.shrn(x,22n),U32.shln(x,10n))
def r6(+x: U32) -> U32:
  U32.or(U32.shrn(x,6n),U32.shln(x,26n))
def r11(+x: U32) -> U32:
  U32.or(U32.shrn(x,11n),U32.shln(x,21n))
def r25(+x: U32) -> U32:
  U32.or(U32.shrn(x,25n),U32.shln(x,7n))
def r7(+x: U32) -> U32:
  U32.or(U32.shrn(x,7n),U32.shln(x,25n))
def r18(+x: U32) -> U32:
  U32.or(U32.shrn(x,18n),U32.shln(x,14n))
def r17(+x: U32) -> U32:
  U32.or(U32.shrn(x,17n),U32.shln(x,15n))
def r19(+x: U32) -> U32:
  U32.or(U32.shrn(x,19n),U32.shln(x,13n))
def sigma0(+x: U32) -> U32:
  U32.xor(U32.xor(r2(x),r13(x)),r22(x))
def sigma1(+x: U32) -> U32:
  U32.xor(U32.xor(r6(x),r11(x)),r25(x))
def small0(+x: U32) -> U32:
  U32.xor(U32.xor(r7(x),r18(x)),U32.shrn(x,3n))
def small1(+x: U32) -> U32:
  U32.xor(U32.xor(r17(x),r19(x)),U32.shrn(x,10n))
def choose(+e: U32, f: U32, g: U32) -> U32:
  U32.xor(U32.and(e,f),U32.and(U32.not(e),g))
def majority(+a: U32, +b: U32, +c: U32) -> U32:
  U32.xor(U32.xor(U32.and(a,b),U32.and(a,c)),U32.and(b,c))

def initial() -> Words:
  Words{1779033703,3144134277,1013904242,2773480762,1359893119,2600822924,528734635,1541459225}

def initialized(p: B.Budget & Result<&2, &1, E.Error, B.Allocation>) -> B.Budget & Result<&2, &1, E.Error, ShaState>:
  (budget,result) = p
  match result:
    case Fail{error}: (budget,Fail{error})
    case Done{allocation}: (budget,Done{Sha{initial(),Array.new(U32,6n,0),0,0,0,allocation}})

def init(budget: B.Budget) -> B.Budget & Result<&2, &1, E.Error, ShaState>:
  initialized(B.allocate(budget,Charges.sha_state(),0))

def drop(budget: B.Budget, state: ShaState) -> B.Budget & Result<&1, &2, E.Error & B.Allocation, Unit>:
  match state:
    case Sha{words,schedule,pending,high,low,allocation}: B.release(budget,allocation)

def expand_four(index: U32, a: U32, b: U32, c: U32, p: Array<U32> & U32) -> Array<U32>:
  (schedule,d) = p
  Array.set(U32,schedule,index,U32.add(U32.add(small1(a),b),U32.add(small0(c),d)))

def expand_three(+index: U32, a: U32, b: U32, p: Array<U32> & U32) -> Array<U32>:
  (schedule,c) = p
  expand_four(index,a,b,c,Array.get(U32,schedule,U32.sub(index,16)))

def expand_two(+index: U32, a: U32, p: Array<U32> & U32) -> Array<U32>:
  (schedule,b) = p
  expand_three(index,a,b,Array.get(U32,schedule,U32.sub(index,15)))

def expand_one(+index: U32, p: Array<U32> & U32) -> Array<U32>:
  (schedule,a) = p
  expand_two(index,a,Array.get(U32,schedule,U32.sub(index,7)))

def expand(fuel: Nat, +index: U32, schedule: Array<U32>) -> Array<U32>:
  match fuel:
    case 0n: schedule
    case 1n+rest: expand(rest,U32.inc(index),expand_one(index,Array.get(U32,schedule,U32.sub(index,2))))

def new_words(a: U32, b: U32, c: U32, d: U32, e: U32, f: U32, g: U32, +t1: U32, t2: U32) -> Words:
  Words{U32.add(t1,t2),a,b,c,U32.add(d,t1),e,f,g}

def round_words(words: Words, k: U32, w: U32) -> Words:
  match words:
    case Words{+a,+b,+c,d,+e,+f,+g,h}:
      new_words(a,b,c,d,e,f,g,U32.add(U32.add(U32.add(h,sigma1(e)),choose(e,f,g)),U32.add(k,w)),U32.add(sigma0(a),majority(a,b,c)))

def constant(index: U32) -> U32:
  match index:
    case 0: 1116352408
    case 1: 1899447441
    case 2: 3049323471
    case 3: 3921009573
    case 4: 961987163
    case 5: 1508970993
    case 6: 2453635748
    case 7: 2870763221
    case 8: 3624381080
    case 9: 310598401
    case 10: 607225278
    case 11: 1426881987
    case 12: 1925078388
    case 13: 2162078206
    case 14: 2614888103
    case 15: 3248222580
    case 16: 3835390401
    case 17: 4022224774
    case 18: 264347078
    case 19: 604807628
    case 20: 770255983
    case 21: 1249150122
    case 22: 1555081692
    case 23: 1996064986
    case 24: 2554220882
    case 25: 2821834349
    case 26: 2952996808
    case 27: 3210313671
    case 28: 3336571891
    case 29: 3584528711
    case 30: 113926993
    case 31: 338241895
    case 32: 666307205
    case 33: 773529912
    case 34: 1294757372
    case 35: 1396182291
    case 36: 1695183700
    case 37: 1986661051
    case 38: 2177026350
    case 39: 2456956037
    case 40: 2730485921
    case 41: 2820302411
    case 42: 3259730800
    case 43: 3345764771
    case 44: 3516065817
    case 45: 3600352804
    case 46: 4094571909
    case 47: 275423344
    case 48: 430227734
    case 49: 506948616
    case 50: 659060556
    case 51: 883997877
    case 52: 958139571
    case 53: 1322822218
    case 54: 1537002063
    case 55: 1747873779
    case 56: 1955562222
    case 57: 2024104815
    case 58: 2227730452
    case 59: 2361852424
    case 60: 2428436474
    case 61: 2756734187
    case 62: 3204031479
    case 63: 3329325298
    case _: 0
def round(words: Words, index: U32, p: Array<U32> & U32) -> Array<U32> & Words:
  (schedule,w) = p
  (schedule,round_words(words,constant(index),w))

def rounds(fuel: Nat, +index: U32, p: Array<U32> & Words) -> Array<U32> & Words:
  match fuel:
    case 0n: p
    case 1n+rest:
      (schedule,words) = p
      rounds(rest,U32.inc(index),round(words,index,Array.get(U32,schedule,index)))

def add_words(a: Words, b: Words) -> Words:
  match a b:
    case Words{a,b,c,d,e,f,g,h} Words{i,j,k,l,m,n,o,p}:
      Words{U32.add(a,i),U32.add(b,j),U32.add(c,k),U32.add(d,l),U32.add(e,m),U32.add(f,n),U32.add(g,o),U32.add(h,p)}

def compressed(original: Words, p: Array<U32> & Words) -> Words & Array<U32>:
  (schedule,words) = p
  (add_words(original,words),schedule)

def compress(+words: Words, schedule: Array<U32>) -> Words & Array<U32>:
  compressed(words,rounds(64n,0,(expand(48n,16,schedule),words)))

def append_compressed(high: U32, low: U32, allocation: B.Allocation, p: Words & Array<U32>) -> ShaState:
  (words,schedule) = p
  Sha{words,schedule,0,high,low,allocation}

def append_block(words: Words, schedule: Array<U32>, pending: U32, high: U32, low: U32, allocation: B.Allocation, full: Bool) -> ShaState:
  match full:
    case True{}: append_compressed(high,low,allocation,compress(words,schedule))
    case False{}: Sha{words,schedule,pending,high,low,allocation}

def append_word(words: Words, +pending: U32, high: U32, low: U32, allocation: B.Allocation, byte: U32, p: Array<U32> & U32) -> ShaState:
  (schedule,old) = p
  append_block(words,Array.set(U32,schedule,U32.shrn(pending,2n),U32.or(U32.shln(old,8n),byte)),U32.inc(pending),high,low,allocation,U32.is_eq(pending,63))

# Internal block bytes (including padding) are bounded fixed-cost arithmetic.
def append_internal(state: ShaState, byte: U32) -> ShaState:
  match state:
    case Sha{words,schedule,+pending,high,low,allocation}:
      append_word(words,pending,high,low,allocation,byte,Array.get(U32,schedule,U32.shrn(pending,2n)))

def increment_high(high: U32, carry: Bool) -> U32:
  match carry:
    case False{}: high
    case True{}: U32.inc(high)

def update_byte(state: ShaState, byte: U32) -> ShaState:
  match state:
    case Sha{words,schedule,pending,high,+low,allocation}:
      append_internal(Sha{words,schedule,pending,increment_high(high,U32.is_eq(low,4294967295)),U32.inc(low),allocation},byte)

def updated_byte(state: ShaState, p: B.Budget & Bytes.OwnedBytes & Result<&2, &2, E.Error, U32>) -> B.Budget & Bytes.OwnedBytes & ShaState & Result<&2, &2, E.Error, Unit>:
  (budget,bytes,result) = p
  match result:
    case Fail{error}: (budget,bytes,state,Fail{error})
    case Done{byte}: (budget,bytes,update_byte(state,byte),Done{Unit{}})

def update_loop(fuel: Nat, +index: U32, p: B.Budget & Bytes.OwnedBytes & ShaState & Result<&2, &2, E.Error, Unit>) -> B.Budget & Bytes.OwnedBytes & ShaState & Result<&2, &2, E.Error, Unit>:
  match fuel:
    case 0n: p
    case 1n+rest:
      (budget,bytes,state,result) = p
      match result:
        case Fail{error}: (budget,bytes,state,Fail{error})
        case Done{u}: update_loop(rest,U32.inc(index),updated_byte(state,Bytes.get(budget,bytes,index)))

def update_valid(budget: B.Budget, bytes: Bytes.OwnedBytes, state: ShaState, index: U32, length: U32, size: U32, valid: Bool) -> B.Budget & Bytes.OwnedBytes & ShaState & Result<&2, &2, E.Error, Unit>:
  match valid:
    case False{}: (budget,bytes,state,Fail{E.Bounds{index,length,size}})
    case True{}: update_loop(U32.to_nat(length),index,(budget,bytes,state,Done{Unit{}}))

def length_valid(+high: U32, low: U32, n: U32) -> Bool:
  Bool.and(U32.is_le(high,536870911),Bool.or(U32.is_lt(high,536870911),U32.is_le(n,U32.sub(4294967295,low))))

def update_length(budget: B.Budget, bytes: Bytes.OwnedBytes, state: ShaState, index: U32, length: U32, size: U32, high: U32, low: U32, length_ok: Bool, range_ok: Bool) -> B.Budget & Bytes.OwnedBytes & ShaState & Result<&2, &2, E.Error, Unit>:
  match length_ok:
    case False{}: (budget,bytes,state,Fail{E.Overflow{3,high,low}})
    case True{}: update_valid(budget,bytes,state,index,length,size,range_ok)
def update_range(budget: B.Budget, bytes: Bytes.OwnedBytes, state: ShaState, +index: U32, +length: U32, +size: U32, valid: Bool) -> B.Budget & Bytes.OwnedBytes & ShaState & Result<&2, &2, E.Error, Unit>:
  match state valid:
    case state False{}: (budget,bytes,state,Fail{E.Bounds{index,length,size}})
    case Sha{words,schedule,pending,+high,+low,allocation} True{}:
      update_length(budget,bytes,Sha{words,schedule,pending,high,low,allocation},index,length,size,high,low,length_valid(high,low,length),U32.is_le(length,U32.sub(size,index)))

def update_meta(budget: B.Budget, state: ShaState, +index: U32, length: U32, p: Bytes.OwnedBytes & U32 & U32 & U32 & U32) -> B.Budget & Bytes.OwnedBytes & ShaState & Result<&2, &2, E.Error, Unit>:
  (bytes,size0,capacity,run,origin) = p
  +size = {size0: U32}
  update_range(budget,bytes,state,index,length,size,U32.is_le(index,size))

def update(budget: B.Budget, state: ShaState, bytes: Bytes.OwnedBytes, index: U32, length: U32) -> B.Budget & Bytes.OwnedBytes & ShaState & Result<&2, &2, E.Error, Unit>:
  update_meta(budget,state,index,length,Bytes.metadata(bytes))


def zeros(fuel: Nat, state: ShaState) -> ShaState:
  match fuel:
    case 0n: state
    case 1n+rest: zeros(rest,append_internal(state,0))

def pad_count(pending: U32, small: Bool) -> U32:
  match small:
    case True{}: U32.sub(55,pending)
    case False{}: U32.sub(119,pending)

def length_word(state: ShaState, +word: U32) -> ShaState:
  append_internal(append_internal(append_internal(append_internal(state,U32.shrn(word,24n)),U32.and(U32.shrn(word,16n),255)),U32.and(U32.shrn(word,8n),255)),U32.and(word,255))

def padded(state: ShaState) -> ShaState:
  match state:
    case Sha{words,schedule,+pending,+high,+low,allocation}:
      length_word(length_word(zeros(U32.to_nat(pad_count(pending,U32.is_le(pending,55))),append_internal(Sha{words,schedule,pending,high,low,allocation},128)),U32.or(U32.shln(high,3n),U32.shrn(low,29n))),U32.shln(low,3n))

# Call only after allocating 32 bytes and charging all 32 writes.
def digest_word(data: Array<U32>, +index: U32, +word: U32) -> Array<U32>:
  Array.set(U32,Array.set(U32,Array.set(U32,Array.set(U32,data,index,U32.shrn(word,24n)),U32.add(index,1),U32.and(U32.shrn(word,16n),255)),U32.add(index,2),U32.and(U32.shrn(word,8n),255)),U32.add(index,3),U32.and(word,255))

def digest_array(words: Words, data: Array<U32>) -> Array<U32>:
  match words:
    case Words{a,b,c,d,e,f,g,h}:
      digest_word(digest_word(digest_word(digest_word(digest_word(digest_word(digest_word(digest_word(data,0,a),4,b),8,c),12,d),16,e),20,f),24,g),28,h)

def digest_write(words: Words, bytes: Bytes.OwnedBytes) -> Bytes.OwnedBytes:
  match bytes:
    case Bytes.Bytes{S.Storage{data,length,capacity,run,origin,allocation}}:
      Bytes.Bytes{S.Storage{digest_array(words,data),length,capacity,run,origin,allocation}}

def released_digest(digest: Bytes.OwnedBytes, p: B.Budget & Result<&1, &2, E.Error & B.Allocation, Unit>) -> B.Budget & FinalResult:
  (budget,result) = p
  match result:
    case Done{u}: (budget,HashDone{digest})
    case Fail{pair}:
      (error,allocation) = pair
      (budget,ReleaseFailed{error,allocation,digest})

def final_padded(budget: B.Budget, state: ShaState, digest: Bytes.OwnedBytes) -> B.Budget & FinalResult:
  match state:
    case Sha{words,schedule,pending,high,low,allocation}:
      released_digest(digest_write(words,digest),B.release(budget,allocation))

def final_charged(state: ShaState, digest: Bytes.OwnedBytes, p: B.Budget & Result<&2, &2, E.Error, Unit>) -> B.Budget & FinalResult:
  (budget,result) = p
  match result:
    case Fail{error}: (budget,HashFailed{error,state,Some{digest}})
    case Done{u}: final_padded(budget,padded(state),digest)

def final_allocated(state: ShaState, p: B.Budget & Result<&2, &1, E.Error, Bytes.OwnedBytes>) -> B.Budget & FinalResult:
  (budget,result) = p
  match result:
    case Fail{error}: (budget,HashFailed{error,state,None{}})
    case Done{digest}: final_charged(state,digest,B.consume(budget,B.work(32)))

def finalize(budget: B.Budget, state: ShaState) -> B.Budget & FinalResult:
  final_allocated(state,Bytes.new(budget,32))
