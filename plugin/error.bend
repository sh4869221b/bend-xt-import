import Base
import ../core/error.bend as E
import ../core/cursor.bend as C
import ./types.bend as T

# Stable format reason IDs are documented in docs/plugin/api.md.
type Cause is Data:
  Format{reason: U32}
  Core{error: E.Error}

type Diagnostic is Data:
  Diagnostic{cause: Cause, run: U32, origin: U32, offset: U32, parent_start: U32, parent_end: U32, record: Maybe<&2, U32>, depth: U32, declared: U32}

def make(source: C.Range, cause: Cause, offset: U32, parent_start: U32, parent_end: U32, record: Maybe<&2, U32>, depth: U32, declared: U32) -> Diagnostic:
  match source:
    case C.Range{run,origin,start,end}: Diagnostic{cause,run,origin,offset,parent_start,parent_end,record,depth,declared}

def source(source: C.Range, cause: Cause, declared: U32) -> Diagnostic:
  match source:
    case C.Range{+run,+origin,start,+end}: Diagnostic{cause,run,origin,0,0,end,None{},0,declared}

def body(record: T.Record) -> Result<&2, &2, Diagnostic, C.Range>:
  match record:
    case T.Record{signature,flags,form_id,revision,version,unknown,header,payload,full,parent_start,parent_end,depth,ordinal,T.Structural{}}: Done{payload}
    case T.Record{signature,flags,form_id,revision,version,unknown,header,payload,C.Range{run,origin,+start,end},parent_start,parent_end,depth,ordinal,T.OpaqueCompressed{}}:
      Fail{Diagnostic{Format{24},run,origin,start,parent_start,parent_end,Some{start},depth,U32.sub(end,start)}}
