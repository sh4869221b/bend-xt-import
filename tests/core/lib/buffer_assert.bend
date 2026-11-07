import Base
import ../../../core/error.bend as E
import ../../../core/budget.bend as B
import ../../../core/bytes.bend as Bytes

def check(name: String, yes: Bool) -> IO(Unit):
  match yes:
    case True{}: IO.pure(Unit,Unit{})
    case False{}: IO.die(Unit,70,name)

def same(+a: B.Six, +b: B.Six) -> Bool:
  Bool.and(B.fits(a,b),B.fits(b,a))

def error_equal(a: E.Error, b: E.Error) -> Bool:
  match a b:
    case E.Bounds{a,b,c} E.Bounds{d,e,f}: Bool.and(U32.is_eq(a,d),Bool.and(U32.is_eq(b,e),U32.is_eq(c,f)))
    case E.Overflow{a,b,c} E.Overflow{d,e,f}: Bool.and(U32.is_eq(a,d),Bool.and(U32.is_eq(b,e),U32.is_eq(c,f)))
    case E.InvalidByte{a} E.InvalidByte{b}: U32.is_eq(a,b)
    case E.ResourceLimit{a,b,c,d} E.ResourceLimit{e,f,g,h}: Bool.and(U32.is_eq(a,e),Bool.and(U32.is_eq(b,f),Bool.and(U32.is_eq(c,g),U32.is_eq(d,h))))
    case E.InternalInvariant{a} E.InternalInvariant{b}: U32.is_eq(a,b)
    case _ _: False{}

def start(r: Result<&2, &1, E.Error, B.Budget>) -> IO(B.Budget):
  match r:
    case Done{budget}: IO.pure(B.Budget,budget)
    case _: IO.die(B.Budget,70,"budget start")

def created(p: B.Budget & Result<&2, &1, E.Error, Bytes.OwnedBytes>) -> IO(B.Budget & Bytes.OwnedBytes):
  (budget,result) = p
  match result:
    case Done{bytes}: IO.pure(B.Budget & Bytes.OwnedBytes,(budget,bytes))
    case _: IO.die(B.Budget & Bytes.OwnedBytes,70,"bytes new")

def changed(p: B.Budget & Bytes.OwnedBytes & Result<&2, &2, E.Error, Unit>) -> IO(B.Budget & Bytes.OwnedBytes):
  (budget,bytes,result) = p
  match result:
    case Done{u}: IO.pure(B.Budget & Bytes.OwnedBytes,(budget,bytes))
    case _: IO.die(B.Budget & Bytes.OwnedBytes,70,"byte mutation")

def change_failed(expected: E.Error, p: B.Budget & Bytes.OwnedBytes & Result<&2, &2, E.Error, Unit>) -> IO(B.Budget & Bytes.OwnedBytes):
  (budget,bytes,result) = p
  match result:
    case Fail{error}:
      do IO<B.Budget & Bytes.OwnedBytes>:
        check("mutation error context",error_equal(expected,error))
        IO.pure(B.Budget & Bytes.OwnedBytes,(budget,bytes))
    case _: IO.die(B.Budget & Bytes.OwnedBytes,70,"mutation should fail")

def read(expected: U32, p: B.Budget & Bytes.OwnedBytes & Result<&2, &2, E.Error, U32>) -> IO(B.Budget & Bytes.OwnedBytes):
  (budget,bytes,result) = p
  match result:
    case Done{actual}:
      do IO<B.Budget & Bytes.OwnedBytes>:
        check("byte content",U32.is_eq(expected,actual))
        IO.pure(B.Budget & Bytes.OwnedBytes,(budget,bytes))
    case _: IO.die(B.Budget & Bytes.OwnedBytes,70,"byte read")

def read_failed(expected: E.Error, p: B.Budget & Bytes.OwnedBytes & Result<&2, &2, E.Error, U32>) -> IO(B.Budget & Bytes.OwnedBytes):
  (budget,bytes,result) = p
  match result:
    case Fail{error}:
      do IO<B.Budget & Bytes.OwnedBytes>:
        check("read error context",error_equal(expected,error))
        IO.pure(B.Budget & Bytes.OwnedBytes,(budget,bytes))
    case _: IO.die(B.Budget & Bytes.OwnedBytes,70,"read should fail")

