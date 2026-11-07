import Base
import ../core/checked.bend as C
import ../core/error.bend as E
import ./types.bend as T

# Values are decoded XML scalars. XML syntax/reference handling is separate.
# Kind: 0 decimal U32, 1 hexadecimal U32. Failure reasons are stable numeric IDs.
type Number is Data:
  Number{base: U32, value: U32, digits: U32}
  NumberBroken{reason: U32}

def begin(hex: Bool) -> Number:
  match hex:
    case False{}: Number{10,0,0}
    case True{}: Number{16,0,0}

def hex_lower(+value: U32, valid: Bool) -> Maybe<&2, U32>:
  match valid:
    case True{}: Some{U32.sub(value,87)}
    case False{}: None{}

def hex_upper(+value: U32, valid: Bool) -> Maybe<&2, U32>:
  match valid:
    case True{}: Some{U32.sub(value,55)}
    case False{}: hex_lower(value,Bool.and(U32.is_ge(value,97),U32.is_le(value,102)))

def digit_ascii(base: U32, +value: U32, valid: Bool) -> Maybe<&2, U32>:
  match base valid:
    case _ True{}: Some{U32.sub(value,48)}
    case 16 False{}: hex_upper(value,Bool.and(U32.is_ge(value,65),U32.is_le(value,70)))
    case _ False{}: None{}

def digit(base: U32, +value: U32) -> Maybe<&2, U32>:
  digit_ascii(base,value,Bool.and(U32.is_ge(value,48),U32.is_le(value,57)))

def added(base: U32, digits: U32, result: Result<&2, &2, E.Error, U32>) -> Number:
  match result:
    case Fail{error}: NumberBroken{2}
    case Done{value}: Number{base,value,U32.inc(digits)}

def multiplied(base: U32, digits: U32, digit: U32, result: Result<&2, &2, E.Error, U32>) -> Number:
  match result:
    case Fail{error}: NumberBroken{2}
    case Done{value}: added(base,digits,C.add(value,digit))

def found(+base: U32, value: U32, digits: U32, result: Maybe<&2, U32>) -> Number:
  match result:
    case None{}: NumberBroken{1}
    case Some{digit}: multiplied(base,digits,digit,C.mul(value,base))

def push_valid(+base: U32, value: U32, +digits: U32, scalar: U32, valid: Bool) -> Number:
  match valid:
    case False{}: NumberBroken{3}
    case True{}: found(base,value,digits,digit(base,scalar))

def push(number: Number, scalar: U32) -> Number:
  match number:
    case NumberBroken{reason}: NumberBroken{reason}
    case Number{+base,value,+digits}: push_valid(base,value,digits,scalar,U32.is_lt(digits,64))

def finish_valid(value: U32, digits: U32, valid: Bool) -> Result<&2, &2, U32, U32>:
  match valid:
    case True{}: Done{value}
    case False{}: Fail{3}

def finish(number: Number, minDigits: U32, maxDigits: U32, maxValue: U32) -> Result<&2, &2, U32, U32>:
  match number:
    case NumberBroken{reason}: Fail{reason}
    case Number{base,+value,+digits}: finish_valid(value,digits,Bool.and(Bool.and(U32.is_ge(digits,minDigits),U32.is_le(digits,maxDigits)),U32.is_le(value,maxValue)))

def character_valid(value: U32, valid: Bool) -> Result<&2, &2, U32, U32>:
  match valid:
    case False{}: Fail{4}
    case True{}: Done{value}

def character_result(result: Result<&2, &2, U32, U32>) -> Result<&2, &2, U32, U32>:
  match result:
    case Fail{reason}: Fail{reason}
    case Done{+value}: character_valid(value,T.xml_character(value))

def character(number: Number) -> Result<&2, &2, U32, U32>:
  character_result(finish(number,1,64,1114111))
