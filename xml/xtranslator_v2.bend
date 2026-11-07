import Base
import ./types.bend as T
import ./numbers.bend as N

# Fixed closed-schema state. Reader owns arenas and commits this state only
# after its validated scalar/entry action succeeds under the shared budget.

type RootData is Data:
  RootData{rootSeen: U32, paramsSeen: U32, stringSeen: U32, fuzSeen: U32, entries: U32, paramsBytes: U32, entryBytes: U32, paramsScalars: U32, entryScalars: U32, rootAt: T.Position, paramsAt: T.Position, paramsEnd: T.Position, entryAt: T.Position, fuzAt: T.Position, done: Bool}

type Control is Data:
  Control{role: U32, parent: U32, pending: U32, tagAt: T.Position, attrMask: U32, attrId: U32, number: N.Number, attrLength: U32, leafParent: U32, leafAt: T.Position, leafStart: U32, leafLength: U32, leafBytes: U32, first: U32, last: U32, packedRecord: U32, packedField: U32, edidAscii: Bool, edidPipe: Bool, edidBracket: Bool, edidNumber: N.Number}

type EntryValues is Data:
  EntryValues{list: U32, partial: T.Partial, sid: Maybe<&2, T.Sid>, rec: T.Rec, index: Maybe<&2, U32>, maximum: Maybe<&2, U32>, identity: T.Identity, edid: T.FieldRef, sourceText: T.FieldRef, destText: T.FieldRef, fuz: T.Fuz}

type ParamValues is Data:
  ParamValues{addon: T.FieldRef, sourceLanguage: T.FieldRef, destLanguage: T.FieldRef}

type State is Data:
  State{source: T.SourceKey, limits: T.Limits, root: RootData, control: Control, values: EntryValues, params: ParamValues, valid: Bool}

type Action is Data:
  NoAction{}
  AppendParams{value: U32, width: U32}
  AppendEntry{value: U32, width: U32}
  ChargeText{width: U32}
  YieldEntry{meta: T.EntryMeta}

type Step is Data:
  Advance{state: State, action: Action}
  Rejected{state: State, diagnostic: T.Diagnostic}

type Summary is Data:
  Summary{params: T.ParamsMeta, count: U32}

def root_rootSeen(+state: RootData) -> U32:
  match state:
    case RootData{+rootSeen,+paramsSeen,+stringSeen,+fuzSeen,+entries,+paramsBytes,+entryBytes,+paramsScalars,+entryScalars,+rootAt,+paramsAt,+paramsEnd,+entryAt,+fuzAt,+done}: rootSeen

def root_set_rootSeen(+state: RootData, +value: U32) -> RootData:
  match state:
    case RootData{+rootSeen,+paramsSeen,+stringSeen,+fuzSeen,+entries,+paramsBytes,+entryBytes,+paramsScalars,+entryScalars,+rootAt,+paramsAt,+paramsEnd,+entryAt,+fuzAt,+done}: RootData{value,paramsSeen,stringSeen,fuzSeen,entries,paramsBytes,entryBytes,paramsScalars,entryScalars,rootAt,paramsAt,paramsEnd,entryAt,fuzAt,done}

def root_paramsSeen(+state: RootData) -> U32:
  match state:
    case RootData{+rootSeen,+paramsSeen,+stringSeen,+fuzSeen,+entries,+paramsBytes,+entryBytes,+paramsScalars,+entryScalars,+rootAt,+paramsAt,+paramsEnd,+entryAt,+fuzAt,+done}: paramsSeen

def root_set_paramsSeen(+state: RootData, +value: U32) -> RootData:
  match state:
    case RootData{+rootSeen,+paramsSeen,+stringSeen,+fuzSeen,+entries,+paramsBytes,+entryBytes,+paramsScalars,+entryScalars,+rootAt,+paramsAt,+paramsEnd,+entryAt,+fuzAt,+done}: RootData{rootSeen,value,stringSeen,fuzSeen,entries,paramsBytes,entryBytes,paramsScalars,entryScalars,rootAt,paramsAt,paramsEnd,entryAt,fuzAt,done}

def root_stringSeen(+state: RootData) -> U32:
  match state:
    case RootData{+rootSeen,+paramsSeen,+stringSeen,+fuzSeen,+entries,+paramsBytes,+entryBytes,+paramsScalars,+entryScalars,+rootAt,+paramsAt,+paramsEnd,+entryAt,+fuzAt,+done}: stringSeen

def root_set_stringSeen(+state: RootData, +value: U32) -> RootData:
  match state:
    case RootData{+rootSeen,+paramsSeen,+stringSeen,+fuzSeen,+entries,+paramsBytes,+entryBytes,+paramsScalars,+entryScalars,+rootAt,+paramsAt,+paramsEnd,+entryAt,+fuzAt,+done}: RootData{rootSeen,paramsSeen,value,fuzSeen,entries,paramsBytes,entryBytes,paramsScalars,entryScalars,rootAt,paramsAt,paramsEnd,entryAt,fuzAt,done}

def root_fuzSeen(+state: RootData) -> U32:
  match state:
    case RootData{+rootSeen,+paramsSeen,+stringSeen,+fuzSeen,+entries,+paramsBytes,+entryBytes,+paramsScalars,+entryScalars,+rootAt,+paramsAt,+paramsEnd,+entryAt,+fuzAt,+done}: fuzSeen

def root_set_fuzSeen(+state: RootData, +value: U32) -> RootData:
  match state:
    case RootData{+rootSeen,+paramsSeen,+stringSeen,+fuzSeen,+entries,+paramsBytes,+entryBytes,+paramsScalars,+entryScalars,+rootAt,+paramsAt,+paramsEnd,+entryAt,+fuzAt,+done}: RootData{rootSeen,paramsSeen,stringSeen,value,entries,paramsBytes,entryBytes,paramsScalars,entryScalars,rootAt,paramsAt,paramsEnd,entryAt,fuzAt,done}

def root_entries(+state: RootData) -> U32:
  match state:
    case RootData{+rootSeen,+paramsSeen,+stringSeen,+fuzSeen,+entries,+paramsBytes,+entryBytes,+paramsScalars,+entryScalars,+rootAt,+paramsAt,+paramsEnd,+entryAt,+fuzAt,+done}: entries

def root_set_entries(+state: RootData, +value: U32) -> RootData:
  match state:
    case RootData{+rootSeen,+paramsSeen,+stringSeen,+fuzSeen,+entries,+paramsBytes,+entryBytes,+paramsScalars,+entryScalars,+rootAt,+paramsAt,+paramsEnd,+entryAt,+fuzAt,+done}: RootData{rootSeen,paramsSeen,stringSeen,fuzSeen,value,paramsBytes,entryBytes,paramsScalars,entryScalars,rootAt,paramsAt,paramsEnd,entryAt,fuzAt,done}

def root_paramsBytes(+state: RootData) -> U32:
  match state:
    case RootData{+rootSeen,+paramsSeen,+stringSeen,+fuzSeen,+entries,+paramsBytes,+entryBytes,+paramsScalars,+entryScalars,+rootAt,+paramsAt,+paramsEnd,+entryAt,+fuzAt,+done}: paramsBytes

def root_set_paramsBytes(+state: RootData, +value: U32) -> RootData:
  match state:
    case RootData{+rootSeen,+paramsSeen,+stringSeen,+fuzSeen,+entries,+paramsBytes,+entryBytes,+paramsScalars,+entryScalars,+rootAt,+paramsAt,+paramsEnd,+entryAt,+fuzAt,+done}: RootData{rootSeen,paramsSeen,stringSeen,fuzSeen,entries,value,entryBytes,paramsScalars,entryScalars,rootAt,paramsAt,paramsEnd,entryAt,fuzAt,done}

def root_entryBytes(+state: RootData) -> U32:
  match state:
    case RootData{+rootSeen,+paramsSeen,+stringSeen,+fuzSeen,+entries,+paramsBytes,+entryBytes,+paramsScalars,+entryScalars,+rootAt,+paramsAt,+paramsEnd,+entryAt,+fuzAt,+done}: entryBytes

def root_set_entryBytes(+state: RootData, +value: U32) -> RootData:
  match state:
    case RootData{+rootSeen,+paramsSeen,+stringSeen,+fuzSeen,+entries,+paramsBytes,+entryBytes,+paramsScalars,+entryScalars,+rootAt,+paramsAt,+paramsEnd,+entryAt,+fuzAt,+done}: RootData{rootSeen,paramsSeen,stringSeen,fuzSeen,entries,paramsBytes,value,paramsScalars,entryScalars,rootAt,paramsAt,paramsEnd,entryAt,fuzAt,done}

def root_paramsScalars(+state: RootData) -> U32:
  match state:
    case RootData{+rootSeen,+paramsSeen,+stringSeen,+fuzSeen,+entries,+paramsBytes,+entryBytes,+paramsScalars,+entryScalars,+rootAt,+paramsAt,+paramsEnd,+entryAt,+fuzAt,+done}: paramsScalars

def root_set_paramsScalars(+state: RootData, +value: U32) -> RootData:
  match state:
    case RootData{+rootSeen,+paramsSeen,+stringSeen,+fuzSeen,+entries,+paramsBytes,+entryBytes,+paramsScalars,+entryScalars,+rootAt,+paramsAt,+paramsEnd,+entryAt,+fuzAt,+done}: RootData{rootSeen,paramsSeen,stringSeen,fuzSeen,entries,paramsBytes,entryBytes,value,entryScalars,rootAt,paramsAt,paramsEnd,entryAt,fuzAt,done}

def root_entryScalars(+state: RootData) -> U32:
  match state:
    case RootData{+rootSeen,+paramsSeen,+stringSeen,+fuzSeen,+entries,+paramsBytes,+entryBytes,+paramsScalars,+entryScalars,+rootAt,+paramsAt,+paramsEnd,+entryAt,+fuzAt,+done}: entryScalars

def root_set_entryScalars(+state: RootData, +value: U32) -> RootData:
  match state:
    case RootData{+rootSeen,+paramsSeen,+stringSeen,+fuzSeen,+entries,+paramsBytes,+entryBytes,+paramsScalars,+entryScalars,+rootAt,+paramsAt,+paramsEnd,+entryAt,+fuzAt,+done}: RootData{rootSeen,paramsSeen,stringSeen,fuzSeen,entries,paramsBytes,entryBytes,paramsScalars,value,rootAt,paramsAt,paramsEnd,entryAt,fuzAt,done}

def root_rootAt(+state: RootData) -> T.Position:
  match state:
    case RootData{+rootSeen,+paramsSeen,+stringSeen,+fuzSeen,+entries,+paramsBytes,+entryBytes,+paramsScalars,+entryScalars,+rootAt,+paramsAt,+paramsEnd,+entryAt,+fuzAt,+done}: rootAt

def root_set_rootAt(+state: RootData, +value: T.Position) -> RootData:
  match state:
    case RootData{+rootSeen,+paramsSeen,+stringSeen,+fuzSeen,+entries,+paramsBytes,+entryBytes,+paramsScalars,+entryScalars,+rootAt,+paramsAt,+paramsEnd,+entryAt,+fuzAt,+done}: RootData{rootSeen,paramsSeen,stringSeen,fuzSeen,entries,paramsBytes,entryBytes,paramsScalars,entryScalars,value,paramsAt,paramsEnd,entryAt,fuzAt,done}

def root_paramsAt(+state: RootData) -> T.Position:
  match state:
    case RootData{+rootSeen,+paramsSeen,+stringSeen,+fuzSeen,+entries,+paramsBytes,+entryBytes,+paramsScalars,+entryScalars,+rootAt,+paramsAt,+paramsEnd,+entryAt,+fuzAt,+done}: paramsAt

def root_set_paramsAt(+state: RootData, +value: T.Position) -> RootData:
  match state:
    case RootData{+rootSeen,+paramsSeen,+stringSeen,+fuzSeen,+entries,+paramsBytes,+entryBytes,+paramsScalars,+entryScalars,+rootAt,+paramsAt,+paramsEnd,+entryAt,+fuzAt,+done}: RootData{rootSeen,paramsSeen,stringSeen,fuzSeen,entries,paramsBytes,entryBytes,paramsScalars,entryScalars,rootAt,value,paramsEnd,entryAt,fuzAt,done}

def root_paramsEnd(+state: RootData) -> T.Position:
  match state:
    case RootData{+rootSeen,+paramsSeen,+stringSeen,+fuzSeen,+entries,+paramsBytes,+entryBytes,+paramsScalars,+entryScalars,+rootAt,+paramsAt,+paramsEnd,+entryAt,+fuzAt,+done}: paramsEnd

