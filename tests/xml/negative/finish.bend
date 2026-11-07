import Base
import ../../../core/budget.bend as B
import ../../../xml/reader.bend as R

# Successful finish consumes the Reader; attempting a second call with the
# same affine reader and budget must be rejected even in an unreachable def.
def repeated(budget: B.Budget,reader: R.Reader) -> (B.Budget & R.FinishResult) & (B.Budget & R.FinishResult):
  (R.finish(budget,reader),R.finish(budget,reader))

def main() -> U32:
  1
