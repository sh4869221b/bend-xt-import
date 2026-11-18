import Base
import ./types.bend as T

# Closed vocabulary, represented by a fixed 26-bit candidate mask.
type Name is Data:
  Name{mask: U32, length: U32, at: T.Position}

def char(+id: U32, +index: U32) -> U32:
  match id index:
    case 0 0: 83
    case 0 1: 83
    case 0 2: 84
    case 0 3: 88
    case 0 4: 77
    case 0 5: 76
    case 0 6: 82
    case 0 7: 101
    case 0 8: 115
    case 0 9: 115
    case 0 10: 111
    case 0 11: 117
    case 0 12: 114
    case 0 13: 99
    case 0 14: 101
    case 0 15: 115
    case 1 0: 80
    case 1 1: 97
    case 1 2: 114
    case 1 3: 97
    case 1 4: 109
    case 1 5: 115
    case 2 0: 65
    case 2 1: 100
    case 2 2: 100
    case 2 3: 111
    case 2 4: 110
    case 3 0: 83
    case 3 1: 111
    case 3 2: 117
    case 3 3: 114
    case 3 4: 99
    case 3 5: 101
    case 4 0: 68
    case 4 1: 101
    case 4 2: 115
    case 4 3: 116
    case 5 0: 86
    case 5 1: 101
    case 5 2: 114
    case 5 3: 115
    case 5 4: 105
    case 5 5: 111
    case 5 6: 110
    case 6 0: 67
    case 6 1: 111
    case 6 2: 110
    case 6 3: 116
    case 6 4: 101
    case 6 5: 110
    case 6 6: 116
    case 7 0: 83
    case 7 1: 116
    case 7 2: 114
    case 7 3: 105
    case 7 4: 110
    case 7 5: 103
    case 8 0: 69
    case 8 1: 68
    case 8 2: 73
    case 8 3: 68
    case 9 0: 82
    case 9 1: 69
    case 9 2: 67
    case 10 0: 70
    case 10 1: 117
    case 10 2: 122
    case 10 3: 73
    case 10 4: 110
    case 10 5: 102
    case 10 6: 111
    case 11 0: 114
    case 11 1: 101
    case 11 2: 115
    case 11 3: 112
    case 11 4: 111
    case 11 5: 110
    case 11 6: 115
    case 11 7: 101
    case 11 8: 73
    case 11 9: 100
    case 12 0: 70
    case 12 1: 117
    case 12 2: 122
    case 13 0: 76
    case 13 1: 105
    case 13 2: 115
    case 13 3: 116
    case 14 0: 80
    case 14 1: 97
    case 14 2: 114
    case 14 3: 116
    case 14 4: 105
    case 14 5: 97
    case 14 6: 108
    case 15 0: 115
    case 15 1: 73
    case 15 2: 68
    case 16 0: 105
    case 16 1: 100
    case 17 0: 105
    case 17 1: 100
    case 17 2: 77
    case 17 3: 97
    case 17 4: 120
    case 18 0: 118
    case 18 1: 101
    case 18 2: 114
    case 18 3: 115
    case 18 4: 105
    case 18 5: 111
    case 18 6: 110
    case 19 0: 101
    case 19 1: 110
    case 19 2: 99
    case 19 3: 111
    case 19 4: 100
    case 19 5: 105
    case 19 6: 110
    case 19 7: 103
    case 20 0: 115
    case 20 1: 116
    case 20 2: 97
    case 20 3: 110
    case 20 4: 100
    case 20 5: 97
    case 20 6: 108
    case 20 7: 111
    case 20 8: 110
    case 20 9: 101
    case 21 0: 97
    case 21 1: 109
    case 21 2: 112
    case 22 0: 108
    case 22 1: 116
    case 23 0: 103
    case 23 1: 116
    case 24 0: 97
    case 24 1: 112
    case 24 2: 111
    case 24 3: 115
    case 25 0: 113
    case 25 1: 117
    case 25 2: 111
    case 25 3: 116
    case _ _: 0

def length(+id: U32) -> U32:
  match id:
    case 0: 16
    case 1: 6
    case 2: 5
    case 3: 6
    case 4: 4
    case 5: 7
    case 6: 7
    case 7: 6
    case 8: 4
    case 9: 3
    case 10: 7
    case 11: 10
    case 12: 3
    case 13: 4
    case 14: 7
    case 15: 3
    case 16: 2
    case 17: 5
    case 18: 7
    case 19: 8
    case 20: 10
    case 21: 3
    case 22: 2
    case 23: 2
    case 24: 4
    case 25: 4
    case _: 0

def external(+id: U32) -> U32:
  match id:
    case 0: 1
    case 1: 2
    case 2: 3
    case 3: 4
    case 4: 5
    case 5: 6
    case 6: 7
    case 7: 8
    case 8: 9
    case 9: 10
    case 10: 11
    case 11: 12
    case 12: 13
    case 13: 101
    case 14: 102
    case 15: 103
    case 16: 104
    case 17: 105
    case 18: 201
    case 19: 202
    case 20: 203
    case 21: 301
    case 22: 302
    case 23: 303
    case 24: 304
    case 25: 305
    case _: 0

def chosen(+bit: U32, +found: U32, +yes: Bool) -> U32:
  match yes:
    case True{}: U32.or(bit,found)
    case False{}: found

def scan(+fuel: Nat, +id: U32, +bit: U32, +mask: U32, +index: U32, +value: U32, +found: U32) -> U32:
  match fuel:
    case 0n: found
    case 1n+rest: scan(rest,U32.inc(id),U32.shl(bit),mask,index,value,chosen(bit,found,Bool.and(U32.is_gt(U32.and(mask,bit),0),U32.is_eq(char(id,index),value))))

def pushed(+length: U32, +at: T.Position, +mask: U32) -> Result<&2, &2, U32, Name>:
  match mask:
    case 0: Fail{2}
    case n: Done{Name{n,U32.inc(length),at}}

def push_valid(+mask: U32, +length: U32, +at: T.Position, +value: U32, +valid: Bool) -> Result<&2, &2, U32, Name>:
  match valid:
    case False{}: Fail{7}
    case True{}: pushed(length,at,scan(26n,0,1,mask,length,value,0))

def push(+name: Name, +value: U32, +max: U32) -> Result<&2, &2, U32, Name>:
  match name:
    case Name{+mask,+length,+at}: push_valid(mask,length,at,value,U32.is_lt(length,max))

def select_chosen(+id: U32, +fallback: U32, +yes: Bool) -> U32:
  match yes:
    case True{}: external(id)
    case False{}: fallback

def select(+fuel: Nat, +id: U32, +bit: U32, +mask: U32, +size: U32) -> U32:
  match fuel:
    case 0n: 0
    case 1n+rest: select_chosen(id,select(rest,U32.inc(id),U32.shl(bit),mask,size),Bool.and(U32.is_gt(U32.and(mask,bit),0),U32.is_eq(length(id),size)))

def finish(+name: Name) -> U32:
  match name:
    case Name{+mask,+length,+at}: select(26n,0,1,mask,length)

def start(+mask: U32, +at: T.Position) -> Name:
  Name{mask,0,at}

def position(+name: Name) -> T.Position:
  match name:
    case Name{+mask,+length,+at}: at