def usage(used: B.Six, held: B.Six, p: B.Budget & B.Six & B.Six) -> IO(B.Budget):
  (budget,actual_used,actual_held) = p
  do IO<B.Budget>:
    check("used counters",same(used,actual_used))
    check("held counters",same(held,actual_held))
    IO.pure(B.Budget,budget)

def metadata(length: U32, capacity: U32, run: U32, origin: U32, p: Bytes.OwnedBytes & U32 & U32 & U32 & U32) -> IO(Bytes.OwnedBytes):
  (bytes,l,c,r,o) = p
  do IO<Bytes.OwnedBytes>:
    check("buffer logical length",U32.is_eq(length,l))
    check("buffer physical capacity",U32.is_eq(capacity,c))
    check("buffer run",U32.is_eq(run,r))
    check("buffer allocation identity",U32.is_eq(origin,o))
    IO.pure(Bytes.OwnedBytes,bytes)

def dropped(p: B.Budget & Result<&1, &2, E.Error & B.Allocation, Unit>) -> IO(B.Budget):
  (budget,result) = p
  match result:
    case Done{u}: IO.pure(B.Budget,budget)
    case _: IO.die(B.Budget,70,"buffer drop")

def finished(name: String, expected: B.Six, r: Result<&1, &2, E.Error & B.Budget, B.Six>) -> IO(Unit):
  match r:
    case Done{actual}:
      do IO<Unit>:
        check("final counters",same(expected,actual))
        IO.print(name)
    case _: IO.die(Unit,70,"live or held leak")

def reserved(p: B.Budget & Result<&2, &1, E.Error, B.Reservation>) -> IO(B.Budget & B.Reservation):
  (budget,result) = p
  match result:
    case Done{ticket}: IO.pure(B.Budget & B.Reservation,(budget,ticket))
    case _: IO.die(B.Budget & B.Reservation,70,"reserve validation work")

def cancelled(p: B.Budget & Result<&1, &1, E.Error & B.Reservation, Maybe<&1, B.Allocation>>) -> IO(B.Budget):
  (budget,result) = p
  match result:
    case Done{None{}}: IO.pure(B.Budget,budget)
    case _: IO.die(B.Budget,70,"cancel validation work")

def copy_done(p: B.Budget & Bytes.OwnedBytes & Bytes.CopyResult) -> IO(B.Budget & Bytes.OwnedBytes & Bytes.OwnedBytes):
  (budget,source,result) = p
  match result:
    case Bytes.Copied{dest}: IO.pure(B.Budget & Bytes.OwnedBytes & Bytes.OwnedBytes,(budget,source,dest))
    case _: IO.die(B.Budget & Bytes.OwnedBytes & Bytes.OwnedBytes,70,"copy success")

def copy_failed(expected: E.Error, p: B.Budget & Bytes.OwnedBytes & Bytes.CopyResult) -> IO(B.Budget & Bytes.OwnedBytes):
  (budget,source,result) = p
  match result:
    case Bytes.CopyFailed{error,None{}}:
      do IO<B.Budget & Bytes.OwnedBytes>:
        check("copy preflight error",error_equal(expected,error))
        IO.pure(B.Budget & Bytes.OwnedBytes,(budget,source))
    case _: IO.die(B.Budget & Bytes.OwnedBytes,70,"copy allocated after rejection")

def copy_partial(expected: E.Error, p: B.Budget & Bytes.OwnedBytes & Bytes.CopyResult) -> IO(B.Budget & Bytes.OwnedBytes & Bytes.OwnedBytes):
  (budget,source,result) = p
  match result:
    case Bytes.CopyFailed{error,Some{dest}}:
      do IO<B.Budget & Bytes.OwnedBytes & Bytes.OwnedBytes>:
        check("copy partial error",error_equal(expected,error))
        IO.pure(B.Budget & Bytes.OwnedBytes & Bytes.OwnedBytes,(budget,source,dest))
    case _: IO.die(B.Budget & Bytes.OwnedBytes & Bytes.OwnedBytes,70,"copy must return both owners")