def root_set_paramsEnd(+state: RootData, +value: T.Position) -> RootData:
  match state:
    case RootData{+rootSeen,+paramsSeen,+stringSeen,+fuzSeen,+entries,+paramsBytes,+entryBytes,+paramsScalars,+entryScalars,+rootAt,+paramsAt,+paramsEnd,+entryAt,+fuzAt,+done}: RootData{rootSeen,paramsSeen,stringSeen,fuzSeen,entries,paramsBytes,entryBytes,paramsScalars,entryScalars,rootAt,paramsAt,value,entryAt,fuzAt,done}

def root_entryAt(+state: RootData) -> T.Position:
  match state:
    case RootData{+rootSeen,+paramsSeen,+stringSeen,+fuzSeen,+entries,+paramsBytes,+entryBytes,+paramsScalars,+entryScalars,+rootAt,+paramsAt,+paramsEnd,+entryAt,+fuzAt,+done}: entryAt

def root_set_entryAt(+state: RootData, +value: T.Position) -> RootData:
  match state:
    case RootData{+rootSeen,+paramsSeen,+stringSeen,+fuzSeen,+entries,+paramsBytes,+entryBytes,+paramsScalars,+entryScalars,+rootAt,+paramsAt,+paramsEnd,+entryAt,+fuzAt,+done}: RootData{rootSeen,paramsSeen,stringSeen,fuzSeen,entries,paramsBytes,entryBytes,paramsScalars,entryScalars,rootAt,paramsAt,paramsEnd,value,fuzAt,done}

def root_fuzAt(+state: RootData) -> T.Position:
  match state:
    case RootData{+rootSeen,+paramsSeen,+stringSeen,+fuzSeen,+entries,+paramsBytes,+entryBytes,+paramsScalars,+entryScalars,+rootAt,+paramsAt,+paramsEnd,+entryAt,+fuzAt,+done}: fuzAt

def root_set_fuzAt(+state: RootData, +value: T.Position) -> RootData:
  match state:
    case RootData{+rootSeen,+paramsSeen,+stringSeen,+fuzSeen,+entries,+paramsBytes,+entryBytes,+paramsScalars,+entryScalars,+rootAt,+paramsAt,+paramsEnd,+entryAt,+fuzAt,+done}: RootData{rootSeen,paramsSeen,stringSeen,fuzSeen,entries,paramsBytes,entryBytes,paramsScalars,entryScalars,rootAt,paramsAt,paramsEnd,entryAt,value,done}

def root_done(+state: RootData) -> Bool:
  match state:
    case RootData{+rootSeen,+paramsSeen,+stringSeen,+fuzSeen,+entries,+paramsBytes,+entryBytes,+paramsScalars,+entryScalars,+rootAt,+paramsAt,+paramsEnd,+entryAt,+fuzAt,+done}: done

def root_set_done(+state: RootData, +value: Bool) -> RootData:
  match state:
    case RootData{+rootSeen,+paramsSeen,+stringSeen,+fuzSeen,+entries,+paramsBytes,+entryBytes,+paramsScalars,+entryScalars,+rootAt,+paramsAt,+paramsEnd,+entryAt,+fuzAt,+done}: RootData{rootSeen,paramsSeen,stringSeen,fuzSeen,entries,paramsBytes,entryBytes,paramsScalars,entryScalars,rootAt,paramsAt,paramsEnd,entryAt,fuzAt,value}

def ctl_role(+state: Control) -> U32:
  match state:
    case Control{+role,+parent,+pending,+tagAt,+attrMask,+attrId,+number,+attrLength,+leafParent,+leafAt,+leafStart,+leafLength,+leafBytes,+first,+last,+packedRecord,+packedField,+edidAscii,+edidPipe,+edidBracket,+edidNumber}: role

def ctl_set_role(+state: Control, +value: U32) -> Control:
  match state:
    case Control{+role,+parent,+pending,+tagAt,+attrMask,+attrId,+number,+attrLength,+leafParent,+leafAt,+leafStart,+leafLength,+leafBytes,+first,+last,+packedRecord,+packedField,+edidAscii,+edidPipe,+edidBracket,+edidNumber}: Control{value,parent,pending,tagAt,attrMask,attrId,number,attrLength,leafParent,leafAt,leafStart,leafLength,leafBytes,first,last,packedRecord,packedField,edidAscii,edidPipe,edidBracket,edidNumber}

def ctl_parent(+state: Control) -> U32:
  match state:
    case Control{+role,+parent,+pending,+tagAt,+attrMask,+attrId,+number,+attrLength,+leafParent,+leafAt,+leafStart,+leafLength,+leafBytes,+first,+last,+packedRecord,+packedField,+edidAscii,+edidPipe,+edidBracket,+edidNumber}: parent

def ctl_set_parent(+state: Control, +value: U32) -> Control:
  match state:
    case Control{+role,+parent,+pending,+tagAt,+attrMask,+attrId,+number,+attrLength,+leafParent,+leafAt,+leafStart,+leafLength,+leafBytes,+first,+last,+packedRecord,+packedField,+edidAscii,+edidPipe,+edidBracket,+edidNumber}: Control{role,value,pending,tagAt,attrMask,attrId,number,attrLength,leafParent,leafAt,leafStart,leafLength,leafBytes,first,last,packedRecord,packedField,edidAscii,edidPipe,edidBracket,edidNumber}

def ctl_pending(+state: Control) -> U32:
  match state:
    case Control{+role,+parent,+pending,+tagAt,+attrMask,+attrId,+number,+attrLength,+leafParent,+leafAt,+leafStart,+leafLength,+leafBytes,+first,+last,+packedRecord,+packedField,+edidAscii,+edidPipe,+edidBracket,+edidNumber}: pending

def ctl_set_pending(+state: Control, +value: U32) -> Control:
  match state:
    case Control{+role,+parent,+pending,+tagAt,+attrMask,+attrId,+number,+attrLength,+leafParent,+leafAt,+leafStart,+leafLength,+leafBytes,+first,+last,+packedRecord,+packedField,+edidAscii,+edidPipe,+edidBracket,+edidNumber}: Control{role,parent,value,tagAt,attrMask,attrId,number,attrLength,leafParent,leafAt,leafStart,leafLength,leafBytes,first,last,packedRecord,packedField,edidAscii,edidPipe,edidBracket,edidNumber}

def ctl_tagAt(+state: Control) -> T.Position:
  match state:
    case Control{+role,+parent,+pending,+tagAt,+attrMask,+attrId,+number,+attrLength,+leafParent,+leafAt,+leafStart,+leafLength,+leafBytes,+first,+last,+packedRecord,+packedField,+edidAscii,+edidPipe,+edidBracket,+edidNumber}: tagAt

def ctl_set_tagAt(+state: Control, +value: T.Position) -> Control:
  match state:
    case Control{+role,+parent,+pending,+tagAt,+attrMask,+attrId,+number,+attrLength,+leafParent,+leafAt,+leafStart,+leafLength,+leafBytes,+first,+last,+packedRecord,+packedField,+edidAscii,+edidPipe,+edidBracket,+edidNumber}: Control{role,parent,pending,value,attrMask,attrId,number,attrLength,leafParent,leafAt,leafStart,leafLength,leafBytes,first,last,packedRecord,packedField,edidAscii,edidPipe,edidBracket,edidNumber}

def ctl_attrMask(+state: Control) -> U32:
  match state:
    case Control{+role,+parent,+pending,+tagAt,+attrMask,+attrId,+number,+attrLength,+leafParent,+leafAt,+leafStart,+leafLength,+leafBytes,+first,+last,+packedRecord,+packedField,+edidAscii,+edidPipe,+edidBracket,+edidNumber}: attrMask

def ctl_set_attrMask(+state: Control, +value: U32) -> Control:
  match state:
    case Control{+role,+parent,+pending,+tagAt,+attrMask,+attrId,+number,+attrLength,+leafParent,+leafAt,+leafStart,+leafLength,+leafBytes,+first,+last,+packedRecord,+packedField,+edidAscii,+edidPipe,+edidBracket,+edidNumber}: Control{role,parent,pending,tagAt,value,attrId,number,attrLength,leafParent,leafAt,leafStart,leafLength,leafBytes,first,last,packedRecord,packedField,edidAscii,edidPipe,edidBracket,edidNumber}

def ctl_attrId(+state: Control) -> U32:
  match state:
    case Control{+role,+parent,+pending,+tagAt,+attrMask,+attrId,+number,+attrLength,+leafParent,+leafAt,+leafStart,+leafLength,+leafBytes,+first,+last,+packedRecord,+packedField,+edidAscii,+edidPipe,+edidBracket,+edidNumber}: attrId

def ctl_set_attrId(+state: Control, +value: U32) -> Control:
  match state:
    case Control{+role,+parent,+pending,+tagAt,+attrMask,+attrId,+number,+attrLength,+leafParent,+leafAt,+leafStart,+leafLength,+leafBytes,+first,+last,+packedRecord,+packedField,+edidAscii,+edidPipe,+edidBracket,+edidNumber}: Control{role,parent,pending,tagAt,attrMask,value,number,attrLength,leafParent,leafAt,leafStart,leafLength,leafBytes,first,last,packedRecord,packedField,edidAscii,edidPipe,edidBracket,edidNumber}

def ctl_number(+state: Control) -> N.Number:
  match state:
    case Control{+role,+parent,+pending,+tagAt,+attrMask,+attrId,+number,+attrLength,+leafParent,+leafAt,+leafStart,+leafLength,+leafBytes,+first,+last,+packedRecord,+packedField,+edidAscii,+edidPipe,+edidBracket,+edidNumber}: number

def ctl_set_number(+state: Control, +value: N.Number) -> Control:
  match state:
    case Control{+role,+parent,+pending,+tagAt,+attrMask,+attrId,+number,+attrLength,+leafParent,+leafAt,+leafStart,+leafLength,+leafBytes,+first,+last,+packedRecord,+packedField,+edidAscii,+edidPipe,+edidBracket,+edidNumber}: Control{role,parent,pending,tagAt,attrMask,attrId,value,attrLength,leafParent,leafAt,leafStart,leafLength,leafBytes,first,last,packedRecord,packedField,edidAscii,edidPipe,edidBracket,edidNumber}

def ctl_attrLength(+state: Control) -> U32:
  match state:
    case Control{+role,+parent,+pending,+tagAt,+attrMask,+attrId,+number,+attrLength,+leafParent,+leafAt,+leafStart,+leafLength,+leafBytes,+first,+last,+packedRecord,+packedField,+edidAscii,+edidPipe,+edidBracket,+edidNumber}: attrLength

def ctl_set_attrLength(+state: Control, +value: U32) -> Control:
  match state:
    case Control{+role,+parent,+pending,+tagAt,+attrMask,+attrId,+number,+attrLength,+leafParent,+leafAt,+leafStart,+leafLength,+leafBytes,+first,+last,+packedRecord,+packedField,+edidAscii,+edidPipe,+edidBracket,+edidNumber}: Control{role,parent,pending,tagAt,attrMask,attrId,number,value,leafParent,leafAt,leafStart,leafLength,leafBytes,first,last,packedRecord,packedField,edidAscii,edidPipe,edidBracket,edidNumber}

def ctl_leafParent(+state: Control) -> U32:
  match state:
    case Control{+role,+parent,+pending,+tagAt,+attrMask,+attrId,+number,+attrLength,+leafParent,+leafAt,+leafStart,+leafLength,+leafBytes,+first,+last,+packedRecord,+packedField,+edidAscii,+edidPipe,+edidBracket,+edidNumber}: leafParent

def ctl_set_leafParent(+state: Control, +value: U32) -> Control:
  match state:
    case Control{+role,+parent,+pending,+tagAt,+attrMask,+attrId,+number,+attrLength,+leafParent,+leafAt,+leafStart,+leafLength,+leafBytes,+first,+last,+packedRecord,+packedField,+edidAscii,+edidPipe,+edidBracket,+edidNumber}: Control{role,parent,pending,tagAt,attrMask,attrId,number,attrLength,value,leafAt,leafStart,leafLength,leafBytes,first,last,packedRecord,packedField,edidAscii,edidPipe,edidBracket,edidNumber}

def ctl_leafAt(+state: Control) -> T.Position:
  match state:
    case Control{+role,+parent,+pending,+tagAt,+attrMask,+attrId,+number,+attrLength,+leafParent,+leafAt,+leafStart,+leafLength,+leafBytes,+first,+last,+packedRecord,+packedField,+edidAscii,+edidPipe,+edidBracket,+edidNumber}: leafAt

