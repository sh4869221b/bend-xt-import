import Base

# Candidate core-linux-x86_64-c1 profile. Acceptance requires the matching
# generated-layout/resource evidence; these are not independent RSS limits.
def budget_state() -> U32:
  65536

def owner_metadata() -> U32:
  4096

def bytes(capacity: U32) -> U32:
  U32.max(65536,U32.mul(capacity,16))

def scalars(capacity: U32) -> U32:
  U32.max(65536,U32.mul(capacity,32))

def sha_state() -> U32:
  65536
