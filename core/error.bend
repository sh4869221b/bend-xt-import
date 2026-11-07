import Base

# Numeric context only; no input-controlled String is retained in an error.
type Error is Data:
  Bounds{position: U32, requested: U32, end: U32}
  InvalidByte{value: U32}
  Overflow{operation: U32, left: U32, right: U32}
  InvalidEncoding{codec: U32, offset: U32, reason: U32}
  ResourceLimit{dimension: U32, limit: U32, used: U32, requested: U32}
  Io{operation: U32, number: U32, completed: U32}
  Unsupported{capability: U32}
  SourceChanged{}
  UnsafeNamespace{reason: U32}
  ResidualWork{reason: U32}
  InternalInvariant{reason: U32}