def ctl_set_leafAt(+state: Control, +value: T.Position) -> Control:
  match state:
    case Control{+role,+parent,+pending,+tagAt,+attrMask,+attrId,+number,+attrLength,+leafParent,+leafAt,+leafStart,+leafLength,+leafBytes,+first,+last,+packedRecord,+packedField,+edidAscii,+edidPipe,+edidBracket,+edidNumber}: Control{role,parent,pending,tagAt,attrMask,attrId,number,attrLength,leafParent,value,leafStart,leafLength,leafBytes,first,last,packedRecord,packedField,edidAscii,edidPipe,edidBracket,edidNumber}

def ctl_leafStart(+state: Control) -> U32:
  match state:
    case Control{+role,+parent,+pending,+tagAt,+attrMask,+attrId,+number,+attrLength,+leafParent,+leafAt,+leafStart,+leafLength,+leafBytes,+first,+last,+packedRecord,+packedField,+edidAscii,+edidPipe,+edidBracket,+edidNumber}: leafStart

def ctl_set_leafStart(+state: Control, +value: U32) -> Control:
  match state:
    case Control{+role,+parent,+pending,+tagAt,+attrMask,+attrId,+number,+attrLength,+leafParent,+leafAt,+leafStart,+leafLength,+leafBytes,+first,+last,+packedRecord,+packedField,+edidAscii,+edidPipe,+edidBracket,+edidNumber}: Control{role,parent,pending,tagAt,attrMask,attrId,number,attrLength,leafParent,leafAt,value,leafLength,leafBytes,first,last,packedRecord,packedField,edidAscii,edidPipe,edidBracket,edidNumber}

def ctl_leafLength(+state: Control) -> U32:
  match state:
    case Control{+role,+parent,+pending,+tagAt,+attrMask,+attrId,+number,+attrLength,+leafParent,+leafAt,+leafStart,+leafLength,+leafBytes,+first,+last,+packedRecord,+packedField,+edidAscii,+edidPipe,+edidBracket,+edidNumber}: leafLength

def ctl_set_leafLength(+state: Control, +value: U32) -> Control:
  match state:
    case Control{+role,+parent,+pending,+tagAt,+attrMask,+attrId,+number,+attrLength,+leafParent,+leafAt,+leafStart,+leafLength,+leafBytes,+first,+last,+packedRecord,+packedField,+edidAscii,+edidPipe,+edidBracket,+edidNumber}: Control{role,parent,pending,tagAt,attrMask,attrId,number,attrLength,leafParent,leafAt,leafStart,value,leafBytes,first,last,packedRecord,packedField,edidAscii,edidPipe,edidBracket,edidNumber}

def ctl_leafBytes(+state: Control) -> U32:
  match state:
    case Control{+role,+parent,+pending,+tagAt,+attrMask,+attrId,+number,+attrLength,+leafParent,+leafAt,+leafStart,+leafLength,+leafBytes,+first,+last,+packedRecord,+packedField,+edidAscii,+edidPipe,+edidBracket,+edidNumber}: leafBytes

def ctl_set_leafBytes(+state: Control, +value: U32) -> Control:
  match state:
    case Control{+role,+parent,+pending,+tagAt,+attrMask,+attrId,+number,+attrLength,+leafParent,+leafAt,+leafStart,+leafLength,+leafBytes,+first,+last,+packedRecord,+packedField,+edidAscii,+edidPipe,+edidBracket,+edidNumber}: Control{role,parent,pending,tagAt,attrMask,attrId,number,attrLength,leafParent,leafAt,leafStart,leafLength,value,first,last,packedRecord,packedField,edidAscii,edidPipe,edidBracket,edidNumber}

def ctl_first(+state: Control) -> U32:
  match state:
    case Control{+role,+parent,+pending,+tagAt,+attrMask,+attrId,+number,+attrLength,+leafParent,+leafAt,+leafStart,+leafLength,+leafBytes,+first,+last,+packedRecord,+packedField,+edidAscii,+edidPipe,+edidBracket,+edidNumber}: first

def ctl_set_first(+state: Control, +value: U32) -> Control:
  match state:
    case Control{+role,+parent,+pending,+tagAt,+attrMask,+attrId,+number,+attrLength,+leafParent,+leafAt,+leafStart,+leafLength,+leafBytes,+first,+last,+packedRecord,+packedField,+edidAscii,+edidPipe,+edidBracket,+edidNumber}: Control{role,parent,pending,tagAt,attrMask,attrId,number,attrLength,leafParent,leafAt,leafStart,leafLength,leafBytes,value,last,packedRecord,packedField,edidAscii,edidPipe,edidBracket,edidNumber}

def ctl_last(+state: Control) -> U32:
  match state:
    case Control{+role,+parent,+pending,+tagAt,+attrMask,+attrId,+number,+attrLength,+leafParent,+leafAt,+leafStart,+leafLength,+leafBytes,+first,+last,+packedRecord,+packedField,+edidAscii,+edidPipe,+edidBracket,+edidNumber}: last

def ctl_set_last(+state: Control, +value: U32) -> Control:
  match state:
    case Control{+role,+parent,+pending,+tagAt,+attrMask,+attrId,+number,+attrLength,+leafParent,+leafAt,+leafStart,+leafLength,+leafBytes,+first,+last,+packedRecord,+packedField,+edidAscii,+edidPipe,+edidBracket,+edidNumber}: Control{role,parent,pending,tagAt,attrMask,attrId,number,attrLength,leafParent,leafAt,leafStart,leafLength,leafBytes,first,value,packedRecord,packedField,edidAscii,edidPipe,edidBracket,edidNumber}

def ctl_packedRecord(+state: Control) -> U32:
  match state:
    case Control{+role,+parent,+pending,+tagAt,+attrMask,+attrId,+number,+attrLength,+leafParent,+leafAt,+leafStart,+leafLength,+leafBytes,+first,+last,+packedRecord,+packedField,+edidAscii,+edidPipe,+edidBracket,+edidNumber}: packedRecord

def ctl_set_packedRecord(+state: Control, +value: U32) -> Control:
  match state:
    case Control{+role,+parent,+pending,+tagAt,+attrMask,+attrId,+number,+attrLength,+leafParent,+leafAt,+leafStart,+leafLength,+leafBytes,+first,+last,+packedRecord,+packedField,+edidAscii,+edidPipe,+edidBracket,+edidNumber}: Control{role,parent,pending,tagAt,attrMask,attrId,number,attrLength,leafParent,leafAt,leafStart,leafLength,leafBytes,first,last,value,packedField,edidAscii,edidPipe,edidBracket,edidNumber}

def ctl_packedField(+state: Control) -> U32:
  match state:
    case Control{+role,+parent,+pending,+tagAt,+attrMask,+attrId,+number,+attrLength,+leafParent,+leafAt,+leafStart,+leafLength,+leafBytes,+first,+last,+packedRecord,+packedField,+edidAscii,+edidPipe,+edidBracket,+edidNumber}: packedField

def ctl_set_packedField(+state: Control, +value: U32) -> Control:
  match state:
    case Control{+role,+parent,+pending,+tagAt,+attrMask,+attrId,+number,+attrLength,+leafParent,+leafAt,+leafStart,+leafLength,+leafBytes,+first,+last,+packedRecord,+packedField,+edidAscii,+edidPipe,+edidBracket,+edidNumber}: Control{role,parent,pending,tagAt,attrMask,attrId,number,attrLength,leafParent,leafAt,leafStart,leafLength,leafBytes,first,last,packedRecord,value,edidAscii,edidPipe,edidBracket,edidNumber}

def ctl_edidAscii(+state: Control) -> Bool:
  match state:
    case Control{+role,+parent,+pending,+tagAt,+attrMask,+attrId,+number,+attrLength,+leafParent,+leafAt,+leafStart,+leafLength,+leafBytes,+first,+last,+packedRecord,+packedField,+edidAscii,+edidPipe,+edidBracket,+edidNumber}: edidAscii

def ctl_set_edidAscii(+state: Control, +value: Bool) -> Control:
  match state:
    case Control{+role,+parent,+pending,+tagAt,+attrMask,+attrId,+number,+attrLength,+leafParent,+leafAt,+leafStart,+leafLength,+leafBytes,+first,+last,+packedRecord,+packedField,+edidAscii,+edidPipe,+edidBracket,+edidNumber}: Control{role,parent,pending,tagAt,attrMask,attrId,number,attrLength,leafParent,leafAt,leafStart,leafLength,leafBytes,first,last,packedRecord,packedField,value,edidPipe,edidBracket,edidNumber}

def ctl_edidPipe(+state: Control) -> Bool:
  match state:
    case Control{+role,+parent,+pending,+tagAt,+attrMask,+attrId,+number,+attrLength,+leafParent,+leafAt,+leafStart,+leafLength,+leafBytes,+first,+last,+packedRecord,+packedField,+edidAscii,+edidPipe,+edidBracket,+edidNumber}: edidPipe

def ctl_set_edidPipe(+state: Control, +value: Bool) -> Control:
  match state:
    case Control{+role,+parent,+pending,+tagAt,+attrMask,+attrId,+number,+attrLength,+leafParent,+leafAt,+leafStart,+leafLength,+leafBytes,+first,+last,+packedRecord,+packedField,+edidAscii,+edidPipe,+edidBracket,+edidNumber}: Control{role,parent,pending,tagAt,attrMask,attrId,number,attrLength,leafParent,leafAt,leafStart,leafLength,leafBytes,first,last,packedRecord,packedField,edidAscii,value,edidBracket,edidNumber}

def ctl_edidBracket(+state: Control) -> Bool:
  match state:
    case Control{+role,+parent,+pending,+tagAt,+attrMask,+attrId,+number,+attrLength,+leafParent,+leafAt,+leafStart,+leafLength,+leafBytes,+first,+last,+packedRecord,+packedField,+edidAscii,+edidPipe,+edidBracket,+edidNumber}: edidBracket

def ctl_set_edidBracket(+state: Control, +value: Bool) -> Control:
  match state:
    case Control{+role,+parent,+pending,+tagAt,+attrMask,+attrId,+number,+attrLength,+leafParent,+leafAt,+leafStart,+leafLength,+leafBytes,+first,+last,+packedRecord,+packedField,+edidAscii,+edidPipe,+edidBracket,+edidNumber}: Control{role,parent,pending,tagAt,attrMask,attrId,number,attrLength,leafParent,leafAt,leafStart,leafLength,leafBytes,first,last,packedRecord,packedField,edidAscii,edidPipe,value,edidNumber}

def ctl_edidNumber(+state: Control) -> N.Number:
  match state:
    case Control{+role,+parent,+pending,+tagAt,+attrMask,+attrId,+number,+attrLength,+leafParent,+leafAt,+leafStart,+leafLength,+leafBytes,+first,+last,+packedRecord,+packedField,+edidAscii,+edidPipe,+edidBracket,+edidNumber}: edidNumber

def ctl_set_edidNumber(+state: Control, +value: N.Number) -> Control:
  match state:
    case Control{+role,+parent,+pending,+tagAt,+attrMask,+attrId,+number,+attrLength,+leafParent,+leafAt,+leafStart,+leafLength,+leafBytes,+first,+last,+packedRecord,+packedField,+edidAscii,+edidPipe,+edidBracket,+edidNumber}: Control{role,parent,pending,tagAt,attrMask,attrId,number,attrLength,leafParent,leafAt,leafStart,leafLength,leafBytes,first,last,packedRecord,packedField,edidAscii,edidPipe,edidBracket,value}

def val_list(+state: EntryValues) -> U32:
  match state:
    case EntryValues{+list,+partial,+sid,+rec,+index,+maximum,+identity,+edid,+sourceText,+destText,+fuz}: list

def val_set_list(+state: EntryValues, +value: U32) -> EntryValues:
  match state:
    case EntryValues{+list,+partial,+sid,+rec,+index,+maximum,+identity,+edid,+sourceText,+destText,+fuz}: EntryValues{value,partial,sid,rec,index,maximum,identity,edid,sourceText,destText,fuz}

def val_partial(+state: EntryValues) -> T.Partial:
  match state:
    case EntryValues{+list,+partial,+sid,+rec,+index,+maximum,+identity,+edid,+sourceText,+destText,+fuz}: partial

def val_set_partial(+state: EntryValues, +value: T.Partial) -> EntryValues:
  match state:
    case EntryValues{+list,+partial,+sid,+rec,+index,+maximum,+identity,+edid,+sourceText,+destText,+fuz}: EntryValues{list,value,sid,rec,index,maximum,identity,edid,sourceText,destText,fuz}

