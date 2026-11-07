import Base
import ../../core/budget.bend as B
import ../../core/bytes.bend as Bytes
import ../../core/cursor.bend as C
import ../../core/error.bend as E
import ../../plugin/types.bend as T
import ../../plugin/error.bend as D
import ../../plugin/state.bend as S
import ../../plugin/frame.bend as F
import ../../plugin/copy.bend as Copy
import ../../hash/sha256.bend as SHA
import ./support.bend as H
import ./report.bend as R

type Config is Data:
  Config{fixture: H.Fixture, chunk: U32, output: U32, limits: T.Limits, quiet: Bool, copying: Bool}

def finished(terminal: String, budget: B.Budget) -> IO(Unit):
  do IO<Unit>:
    H.usage(B.finish(budget))
    IO.print(terminal)
    IO.print("BALANCED")

def finish_window(terminal: String, budget: B.Budget, window: C.ByteWindow) -> IO(Unit):
  do IO<Unit>:
    budget : B.Budget <- H.drop_window(budget,window)
    finished(terminal,budget)

def finish_scan(terminal: String, window: C.ByteWindow, p: B.Budget & Result<&1, &2, E.Error & B.Allocation, Unit>) -> IO(Unit):
  do IO<Unit>:
    budget : B.Budget <- H.dropped(p)
    finish_window(terminal,budget,window)

def canceled(p: B.Budget & Result<&1, &1, E.Error & B.Reservation, Maybe<&1, B.Allocation>>) -> IO(B.Budget):
  (budget,result) = p
  match result:
    case Done{None{}}: IO.pure(B.Budget,budget)
    case _: IO.die(B.Budget,70,"reservation cleanup failed")

def cancel(budget: B.Budget, ticket: Maybe<&1, B.Reservation>) -> IO(B.Budget):
  match ticket:
    case None{}: IO.pure(B.Budget,budget)
    case Some{ticket}: canceled(B.cancel(budget,ticket))

def hex_digit(n: U32, big: Bool) -> Char:
  match big:
    case False{}: Chr{U32.add(n,48)}
    case True{}: Chr{U32.add(n,87)}

def digit(+n: U32) -> Char:
  hex_digit(n,U32.is_lt(9,n))

def hex_byte(+n: U32) -> String:
  SCon{digit(U32.div(n,16)),SCon{digit(U32.mod(n,16)),SNil{}}}

def checked_byte(absolute: U32, fixture: H.Fixture, +value: U32, valid: Bool) -> IO(String):
  match valid:
    case True{}: IO.pure(String,hex_byte(value))
    case False{}: IO.die(String,70,"production copier changed a byte")

def got_byte(+absolute: U32, +fixture: H.Fixture, p: B.Budget & Bytes.OwnedBytes & Result<&2, &2, E.Error, U32>) -> IO(B.Budget & Bytes.OwnedBytes & String):
  (budget,bytes,result) = p
  match result:
    case Fail{error}: IO.die(B.Budget & Bytes.OwnedBytes & String,70,"copy verification read failed")
    case Done{+value}:
      do IO<B.Budget & Bytes.OwnedBytes & String>:
        encoded : String <- checked_byte(absolute,fixture,value,U32.is_eq(value,H.byte(fixture,absolute)))
        return (budget,bytes,encoded)

def append_hex(quiet: Bool, prefix: String, suffix: String) -> String:
  match quiet:
    case True{}: ""
    case False{}: String.reverse(suffix) ++ prefix

def sink_join(quiet: Bool, encoded: String, p: B.Budget & Bytes.OwnedBytes & String) -> B.Budget & Bytes.OwnedBytes & String:
  (budget,bytes,next) = p
  (budget,bytes,append_hex(quiet,encoded,next))

def sink(fuel: Nat, +fixture: H.Fixture, +quiet: Bool, +absolute: U32, +index: U32, p: B.Budget & Bytes.OwnedBytes & String) -> IO(B.Budget & Bytes.OwnedBytes & String):
  match fuel:
    case 0n: IO.pure(B.Budget & Bytes.OwnedBytes & String,p)
    case 1n+rest:
      (budget,bytes,encoded) = p
      do IO<B.Budget & Bytes.OwnedBytes & String>:
        next : B.Budget & Bytes.OwnedBytes & String <- got_byte(absolute,fixture,Bytes.get(budget,bytes,index))
        sink(rest,fixture,quiet,U32.inc(absolute),U32.inc(index),sink_join(quiet,encoded,next))

def print_chunk(quiet: Bool, encoded: String) -> IO(Unit):
  match quiet:
    case True{}: IO.pure(Unit,Unit{})
    case False{}: IO.print("COPY " ++ String.reverse(encoded))

