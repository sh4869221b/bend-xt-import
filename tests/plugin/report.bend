# Stable whitespace protocol for the independent Python oracle.
import Base
import ../../core/error.bend as E
import ../../core/cursor.bend as C
import ../../plugin/types.bend as T
import ../../plugin/error.bend as D
import ./support.bend as H

def body(kind: T.BodyKind) -> String:
  match kind:
    case T.Structural{}: "0"
    case T.OpaqueCompressed{}: "1"

def record(r: T.Record) -> String:
  match r:
    case T.Record{signature,flags,formid,revision,version,unknown,header,payload,full,parent_start,parent_end,depth,ordinal,kind}:
      "R " ++ U32.show(signature) ++ " " ++ U32.show(flags) ++ " " ++ U32.show(formid) ++ " " ++ U32.show(revision) ++ " " ++ U32.show(version) ++ " " ++ U32.show(unknown) ++ " " ++ H.range(header) ++ " " ++ H.range(payload) ++ " " ++ H.range(full) ++ " " ++ U32.show(parent_start) ++ " " ++ U32.show(parent_end) ++ " " ++ U32.show(depth) ++ " " ++ U32.show(ordinal) ++ " " ++ body(kind)

def group(r: T.Group) -> String:
  match r:
    case T.Group{label,kind,stamp1,stamp2,header,full,parent_start,parent_end,depth}:
      "G " ++ U32.show(label) ++ " " ++ U32.show(kind) ++ " " ++ U32.show(stamp1) ++ " " ++ U32.show(stamp2) ++ " " ++ H.range(header) ++ " " ++ H.range(full) ++ " " ++ U32.show(parent_start) ++ " " ++ U32.show(parent_end) ++ " " ++ U32.show(depth)

def escape(r: Maybe<&2, C.Range>) -> String:
  match r:
    case None{}: "0 0 0 0 0"
    case Some{span}: "1 " ++ H.range(span)

def field(f: T.Subrecord) -> String:
  match f:
    case T.Subrecord{signature,original,length,header,payload,full,extended,record_start,ordinal}:
      "F " ++ U32.show(signature) ++ " " ++ U32.show(original) ++ " " ++ U32.show(length) ++ " " ++ H.range(header) ++ " " ++ H.range(payload) ++ " " ++ H.range(full) ++ " " ++ escape(extended) ++ " " ++ U32.show(record_start) ++ " " ++ U32.show(ordinal)

def body_access(kind: T.BodyKind, r: Result<&2, &2, D.Diagnostic, C.Range>) -> IO(Unit):
  match kind r:
    case T.Structural{} Done{range}: IO.pure(Unit,Unit{})
    case T.OpaqueCompressed{} Fail{D.Diagnostic{D.Format{24},run,origin,offset,parent_start,parent_end,record,depth,declared}}: IO.pure(Unit,Unit{})
    case _ _: IO.die(Unit,70,"structural body capability mismatch")

def access_record(+r: T.Record) -> IO(Unit):
  match r:
    case T.Record{signature,flags,formid,revision,version,unknown,header,payload,full,parent_start,parent_end,depth,ordinal,kind}: body_access(kind,D.body(r))

def event_line(event: T.ScanEvent) -> String:
  match event:
    case T.RecordStart{r}: record(r)
    case T.GroupStart{g}: group(g)
    case T.Field{f}: field(f)
    case T.RecordEnd{start,end,count,kind}: "E " ++ U32.show(start) ++ " " ++ U32.show(end) ++ " " ++ U32.show(count) ++ " " ++ body(kind)
    case T.GroupEnd{start,end,depth}: "Z " ++ U32.show(start) ++ " " ++ U32.show(end) ++ " " ++ U32.show(depth)

def event_access(event: T.ScanEvent) -> IO(Unit):
  match event:
    case T.RecordStart{r}: access_record(r)
    case _: IO.pure(Unit,Unit{})

def event_print(quiet: Bool, event: T.ScanEvent) -> IO(Unit):
  match quiet:
    case True{}: IO.pure(Unit,Unit{})
    case False{}: IO.print(event_line(event))

def event(quiet: Bool, +event: T.ScanEvent) -> IO(Unit):
  do IO<Unit>:
    event_access(event)
    event_print(quiet,event)

def summary(s: T.Summary) -> String:
  match s:
    case T.Summary{source,records,objects,subrecords,opaque,all}: "STATUS OK " ++ H.range(source) ++ " " ++ U32.show(records) ++ " " ++ U32.show(objects) ++ " " ++ U32.show(subrecords) ++ " " ++ U32.show(opaque) ++ " " ++ H.bool(all)

def core(error: E.Error) -> String:
  match error:
    case E.Bounds{a,b,c}: "1 " ++ U32.show(a) ++ " " ++ U32.show(b) ++ " " ++ U32.show(c) ++ " 0"
    case E.InvalidByte{a}: "2 " ++ U32.show(a) ++ " 0 0 0"
    case E.Overflow{a,b,c}: "3 " ++ U32.show(a) ++ " " ++ U32.show(b) ++ " " ++ U32.show(c) ++ " 0"
    case E.InvalidEncoding{a,b,c}: "4 " ++ U32.show(a) ++ " " ++ U32.show(b) ++ " " ++ U32.show(c) ++ " 0"
    case E.ResourceLimit{a,b,c,d}: "5 " ++ U32.show(a) ++ " " ++ U32.show(b) ++ " " ++ U32.show(c) ++ " " ++ U32.show(d)
    case E.Io{a,b,c}: "6 " ++ U32.show(a) ++ " " ++ U32.show(b) ++ " " ++ U32.show(c) ++ " 0"
    case E.Unsupported{a}: "7 " ++ U32.show(a) ++ " 0 0 0"
    case E.SourceChanged{}: "8 0 0 0 0"
    case E.UnsafeNamespace{a}: "9 " ++ U32.show(a) ++ " 0 0 0"
    case E.ResidualWork{a}: "10 " ++ U32.show(a) ++ " 0 0 0"
    case E.InternalInvariant{a}: "11 " ++ U32.show(a) ++ " 0 0 0"

def cause(c: D.Cause) -> String:
  match c:
    case D.Format{reason}: "0 " ++ U32.show(reason) ++ " 0 0 0 0"
    case D.Core{error}: "1 " ++ core(error)

def owner(record: Maybe<&2, U32>) -> String:
  match record:
    case None{}: "0 0"
    case Some{start}: "1 " ++ U32.show(start)

def diagnostic(d: D.Diagnostic) -> String:
  match d:
    case D.Diagnostic{why,run,origin,offset,parent_start,parent_end,record,depth,declared}:
      "STATUS ERROR " ++ cause(why) ++ " " ++ U32.show(run) ++ " " ++ U32.show(origin) ++ " " ++ U32.show(offset) ++ " " ++ U32.show(parent_start) ++ " " ++ U32.show(parent_end) ++ " " ++ owner(record) ++ " " ++ U32.show(depth) ++ " " ++ U32.show(declared)
