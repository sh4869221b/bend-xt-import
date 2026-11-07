# Pure Bend core API

This is Issue #2's bounded, pure core. It does not open files, parse plugins/XML,
import translations, or enable transactional apply. Issue #3's snapshot/host
boundary is separate. Required execution profile: locked Bend 2.0.40 C backend,
Linux x86_64, one worker, GPU off; resource evidence must pass for the exact build.

Bend modules are not private namespaces. `tools/core/lint.py` defines the supported
API boundary: raw owner constructors, Array access, unchecked helpers and source
window binding belong to the reviewed implementation/adapter modules. External
Bend programs that bypass that boundary are outside this contract. The core does
not claim to sandbox hostile Bend source code.

## Ownership and failures

`Budget`, `Reservation`, `Allocation`, `OwnedBytes`, `ScalarChunk`, `SourceOwner`,
`ByteWindow`, and `ShaState` are affine `Type` values. Public operations return the
budget and owners on both successful and recoverable error paths. Libraries never
call `IO.die`. Affinity prevents duplication, not abandonment: callers must dispose
returned owners and settle reservations, including failure payloads.

One invocation entry point calls `budget.start(runId,limits)` once. All its files,
entries, scans and phases share that one budget. The run ID distinguishes
invocations; it is not an OS identity or a cryptographic capability. Concurrent
or independent invocations must not share tokens or reuse an ID while their owners
are combined. The supported repository entry point is the only non-test caller
allowed to initialize a budget. Provenance verification starts a separate run.

Errors have bounded numeric context: Bounds(position,requested,end), InvalidByte,
Overflow(operation,left,right), InvalidEncoding(codec,offset,reason),
ResourceLimit(dimension,limit,used,requested), Io, Unsupported, SourceChanged,
UnsafeNamespace, ResidualWork and InternalInvariant. Context positions are bytes
unless the operation explicitly takes a scalar index. Bounds for subrange uses
parent-relative coordinates. SHA length overflow uses operation 3 and hi/lo byte
count limbs. CLI exit-code mapping belongs to a later issue.

## Budget

`Six{input,expanded,output,logical,live,work}` keeps six independent U32 dimensions.
The profile caps are respectively 1 GiB, 1 GiB, 1 GiB, 512 MiB, 256 MiB and 1 GiB.
These are aggregate accounting ceilings, not evidence that all maximum-sized
files/format structures are supported. Additional per-file/format limits from
DESIGN.md still apply in future parsers.

- `reserve_many(budget,request)` checks all counters before constructing a ticket.
  Used+held never exceeds the limit. Ticket metadata is included in live held
  charge, even for a zero request. Failure returns unchanged budget and no ticket.
- `settle(budget,ticket,actual)` commits actual consumption and cancels unused held
  amounts. Actual cannot exceed the reservation. Failure returns the original
  ticket and unchanged budget. Positive live consumption returns Some Allocation;
  zero live returns None. `cancel` settles zero and cannot leave an uncharged owner.
- `consume` is immediate known byte-work/byte-counter consumption; it refuses live
  allocation requests. It must precede the corresponding work.
- Owners carry their live Allocation until disposed. `release` only refunds live
  storage; consumable counters never decrease. `finish` consumes a fully settled
  budget and returns final usage with live=0. Outstanding owners/tickets prevent it.

Input counts bytes acquired into authoritative snapshots once. Expanded counts
actual decompressor output each time. Output counts successfully emitted final
artifacts, including metadata, once per emission; discarded/rebuilt emissions
still count. Logical counts each referenced length, including aliases. Host short
IO reserves a maximum, settles the actual transferred prefix, and still reports
any error. Pure internal buffer construction/codec output is not final-artifact
output and is not automatically charged to the output dimension.

Work is normative logical byte visits, not instructions or RSS. Owned byte reads
and writes cost one each; a copy costs n reads+n writes in addition to destination
initialization. Creating an initialized buffer charges its physical capacity's
zero writes. Scalar creation charges canonical-width-one initialization; the width
metadata array is bookkeeping. Scalar writes/emission and inspection each cost
canonical UTF-8 width. UTF-8/CP1252 decoding costs input reads plus scalar emission;
encoding costs scalar inspection plus encoded-byte writes. Width metadata is read
before scalar values so exact-limit preflight does not inspect an unpaid scalar.
Metadata/range arithmetic is bounded bookkeeping and has no byte-work charge.
Snapshot OS-boundary transfers, future scans and readback each add their own visits.

## Checked values, bytes and scalar chunks

`checked.add/sub/mul/byte/ceil_capacity` reject overflow and invalid bytes before
arithmetic/access. Buffers have logical length <= power-of-two capacity <=65536.
Empty buffers have minimum capacity 1. OwnedBytes stores Array<U32> values constrained
to 0..255, not a packed native byte vector. ScalarChunk stores valid Unicode scalars
and a second Array<U32> of widths. No public clone or implicit String/List conversion
exists; full logical text builders are separate future budgeted structures.