def digest_got(text: String, p: B.Budget & Bytes.OwnedBytes & Result<&2, &2, E.Error, U32>) -> B.Budget & Bytes.OwnedBytes & String:
  (budget,bytes,result) = p
  match result:
    case Done{value}: (budget,bytes,text ++ hex_byte(value))
    case Fail{error}: (budget,bytes,"INVALID")

def digest_text(fuel: Nat, +index: U32, p: B.Budget & Bytes.OwnedBytes & String) -> B.Budget & Bytes.OwnedBytes & String:
  match fuel:
    case 0n: p
    case 1n+rest:
      (budget,bytes,text) = p
      digest_text(rest,U32.inc(index),digest_got(text,Bytes.get(budget,bytes,index)))

def print_digest(p: B.Budget & Bytes.OwnedBytes & String) -> IO(B.Budget):
  (budget,bytes,text) = p
  do IO<B.Budget>:
    IO.print("SHA256 " ++ text)
    H.dropped(Bytes.drop(budget,bytes))

def final_hash(p: B.Budget & SHA.FinalResult) -> IO(B.Budget):
  (budget,result) = p
  match result:
    case SHA.HashDone{digest}: print_digest(digest_text(32n,0,(budget,digest,"")))
    case _: IO.die(B.Budget,70,"hash finalization failed")

def drop_optional(budget: B.Budget, bytes: Maybe<&1, Bytes.OwnedBytes>) -> IO(B.Budget):
  match bytes:
    case None{}: IO.pure(B.Budget,budget)
    case Some{bytes}: H.dropped(Bytes.drop(budget,bytes))

def copy_dropped(p: B.Budget & Maybe<&1, Bytes.OwnedBytes> & Result<&1, &2, E.Error & B.Allocation, Unit>) -> IO(B.Budget):
  (budget,bytes,result) = p
  match result:
    case Fail{error}: IO.die(B.Budget,70,"copy state release failed")
    case Done{u}: drop_optional(budget,bytes)

type CopyTest is Type:
  CopyContinue{budget: B.Budget, window: C.ByteWindow, state: Copy.CopyState, hash: SHA.ShaState, offset: U32}
  CopyFinished{budget: B.Budget, window: C.ByteWindow, state: Copy.CopyState, hash: SHA.ShaState, offset: U32}
  CopyError{budget: B.Budget, window: C.ByteWindow, state: Copy.CopyState, hash: SHA.ShaState, diagnostic: D.Diagnostic}

def copy_resumed(budget: B.Budget, window: C.ByteWindow, hash: SHA.ShaState, offset: U32, result: Result<&1, &1, D.Diagnostic & Copy.CopyState & Bytes.OwnedBytes, Copy.CopyState>) -> IO(CopyTest):
  match result:
    case Done{state}: IO.pure(CopyTest,CopyContinue{budget,window,state,hash,offset})
    case _: IO.die(CopyTest,70,"copy handback refused empty buffer")

def copied_chunk(window: C.ByteWindow, state: Copy.CopyState, hash: SHA.ShaState, offset: U32, bytes: Bytes.OwnedBytes, final: Bool, budget: B.Budget) -> IO(CopyTest):
  match final:
    case False{}: copy_resumed(budget,window,hash,offset,Copy.resume(state,Bytes.clear(bytes)))
    case True{}:
      do IO<CopyTest>:
        budget : B.Budget <- H.dropped(Bytes.drop(budget,bytes))
        return CopyFinished{budget,window,state,hash,offset}

def hashed_chunk(window: C.ByteWindow, state: Copy.CopyState, offset: U32, final: Bool, p: B.Budget & Bytes.OwnedBytes & SHA.ShaState & Result<&2, &2, E.Error, Unit>) -> IO(CopyTest):
  (budget,bytes,hash,result) = p
  match result:
    case Done{u}: copied_chunk(window,state,hash,offset,bytes,final,budget)
    case _: IO.die(CopyTest,70,"copy digest update failed")

def sunk_chunk(window: C.ByteWindow, state: Copy.CopyState, hash: SHA.ShaState, quiet: Bool, offset: U32, +length: U32, final: Bool, p: B.Budget & Bytes.OwnedBytes & String) -> IO(CopyTest):
  (budget,bytes,encoded) = p
  do IO<CopyTest>:
    print_chunk(quiet,encoded)
    hashed_chunk(window,state,U32.add(offset,length),final,SHA.update(budget,hash,bytes,0,length))