def val_sid(+state: EntryValues) -> Maybe<&2, T.Sid>:
  match state:
    case EntryValues{+list,+partial,+sid,+rec,+index,+maximum,+identity,+edid,+sourceText,+destText,+fuz}: sid

def val_set_sid(+state: EntryValues, +value: Maybe<&2, T.Sid>) -> EntryValues:
  match state:
    case EntryValues{+list,+partial,+sid,+rec,+index,+maximum,+identity,+edid,+sourceText,+destText,+fuz}: EntryValues{list,partial,value,rec,index,maximum,identity,edid,sourceText,destText,fuz}

def val_rec(+state: EntryValues) -> T.Rec:
  match state:
    case EntryValues{+list,+partial,+sid,+rec,+index,+maximum,+identity,+edid,+sourceText,+destText,+fuz}: rec

def val_set_rec(+state: EntryValues, +value: T.Rec) -> EntryValues:
  match state:
    case EntryValues{+list,+partial,+sid,+rec,+index,+maximum,+identity,+edid,+sourceText,+destText,+fuz}: EntryValues{list,partial,sid,value,index,maximum,identity,edid,sourceText,destText,fuz}

def val_index(+state: EntryValues) -> Maybe<&2, U32>:
  match state:
    case EntryValues{+list,+partial,+sid,+rec,+index,+maximum,+identity,+edid,+sourceText,+destText,+fuz}: index

def val_set_index(+state: EntryValues, +value: Maybe<&2, U32>) -> EntryValues:
  match state:
    case EntryValues{+list,+partial,+sid,+rec,+index,+maximum,+identity,+edid,+sourceText,+destText,+fuz}: EntryValues{list,partial,sid,rec,value,maximum,identity,edid,sourceText,destText,fuz}

def val_maximum(+state: EntryValues) -> Maybe<&2, U32>:
  match state:
    case EntryValues{+list,+partial,+sid,+rec,+index,+maximum,+identity,+edid,+sourceText,+destText,+fuz}: maximum

def val_set_maximum(+state: EntryValues, +value: Maybe<&2, U32>) -> EntryValues:
  match state:
    case EntryValues{+list,+partial,+sid,+rec,+index,+maximum,+identity,+edid,+sourceText,+destText,+fuz}: EntryValues{list,partial,sid,rec,index,value,identity,edid,sourceText,destText,fuz}

def val_identity(+state: EntryValues) -> T.Identity:
  match state:
    case EntryValues{+list,+partial,+sid,+rec,+index,+maximum,+identity,+edid,+sourceText,+destText,+fuz}: identity

def val_set_identity(+state: EntryValues, +value: T.Identity) -> EntryValues:
  match state:
    case EntryValues{+list,+partial,+sid,+rec,+index,+maximum,+identity,+edid,+sourceText,+destText,+fuz}: EntryValues{list,partial,sid,rec,index,maximum,value,edid,sourceText,destText,fuz}

def val_edid(+state: EntryValues) -> T.FieldRef:
  match state:
    case EntryValues{+list,+partial,+sid,+rec,+index,+maximum,+identity,+edid,+sourceText,+destText,+fuz}: edid

def val_set_edid(+state: EntryValues, +value: T.FieldRef) -> EntryValues:
  match state:
    case EntryValues{+list,+partial,+sid,+rec,+index,+maximum,+identity,+edid,+sourceText,+destText,+fuz}: EntryValues{list,partial,sid,rec,index,maximum,identity,value,sourceText,destText,fuz}

def val_sourceText(+state: EntryValues) -> T.FieldRef:
  match state:
    case EntryValues{+list,+partial,+sid,+rec,+index,+maximum,+identity,+edid,+sourceText,+destText,+fuz}: sourceText

def val_set_sourceText(+state: EntryValues, +value: T.FieldRef) -> EntryValues:
  match state:
    case EntryValues{+list,+partial,+sid,+rec,+index,+maximum,+identity,+edid,+sourceText,+destText,+fuz}: EntryValues{list,partial,sid,rec,index,maximum,identity,edid,value,destText,fuz}

def val_destText(+state: EntryValues) -> T.FieldRef:
  match state:
    case EntryValues{+list,+partial,+sid,+rec,+index,+maximum,+identity,+edid,+sourceText,+destText,+fuz}: destText

def val_set_destText(+state: EntryValues, +value: T.FieldRef) -> EntryValues:
  match state:
    case EntryValues{+list,+partial,+sid,+rec,+index,+maximum,+identity,+edid,+sourceText,+destText,+fuz}: EntryValues{list,partial,sid,rec,index,maximum,identity,edid,sourceText,value,fuz}

def val_fuz(+state: EntryValues) -> T.Fuz:
  match state:
    case EntryValues{+list,+partial,+sid,+rec,+index,+maximum,+identity,+edid,+sourceText,+destText,+fuz}: fuz

def val_set_fuz(+state: EntryValues, +value: T.Fuz) -> EntryValues:
  match state:
    case EntryValues{+list,+partial,+sid,+rec,+index,+maximum,+identity,+edid,+sourceText,+destText,+fuz}: EntryValues{list,partial,sid,rec,index,maximum,identity,edid,sourceText,destText,value}

def param_addon(+state: ParamValues) -> T.FieldRef:
  match state:
    case ParamValues{+addon,+sourceLanguage,+destLanguage}: addon

def param_set_addon(+state: ParamValues, +value: T.FieldRef) -> ParamValues:
  match state:
    case ParamValues{+addon,+sourceLanguage,+destLanguage}: ParamValues{value,sourceLanguage,destLanguage}

def param_sourceLanguage(+state: ParamValues) -> T.FieldRef:
  match state:
    case ParamValues{+addon,+sourceLanguage,+destLanguage}: sourceLanguage

def param_set_sourceLanguage(+state: ParamValues, +value: T.FieldRef) -> ParamValues:
  match state:
    case ParamValues{+addon,+sourceLanguage,+destLanguage}: ParamValues{addon,value,destLanguage}

def param_destLanguage(+state: ParamValues) -> T.FieldRef:
  match state:
    case ParamValues{+addon,+sourceLanguage,+destLanguage}: destLanguage

def param_set_destLanguage(+state: ParamValues, +value: T.FieldRef) -> ParamValues:
  match state:
    case ParamValues{+addon,+sourceLanguage,+destLanguage}: ParamValues{addon,sourceLanguage,value}

def state_source(+state: State) -> T.SourceKey:
  match state:
    case State{+source,+limits,+root,+control,+values,+params,+valid}: source

def state_set_source(+state: State, +value: T.SourceKey) -> State:
  match state:
    case State{+source,+limits,+root,+control,+values,+params,+valid}: State{value,limits,root,control,values,params,valid}

def state_limits(+state: State) -> T.Limits:
  match state:
    case State{+source,+limits,+root,+control,+values,+params,+valid}: limits

def state_set_limits(+state: State, +value: T.Limits) -> State:
  match state:
    case State{+source,+limits,+root,+control,+values,+params,+valid}: State{source,value,root,control,values,params,valid}

def state_root(+state: State) -> RootData:
  match state:
    case State{+source,+limits,+root,+control,+values,+params,+valid}: root

def state_set_root(+state: State, +value: RootData) -> State:
  match state:
    case State{+source,+limits,+root,+control,+values,+params,+valid}: State{source,limits,value,control,values,params,valid}

def state_control(+state: State) -> Control:
  match state:
    case State{+source,+limits,+root,+control,+values,+params,+valid}: control

def state_set_control(+state: State, +value: Control) -> State:
  match state:
    case State{+source,+limits,+root,+control,+values,+params,+valid}: State{source,limits,root,value,values,params,valid}

def state_values(+state: State) -> EntryValues:
  match state:
    case State{+source,+limits,+root,+control,+values,+params,+valid}: values

def state_set_values(+state: State, +value: EntryValues) -> State:
  match state:
    case State{+source,+limits,+root,+control,+values,+params,+valid}: State{source,limits,root,control,value,params,valid}

def state_params(+state: State) -> ParamValues:
  match state:
    case State{+source,+limits,+root,+control,+values,+params,+valid}: params

def state_set_params(+state: State, +value: ParamValues) -> State:
  match state:
    case State{+source,+limits,+root,+control,+values,+params,+valid}: State{source,limits,root,control,values,value,valid}

def state_valid(+state: State) -> Bool:
  match state:
    case State{+source,+limits,+root,+control,+values,+params,+valid}: valid

def state_set_valid(+state: State, +value: Bool) -> State:
  match state:
    case State{+source,+limits,+root,+control,+values,+params,+valid}: State{source,limits,root,control,values,params,value}
def zero() -> T.Position:
  T.zero_position()

def empty_control() -> Control:
  Control{0,0,0,zero(),0,0,N.begin(False{}),0,0,zero(),0,0,0,0,0,0,0,True{},False{},True{},N.begin(True{})}

def empty_values() -> EntryValues:
  EntryValues{3,T.TranslatedAbsent{},None{},T.Rec{0,0,T.Unspecified{}},None{},None{},T.LiteralEdid{},T.missing_field(),T.missing_field(),T.missing_field(),T.Fuz{False{},0,0,T.empty_span()}}

def valid_limits(+limits: T.Limits) -> Bool:
  match limits:
    case T.Limits{+a,+b,+c,+d,+e,+f,+g,+h,+i}: Bool.and(U32.is_le(a,67108864),Bool.and(Bool.and(U32.is_gt(b,0),U32.is_le(b,64)),Bool.and(U32.is_le(c,200000),Bool.and(U32.is_le(d,1048576),Bool.and(U32.is_le(e,4096),Bool.and(U32.is_le(f,64),Bool.and(U32.is_le(g,64),Bool.and(U32.is_le(h,4096),U32.is_le(i,4096)))))))))

def init(+source: T.SourceKey, +limits: T.Limits) -> State:
  State{source,limits,RootData{0,0,0,0,0,0,0,0,0,zero(),zero(),zero(),zero(),zero(),False{}},empty_control(),empty_values(),ParamValues{T.missing_field(),T.missing_field(),T.missing_field()},valid_limits(limits)}

def active(+state: State) -> Bool:
  Bool.or(U32.is_eq(ctl_pending(state_control(state)),8),Bool.or(U32.is_eq(ctl_role(state_control(state)),8),Bool.or(U32.is_eq(ctl_role(state_control(state)),11),Bool.or(U32.is_eq(ctl_leafParent(state_control(state)),8),U32.is_eq(ctl_leafParent(state_control(state)),11)))))

def diagnostic_context(+state: State, +diagnostic: T.Diagnostic, +yes: Bool) -> T.Diagnostic:
  match diagnostic yes:
    case T.Diagnostic{+phase,+reason,+at,+entry,+start,+expected,+observed,+core,+source} True{}: T.Diagnostic{phase,reason,at,root_entries(state_root(state)),root_entryAt(state_root(state)),expected,observed,core,source}
    case _ False{}: diagnostic

def context(+state: State, +diagnostic: T.Diagnostic) -> T.Diagnostic:
  diagnostic_context(state,T.with_source(diagnostic,state_source(state)),active(state))

def reject(+state: State, +reason: U32, +at: T.Position, +expected: U32, +observed: U32) -> Step:
  Rejected{state,context(state,T.error(3,reason,at,expected,observed))}

def advance(+state: State) -> Step:
  Advance{state,NoAction{}}

def with_ctl(+state: State, +control: Control) -> State:
  state_set_control(state,control)

def with_root(+state: State, +root: RootData) -> State:
  state_set_root(state,root)

def role(+state: State, +role: U32) -> State:
  with_ctl(state,ctl_set_role(state_control(state),role))

def parent_of(+name: U32) -> U32:
  match name:
    case 1: 0
    case 2: 1
    case 7: 1
    case 8: 7
    case 11: 8
    case _: 0

def depth_case7(+name: U32, +parent: U32, +hit: Bool) -> U32:
  match hit:
    case True{}: 5
    case False{}: 0

def depth_case6(+name: U32, +parent: U32, +hit: Bool) -> U32:
  match hit:
    case True{}: 4
    case False{}: depth_case7(name,parent,U32.is_eq(parent,11))

def depth_case5(+name: U32, +parent: U32, +hit: Bool) -> U32:
  match hit:
    case True{}: 3
    case False{}: depth_case6(name,parent,U32.is_eq(parent,8))

def depth_case4(+name: U32, +parent: U32, +hit: Bool) -> U32:
  match hit:
    case True{}: 4
    case False{}: depth_case5(name,parent,U32.is_eq(parent,2))

