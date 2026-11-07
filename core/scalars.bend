import Base
import ./storage.bend as S
import ./budget.bend as B
import ./checked.bend as C
import ./error.bend as E
import ./unicode.bend as U
import ./charges.bend as Charges

# Widths are bounded metadata, inspected before visiting the scalar value.
# They permit exact canonical-byte preflight without reading a scalar first.
type ScalarChunk is Type:
  Scalars{storage: S.Storage, widths: Array<U32>}

def created(budget: B.Budget, length: U32, capacity: U32, +depth: U32, p: B.Allocation & U32 & U32) -> B.Budget & Result<&2, &1, E.Error, ScalarChunk>:
  (allocation,run,origin) = p
  (budget,Done{Scalars{S.Storage{Array.new(U32,U32.to_nat(depth),0),length,capacity,run,origin,allocation},Array.new(U32,U32.to_nat(depth),1)}})

def allocated(length: U32, capacity: U32, depth: U32, p: B.Budget & Result<&2, &1, E.Error, B.Allocation>) -> B.Budget & Result<&2, &1, E.Error, ScalarChunk>:
  (budget,result) = p
  match result:
    case Fail{error}: (budget,Fail{error})
    case Done{allocation}: created(budget,length,capacity,depth,B.identity(allocation))

def capacity_ready(budget: B.Budget, length: U32, r: Result<&2, &1, E.Error, U32 & U32>) -> B.Budget & Result<&2, &1, E.Error, ScalarChunk>:
  match r:
    case Fail{error}: (budget,Fail{error})
    case Done{pair}:
      (capacity0,depth) = pair
      +capacity = {capacity0: U32}
      allocated(length,capacity,depth,B.allocate(budget,Charges.scalars(capacity),capacity))

def new(budget: B.Budget, +length: U32) -> B.Budget & Result<&2, &1, E.Error, ScalarChunk>:
  capacity_ready(budget,length,C.ceil_capacity(length))

def drop(budget: B.Budget, owner: ScalarChunk) -> B.Budget & Result<&1, &2, E.Error & B.Allocation, Unit>:
  match owner:
    case Scalars{storage,widths}: S.drop(budget,storage)

def metadata_ready(widths: Array<U32>, p: S.Storage & U32 & U32 & U32 & U32) -> ScalarChunk & U32 & U32 & U32 & U32:
  (storage,length,capacity,run,origin) = p
  (Scalars{storage,widths},length,capacity,run,origin)

def metadata(owner: ScalarChunk) -> ScalarChunk & U32 & U32 & U32 & U32:
  match owner:
    case Scalars{storage,widths}: metadata_ready(widths,S.metadata(storage))

def got(widths: Array<U32>, p: B.Budget & S.Storage & Result<&2, &2, E.Error, U32>) -> B.Budget & ScalarChunk & Result<&2, &2, E.Error, U32>:
  (budget,storage,result) = p
  (budget,Scalars{storage,widths},result)

def get_charged(storage: S.Storage, widths: Array<U32>, index: U32, p: B.Budget & Result<&2, &2, E.Error, Unit>) -> B.Budget & ScalarChunk & Result<&2, &2, E.Error, U32>:
  (budget,result) = p
  match result:
    case Fail{error}: (budget,Scalars{storage,widths},Fail{error})
    case Done{u}: got(widths,S.read_owned(budget,storage,index))

def get_width(budget: B.Budget, storage: S.Storage, index: U32, p: Array<U32> & U32) -> B.Budget & ScalarChunk & Result<&2, &2, E.Error, U32>:
  (widths,width) = p
  get_charged(storage,widths,index,B.consume(budget,B.work(width)))

def get_valid(budget: B.Budget, storage: S.Storage, widths: Array<U32>, +index: U32, length: U32, valid: Bool) -> B.Budget & ScalarChunk & Result<&2, &2, E.Error, U32>:
  match valid:
    case False{}: (budget,Scalars{storage,widths},Fail{E.Bounds{index,1,length}})
    case True{}: get_width(budget,storage,index,Array.get(U32,widths,index))

def get(budget: B.Budget, owner: ScalarChunk, +index: U32) -> B.Budget & ScalarChunk & Result<&2, &2, E.Error, U32>:
  match owner:
    case Scalars{S.Storage{data,+length,+capacity,run,origin,allocation},widths}:
      get_valid(budget,S.Storage{data,length,capacity,run,origin,allocation},widths,index,length,Bool.and(U32.is_le(length,capacity),U32.is_lt(index,length)))