`new`, `get`, `put`, `append`, `clear`, `metadata`, and `drop` thread owners. `clear`
retains capacity/reservation and sets logical length to zero. Reads/put use logical
length; append uses remaining capacity. Neither masked Array indices nor unused
padding authorize an access. Invalid values, bounds and budget refusals preserve
existing contents. `bytes.copy_range` allocates a distinct owner while retaining
the source; CopyFailed returns any partial destination for disposal. The source
is never modified by copying. Failure can consume actual prefix work; no refund.

## Source ranges and windows

A logical SourceOwner has immutable run/source-id/totalSize independently of buffer
allocation identity. The trusted stream adapter creates it, uses `source_range`
to validate root ranges, and binds owned windows. Bind checks base<=totalSize and
length<=totalSize-base. The adapter must prove its bytes came from that same source;
this pure core cannot establish file provenance. #2 uses synthetic adapters only.

A ByteWindow owns the SourceOwner, OwnedBytes and absolute base. Clients cannot
mutate its bytes without consuming the window through the trusted adapter. Refill
reuses that source token only for the same source; a different source gets a new
identity. A prior Range/ReadState then fails against the new source, even when the
same physical buffer is reused.

`subrange`, `cursor`, `take`, `skip`, and `remaining` use subtraction-before-addition
checks. Zero-length take at end succeeds. Width 1/2/4 begin helpers validate the
entire requested range before reads. `continued` performs available byte visits,
returns NeedMore with a bounded partial assembler at a window edge, and resumes
without rereading consumed prefix bytes. It validates source identity before access.
Both endian orders are explicit. ReadProgress is an internal intermediate state.

## Strict streaming codecs

`codec.decode(kind,budget,input,output,state,start)` uses kind 0 for UTF-8 and 1 for
Windows-1252. Start is the next index within this input chunk. Return Progress
contains carried state, next input index, number of new output scalars and status:
0 input exhausted, 1 output full, 2 sticky error; 3 is internal only. Clear/replace
a full output chunk and resume with the returned state/index. At a new input chunk,
start at zero with carried decoder state. `utf8.finish` rejects an unfinished scalar.
Errors carry absolute stream offsets; overlong/surrogate/range second-byte failures
identify the offending byte, and truncated sequences identify their starting byte.

UTF-8 preserves NUL and BOM as ordinary scalars, rejects malformed/overlong forms,
surrogates and values above U+10FFFF, and never normalizes or replaces. CP1252 follows
the [Microsoft mapping published by Unicode](https://www.unicode.org/Public/MAPPINGS/VENDORS/MICSFT/WINDOWS/CP1252.TXT):
81/8D/8F/90/9D are undefined errors, all 251 defined bytes have an exact reverse map.

`codec.encoder_init` creates the initial encode state. `encode` takes a ScalarChunk
and OwnedBytes output. If output is full, Pending retains an already inspected
scalar/packet; keep the same input and returned next index until it is emitted.
Resumption charges only new output writes. A sticky error cannot be resumed as
success. The output may contain a valid prefix, which a higher-level operation
must not mistake for a completed field/artifact. All arrays and the budget are
returned, including on errors.

## SHA-256 and hex

`sha256.init/update/finalize/drop` implement raw-byte SHA-256 entirely in Bend.
State owns eight words and a fixed 64-word schedule/pending representation. U32
compression additions deliberately wrap; offset/budget arithmetic does not. Total
bytes use hi/lo U32 limbs and reject lengths outside SHA's 64-bit bit-length domain.
`update` validates input length first and returns the state/input/budget on errors.
Partial work-budget failures retain exactly the processed prefix in the state.

Finalize consumes successful state and returns exactly 32 raw digest bytes. Its
failure variants retain the state/any output allocation, or the allocation needing
release after an invariant failure. Callers must dispose all returned resources.
`hex.format` separately produces 64 lowercase ASCII bytes and retains the raw
32-byte source. Non-32 input is refused before allocation; partial-work failures
return both owners. No unbounded String is created.

Hash input visits cost n, while the fixed internal schedule/padding arithmetic
is documented separately: 48 expanded words and 64 rounds per compressed block,
plus one or two final blocks. Resource reports include actual elapsed time and
memory; logical work does not multiply input bytes by 64 rounds. Correctness tests
use NIST/RFC vectors and Python hashlib as independent test oracles, not production
implementations. See [NIST's vector guidance](https://csrc.nist.gov/projects/cryptographic-algorithm-validation-program/secure-hashing);
passing these tests is not CAVP certification.

## Read-only window metadata (Issue #4 addition)

`cursor.window_metadata(window)` returns the same affine ByteWindow and
`Result<&2,&1,Error,Range & U32 & U32>`. Success contains the authoritative full
logical source range `[0,totalSize)`, absolute window base, and logical byte
length, with the source identity retained. It checks window/byte bounds, storage
capacity, and matching source/storage invocation runs (their allocation IDs remain
distinct). It reads no bytes and consumes no work. Empty and end-of-source windows are valid. Failure
also returns the window. This grants neither raw byte access, source construction,
window rebinding, nor permission to mutate storage. A client can therefore reject
foreign refills and distinguish the logical source end from a window end without
trusting a caller-supplied shortened range.