def depth_case3(+name: U32, +parent: U32, +hit: Bool) -> U32:
  match hit:
    case True{}: 3
    case False{}: depth_case4(name,parent,U32.is_eq(name,11))

def depth_case2(+name: U32, +parent: U32, +hit: Bool) -> U32:
  match hit:
    case True{}: 2
    case False{}: depth_case3(name,parent,U32.is_eq(name,8))

def depth_case1(+name: U32, +parent: U32, +hit: Bool) -> U32:
  match hit:
    case True{}: 2
    case False{}: depth_case2(name,parent,U32.is_eq(name,7))

def depth_case0(+name: U32, +parent: U32, +hit: Bool) -> U32:
  match hit:
    case True{}: 1
    case False{}: depth_case1(name,parent,U32.is_eq(name,2))

def depth(+name: U32, +parent: U32) -> U32:
  depth_case0(name,parent,U32.is_eq(name,1))

def allowed_case14(+parent: U32, +name: U32, +hit: Bool) -> Bool:
  match hit:
    case True{}: True{}
    case False{}: False{}

def allowed_case13(+parent: U32, +name: U32, +hit: Bool) -> Bool:
  match hit:
    case True{}: True{}
    case False{}: allowed_case14(parent,name,Bool.and(U32.is_eq(parent,11),U32.is_eq(name,13)))

def allowed_case12(+parent: U32, +name: U32, +hit: Bool) -> Bool:
  match hit:
    case True{}: True{}
    case False{}: allowed_case13(parent,name,Bool.and(U32.is_eq(parent,11),U32.is_eq(name,12)))

def allowed_case11(+parent: U32, +name: U32, +hit: Bool) -> Bool:
  match hit:
    case True{}: True{}
    case False{}: allowed_case12(parent,name,Bool.and(U32.is_eq(parent,8),U32.is_eq(name,11)))

def allowed_case10(+parent: U32, +name: U32, +hit: Bool) -> Bool:
  match hit:
    case True{}: True{}
    case False{}: allowed_case11(parent,name,Bool.and(U32.is_eq(parent,8),U32.is_eq(name,5)))

def allowed_case9(+parent: U32, +name: U32, +hit: Bool) -> Bool:
  match hit:
    case True{}: True{}
    case False{}: allowed_case10(parent,name,Bool.and(U32.is_eq(parent,8),U32.is_eq(name,4)))

def allowed_case8(+parent: U32, +name: U32, +hit: Bool) -> Bool:
  match hit:
    case True{}: True{}
    case False{}: allowed_case9(parent,name,Bool.and(U32.is_eq(parent,8),U32.is_eq(name,10)))

def allowed_case7(+parent: U32, +name: U32, +hit: Bool) -> Bool:
  match hit:
    case True{}: True{}
    case False{}: allowed_case8(parent,name,Bool.and(U32.is_eq(parent,8),U32.is_eq(name,9)))

def allowed_case6(+parent: U32, +name: U32, +hit: Bool) -> Bool:
  match hit:
    case True{}: True{}
    case False{}: allowed_case7(parent,name,Bool.and(U32.is_eq(parent,7),U32.is_eq(name,8)))

def allowed_case5(+parent: U32, +name: U32, +hit: Bool) -> Bool:
  match hit:
    case True{}: True{}
    case False{}: allowed_case6(parent,name,Bool.and(U32.is_eq(parent,2),U32.is_eq(name,6)))

def allowed_case4(+parent: U32, +name: U32, +hit: Bool) -> Bool:
  match hit:
    case True{}: True{}
    case False{}: allowed_case5(parent,name,Bool.and(U32.is_eq(parent,2),U32.is_eq(name,5)))

def allowed_case3(+parent: U32, +name: U32, +hit: Bool) -> Bool:
  match hit:
    case True{}: True{}
    case False{}: allowed_case4(parent,name,Bool.and(U32.is_eq(parent,2),U32.is_eq(name,4)))

def allowed_case2(+parent: U32, +name: U32, +hit: Bool) -> Bool:
  match hit:
    case True{}: True{}
    case False{}: allowed_case3(parent,name,Bool.and(U32.is_eq(parent,2),U32.is_eq(name,3)))

def allowed_case1(+parent: U32, +name: U32, +hit: Bool) -> Bool:
  match hit:
    case True{}: True{}
    case False{}: allowed_case2(parent,name,Bool.and(U32.is_eq(parent,1),U32.is_eq(name,7)))

def allowed_case0(+parent: U32, +name: U32, +hit: Bool) -> Bool:
  match hit:
    case True{}: True{}
    case False{}: allowed_case1(parent,name,Bool.and(U32.is_eq(parent,1),U32.is_eq(name,2)))

def allowed(+parent: U32, +name: U32) -> Bool:
  allowed_case0(parent,name,Bool.and(U32.is_eq(parent,0),U32.is_eq(name,1)))

def element_bit_case11(+parent: U32, +name: U32, +hit: Bool) -> U32:
  match hit:
    case True{}: 1
    case False{}: 0

def element_bit_case10(+parent: U32, +name: U32, +hit: Bool) -> U32:
  match hit:
    case True{}: 16
    case False{}: element_bit_case11(parent,name,Bool.and(U32.is_eq(parent,11),U32.is_eq(name,12)))

def element_bit_case9(+parent: U32, +name: U32, +hit: Bool) -> U32:
  match hit:
    case True{}: 8
    case False{}: element_bit_case10(parent,name,Bool.and(U32.is_eq(parent,8),U32.is_eq(name,11)))

def element_bit_case8(+parent: U32, +name: U32, +hit: Bool) -> U32:
  match hit:
    case True{}: 4
    case False{}: element_bit_case9(parent,name,Bool.and(U32.is_eq(parent,8),U32.is_eq(name,5)))

def element_bit_case7(+parent: U32, +name: U32, +hit: Bool) -> U32:
  match hit:
    case True{}: 2
    case False{}: element_bit_case8(parent,name,Bool.and(U32.is_eq(parent,8),U32.is_eq(name,4)))

def element_bit_case6(+parent: U32, +name: U32, +hit: Bool) -> U32:
  match hit:
    case True{}: 1
    case False{}: element_bit_case7(parent,name,Bool.and(U32.is_eq(parent,8),U32.is_eq(name,10)))

def element_bit_case5(+parent: U32, +name: U32, +hit: Bool) -> U32:
  match hit:
    case True{}: 8
    case False{}: element_bit_case6(parent,name,Bool.and(U32.is_eq(parent,8),U32.is_eq(name,9)))

def element_bit_case4(+parent: U32, +name: U32, +hit: Bool) -> U32:
  match hit:
    case True{}: 4
    case False{}: element_bit_case5(parent,name,Bool.and(U32.is_eq(parent,2),U32.is_eq(name,6)))

def element_bit_case3(+parent: U32, +name: U32, +hit: Bool) -> U32:
  match hit:
    case True{}: 2
    case False{}: element_bit_case4(parent,name,Bool.and(U32.is_eq(parent,2),U32.is_eq(name,5)))

def element_bit_case2(+parent: U32, +name: U32, +hit: Bool) -> U32:
  match hit:
    case True{}: 1
    case False{}: element_bit_case3(parent,name,Bool.and(U32.is_eq(parent,2),U32.is_eq(name,4)))

def element_bit_case1(+parent: U32, +name: U32, +hit: Bool) -> U32:
  match hit:
    case True{}: 2
    case False{}: element_bit_case2(parent,name,Bool.and(U32.is_eq(parent,2),U32.is_eq(name,3)))

def element_bit_case0(+parent: U32, +name: U32, +hit: Bool) -> U32:
  match hit:
    case True{}: 1
    case False{}: element_bit_case1(parent,name,Bool.and(U32.is_eq(parent,1),U32.is_eq(name,7)))

def element_bit(+parent: U32, +name: U32) -> U32:
  element_bit_case0(parent,name,Bool.and(U32.is_eq(parent,1),U32.is_eq(name,2)))

def seen(+state: State, +parent: U32) -> U32:
  match parent:
    case 1: root_rootSeen(state_root(state))
    case 2: root_paramsSeen(state_root(state))
    case 8: root_stringSeen(state_root(state))
    case 11: root_fuzSeen(state_root(state))
    case _: 0

def set_seen(+state: State, +parent: U32, +mask: U32) -> State:
  match parent:
    case 1: with_root(state,root_set_rootSeen(state_root(state),mask))
    case 2: with_root(state,root_set_paramsSeen(state_root(state),mask))
    case 8: with_root(state,root_set_stringSeen(state_root(state),mask))
    case 11: with_root(state,root_set_fuzSeen(state_root(state),mask))
    case _: state

def depth_limit(+limits: T.Limits) -> U32:
  match limits:
    case T.Limits{+a,+b,+c,+d,+e,+f,+g,+h,+i}: b

def entries_limit(+limits: T.Limits) -> U32:
  match limits:
    case T.Limits{+a,+b,+c,+d,+e,+f,+g,+h,+i}: c

def entry_text_limit(+limits: T.Limits) -> U32:
  match limits:
    case T.Limits{+a,+b,+c,+d,+e,+f,+g,+h,+i}: d

def params_text_limit(+limits: T.Limits) -> U32:
  match limits:
    case T.Limits{+a,+b,+c,+d,+e,+f,+g,+h,+i}: e

def fuz_limit(+limits: T.Limits) -> U32:
  match limits:
    case T.Limits{+a,+b,+c,+d,+e,+f,+g,+h,+i}: h

def fuz_text_limit(+limits: T.Limits) -> U32:
  match limits:
    case T.Limits{+a,+b,+c,+d,+e,+f,+g,+h,+i}: i

def fuz_count(+fuz: T.Fuz) -> U32:
  match fuz:
    case T.Fuz{+present,+response,+count,+span}: count

def fuz_response(+fuz: T.Fuz) -> U32:
  match fuz:
    case T.Fuz{+present,+response,+count,+span}: response

def fuz_set_count(+fuz: T.Fuz, +count: U32) -> T.Fuz:
  match fuz:
    case T.Fuz{+present,+response,+old,+span}: T.Fuz{present,response,count,span}

def fuz_set_response(+fuz: T.Fuz, +response: U32) -> T.Fuz:
  match fuz:
    case T.Fuz{+present,+old,+count,+span}: T.Fuz{present,response,count,span}

# Source role is retained during the opening tag; pending is entered at >.
def stage_tag(+state: State, +name: U32, +at: T.Position) -> State:
  with_ctl(state,ctl_set_attrId(ctl_set_attrMask(ctl_set_tagAt(ctl_set_pending(ctl_set_parent(state_control(state),ctl_role(state_control(state))),name),at),0),0))

def stage_entry(+state: State, +at: T.Position) -> State:
  state_set_values(with_root(state,root_set_entryAt(root_set_entryScalars(root_set_entryBytes(root_set_stringSeen(root_set_entries(state_root(state),U32.inc(root_entries(state_root(state)))),0),0),0),at)),empty_values())

def stage_fuz(+state: State, +at: T.Position) -> State:
  state_set_values(with_root(state,root_set_fuzAt(root_set_fuzSeen(state_root(state),0),at)),val_set_fuz(state_values(state),T.Fuz{True{},0,0,T.Span{at,at}}))

def open_entry(+state: State, +at: T.Position, +valid: Bool) -> Step:
  match valid:
    case True{}: advance(stage_entry(state,at))
    case False{}: reject(state,7,at,entries_limit(state_limits(state)),root_entries(state_root(state)))

def open_fuz(+state: State, +at: T.Position, +valid: Bool) -> Step:
  match valid:
    case True{}: advance(state_set_values(state,val_set_fuz(state_values(state),fuz_set_count(val_fuz(state_values(state)),U32.inc(fuz_count(val_fuz(state_values(state))))))))
    case False{}: reject(state,7,at,fuz_limit(state_limits(state)),fuz_count(val_fuz(state_values(state))))

def open_special(+state: State, +name: U32, +at: T.Position) -> Step:
  match name:
    case 1: advance(with_root(state,root_set_rootAt(state_root(state),at)))
    case 2: advance(with_root(state,root_set_paramsAt(state_root(state),at)))
    case 8: open_entry(state,at,U32.is_lt(root_entries(state_root(state)),entries_limit(state_limits(state))))
    case 11: advance(stage_fuz(state,at))
    case 13: open_fuz(state,at,U32.is_lt(fuz_count(val_fuz(state_values(state))),fuz_limit(state_limits(state))))
    case _: advance(state)

