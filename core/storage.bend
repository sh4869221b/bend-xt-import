import Base
import ./budget.bend as B
import ./error.bend as E
import ./checked.bend as C
import ./charges.bend as Charges

# Trusted internal storage. No external caller may construct/access this type.
type Storage is Type:
  Storage{data: Array<U32>, length: U32, capacity: U32, run: U32, origin: U32, allocation: B.Allocation}

def create(budget: B.Budget, length: U32, capacity: U32, depth: U32, p: B.Allocation & U32 & U32) -> B.Budget & Result<&2, &1, E.Error, Storage>:
  (allocation,run,origin) = p
  (budget,Done{Storage{Array.new(U32,U32.to_nat(depth),0),length,capacity,run,origin,allocation}})

def allocated(length: U32, +capacity: U32, depth: U32, p: B.Budget & Result<&2, &1, E.Error, B.Allocation>) -> B.Budget & Result<&2, &1, E.Error, Storage>:
  (budget,result) = p
  match result:
    case Fail{error}: (budget,Fail{error})
    case Done{allocation}: create(budget,length,capacity,depth,B.identity(allocation))

def capacity_ready(budget: B.Budget, length: U32, r: Result<&2, &1, E.Error, U32 & U32>) -> B.Budget & Result<&2, &1, E.Error, Storage>:
  match r:
    case Fail{error}: (budget,Fail{error})
    case Done{pair}:
      (capacity0,depth) = pair
      +capacity = {capacity0: U32}
      allocated(length,capacity,depth,B.allocate(budget,Charges.bytes(capacity),capacity))

# An initialized logical length; append callers may start empty and reuse capacity.
def new(budget: B.Budget, +length: U32) -> B.Budget & Result<&2, &1, E.Error, Storage>:
  capacity_ready(budget,length,C.ceil_capacity(length))

def drop(budget: B.Budget, storage: Storage) -> B.Budget & Result<&1, &2, E.Error & B.Allocation, Unit>:
  match storage:
    case Storage{data,length,capacity,run,origin,allocation}: B.release(budget,allocation)

def metadata(storage: Storage) -> Storage & U32 & U32 & U32 & U32:
  match storage:
    case Storage{data,+length,+capacity,+run,+origin,allocation}: (Storage{data,length,capacity,run,origin,allocation},length,capacity,run,origin)

def read_value(length: U32, capacity: U32, run: U32, origin: U32, allocation: B.Allocation, p: Array<U32> & U32) -> Storage & U32:
  (data,value) = p
  (Storage{data,length,capacity,run,origin,allocation},value)

def read_done(budget: B.Budget, p: Storage & U32) -> B.Budget & Storage & Result<&2, &2, E.Error, U32>:
  (storage,value) = p
  (budget,storage,Done{value})

def read_owned(budget: B.Budget, storage: Storage, index: U32) -> B.Budget & Storage & Result<&2, &2, E.Error, U32>:
  match storage:
    case Storage{data,length,capacity,run,origin,allocation}:
      read_done(budget,read_value(length,capacity,run,origin,allocation,Array.get(U32,data,index)))

def read_charged(storage: Storage, index: U32, p: B.Budget & Result<&2, &2, E.Error, Unit>) -> B.Budget & Storage & Result<&2, &2, E.Error, U32>:
  (budget,result) = p
  match result:
    case Fail{error}: (budget,storage,Fail{error})
    case Done{u}: read_owned(budget,storage,index)

def read_valid(budget: B.Budget, storage: Storage, index: U32, length: U32, valid: Bool) -> B.Budget & Storage & Result<&2, &2, E.Error, U32>:
  match valid:
    case False{}: (budget,storage,Fail{E.Bounds{index,1,length}})
    case True{}: read_charged(storage,index,B.consume(budget,B.work(1)))

def get(budget: B.Budget, storage: Storage, +index: U32) -> B.Budget & Storage & Result<&2, &2, E.Error, U32>:
  match storage:
    case Storage{data,+length,+capacity,run,origin,allocation}:
      read_valid(budget,Storage{data,length,capacity,run,origin,allocation},index,length,Bool.and(U32.is_le(length,capacity),U32.is_lt(index,length)))

def write_owned(budget: B.Budget, storage: Storage, index: U32, value: U32) -> B.Budget & Storage & Result<&2, &2, E.Error, Unit>:
  match storage:
    case Storage{data,length,capacity,run,origin,allocation}:
      (budget,Storage{Array.set(U32,data,index,value),length,capacity,run,origin,allocation},Done{Unit{}})

def write_charged(storage: Storage, index: U32, value: U32, p: B.Budget & Result<&2, &2, E.Error, Unit>) -> B.Budget & Storage & Result<&2, &2, E.Error, Unit>:
  (budget,result) = p
  match result:
    case Fail{error}: (budget,storage,Fail{error})
    case Done{u}: write_owned(budget,storage,index,value)

def write_valid(budget: B.Budget, storage: Storage, index: U32, length: U32, value: U32, valid: Bool) -> B.Budget & Storage & Result<&2, &2, E.Error, Unit>:
  match valid:
    case False{}: (budget,storage,Fail{E.Bounds{index,1,length}})
    case True{}: write_charged(storage,index,value,B.consume(budget,B.work(1)))

def put(budget: B.Budget, storage: Storage, +index: U32, value: U32) -> B.Budget & Storage & Result<&2, &2, E.Error, Unit>:
  match storage:
    case Storage{data,+length,+capacity,run,origin,allocation}:
      write_valid(budget,Storage{data,length,capacity,run,origin,allocation},index,length,value,Bool.and(U32.is_le(length,capacity),U32.is_lt(index,length)))

def clear(storage: Storage) -> Storage:
  match storage:
    case Storage{data,length,capacity,run,origin,allocation}: Storage{data,0,capacity,run,origin,allocation}

def append_owned(budget: B.Budget, storage: Storage, value: U32) -> B.Budget & Storage & Result<&2, &2, E.Error, Unit>:
  match storage:
    case Storage{data,+length,capacity,run,origin,allocation}:
      (budget,Storage{Array.set(U32,data,length,value),U32.inc(length),capacity,run,origin,allocation},Done{Unit{}})

def append_charged(storage: Storage, value: U32, p: B.Budget & Result<&2, &2, E.Error, Unit>) -> B.Budget & Storage & Result<&2, &2, E.Error, Unit>:
  (budget,result) = p
  match result:
    case Fail{error}: (budget,storage,Fail{error})
    case Done{u}: append_owned(budget,storage,value)

def append_valid(budget: B.Budget, storage: Storage, length: U32, capacity: U32, value: U32, valid: Bool) -> B.Budget & Storage & Result<&2, &2, E.Error, Unit>:
  match valid:
    case False{}: (budget,storage,Fail{E.Bounds{length,1,capacity}})
    case True{}: append_charged(storage,value,B.consume(budget,B.work(1)))

def append(budget: B.Budget, storage: Storage, value: U32) -> B.Budget & Storage & Result<&2, &2, E.Error, Unit>:
  match storage:
    case Storage{data,+length,+capacity,run,origin,allocation}:
      append_valid(budget,Storage{data,length,capacity,run,origin,allocation},length,capacity,value,U32.is_lt(length,capacity))
