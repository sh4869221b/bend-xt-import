import Base
import ./storage.bend as S
import ./budget.bend as B
import ./error.bend as E
import ./unicode.bend as U

type OwnedBytes is Type:
  Bytes{storage: S.Storage}

def created(p: B.Budget & Result<&2, &1, E.Error, S.Storage>) -> B.Budget & Result<&2, &1, E.Error, OwnedBytes>:
  (budget,result) = p
  match result:
    case Fail{error}: (budget,Fail{error})
    case Done{storage}: (budget,Done{Bytes{storage}})

def new(budget: B.Budget, length: U32) -> B.Budget & Result<&2, &1, E.Error, OwnedBytes>:
  created(S.new(budget,length))

def drop(budget: B.Budget, owner: OwnedBytes) -> B.Budget & Result<&1, &2, E.Error & B.Allocation, Unit>:
  match owner:
    case Bytes{storage}: S.drop(budget,storage)

def metadata_ready(p: S.Storage & U32 & U32 & U32 & U32) -> OwnedBytes & U32 & U32 & U32 & U32:
  (storage,length,capacity,run,origin) = p
  (Bytes{storage},length,capacity,run,origin)

def metadata(owner: OwnedBytes) -> OwnedBytes & U32 & U32 & U32 & U32:
  match owner:
    case Bytes{storage}: metadata_ready(S.metadata(storage))

def got(p: B.Budget & S.Storage & Result<&2, &2, E.Error, U32>) -> B.Budget & OwnedBytes & Result<&2, &2, E.Error, U32>:
  (budget,storage,result) = p
  (budget,Bytes{storage},result)

def get(budget: B.Budget, owner: OwnedBytes, index: U32) -> B.Budget & OwnedBytes & Result<&2, &2, E.Error, U32>:
  match owner:
    case Bytes{storage}: got(S.get(budget,storage,index))

def changed(p: B.Budget & S.Storage & Result<&2, &2, E.Error, Unit>) -> B.Budget & OwnedBytes & Result<&2, &2, E.Error, Unit>:
  (budget,storage,result) = p
  (budget,Bytes{storage},result)

def put_valid(budget: B.Budget, owner: OwnedBytes, index: U32, value: U32, valid: Bool) -> B.Budget & OwnedBytes & Result<&2, &2, E.Error, Unit>:
  match owner valid:
    case Bytes{storage} False{}: (budget,Bytes{storage},Fail{E.InvalidByte{value}})
    case Bytes{storage} True{}: changed(S.put(budget,storage,index,value))

def put(budget: B.Budget, owner: OwnedBytes, index: U32, +value: U32) -> B.Budget & OwnedBytes & Result<&2, &2, E.Error, Unit>:
  put_valid(budget,owner,index,value,U32.is_le(value,255))

def clear(owner: OwnedBytes) -> OwnedBytes:
  match owner:
    case Bytes{storage}: Bytes{S.clear(storage)}

def append_valid(budget: B.Budget, owner: OwnedBytes, value: U32, valid: Bool) -> B.Budget & OwnedBytes & Result<&2, &2, E.Error, Unit>:
  match owner valid:
    case Bytes{storage} False{}: (budget,Bytes{storage},Fail{E.InvalidByte{value}})
    case Bytes{storage} True{}: changed(S.append(budget,storage,value))

def append(budget: B.Budget, owner: OwnedBytes, +value: U32) -> B.Budget & OwnedBytes & Result<&2, &2, E.Error, Unit>:
  append_valid(budget,owner,value,U32.is_le(value,255))

type CopyResult is Type:
  Copied{bytes: OwnedBytes}
  CopyFailed{error: E.Error, partial: Maybe<&1, OwnedBytes>}

def copied_write(source: OwnedBytes, p: B.Budget & OwnedBytes & Result<&2, &2, E.Error, Unit>) -> B.Budget & OwnedBytes & CopyResult:
  (budget,dest,result) = p
  match result:
    case Fail{error}: (budget,source,CopyFailed{error,Some{dest}})
    case Done{u}: (budget,source,Copied{dest})

def copied_read(dest: OwnedBytes, index: U32, p: B.Budget & OwnedBytes & Result<&2, &2, E.Error, U32>) -> B.Budget & OwnedBytes & CopyResult:
  (budget,source,result) = p
  match result:
    case Fail{error}: (budget,source,CopyFailed{error,Some{dest}})
    case Done{byte}: copied_write(source,put(budget,dest,index,byte))

def copy_loop(fuel: Nat, +source_index: U32, +dest_index: U32, p: B.Budget & OwnedBytes & CopyResult) -> B.Budget & OwnedBytes & CopyResult:
  match fuel:
    case 0n: p
    case 1n+rest:
      (budget,source,result) = p
      match result:
        case CopyFailed{error,partial}: (budget,source,CopyFailed{error,partial})
        case Copied{dest}: copy_loop(rest,U32.inc(source_index),U32.inc(dest_index),copied_read(dest,dest_index,get(budget,source,source_index)))

def copy_allocated(source: OwnedBytes, offset: U32, length: U32, p: B.Budget & Result<&2, &1, E.Error, OwnedBytes>) -> B.Budget & OwnedBytes & CopyResult:
  (budget,result) = p
  match result:
    case Fail{error}: (budget,source,CopyFailed{error,None{}})
    case Done{dest}: copy_loop(U32.to_nat(length),offset,0,(budget,source,Copied{dest}))

def copy_valid(budget: B.Budget, source: OwnedBytes, offset: U32, +length: U32, size: U32, valid: Bool) -> B.Budget & OwnedBytes & CopyResult:
  match valid:
    case False{}: (budget,source,CopyFailed{E.Bounds{offset,length,size},None{}})
    case True{}: copy_allocated(source,offset,length,new(budget,length))

def copy_offset(budget: B.Budget, source: OwnedBytes, +offset: U32, +length: U32, +size: U32, valid: Bool) -> B.Budget & OwnedBytes & CopyResult:
  match valid:
    case False{}: (budget,source,CopyFailed{E.Bounds{offset,length,size},None{}})
    case True{}: copy_valid(budget,source,offset,length,size,U32.is_le(length,U32.sub(size,offset)))

def copy_meta(budget: B.Budget, +offset: U32, length: U32, p: OwnedBytes & U32 & U32 & U32 & U32) -> B.Budget & OwnedBytes & CopyResult:
  (source,size0,capacity,run,origin) = p
  +size = {size0: U32}
  copy_offset(budget,source,offset,length,size,U32.is_le(offset,size))

def copy_range(budget: B.Budget, source: OwnedBytes, offset: U32, length: U32) -> B.Budget & OwnedBytes & CopyResult:
  copy_meta(budget,offset,length,metadata(source))
