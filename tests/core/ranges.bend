import Base
import ../../core/error.bend as E
import ../../core/cursor.bend as C

def assert(ok: Bool) -> IO(Unit):
  match ok:
    case True{}: IO.print("range-checked")
    case False{}: IO.die(Unit,70,"range mismatch")

def range_result(start: U32, end: U32, result: Result<&2, &2, E.Error, C.Range>) -> IO(Unit):
  match result:
    case Done{C.Range{7,9,a,b}}: assert(Bool.and(U32.is_eq(start,a),U32.is_eq(end,b)))
    case _: IO.die(Unit,70,"range result")

def range_error(result: Result<&2, &2, E.Error, C.Range>) -> IO(Unit):
  match result:
    case Fail{E.Bounds{a,b,c}}: IO.print("range-rejected")
    case _: IO.die(Unit,70,"range accepted")

def take_zero(result: Result<&2, &1, E.Error, C.Cursor & C.Range>) -> IO(Unit):
  match result:
    case Fail{error}: IO.die(Unit,70,"zero take failed")
    case Done{pair}:
      (cursor,range) = pair
      match cursor range:
        case C.Cursor{C.Range{7,9,10,20},20} C.Range{7,9,20,20}: IO.print("zero-at-end")
        case _ _: IO.die(Unit,70,"zero take mismatch")

def take_error(result: Result<&2, &1, E.Error, C.Cursor & C.Range>) -> IO(Unit):
  match result:
    case Fail{E.Bounds{a,b,c}}: IO.print("take-rejected")
    case _: IO.die(Unit,70,"take accepted")

def cursor_error(result: Result<&2, &2, E.Error, C.Cursor>) -> IO(Unit):
  match result:
    case Fail{E.Bounds{a,b,c}}: IO.print("cursor-rejected")
    case _: IO.die(Unit,70,"cursor accepted")

def truncated(result: Result<&2, &2, E.Error, C.ReadState>) -> IO(Unit):
  match result:
    case Fail{E.Bounds{19,2,20}}: IO.print("truncation-rejected")
    case _: IO.die(Unit,70,"truncation mismatch")

def remaining(result: Result<&2, &2, E.Error, U32>) -> IO(Unit):
  match result:
    case Done{7}: IO.print("remaining-checked")
    case _: IO.die(Unit,70,"remaining mismatch")

def main() -> IO(Unit):
  do IO<Unit>:
    range_result(0,0,C.range_internal(7,9,0,0,0))
    range_result(4294967295,4294967295,C.range_internal(7,9,4294967295,4294967295,4294967295))
    range_error(C.range_internal(7,9,2,1,3))
    range_error(C.range_internal(7,9,1,4,3))
    range_result(12,15,C.subrange(C.Range{7,9,10,20},2,3))
    range_result(20,20,C.subrange(C.Range{7,9,10,20},10,0))
    range_error(C.subrange(C.Range{7,9,10,20},11,0))
    range_error(C.subrange(C.Range{7,9,10,20},9,2))
    range_error(C.subrange(C.Range{7,9,20,10},0,0))
    range_error(C.subrange(C.Range{7,9,4294967290,4294967295},4,2))
    take_zero(C.take(C.Cursor{C.Range{7,9,10,20},20},0))
    take_error(C.take(C.Cursor{C.Range{7,9,10,20},20},1))
    take_error(C.take(C.Cursor{C.Range{7,9,10,20},21},0))
    take_error(C.take(C.Cursor{C.Range{7,9,10,20},9},0))
    cursor_error(C.cursor(C.Range{7,9,10,20},9))
    cursor_error(C.cursor(C.Range{7,9,10,20},21))
    truncated(C.read_u16_le(C.Cursor{C.Range{7,9,10,20},19}))
    remaining(C.remaining(C.Cursor{C.Range{7,9,10,20},13}))