def chunk_meta(budget: B.Budget, window: C.ByteWindow, state: Copy.CopyState, hash: SHA.ShaState, fixture: H.Fixture, +quiet: Bool, +offset: U32, final: Bool, p: Bytes.OwnedBytes & U32 & U32 & U32 & U32) -> IO(CopyTest):
  (bytes,length,capacity,run,origin) = p
  +length = {length: U32}
  do IO<CopyTest>:
    p : B.Budget & Bytes.OwnedBytes & String <- sink(U32.to_nat(length),fixture,quiet,offset,0,(budget,bytes,""))
    sunk_chunk(window,state,hash,quiet,offset,length,final,p)

def copy_refilled(state: Copy.CopyState, hash: SHA.ShaState, offset: U32, p: B.Budget & C.ByteWindow) -> CopyTest:
  (budget,window) = p
  CopyContinue{budget,window,state,hash,offset}

def copy_result(config: Config, hash: SHA.ShaState, offset: U32, p: B.Budget & C.ByteWindow & Copy.CopyState & Copy.CopyResult) -> IO(CopyTest):
  match config:
    case Config{fixture,chunk,output,limits,quiet,copying}:
      (budget,window,state,result) = p
      match result:
        case Copy.CopyNeedWindow{base}:
          do IO<CopyTest>:
            next : B.Budget & C.ByteWindow <- H.refill(budget,window,fixture,chunk,base)
            return copy_refilled(state,hash,offset,next)
        case Copy.ChunkReady{bytes,final}: chunk_meta(budget,window,state,hash,fixture,quiet,offset,final,Bytes.metadata(bytes))
        case Copy.CopyFailed{diagnostic}: IO.pure(CopyTest,CopyError{budget,window,state,hash,diagnostic})
        case Copy.CopyDone{}: IO.die(CopyTest,70,"copier ended without final chunk")

def copy_loop(fuel: Nat, +config: Config, +terminal: String, step: CopyTest) -> IO(Unit):
  match fuel step:
    case 0n _: IO.die(Unit,70,"copy harness transition fuel exhausted")
    case 1n+rest CopyContinue{budget,window,state,hash,offset}:
      do IO<Unit>:
        next : CopyTest <- copy_result(config,hash,offset,Copy.pump(budget,window,state))
        copy_loop(rest,config,terminal,next)
    case _ CopyFinished{budget,window,state,hash,offset}:
      do IO<Unit>:
        IO.print("COPIED " ++ U32.show(offset))
        budget : B.Budget <- final_hash(SHA.finalize(budget,hash))
        budget : B.Budget <- copy_dropped(Copy.drop(budget,state))
        finish_window(terminal,budget,window)
    case _ CopyError{budget,window,state,hash,diagnostic}:
      do IO<Unit>:
        budget : B.Budget <- H.dropped(SHA.drop(budget,hash))
        budget : B.Budget <- copy_dropped(Copy.drop(budget,state))
        finish_window(R.diagnostic(diagnostic),budget,window)

def copy_started(config: Config, terminal: String, budget: B.Budget, window: C.ByteWindow, hash: SHA.ShaState, result: Result<&1, &1, D.Diagnostic & S.Scanner & Bytes.OwnedBytes, Copy.CopyState>) -> IO(Unit):
  match result:
    case Done{state}: copy_loop(1073741824n,config,terminal,CopyContinue{budget,window,state,hash,0})
    case _: IO.die(Unit,70,"completed scanner refused copy")

def hash_started(config: Config, terminal: String, window: C.ByteWindow, scanner: S.Scanner, output: Bytes.OwnedBytes, p: B.Budget & Result<&2, &1, E.Error, SHA.ShaState>) -> IO(Unit):
  (budget,result) = p
  match result:
    case Done{hash}: copy_started(config,terminal,budget,window,hash,Copy.start(scanner,Bytes.clear(output)))
    case _: IO.die(Unit,70,"copy hash allocation failed")

def output_created(config: Config, terminal: String, window: C.ByteWindow, scanner: S.Scanner, p: B.Budget & Result<&2, &1, E.Error, Bytes.OwnedBytes>) -> IO(Unit):
  (budget,result) = p
  match result:
    case Done{output}: hash_started(config,terminal,window,scanner,output,SHA.init(budget))
    case _: IO.die(Unit,70,"copy output allocation failed")

def complete_selected(config: Config, terminal: String, budget: B.Budget, window: C.ByteWindow, scanner: S.Scanner, output: U32, copying: Bool) -> IO(Unit):
  match copying:
    case False{}: finish_scan(terminal,window,S.drop(budget,scanner))
    case True{}: output_created(config,terminal,window,scanner,Bytes.new(budget,output))

def complete(+config: Config, terminal: String, budget: B.Budget, window: C.ByteWindow, scanner: S.Scanner) -> IO(Unit):
  match config:
    case Config{fixture,chunk,output,limits,quiet,copying}: complete_selected(config,terminal,budget,window,scanner,output,copying)

