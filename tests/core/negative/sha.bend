import Base
import ../../../core/budget.bend as B
import ../../../core/bytes.bend as Bytes
import ../../../core/scalars.bend as Scalars
import ../../../core/cursor.bend as C
import ../../../hash/sha256.bend as SHA

def use(x: SHA.ShaState) -> SHA.ShaState & SHA.ShaState:
  (x,x)

def main() -> U32:
  0
