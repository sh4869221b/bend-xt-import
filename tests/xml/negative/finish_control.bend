import Base
import ../../../core/budget.bend as B
import ../../../xml/reader.bend as R

def once(budget: B.Budget,reader: R.Reader) -> B.Budget & R.FinishResult:
  R.finish(budget,reader)

def main() -> U32:
  1
