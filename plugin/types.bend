import Base
import ../core/cursor.bend as C

# Fixed-size observations. These values confer no edit or source ownership.
type Limits is Data:
  Limits{source: U32, payload: U32, records: U32, objects: U32, subrecords: U32, depth: U32}

def defaults() -> Limits:
  Limits{268435456,33554432,2000000,2000000,8000000,64}

def limits_valid(limits: Limits) -> Bool:
  match limits:
    case Limits{source,payload,+records,+objects,subrecords,depth}:
      Bool.and(U32.is_le(source,268435456),Bool.and(U32.is_le(payload,33554432),Bool.and(U32.is_le(records,objects),Bool.and(U32.is_le(objects,2000000),Bool.and(U32.is_le(subrecords,8000000),U32.is_le(depth,64))))))

def tes4() -> U32:
  877872468

def grup() -> U32:
  1347768903

def xxxx() -> U32:
  1482184792

type BodyKind is Data:
  Structural{}
  OpaqueCompressed{}

type Record is Data:
  Record{signature: U32, flags: U32, form_id: U32, revision: U32, form_version: U32, unknown: U32, header: C.Range, payload: C.Range, full: C.Range, parent_start: U32, parent_end: U32, depth: U32, ordinal: U32, body: BodyKind}

type Group is Data:
  Group{label: U32, group_type: U32, stamp1: U32, stamp2: U32, header: C.Range, full: C.Range, parent_start: U32, parent_end: U32, depth: U32}

type Subrecord is Data:
  Subrecord{signature: U32, original_size: U32, length: U32, header: C.Range, payload: C.Range, full: C.Range, escape: Maybe<&2, C.Range>, record_start: U32, ordinal: U32}

type ScanEvent is Data:
  GroupStart{group: Group}
  GroupEnd{start: U32, end: U32, depth: U32}
  RecordStart{record: Record}
  Field{field: Subrecord}
  RecordEnd{record_start: U32, end: U32, count: U32, body: BodyKind}

type Summary is Data:
  Summary{source: C.Range, records: U32, objects: U32, subrecords: U32, opaque: U32, all_bodies: Bool}

def bit(flags: U32, mask: U32) -> Bool:
  Bool.not(U32.is_zero(U32.and(flags,mask)))

def compressed(flags: U32) -> Bool:
  bit(flags,262144)

def deleted(flags: U32) -> Bool:
  bit(flags,32)

def tes4_master(flags: U32) -> Bool:
  bit(flags,1)

def tes4_localized(flags: U32) -> Bool:
  bit(flags,128)

def tes4_light(flags: U32) -> Bool:
  bit(flags,512)

def body_kind_valid(compressed: Bool) -> BodyKind:
  match compressed:
    case True{}: OpaqueCompressed{}
    case False{}: Structural{}

def body_kind(flags: U32) -> BodyKind:
  body_kind_valid(compressed(flags))

def range_start(range: C.Range) -> U32:
  match range:
    case C.Range{run,origin,start,end}: start

def range_end(range: C.Range) -> U32:
  match range:
    case C.Range{run,origin,start,end}: end