def changed(widths: Array<U32>, p: B.Budget & S.Storage & Result<&2, &2, E.Error, Unit>) -> B.Budget & ScalarChunk & Result<&2, &2, E.Error, Unit>:
  (budget,storage,result) = p
  (budget,Scalars{storage,widths},result)

# Internal-only, after all bounds and canonical-width work are reserved.
def put_precharged(budget: B.Budget, owner: ScalarChunk, +index: U32, +value: U32) -> B.Budget & ScalarChunk & Result<&2, &2, E.Error, Unit>:
  match owner:
    case Scalars{storage,widths}: changed(Array.set(U32,widths,index,U.width(value)),S.write_owned(budget,storage,index,value))

def put_charged(owner: ScalarChunk, index: U32, value: U32, p: B.Budget & Result<&2, &2, E.Error, Unit>) -> B.Budget & ScalarChunk & Result<&2, &2, E.Error, Unit>:
  (budget,result) = p
  match result:
    case Fail{error}: (budget,owner,Fail{error})
    case Done{u}: put_precharged(budget,owner,index,value)

def put_bounds(budget: B.Budget, owner: ScalarChunk, index: U32, length: U32, +value: U32, valid: Bool) -> B.Budget & ScalarChunk & Result<&2, &2, E.Error, Unit>:
  match valid:
    case False{}: (budget,owner,Fail{E.Bounds{index,1,length}})
    case True{}: put_charged(owner,index,value,B.consume(budget,B.work(U.width(value))))

def put_scalar(budget: B.Budget, owner: ScalarChunk, +index: U32, value: U32, valid: Bool) -> B.Budget & ScalarChunk & Result<&2, &2, E.Error, Unit>:
  match owner valid:
    case Scalars{storage,widths} False{}: (budget,Scalars{storage,widths},Fail{E.InvalidEncoding{0,index,5}})
    case Scalars{S.Storage{data,+length,+capacity,run,origin,allocation},widths} True{}:
      put_bounds(budget,Scalars{S.Storage{data,length,capacity,run,origin,allocation},widths},index,length,value,Bool.and(U32.is_le(length,capacity),U32.is_lt(index,length)))

def put(budget: B.Budget, owner: ScalarChunk, index: U32, +value: U32) -> B.Budget & ScalarChunk & Result<&2, &2, E.Error, Unit>:
  put_scalar(budget,owner,index,value,U.scalar(value))

def clear(owner: ScalarChunk) -> ScalarChunk:
  match owner:
    case Scalars{storage,widths}: Scalars{S.clear(storage),widths}

def append_precharged(budget: B.Budget, owner: ScalarChunk, +value: U32) -> B.Budget & ScalarChunk & Result<&2, &2, E.Error, Unit>:
  match owner:
    case Scalars{S.Storage{data,+length,capacity,run,origin,allocation},widths}:
      changed(Array.set(U32,widths,length,U.width(value)),S.append_owned(budget,S.Storage{data,length,capacity,run,origin,allocation},value))

def append_charged(owner: ScalarChunk, value: U32, p: B.Budget & Result<&2, &2, E.Error, Unit>) -> B.Budget & ScalarChunk & Result<&2, &2, E.Error, Unit>:
  (budget,result) = p
  match result:
    case Fail{error}: (budget,owner,Fail{error})
    case Done{u}: append_precharged(budget,owner,value)

def append_bounds(budget: B.Budget, owner: ScalarChunk, length: U32, capacity: U32, +value: U32, valid: Bool) -> B.Budget & ScalarChunk & Result<&2, &2, E.Error, Unit>:
  match valid:
    case False{}: (budget,owner,Fail{E.Bounds{length,1,capacity}})
    case True{}: append_charged(owner,value,B.consume(budget,B.work(U.width(value))))

def append_scalar(budget: B.Budget, owner: ScalarChunk, value: U32, valid: Bool) -> B.Budget & ScalarChunk & Result<&2, &2, E.Error, Unit>:
  match owner valid:
    case Scalars{storage,widths} False{}: (budget,Scalars{storage,widths},Fail{E.InvalidEncoding{0,0,5}})
    case Scalars{S.Storage{data,+length,+capacity,run,origin,allocation},widths} True{}:
      append_bounds(budget,Scalars{S.Storage{data,length,capacity,run,origin,allocation},widths},length,capacity,value,U32.is_lt(length,capacity))

def append(budget: B.Budget, owner: ScalarChunk, +value: U32) -> B.Budget & ScalarChunk & Result<&2, &2, E.Error, Unit>:
  append_scalar(budget,owner,value,U.scalar(value))