def open_unique(+state: State, +name: U32, +at: T.Position, +parent: U32, +bit: U32, +unique: Bool) -> Step:
  match unique:
    case False{}: reject(state,2,at,0,name)
    case True{}: open_special(stage_tag(set_seen(state,parent,U32.or(seen(state,parent),bit)),name,at),name,at)

def open_depth(+state: State, +name: U32, +at: T.Position, +parent: U32, +valid: Bool) -> Step:
  match valid:
    case False{}: reject(state,7,at,depth_limit(state_limits(state)),depth(name,parent))
    case True{}: open_unique(state,name,at,parent,element_bit(parent,name),U32.is_zero(U32.and(seen(state,parent),element_bit(parent,name))))

def open_valid(+state: State, +name: U32, +at: T.Position, +parent: U32, +valid: Bool) -> Step:
  match valid:
    case False{}: reject(state,1,at,parent,name)
    case True{}: open_depth(state,name,at,parent,U32.is_le(depth(name,parent),depth_limit(state_limits(state))))

def open(+state: State, +name: U32, +at: T.Position) -> Step:
  open_valid(state,name,at,ctl_role(state_control(state)),Bool.and(Bool.and(U32.is_zero(ctl_pending(state_control(state))),Bool.not(root_done(state_root(state)))),allowed(ctl_role(state_control(state)),name)))

def attribute_bit(+name: U32) -> U32:
  match name:
    case 101: 1
    case 102: 2
    case 103: 4
    case 104: 8
    case 105: 16
    case _: 0

def attribute_allowed_case4(+tag: U32, +name: U32, +hit: Bool) -> Bool:
  match hit:
    case True{}: True{}
    case False{}: False{}

def attribute_allowed_case3(+tag: U32, +name: U32, +hit: Bool) -> Bool:
  match hit:
    case True{}: True{}
    case False{}: attribute_allowed_case4(tag,name,Bool.and(U32.is_eq(tag,10),U32.is_eq(name,105)))

def attribute_allowed_case2(+tag: U32, +name: U32, +hit: Bool) -> Bool:
  match hit:
    case True{}: True{}
    case False{}: attribute_allowed_case3(tag,name,Bool.and(U32.is_eq(tag,10),U32.is_eq(name,104)))

def attribute_allowed_case1(+tag: U32, +name: U32, +hit: Bool) -> Bool:
  match hit:
    case True{}: True{}
    case False{}: attribute_allowed_case2(tag,name,Bool.and(U32.is_eq(tag,8),U32.is_eq(name,103)))

def attribute_allowed_case0(+tag: U32, +name: U32, +hit: Bool) -> Bool:
  match hit:
    case True{}: True{}
    case False{}: attribute_allowed_case1(tag,name,Bool.and(U32.is_eq(tag,8),U32.is_eq(name,102)))

def attribute_allowed(+tag: U32, +name: U32) -> Bool:
  attribute_allowed_case0(tag,name,Bool.and(U32.is_eq(tag,8),U32.is_eq(name,101)))

def attribute_unique(+state: State, +name: U32, +at: T.Position, +valid: Bool) -> Step:
  match valid:
    case False{}: reject(state,2,at,0,name)
    case True{}: advance(with_ctl(state,ctl_set_attrLength(ctl_set_number(ctl_set_attrId(ctl_set_attrMask(state_control(state),U32.or(ctl_attrMask(state_control(state)),attribute_bit(name))),name),N.begin(U32.is_eq(name,103))),0)))

def attribute_valid(+state: State, +name: U32, +at: T.Position, +valid: Bool) -> Step:
  match valid:
    case False{}: reject(state,3,at,ctl_pending(state_control(state)),name)
    case True{}: attribute_unique(state,name,at,U32.is_zero(U32.and(ctl_attrMask(state_control(state)),attribute_bit(name))))

def attribute(+state: State, +name: U32, +at: T.Position) -> Step:
  attribute_valid(state,name,at,Bool.and(U32.is_zero(ctl_attrId(state_control(state))),attribute_allowed(ctl_pending(state_control(state)),name)))

def consume_count(+state: State, +params: Bool, +width: U32) -> State:
  match params:
    case True{}: with_root(state,root_set_paramsBytes(state_root(state),U32.add(root_paramsBytes(state_root(state)),width)))
    case False{}: with_root(state,root_set_entryBytes(state_root(state),U32.add(root_entryBytes(state_root(state)),width)))

def count_fits(+state: State, +params: Bool, +width: U32) -> Bool:
  match params:
    case True{}: U32.is_le(width,U32.sub(params_text_limit(state_limits(state)),root_paramsBytes(state_root(state))))
    case False{}: U32.is_le(width,U32.sub(entry_text_limit(state_limits(state)),root_entryBytes(state_root(state))))

def attr_number(+state: State, +span: T.Span, +width: U32, +number: N.Number) -> Step:
  match number:
    case N.NumberBroken{+reason}: reject(state,4,T.start(span),0,reason)
    case _: Advance{with_ctl(consume_count(state,False{},width),ctl_set_attrLength(ctl_set_number(state_control(state),number),U32.inc(ctl_attrLength(state_control(state))))),ChargeText{width}}

def attr_scalar_valid(+state: State, +value: U32, +span: T.Span, +width: U32, +valid: Bool) -> Step:
  match valid:
    case False{}: reject(state,7,T.start(span),entry_text_limit(state_limits(state)),root_entryBytes(state_root(state)))
    case True{}: attr_number(state,span,width,N.push(ctl_number(state_control(state)),value))

def attr_scalar(+state: State, +value: U32, +span: T.Span) -> Step:
  attr_scalar_valid(state,value,span,T.utf8_width(value),Bool.and(Bool.and(U32.is_gt(ctl_attrId(state_control(state)),0),U32.is_lt(ctl_attrLength(state_control(state)),16)),count_fits(state,False{},T.utf8_width(value))))

def attr_complete_number(+state: State, +name: U32) -> Result<&2,&2,U32,U32>:
  match name:
    case 101: N.finish(ctl_number(state_control(state)),1,1,2)
    case 102: N.finish(ctl_number(state_control(state)),1,1,2)
    case 103: N.finish(ctl_number(state_control(state)),6,8,4294967295)
    case 104: N.finish(ctl_number(state_control(state)),1,16,65535)
    case 105: N.finish(ctl_number(state_control(state)),1,16,65535)
    case _: Fail{1}

def partial(+value: U32) -> T.Partial:
  match value:
    case 1: T.Incomplete{}
    case _: T.Locked{}

def attr_assigned_case5(+state: State, +name: U32, +value: U32, +at: T.Position, +hit: Bool) -> Step:
  match hit:
    case True{}: advance(state_set_values(state,val_set_maximum(state_values(state),Some{value})))
    case False{}: reject(state,3,at,0,name)

def attr_assigned_case4(+state: State, +name: U32, +value: U32, +at: T.Position, +hit: Bool) -> Step:
  match hit:
    case True{}: advance(state_set_values(state,val_set_index(state_values(state),Some{value})))
    case False{}: attr_assigned_case5(state,name,value,at,U32.is_eq(name,105))

def attr_assigned_case3(+state: State, +name: U32, +value: U32, +at: T.Position, +hit: Bool) -> Step:
  match hit:
    case True{}: advance(state_set_values(state,val_set_sid(state_values(state),Some{T.Sid{value,ctl_attrLength(state_control(state))}})))
    case False{}: attr_assigned_case4(state,name,value,at,U32.is_eq(name,104))

def attr_assigned_case2(+state: State, +name: U32, +value: U32, +at: T.Position, +hit: Bool) -> Step:
  match hit:
    case True{}: advance(state_set_values(state,val_set_partial(state_values(state),partial(value))))
    case False{}: attr_assigned_case3(state,name,value,at,U32.is_eq(name,103))

def attr_assigned_case1(+state: State, +name: U32, +value: U32, +at: T.Position, +hit: Bool) -> Step:
  match hit:
    case True{}: advance(state_set_values(state,val_set_list(state_values(state),value)))
    case False{}: attr_assigned_case2(state,name,value,at,U32.is_eq(name,102))

def attr_assigned_case0(+state: State, +name: U32, +value: U32, +at: T.Position, +hit: Bool) -> Step:
  match hit:
    case True{}: reject(state,4,at,1,value)
    case False{}: attr_assigned_case1(state,name,value,at,U32.is_eq(name,101))

def attr_assigned(+state: State, +name: U32, +value: U32, +at: T.Position) -> Step:
  attr_assigned_case0(state,name,value,at,Bool.and(U32.is_eq(name,102),U32.is_eq(value,0)))

def attr_finished(+state: State, +name: U32, +at: T.Position, +result: Result<&2,&2,U32,U32>) -> Step:
  match result:
    case Fail{+reason}: reject(state,4,at,name,reason)
    case Done{+value}: attr_assigned(with_ctl(state,ctl_set_attrId(state_control(state),0)),name,value,at)

def attribute_end(+state: State, +at: T.Position) -> Step:
  attr_finished(state,ctl_attrId(state_control(state)),at,attr_complete_number(state,ctl_attrId(state_control(state))))

def leaf_start(+state: State, +parent: U32) -> U32:
  match parent:
    case 2: root_paramsScalars(state_root(state))
    case _: root_entryScalars(state_root(state))

def reset_leaf(+control: Control, +parent: U32, +at: T.Position, +start: U32) -> Control:
  ctl_set_edidNumber(ctl_set_edidBracket(ctl_set_edidPipe(ctl_set_edidAscii(ctl_set_packedField(ctl_set_packedRecord(ctl_set_last(ctl_set_first(ctl_set_leafBytes(ctl_set_leafLength(ctl_set_leafStart(ctl_set_leafAt(ctl_set_leafParent(control,parent),at),start),0),0),0),0),0),0),True{}),False{}),True{}),N.begin(True{}))

def enter(+state: State, +name: U32) -> State:
  with_ctl(state,ctl_set_number(ctl_set_pending(ctl_set_role(reset_leaf(state_control(state),ctl_parent(state_control(state)),ctl_tagAt(state_control(state)),leaf_start(state,ctl_parent(state_control(state)))),name),0),N.begin(False{})))

def leave(+state: State, +parent: U32) -> State:
  with_ctl(state,ctl_set_pending(ctl_set_leafParent(ctl_set_role(state_control(state),parent),0),0))

def close_root(+state: State, +end: T.Position, +valid: Bool) -> Step:
  match valid:
    case False{}: reject(state,5,end,3,root_rootSeen(state_root(state)))
    case True{}: advance(leave(with_root(state,root_set_done(state_root(state),True{})),0))

def close_params(+state: State, +end: T.Position, +valid: Bool) -> Step:
  match valid:
    case False{}: reject(state,5,end,15,root_paramsSeen(state_root(state)))
    case True{}: advance(leave(with_root(state,root_set_paramsEnd(state_root(state),end)),1))

def final_identity(+rec: T.Rec, +original: T.Identity) -> T.Identity:
  match rec:
    case T.Rec{+record,1447903556,+occurrence}: T.UnsupportedIdentity{3}
    case _: original

def entry_meta(+state: State, +end: T.Position) -> T.EntryMeta:
  T.EntryMeta{state_source(state),root_entries(state_root(state)),T.Span{root_entryAt(state_root(state)),end},val_list(state_values(state)),val_partial(state_values(state)),val_sid(state_values(state)),val_rec(state_values(state)),final_identity(val_rec(state_values(state)),val_identity(state_values(state))),val_edid(state_values(state)),val_sourceText(state_values(state)),val_destText(state_values(state)),val_fuz(state_values(state))}

def close_entry(+state: State, +end: T.Position, +valid: Bool) -> Step:
  match valid:
    case False{}: reject(state,5,end,15,root_stringSeen(state_root(state)))
    case True{}: Advance{leave(state,7),YieldEntry{entry_meta(state,end)}}

def close_fuz(+state: State, +end: T.Position, +valid: Bool) -> Step:
  match valid:
    case False{}: reject(state,5,end,12,root_fuzSeen(state_root(state)))
    case True{}: advance(leave(state_set_values(state,val_set_fuz(state_values(state),T.Fuz{True{},fuz_response(val_fuz(state_values(state))),fuz_count(val_fuz(state_values(state))),T.Span{root_fuzAt(state_root(state)),end}})),8))

def rec_assigned(+state: State, +occurrence: T.Occurrence) -> Step:
  advance(leave(state_set_values(state,val_set_rec(state_values(state),T.Rec{ctl_packedRecord(state_control(state)),ctl_packedField(state_control(state)),occurrence})),8))

def occurrence_bound(+state: State, +index: U32, +max: U32, +at: T.Position, +valid: Bool) -> Step:
  match valid:
    case False{}: reject(state,4,at,max,index)
    case True{}: rec_assigned(state,T.Explicit{index,max})