def scan_refilled(scanner: S.Scanner, p: B.Budget & C.ByteWindow) -> B.Budget & C.ByteWindow & S.Scanner & S.Status:
  (budget,window) = p
  F.next(budget,window,scanner)

def scan_refill(config: Config, base: U32, scanner: S.Scanner, budget: B.Budget, window: C.ByteWindow) -> IO(B.Budget & C.ByteWindow & S.Scanner & S.Status):
  match config:
    case Config{fixture,chunk,output,limits,quiet,copying}:
      do IO<B.Budget & C.ByteWindow & S.Scanner & S.Status>:
        p : B.Budget & C.ByteWindow <- H.refill(budget,window,fixture,chunk,base)
        return scan_refilled(scanner,p)

def scan_event(config: Config, event: T.ScanEvent) -> IO(Unit):
  match config:
    case Config{fixture,chunk,output,limits,quiet,copying}: R.event(quiet,event)

def scan_loop(fuel: Nat, +config: Config, p: B.Budget & C.ByteWindow & S.Scanner & S.Status) -> IO(Unit):
  match fuel:
    case 0n: IO.die(Unit,70,"scan harness transition fuel exhausted")
    case 1n+rest:
      (budget,window,scanner,status) = p
      match status:
        case S.Yield{event}:
          do IO<Unit>:
            scan_event(config,event)
            scan_loop(rest,config,F.next(budget,window,scanner))
        case S.NeedWindow{offset}:
          do IO<Unit>:
            p : B.Budget & C.ByteWindow & S.Scanner & S.Status <- scan_refill(config,offset,scanner,budget,window)
            scan_loop(rest,config,p)
        case S.Complete{summary}: complete(config,R.summary(summary),budget,window,scanner)
        case S.Failed{diagnostic}: finish_scan(R.diagnostic(diagnostic),window,S.drop(budget,scanner))

def scanner_started(config: Config, p: B.Budget & C.ByteWindow & F.StartResult) -> IO(Unit):
  (budget,window,result) = p
  match result:
    case F.Started{scanner}: scan_loop(1073741824n,config,F.next(budget,window,scanner))
    case F.StartFailed{diagnostic,ticket}:
      do IO<Unit>:
        budget : B.Budget <- cancel(budget,ticket)
        finish_window(R.diagnostic(diagnostic),budget,window)

def window_created(+config: Config, p: B.Budget & C.ByteWindow) -> IO(Unit):
  match config:
    case Config{fixture,chunk,output,limits,quiet,copying}:
      (budget,window) = p
      scanner_started(config,F.start(budget,window,limits))

def input_created(+config: Config, source: C.SourceOwner, p: B.Budget & Result<&2, &1, E.Error, Bytes.OwnedBytes>) -> IO(Unit):
  match config:
    case Config{fixture,chunk,output,limits,quiet,copying}:
      (budget,result) = p
      match result:
        case Done{bytes}:
          do IO<Unit>:
            p : B.Budget & C.ByteWindow <- H.window(budget,source,bytes,fixture,chunk,0)
            window_created(config,p)
        case _: IO.die(Unit,70,"input allocation failed")

def source_created(+config: Config, p: B.Budget & Result<&2, &1, E.Error, C.SourceOwner>) -> IO(Unit):
  match config:
    case Config{fixture,chunk,output,limits,quiet,copying}:
      (budget,result) = p
      match result:
        case Done{source}: input_created(config,source,Bytes.new(budget,chunk))
        case _: IO.die(Unit,70,"source allocation failed")

def input_charged(+config: Config, p: B.Budget & Result<&2, &2, E.Error, Unit>) -> IO(Unit):
  match config:
    case Config{fixture,chunk,output,limits,quiet,copying}:
      (budget,result) = p
      match result:
        case Done{u}: source_created(config,C.source(budget,H.size(fixture)))
        case _: IO.die(Unit,70,"synthetic input acquisition budget failed")

def budget_started(+config: Config, result: Result<&2, &1, E.Error, B.Budget>) -> IO(Unit):
  match config result:
    case Config{fixture,chunk,output,limits,quiet,copying} Done{budget}: input_charged(config,B.consume(budget,B.Six{H.size(fixture),0,0,0,0,0}))
    case _ _: IO.die(Unit,70,"test budget start failed")

def run(fixture: H.Fixture, chunk: U32, output: U32, limits: T.Limits, quiet: Bool, copying: Bool, work: U32, live: U32) -> IO(Unit):
  budget_started(Config{fixture,chunk,output,limits,quiet,copying},B.start(1,B.Six{1073741824,0,0,0,live,work}))
