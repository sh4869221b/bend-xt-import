import Base
import ../core/error.bend as E
import ../core/budget.bend as B
import ../core/bytes.bend as Bytes

def digit(n: U32, decimal: Bool) -> U32:
  match decimal:
    case True{}: U32.add(n,48)
    case False{}: U32.add(n,87)

def nibble(+n: U32) -> U32:
  digit(n,U32.is_lt(n,10))

def second_written(source: Bytes.OwnedBytes, p: B.Budget & Bytes.OwnedBytes & Result<&2, &2, E.Error, Unit>) -> B.Budget & Bytes.OwnedBytes & Bytes.CopyResult:
  (budget,dest,result) = p
  match result:
    case Fail{error}: (budget,source,Bytes.CopyFailed{error,Some{dest}})
    case Done{u}: (budget,source,Bytes.Copied{dest})

def first_written(source: Bytes.OwnedBytes, index: U32, byte: U32, p: B.Budget & Bytes.OwnedBytes & Result<&2, &2, E.Error, Unit>) -> B.Budget & Bytes.OwnedBytes & Bytes.CopyResult:
  (budget,dest,result) = p
  match result:
    case Fail{error}: (budget,source,Bytes.CopyFailed{error,Some{dest}})
    case Done{u}: second_written(source,Bytes.put(budget,dest,U32.add(U32.mul(index,2),1),nibble(U32.and(byte,15))))

def read(dest: Bytes.OwnedBytes, +index: U32, p: B.Budget & Bytes.OwnedBytes & Result<&2, &2, E.Error, U32>) -> B.Budget & Bytes.OwnedBytes & Bytes.CopyResult:
  (budget,source,result) = p
  match result:
    case Fail{error}: (budget,source,Bytes.CopyFailed{error,Some{dest}})
    case Done{+byte}: first_written(source,index,byte,Bytes.put(budget,dest,U32.mul(index,2),nibble(U32.shrn(byte,4n))))

def loop(fuel: Nat, +index: U32, p: B.Budget & Bytes.OwnedBytes & Bytes.CopyResult) -> B.Budget & Bytes.OwnedBytes & Bytes.CopyResult:
  match fuel:
    case 0n: p
    case 1n+rest:
      (budget,source,result) = p
      match result:
        case Bytes.CopyFailed{error,partial}: (budget,source,Bytes.CopyFailed{error,partial})
        case Bytes.Copied{dest}: loop(rest,U32.inc(index),read(dest,index,Bytes.get(budget,source,index)))

def allocated(source: Bytes.OwnedBytes, p: B.Budget & Result<&2, &1, E.Error, Bytes.OwnedBytes>) -> B.Budget & Bytes.OwnedBytes & Bytes.CopyResult:
  (budget,result) = p
  match result:
    case Fail{error}: (budget,source,Bytes.CopyFailed{error,None{}})
    case Done{dest}: loop(32n,0,(budget,source,Bytes.Copied{dest}))

def valid(budget: B.Budget, source: Bytes.OwnedBytes, length: U32, okay: Bool) -> B.Budget & Bytes.OwnedBytes & Bytes.CopyResult:
  match okay:
    case False{}: (budget,source,Bytes.CopyFailed{E.Bounds{0,length,32},None{}})
    case True{}: allocated(source,Bytes.new(budget,64))

def metadata(budget: B.Budget, p: Bytes.OwnedBytes & U32 & U32 & U32 & U32) -> B.Budget & Bytes.OwnedBytes & Bytes.CopyResult:
  (source,length0,capacity,run,origin) = p
  +length = {length0: U32}
  valid(budget,source,length,U32.is_eq(length,32))

def format(budget: B.Budget, digest: Bytes.OwnedBytes) -> B.Budget & Bytes.OwnedBytes & Bytes.CopyResult:
  metadata(budget,Bytes.metadata(digest))