def occurrence(+state: State, +index: Maybe<&2,U32>, +maximum: Maybe<&2,U32>, +at: T.Position) -> Step:
  match index maximum:
    case None{} None{}: rec_assigned(state,T.Unspecified{})
    case Some{+index} Some{+max}: occurrence_bound(state,index,max,at,U32.is_le(index,max))
    case _ _: reject(state,5,at,104,105)

def response_assigned(+state: State, +at: T.Position, +result: Result<&2,&2,U32,U32>) -> Step:
  match result:
    case Fail{+reason}: reject(state,4,at,12,reason)
    case Done{+value}: advance(leave(state_set_values(state,val_set_fuz(state_values(state),fuz_set_response(val_fuz(state_values(state)),value))),11))

def reference_field(+state: State, +end: T.Position) -> T.FieldRef:
  T.FieldRef{True{},ctl_leafStart(state_control(state)),ctl_leafLength(state_control(state)),ctl_leafBytes(state_control(state)),T.Span{ctl_leafAt(state_control(state)),end}}

def classify_literal(+valid: Bool) -> T.Identity:
  match valid:
    case True{}: T.LiteralEdid{}
    case False{}: T.UnsupportedIdentity{1}

def classify_bracket(+ascii: Bool, +result: Result<&2,&2,U32,U32>) -> T.Identity:
  match result:
    case Done{+value}: T.BracketFormId{value}
    case Fail{+reason}: classify_literal(ascii)

def classify_case1(+control: Control, +pipe: Bool, +bracket: Bool, +hit: Bool) -> T.Identity:
  match hit:
    case True{}: classify_bracket(ctl_edidAscii(control),N.finish(ctl_edidNumber(control),8,8,4294967295))
    case False{}: classify_literal(ctl_edidAscii(control))

def classify_case0(+control: Control, +pipe: Bool, +bracket: Bool, +hit: Bool) -> T.Identity:
  match hit:
    case True{}: T.UnsupportedIdentity{2}
    case False{}: classify_case1(control,pipe,bracket,Bool.and(Bool.not(pipe),bracket))

def classify(+control: Control, +pipe: Bool, +bracket: Bool) -> T.Identity:
  classify_case0(control,pipe,bracket,pipe)

def identity(+control: Control) -> T.Identity:
  classify(control,ctl_edidPipe(control),Bool.and(ctl_edidBracket(control),U32.is_eq(ctl_leafLength(control),10)))

def field_assigned_case5(+state: State, +name: U32, +parent: U32, +end: T.Position, +hit: Bool) -> Step:
  match hit:
    case True{}: advance(leave(state_set_values(state,val_set_destText(state_values(state),reference_field(state,end))),parent))
    case False{}: advance(leave(state,parent))

def field_assigned_case4(+state: State, +name: U32, +parent: U32, +end: T.Position, +hit: Bool) -> Step:
  match hit:
    case True{}: advance(leave(state_set_values(state,val_set_sourceText(state_values(state),reference_field(state,end))),parent))
    case False{}: field_assigned_case5(state,name,parent,end,Bool.and(U32.is_eq(name,5),U32.is_eq(parent,8)))

def field_assigned_case3(+state: State, +name: U32, +parent: U32, +end: T.Position, +hit: Bool) -> Step:
  match hit:
    case True{}: advance(leave(state_set_values(state,val_set_identity(val_set_edid(state_values(state),reference_field(state,end)),identity(state_control(state)))),parent))
    case False{}: field_assigned_case4(state,name,parent,end,Bool.and(U32.is_eq(name,4),U32.is_eq(parent,8)))

def field_assigned_case2(+state: State, +name: U32, +parent: U32, +end: T.Position, +hit: Bool) -> Step:
  match hit:
    case True{}: advance(leave(state_set_params(state,param_set_destLanguage(state_params(state),reference_field(state,end))),parent))
    case False{}: field_assigned_case3(state,name,parent,end,Bool.and(U32.is_eq(name,9),U32.is_eq(parent,8)))

def field_assigned_case1(+state: State, +name: U32, +parent: U32, +end: T.Position, +hit: Bool) -> Step:
  match hit:
    case True{}: advance(leave(state_set_params(state,param_set_sourceLanguage(state_params(state),reference_field(state,end))),parent))
    case False{}: field_assigned_case2(state,name,parent,end,Bool.and(U32.is_eq(name,5),U32.is_eq(parent,2)))

def field_assigned_case0(+state: State, +name: U32, +parent: U32, +end: T.Position, +hit: Bool) -> Step:
  match hit:
    case True{}: advance(leave(state_set_params(state,param_set_addon(state_params(state),reference_field(state,end))),parent))
    case False{}: field_assigned_case1(state,name,parent,end,Bool.and(U32.is_eq(name,4),U32.is_eq(parent,2)))

def field_assigned(+state: State, +name: U32, +parent: U32, +end: T.Position) -> Step:
  field_assigned_case0(state,name,parent,end,Bool.and(U32.is_eq(name,3),U32.is_eq(parent,2)))

def close_field_case2(+state: State, +name: U32, +parent: U32, +end: T.Position, +valid: Bool, +hit: Bool) -> Step:
  match hit:
    case True{}: response_assigned(state,end,N.finish(ctl_number(state_control(state)),1,16,2147483647))
    case False{}: field_assigned(state,name,parent,end)

def close_field_case1(+state: State, +name: U32, +parent: U32, +end: T.Position, +valid: Bool, +hit: Bool) -> Step:
  match hit:
    case True{}: occurrence(state,val_index(state_values(state)),val_maximum(state_values(state)),end)
    case False{}: close_field_case2(state,name,parent,end,valid,Bool.and(U32.is_eq(name,12),Bool.and(U32.is_eq(parent,11),valid)))

def close_field_case0(+state: State, +name: U32, +parent: U32, +end: T.Position, +valid: Bool, +hit: Bool) -> Step:
  match hit:
    case True{}: reject(state,6,ctl_leafAt(state_control(state)),name,ctl_leafLength(state_control(state)))
    case False{}: close_field_case1(state,name,parent,end,valid,Bool.and(U32.is_eq(name,10),Bool.and(U32.is_eq(parent,8),valid)))

def close_field(+state: State, +name: U32, +parent: U32, +end: T.Position, +valid: Bool) -> Step:
  close_field_case0(state,name,parent,end,valid,Bool.not(valid))

def addon_valid(+control: Control) -> Bool:
  Bool.and(U32.is_gt(ctl_leafLength(control),0),Bool.not(Bool.and(U32.is_eq(ctl_first(control),46),Bool.or(U32.is_eq(ctl_leafLength(control),1),Bool.and(U32.is_eq(ctl_leafLength(control),2),U32.is_eq(ctl_last(control),46))))))

def required_text_case5(+state: State, +name: U32, +parent: U32, +hit: Bool) -> Bool:
  match hit:
    case True{}: U32.is_eq(ctl_leafLength(state_control(state)),9)
    case False{}: True{}

def required_text_case4(+state: State, +name: U32, +parent: U32, +hit: Bool) -> Bool:
  match hit:
    case True{}: U32.is_gt(ctl_leafLength(state_control(state)),0)
    case False{}: required_text_case5(state,name,parent,Bool.and(U32.is_eq(name,10),U32.is_eq(parent,8)))

def required_text_case3(+state: State, +name: U32, +parent: U32, +hit: Bool) -> Bool:
  match hit:
    case True{}: U32.is_eq(ctl_leafLength(state_control(state)),1)
    case False{}: required_text_case4(state,name,parent,Bool.and(U32.is_eq(name,9),U32.is_eq(parent,8)))

def required_text_case2(+state: State, +name: U32, +parent: U32, +hit: Bool) -> Bool:
  match hit:
    case True{}: U32.is_gt(ctl_leafLength(state_control(state)),0)
    case False{}: required_text_case3(state,name,parent,Bool.and(U32.is_eq(name,6),U32.is_eq(parent,2)))

def required_text_case1(+state: State, +name: U32, +parent: U32, +hit: Bool) -> Bool:
  match hit:
    case True{}: U32.is_gt(ctl_leafLength(state_control(state)),0)
    case False{}: required_text_case2(state,name,parent,Bool.and(U32.is_eq(name,5),U32.is_eq(parent,2)))

def required_text_case0(+state: State, +name: U32, +parent: U32, +hit: Bool) -> Bool:
  match hit:
    case True{}: addon_valid(state_control(state))
    case False{}: required_text_case1(state,name,parent,Bool.and(U32.is_eq(name,4),U32.is_eq(parent,2)))

def required_text(+state: State, +name: U32, +parent: U32) -> Bool:
  required_text_case0(state,name,parent,Bool.and(U32.is_eq(name,3),U32.is_eq(parent,2)))

def close_kind(+state: State, +name: U32, +end: T.Position) -> Step:
  match name:
    case 1: close_root(state,end,U32.is_eq(root_rootSeen(state_root(state)),3))
    case 2: close_params(state,end,U32.is_eq(root_paramsSeen(state_root(state)),15))
    case 7: advance(leave(state,1))
    case 8: close_entry(state,end,U32.is_eq(U32.and(root_stringSeen(state_root(state)),15),15))
    case 11: close_fuz(state,end,Bool.and(U32.is_eq(root_fuzSeen(state_root(state)),1),U32.is_gt(fuz_count(val_fuz(state_values(state))),0)))
    case _: close_field(state,name,ctl_leafParent(state_control(state)),end,required_text(state,name,ctl_leafParent(state_control(state))))

def close_valid(+state: State, +name: U32, +span: T.Span, +valid: Bool) -> Step:
  match valid:
    case False{}: reject(state,1,T.start(span),ctl_role(state_control(state)),name)
    case True{}: close_kind(state,name,T.end(span))

def close(+state: State, +name: U32, +span: T.Span) -> Step:
  close_valid(state,name,span,Bool.and(U32.is_zero(ctl_pending(state_control(state))),U32.is_eq(ctl_role(state_control(state)),name)))

def start_valid_case1(+state: State, +name: U32, +empty: Bool, +at: T.Position, +valid: Bool, +hit: Bool) -> Step:
  match hit:
    case True{}: advance(enter(state,name))
    case False{}: close(enter(state,name),name,T.Span{ctl_tagAt(state_control(state)),at})

def start_valid_case0(+state: State, +name: U32, +empty: Bool, +at: T.Position, +valid: Bool, +hit: Bool) -> Step:
  match hit:
    case True{}: reject(state,5,at,101,name)
    case False{}: start_valid_case1(state,name,empty,at,valid,Bool.and(Bool.not(empty),valid))

def start_valid(+state: State, +name: U32, +empty: Bool, +at: T.Position, +valid: Bool) -> Step:
  start_valid_case0(state,name,empty,at,valid,Bool.not(valid))

def start_end(+state: State, +empty: Bool, +at: T.Position) -> Step:
  start_valid(state,ctl_pending(state_control(state)),empty,at,Bool.and(Bool.and(U32.is_gt(ctl_pending(state_control(state)),0),U32.is_zero(ctl_attrId(state_control(state)))),Bool.or(U32.is_ne(ctl_pending(state_control(state)),8),U32.is_eq(U32.and(ctl_attrMask(state_control(state)),1),1))))

def is_container(+name: U32) -> Bool:
  match name:
    case 1: True{}
    case 2: True{}
    case 7: True{}
    case 8: True{}
    case 11: True{}
    case _: False{}

def retained_case5(+name: U32, +parent: U32, +hit: Bool) -> Bool:
  match hit:
    case True{}: True{}
    case False{}: False{}

def retained_case4(+name: U32, +parent: U32, +hit: Bool) -> Bool:
  match hit:
    case True{}: True{}
    case False{}: retained_case5(name,parent,Bool.and(U32.is_eq(name,5),U32.is_eq(parent,8)))

def retained_case3(+name: U32, +parent: U32, +hit: Bool) -> Bool:
  match hit:
    case True{}: True{}
    case False{}: retained_case4(name,parent,Bool.and(U32.is_eq(name,4),U32.is_eq(parent,8)))

def retained_case2(+name: U32, +parent: U32, +hit: Bool) -> Bool:
  match hit:
    case True{}: True{}
    case False{}: retained_case3(name,parent,Bool.and(U32.is_eq(name,9),U32.is_eq(parent,8)))

def retained_case1(+name: U32, +parent: U32, +hit: Bool) -> Bool:
  match hit:
    case True{}: True{}
    case False{}: retained_case2(name,parent,Bool.and(U32.is_eq(name,5),U32.is_eq(parent,2)))

def retained_case0(+name: U32, +parent: U32, +hit: Bool) -> Bool:
  match hit:
    case True{}: True{}
    case False{}: retained_case1(name,parent,Bool.and(U32.is_eq(name,4),U32.is_eq(parent,2)))

def retained(+name: U32, +parent: U32) -> Bool:
  retained_case0(name,parent,Bool.and(U32.is_eq(name,3),U32.is_eq(parent,2)))

def leaf_limit_case6(+state: State, +name: U32, +parent: U32, +hit: Bool) -> U32:
  match hit:
    case True{}: fuz_text_limit(state_limits(state))
    case False{}: entry_text_limit(state_limits(state))

def leaf_limit_case5(+state: State, +name: U32, +parent: U32, +hit: Bool) -> U32:
  match hit:
    case True{}: 16
    case False{}: leaf_limit_case6(state,name,parent,Bool.and(U32.is_eq(name,13),U32.is_eq(parent,11)))

def leaf_limit_case4(+state: State, +name: U32, +parent: U32, +hit: Bool) -> U32:
  match hit:
    case True{}: 9
    case False{}: leaf_limit_case5(state,name,parent,Bool.and(U32.is_eq(name,12),U32.is_eq(parent,11)))

def leaf_limit_case3(+state: State, +name: U32, +parent: U32, +hit: Bool) -> U32:
  match hit:
    case True{}: 1
    case False{}: leaf_limit_case4(state,name,parent,Bool.and(U32.is_eq(name,10),U32.is_eq(parent,8)))

def leaf_limit_case2(+state: State, +name: U32, +parent: U32, +hit: Bool) -> U32:
  match hit:
    case True{}: 256
    case False{}: leaf_limit_case3(state,name,parent,Bool.and(U32.is_eq(name,6),U32.is_eq(parent,2)))

def leaf_limit_case1(+state: State, +name: U32, +parent: U32, +hit: Bool) -> U32:
  match hit:
    case True{}: 256
    case False{}: leaf_limit_case2(state,name,parent,Bool.and(U32.is_eq(name,5),U32.is_eq(parent,2)))

def leaf_limit_case0(+state: State, +name: U32, +parent: U32, +hit: Bool) -> U32:
  match hit:
    case True{}: 1024
    case False{}: leaf_limit_case1(state,name,parent,Bool.and(U32.is_eq(name,4),U32.is_eq(parent,2)))

def leaf_limit(+state: State, +name: U32, +parent: U32) -> U32:
  leaf_limit_case0(state,name,parent,Bool.and(U32.is_eq(name,3),U32.is_eq(parent,2)))

def leaf_first(+control: Control, +value: U32, +first: Bool) -> Control:
  match first:
    case True{}: ctl_set_first(control,value)
    case False{}: control

def leaf_bookkeep(+control: Control, +value: U32, +width: U32) -> Control:
  ctl_set_leafBytes(ctl_set_leafLength(ctl_set_last(leaf_first(control,value,U32.is_zero(ctl_leafLength(control))),value),U32.inc(ctl_leafLength(control))),U32.add(ctl_leafBytes(control),width))

def edid_number(+control: Control, +value: U32, +digit: Bool) -> Control:
  match digit:
    case True{}: ctl_set_edidNumber(control,N.push(ctl_edidNumber(control),value))
    case False{}: control

def edid_position(+index: U32, +value: U32) -> Bool:
  match index:
    case 0: U32.is_eq(value,91)
    case 9: U32.is_eq(value,93)
    case _: Bool.and(U32.is_ge(index,1),U32.is_le(index,8))

def edid_scalar(+control: Control, +value: U32) -> Control:
  edid_number(ctl_set_edidBracket(ctl_set_edidPipe(ctl_set_edidAscii(control,Bool.and(ctl_edidAscii(control),Bool.and(U32.is_ge(value,33),U32.is_le(value,126)))),Bool.or(ctl_edidPipe(control),U32.is_eq(value,124))),Bool.and(ctl_edidBracket(control),edid_position(ctl_leafLength(control),value))),value,Bool.and(U32.is_ge(ctl_leafLength(control),1),U32.is_le(ctl_leafLength(control),8)))

def signature(+value: U32) -> Bool:
  Bool.and(Bool.and(U32.is_ge(value,33),U32.is_le(value,126)),U32.is_ne(value,58))

def rec_half(+control: Control, +value: U32, +first: Bool) -> Control:
  match first:
    case True{}: ctl_set_packedRecord(control,U32.or(U32.shln(ctl_packedRecord(control),8n),value))
    case False{}: ctl_set_packedField(control,U32.or(U32.shln(ctl_packedField(control),8n),value))

def rec_scalar(+control: Control, +value: U32, +index: U32) -> Control:
  match index:
    case 4: control
    case _: rec_half(control,value,U32.is_lt(index,4))

def rec_valid(+index: U32, +value: U32) -> Bool:
  match index:
    case 4: U32.is_eq(value,58)
    case _: Bool.and(U32.is_lt(index,9),signature(value))

def field_character_case2(+name: U32, +parent: U32, +index: U32, +value: U32, +hit: Bool) -> Bool:
  match hit:
    case True{}: rec_valid(index,value)
    case False{}: True{}

def field_character_case1(+name: U32, +parent: U32, +index: U32, +value: U32, +hit: Bool) -> Bool:
  match hit:
    case True{}: Bool.and(U32.is_zero(index),U32.is_eq(value,50))
    case False{}: field_character_case2(name,parent,index,value,Bool.and(U32.is_eq(name,10),U32.is_eq(parent,8)))

def field_character_case0(+name: U32, +parent: U32, +index: U32, +value: U32, +hit: Bool) -> Bool:
  match hit:
    case True{}: Bool.and(Bool.and(U32.is_ge(value,32),U32.is_ne(value,127)),Bool.and(U32.is_ne(value,47),U32.is_ne(value,92)))
    case False{}: field_character_case1(name,parent,index,value,Bool.and(U32.is_eq(name,6),U32.is_eq(parent,2)))

def field_character(+name: U32, +parent: U32, +index: U32, +value: U32) -> Bool:
  field_character_case0(name,parent,index,value,Bool.and(U32.is_eq(name,3),U32.is_eq(parent,2)))

def leaf_semantics_case2(+control: Control, +name: U32, +parent: U32, +value: U32, +hit: Bool) -> Control:
  match hit:
    case True{}: ctl_set_number(control,N.push(ctl_number(control),value))
    case False{}: control

def leaf_semantics_case1(+control: Control, +name: U32, +parent: U32, +value: U32, +hit: Bool) -> Control:
  match hit:
    case True{}: rec_scalar(control,value,ctl_leafLength(control))
    case False{}: leaf_semantics_case2(control,name,parent,value,Bool.and(U32.is_eq(name,12),U32.is_eq(parent,11)))

def leaf_semantics_case0(+control: Control, +name: U32, +parent: U32, +value: U32, +hit: Bool) -> Control:
  match hit:
    case True{}: edid_scalar(control,value)
    case False{}: leaf_semantics_case1(control,name,parent,value,Bool.and(U32.is_eq(name,10),U32.is_eq(parent,8)))

def leaf_semantics(+control: Control, +name: U32, +parent: U32, +value: U32) -> Control:
  leaf_semantics_case0(control,name,parent,value,Bool.and(U32.is_eq(name,9),U32.is_eq(parent,8)))

def stored_action_case1(+state: State, +value: U32, +width: U32, +params: Bool, +keep: Bool, +hit: Bool) -> Step:
  match hit:
    case True{}: Advance{with_root(state,root_set_paramsScalars(state_root(state),U32.inc(root_paramsScalars(state_root(state))))),AppendParams{value,width}}
    case False{}: Advance{with_root(state,root_set_entryScalars(state_root(state),U32.inc(root_entryScalars(state_root(state))))),AppendEntry{value,width}}

def stored_action_case0(+state: State, +value: U32, +width: U32, +params: Bool, +keep: Bool, +hit: Bool) -> Step:
  match hit:
    case True{}: Advance{state,ChargeText{width}}
    case False{}: stored_action_case1(state,value,width,params,keep,Bool.and(params,keep))

def stored_action(+state: State, +value: U32, +width: U32, +params: Bool, +keep: Bool) -> Step:
  stored_action_case0(state,value,width,params,keep,Bool.not(keep))

def text_committed(+state: State, +value: U32, +width: U32, +name: U32, +parent: U32) -> Step:
  stored_action(with_ctl(consume_count(state,U32.is_eq(parent,2),width),leaf_bookkeep(leaf_semantics(state_control(state),name,parent,value),value,width)),value,width,U32.is_eq(parent,2),retained(name,parent))

def text_character(+state: State, +value: U32, +span: T.Span, +width: U32, +name: U32, +parent: U32, +valid: Bool) -> Step:
  match valid:
    case False{}: reject(state,6,T.start(span),name,value)
    case True{}: text_committed(state,value,width,name,parent)

def text_bound(+state: State, +value: U32, +span: T.Span, +width: U32, +name: U32, +parent: U32, +valid: Bool) -> Step:
  match valid:
    case False{}: reject(state,7,T.start(span),leaf_limit(state,name,parent),ctl_leafBytes(state_control(state)))
    case True{}: text_character(state,value,span,width,name,parent,field_character(name,parent,ctl_leafLength(state_control(state)),value))

def text_leaf(+state: State, +value: U32, +span: T.Span, +width: U32, +name: U32, +parent: U32) -> Step:
  text_bound(state,value,span,width,name,parent,Bool.and(U32.is_le(width,U32.sub(leaf_limit(state,name,parent),ctl_leafBytes(state_control(state)))),count_fits(state,U32.is_eq(parent,2),width)))

def structural_text(+state: State, +value: U32, +span: T.Span, +valid: Bool) -> Step:
  match valid:
    case True{}: advance(state)
    case False{}: reject(state,6,T.start(span),32,value)

def text_kind(+state: State, +value: U32, +span: T.Span, +container: Bool) -> Step:
  match container:
    case True{}: structural_text(state,value,span,T.whitespace(value))
    case False{}: text_leaf(state,value,span,T.utf8_width(value),ctl_role(state_control(state)),ctl_leafParent(state_control(state)))

def text_valid(+state: State, +value: U32, +span: T.Span, +valid: Bool) -> Step:
  match valid:
    case False{}: reject(state,1,T.start(span),0,value)
    case True{}: text_kind(state,value,span,is_container(ctl_role(state_control(state))))

def text(+state: State, +value: U32, +span: T.Span) -> Step:
  text_valid(state,value,span,Bool.and(U32.is_gt(ctl_role(state_control(state)),0),Bool.and(U32.is_zero(ctl_pending(state_control(state))),U32.is_zero(ctl_attrId(state_control(state))))))

def apply_valid(+state: State, +event: T.XmlEvent, +valid: Bool) -> Step:
  match event valid:
    case _ False{}: reject(state,7,zero(),0,0)
    case T.EvOpen{+name,+at} True{}: open(state,name,at)
    case T.EvAttribute{+name,+at} True{}: attribute(state,name,at)
    case T.EvAttributeScalar{+value,+origin,+span} True{}: attr_scalar(state,value,span)
    case T.EvAttributeEnd{+at} True{}: attribute_end(state,at)
    case T.EvStartEnd{+empty,+at} True{}: start_end(state,empty,at)
    case T.EvClose{+name,+span} True{}: close(state,name,span)
    case T.EvText{+value,+origin,+span} True{}: text(state,value,span)

def apply(+state: State, +event: T.XmlEvent) -> Step:
  apply_valid(state,event,state_valid(state))

def summary(+state: State, +end: T.Position) -> Summary:
  Summary{T.ParamsMeta{state_source(state),param_addon(state_params(state)),param_sourceLanguage(state_params(state)),param_destLanguage(state_params(state)),T.Span{root_paramsAt(state_root(state)),root_paramsEnd(state_root(state))}},root_entries(state_root(state))}

def finish_valid(+state: State, +at: T.Position, +valid: Bool) -> Result<&2,&2,T.Diagnostic,Summary>:
  match valid:
    case False{}: Fail{context(state,T.error(3,8,at,0,ctl_role(state_control(state))))}
    case True{}: Done{summary(state,at)}

def finish(+state: State, +at: T.Position) -> Result<&2,&2,T.Diagnostic,Summary>:
  finish_valid(state,at,Bool.and(state_valid(state),Bool.and(root_done(state_root(state)),Bool.and(U32.is_zero(ctl_pending(state_control(state))),U32.is_zero(ctl_role(state_control(state)))))))
