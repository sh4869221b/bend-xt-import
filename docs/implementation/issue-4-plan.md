# Issue #4: bounded FO4 framing and unchanged copying

Status: proposed implementation plan, revision 3, 2026-11-07. Independent plan
review is required before implementation. This document is not implementation,
test, performance, or game-compatibility evidence.

## 1. Scope and starting point

Implement [Issue #4](https://github.com/sh4869221b/bend-xt-import/issues/4) against
the merged Issue #2 core at `1b0421c15f9724a614a7b7bfae9605ec6456eb05`.
The requirements are DESIGN.md sections 4, 5, and 10. The current design is
revision 0.5; its platform clarification does not change this framing task.
Relevant inspected contracts are `docs/core/api.md`, `docs/core/charges.md`,
`core/cursor.bend`, `core/budget.bend`, and the existing core build/evidence tools.

The deliverable is a **pure Bend 2 library**, bounded synthetic adapters/tests,
and fresh CI evidence. It will:

- Scan 24-byte records and GRUPs, uncompressed six-byte subrecord frames and XXXX.
- Emit immutable metadata with source-bound original spans, in file order.
- Validate parent boundaries, the first/unique TES4, counts, depth, and sizes.
- Copy an entirely scanned source without reconstructing any original header or
  payload, yielding exactly the input byte sequence through bounded output chunks.
- Return bounded structural diagnostics and all resources needed for cleanup.

Issue #3 remains independently ongoing. Do not import its host modules, alter its
ABI, wait for its implementation, or use its unaccepted evidence. Production
parsing and copying are Bend. Python is restricted to test fixture generation,
oracles, orchestration, and evidence checks. Test-only IO may transport opaque
fixture bytes into synthetic windows; it must not parse or repair them first.

Out of scope: file acquisition/publication, CLI, XML, string decoding/matching,
compression/decompression, serializers for edits, target selection, duplicate
FormID resolution, relocation-safety decisions, and a supported-game-version
catalog. Exposing form version does not establish that it is supported for an
import. Localized flags can be inspected/copied here without enabling localized
import. This completes only the framing/copy portion of Gate B, not Gate B as a
whole, transactional apply, or game-safety certification.

## 2. Representation and module boundaries

Use a streaming pull/event machine, not a full in-memory tree or a List of every
frame. The parser retains a fixed-size stack and the current header/record state.
Callers consume one event at a time. A later structural index must have its own
budgeted owner; retaining an unbounded collection of these events is outside this
API's contract.

Planned production modules:

| Module | Responsibility |
| --- | --- |
| `plugin/types.bend` | Fixed-size metadata/events, numeric signatures, limits, body-kind and completion summaries. |
| `plugin/error.bend` | Bounded structural context plus format-reason and underlying core errors. |
| `plugin/state.bend` | Affine scanner storage, fixed GRUP stack, allocation and disposal. |
| `plugin/frame.bend` | Full-source record/GRUP state machine and TES4 rule. |
| `plugin/subrecords.bend` | Incremental uncompressed subrecord/XXXX framing. |
| `plugin/copy.bend` | Validated whole-source unchanged copy through bounded chunks. |

All signatures are four raw bytes represented as a little-endian U32, not decoded
text. Preserve every unknown value. Do not reject a signature merely because it
is absent from a record/field catalog. `GRUP` is special only at the object level,
and `XXXX` only at the subrecord level. A `TES4` byte sequence inside a payload is
not a second TES4 record.

Metadata includes:

- Record: signature, raw flags, FormID, raw revision word, form version, raw last
  u16, header span, payload span, complete original span, parent start/end, depth,
  and file-order record ordinal. The raw flag value remains authoritative.
- GRUP: label word, raw group-type word, both raw trailing words containing all
  stamps/unknown values, header/full spans, parent context, and depth. Do not
  impose semantic restrictions on group type or infer a label's meaning.
- Subrecord: signature, original u16 size, effective payload length, actual
  six-byte header span, payload span, full encoding span, optional ten-byte XXXX
  span, owning record start, and zero-based real-subrecord ordinal. The full
  encoding span starts at XXXX when present. The XXXX is not a field occurrence.

Spans use the existing `core/cursor.Range` source identity and absolute half-open
offsets. Derive all spans through `source_range`/`subrange`/`take`; production
parser clients must not construct raw Range, Cursor, SourceOwner or ByteWindow
values. Metadata may be inspected but never used as authorization for an edit.

Expose record compression (`0x00040000`) and deletion (`0x00000020`) distinctly.
For the TES4 header, expose master (`0x1`), localized (`0x80`), and light (`0x200`)
bit facts, with references to the pinned FO4 definitions when documenting them.
Do not apply TES4-specific flag meanings to arbitrary records. No parser or
copier API accepts a filename/extension. All other bits are preserved verbatim.
Deleted records are still structurally scanned; their metadata marks them
ineligible for future translation targeting. This task supplies no target API.

## 3. Window API and ownership contract

### Minimal additive core change

The current public core deliberately does not expose ByteWindow contents or
adapter-only bind/unbind. Add one ownership-preserving read-only operation,
`cursor.window_metadata(window)`, returning the same window plus the full logical
source range `[0,totalSize)`, absolute window base, and logical byte length. It
uses the source token and byte metadata, checks its invariants, performs no byte
read, and grants no mutation or rebinding ability. Return the window on errors.
The proposed exact signature is:

```text
window_metadata(window: ByteWindow)
  -> ByteWindow & Result<&2, &1, E.Error, Range & U32 & U32>
```

The returned tuple is `(fullSourceRange, windowBase, windowLength)`. The Range
encodes only run/source-id/zero/totalSize, so this exposes exactly the agreed
source identity, total size, base and length without granting raw constructors.
Add it to API documentation and the precise lint allowlist, with wrong-source,
empty/end-window, maximum-offset, and ownership tests. Do not expose Array or
relax adapter-only constructors. This is the only required core API addition.

The parser initializes from a ByteWindow, obtaining the full range from that
operation rather than trusting a caller-supplied shorter Range as EOF. Capture
run/source identity and total size once. Every subsequent call checks those facts
before emitting even a metadata-only event, closing groups, or returning Done.
`core.cursor.continued` remains the actual byte reader and charges each visit.

### Scanner shape and operations

Exact Bend tuple/variant syntax will follow the existing affine APIs. The
supported logical operations are:

- `start(budget, window, limits)` returns budget/window and either a new affine
  Scanner or a diagnostic. Validate limits/source size before stack allocation.
- `next(budget, window, scanner)` returns all three owners and one fixed-size
  result: Event, NeedWindow(next absolute offset), Complete(summary), or Failed.
- `input_ended(scanner)` turns an outstanding request into a sticky premature-
  input diagnostic; it is not an alternative way to declare successful EOF.
- `drop(budget, scanner)` disposes stack/state storage and releases its charge.
  A failed release returns the remaining allocation as existing core APIs do.

Events are GroupStart, GroupEnd, RecordStart, Subrecord, and RecordEnd. RecordStart
does not imply that its body has passed. Only Complete certifies the stated scan
level. Complete and Failed are sticky terminal states: repeated calls do not
advance, produce new events, reset counters, or recover into success. A zero-byte
or misplaced window may produce NeedWindow once per call, never an internal
retry loop. The adapter must supply a window covering that exact requested
offset, or report input termination/IO failure. Windows can be smaller than
64 KiB, and fields may cross every possible window split.

Only the synthetic adapter mints SourceOwner and binds/unbinds windows in tests.
It may seek to a requested header offset because the source is immutable; payload
skips need not materialize opaque bytes. Any future #3 adapter must establish
that every refill is from the same authoritative snapshot. Numeric source
identity is not a digest, proof against a dishonest adapter, or OS provenance.

The scanner stores one incomplete 1/2/4-byte core ReadState and fixed-size header
words. Resume without rereading an already consumed prefix. Within one next call,
either produce an event/status or advance a bounded amount of state. In particular,
pop at most one group per GroupEnd event. Do not use file-size recursion, build an
event List, or turn NeedMore into an unbounded synchronous refill loop.

## 4. Record and GRUP framing algorithm

The active parent is the root `[0,size)` or the top GRUP's body interval.
The stack retains each open group's start and end; its capacity is exactly 64.

1. At position equal to a group's end, emit its GroupEnd and pop it. Empty groups
   therefore open and close without inventing a child. Equality with several
   ancestor ends closes them on successive events.
2. At root EOF with an empty stack, complete only if TES4 was accepted and no
   partial header/record/XXXX remains. Empty input reports MissingTES4.
3. Otherwise require 24 bytes remaining within the active parent **before**
   beginning a header. A window edge is not EOF. Read the six header words using
   the existing checked little-endian reader.
4. Require the first object at byte zero to be an ordinary TES4 record, not a
   GRUP containing one. Reject a later TES4 at any nesting depth. Do not accept
   arbitrary leading bytes or a preliminary empty group.
5. GRUP size includes its own 24 bytes. Require size >=24, size <= parentEnd-start,
   and a permitted depth/count before push. Derive end only after those checks;
   emit GroupStart and begin children at start+24.
6. Record size excludes its 24-byte header. Prove the header fits, derive body
   start, and require payloadSize <= parentEnd-bodyStart before computing end.
   Enforce the stored-payload limit and record/object counters before body
   processing. Emit RecordStart with all original spans.
7. For an uncompressed record, run the subrecord machine to the exact record end.
   For a compressed record, mark its entire payload opaque and advance directly
   to its checked end. Emit RecordEnd with the body's validation level, then
   resume sibling framing at that end.

Every ordinary record consumes at least 24 source bytes and every group consumes
its header once. Siblings are processed strictly consecutively; there is no
caller-supplied offset table or search for the next plausible signature. This
prevents accepting overlaps by resynchronizing past malformed bytes. A child
ending beyond its parent, a parent ending partway through a child/header, and
residual bytes too short for a new frame are errors, not padding to ignore.

All checks use `position <= end` followed by `length <= end-position` before
addition. Never first calculate `start+24+payloadSize` or `start+groupSize` and
then compare a wrapped result. Public scans reject oversized sources before
reading; internal arithmetic-unit tests exercise near-U32 boundaries without
raising that production source cap. A declared size that would wrap is safely
reported as a parent-boundary/size error; it need not reach a wrapped add to emit
the core Overflow variant.

## 5. Subrecords and XXXX

The subrecord cursor is bounded by that record's payload range. Zero-length
record bodies and zero-length ordinary subrecord payloads are structurally valid.
No HEDR or other semantic field is required by this generic layer.

At each real-subrecord attempt, check the global real-subrecord limit before
reading/processing another field. If at exact record end, emit RecordEnd instead.
Otherwise require a six-byte header. For a non-XXXX signature, check the u16
payload length against the remaining record bytes, derive spans, emit the event,
and skip to payload end. The payload's contents are not decoded or normalized.

For XXXX:

1. Its u16 size must equal four, and all four length bytes must fit the record.
2. Read the extended u32 length and retain the escape's original ten-byte span.
3. Require an immediately following complete six-byte real header inside the
   same record. No other record/GRUP/window transition can resolve a pending
   escape. Reject a second XXXX even when its size and contents look valid.
4. Use the extended u32 length exclusively. The following real header's u16 is
   preserved and ignored, including nonzero/inconsistent values. Do not require
   that extended lengths exceed 65535: zero and smaller lengths are legal here.
5. Require the real payload to fit the remaining record interval, then emit one
   Subrecord event whose full encoding span includes both headers. Increment the
   real count/ordinal once. No separate translated-field event is emitted for
   XXXX. A complete escape at record end, an incomplete next header, and a next
   payload extending past record end are distinct diagnosed failures.

The count bounds real subrecords; the grammar permits at most one extra escape
per real subrecord, so successful wire-header processing is bounded by twice
that count. Check this multiplication when validating configured limits. An
incomplete/repeated escape fails immediately and cannot create an unmetered
sequence of pseudo-fields. Record ordinals and subrecord ordinals are explicitly
separate; global counts do not reset at a record, group, or refill.

## 6. Compressed and unknown content: precise capability boundary

Compressed payloads are **opaque framing-only data** in this issue. Do not read
the first four bytes as an allocation request, run zlib, or try to interpret the
payload as subrecords. The outer record length must fit; its stored bytes can
still be copied unchanged. This deliberately makes no statement about validity
of the expanded-length prefix or zlib stream, even for a zero/short/arbitrary
compressed payload. An invalid stream is not misreported as validated compression.

Expose a small structural-body access operation returning the uncompressed range
or an explicit `UnsupportedCompressedPayload` diagnostic with the record location.
Use a body-kind discriminant rather than an empty subrecord collection that a
caller could mistake for an inspected empty record. Completion summaries include
the number of opaque compressed records and whether all bodies were structurally
scanned. No edit/semantic capability is granted for either kind. There is no
editing API in this task; document and test compressed access refusal through
the explicit operation, and state that compressed translation remains disabled.

Unknown uncompressed records receive exactly the same subrecord framing checks
as known signatures. Unknown fields are reported as unclassified source spans,
not strings or translatable fields. OFST/CLSZ and an optimized-file flag are
preserved by this copy-only library; their eventual nonidentical-rewrite policy
belongs to the later game/relocation profile. Do not silently drop, repair, or
classify them as safe merely because structural parsing succeeded.

## 7. Byte-identical no-op copy

Copy must be exercised through production Bend code, not a Python identity-copy
oracle or a header reserializer. Use a separate pass over the same immutable
logical source. The copier consumes a **successfully completed affine Scanner**;
a raw summary/event/range is insufficient. Starting it from running/failed state
is refused and returns that owner. Retain the scanner's allocation/identity in
CopyState, with charge covering the larger combined state, until disposal.

The copy API accepts an empty, caller-owned reusable OwnedBytes buffer of capacity
1..65536, and owns it while filling. Pumping returns one of:

- NeedWindow(copy owner, requested absolute offset), retaining a partial output.
- ChunkReady(copy continuation, output owner, final-chunk flag).
- Failed(copy owner, diagnostic), retaining any partial output for disposal.

After a nonfinal ChunkReady, the caller consumes the chunk and explicitly resumes
with an empty buffer; the waiting copier must not advance without that handback.
Final completion means the full ordered byte sequence was produced, not that a
host write/publication succeeded. The final result and drop path must return or
release every remaining owner. No active copy state is duplicable.

Read each byte of `[0,totalSize)` in increasing order using source-bound checked
reads and append the same byte to output. Require identity/size on every window,
never skip output bytes, and retain a read-but-not-appended byte if an operation
fails between the two steps. Errors are sticky; a partial output must never be
returned as a completed copy. No input byte is changed or regenerated from parsed
metadata. In particular preserve unknown flags/stamps/payloads, noncanonical
XXXX encodings, deleted records, HEDR count bytes, and MAST/DATA ordering.
Use a bounded internal pump rather than an externally visible transition per
byte. Existing 1/2/4-byte readers may assemble a small packet to reduce repeated
cursor setup, provided packet emission preserves byte order and pending bytes
without rereads. Benchmark before committing to large resource cases; do not
introduce uncharged raw access to hide an inefficient ownership path.

The caller's synthetic sink concatenates emitted chunks and compares them with
the original fixture byte-for-byte; also compare independent SHA-256 digests for
large cases. The copy pass rereads every byte and is metered separately. Internal
buffer production does not consume `output`: a future final-artifact sink charges
actual successful emissions exactly once, per the existing core contract. This
issue makes no claim about actual disk-copy/publication safety or host IO.

## 8. Limits, accounting, diagnostics, and failures

Initial fixed tested ceilings/defaults:

| Limit | Maximum/default and meaning |
| --- | --- |
| Source bytes | 256 MiB, checked before parser-state allocation or reads. |
| Stored record payload | 32 MiB, for either body kind; no expanded-size claim. |
| Ordinary records | 2,000,000 including TES4. |
| All objects | 2,000,000 records plus GRUPs, preventing empty-group amplification. |
| Real subrecords | 8,000,000 across all uncompressed bodies. |
| GRUP depth | 64 open groups; root is depth zero. |
| Input/output window capacity | 65536, inherited from core. |

Callers may lower limits, including zero count/depth budgets, for constrained runs
and edge tests. Reject configurations above these tested ceilings, inconsistent
record/object caps, or overflowing derived bounds before allocation. These are
format caps in addition to the shared six-dimensional budget, not claims that
every maximum simultaneously fits its work/live budget. Record-size cap is an
explicit conservative stored-size restriction pending compression integration.

Use the invocation's existing Budget throughout scanning and copying. Never
start a new budget per record, refill, retry, or pass. Parser reads cost exactly
the bytes actually read via cursor; range skips inspect no payload bytes and
consume no byte-work. Thus an uncompressed scan costs 24 per object, six per real
subrecord, and ten additional bytes per XXXX. A compressed body adds no body
visits in this issue. Copying costs one read plus one output-buffer write per
byte, in addition to explicitly charged buffer initialization. Synthetic fixture
construction/transport and any verification traversal have their own real costs.
Input acquisition is charged by the adapter once, never again by the scanner;
there is no decompressor or automatic logical-text charge here.

Reserve scanner/stack live storage before constructing it using public
`reserve_many`/`settle`; retain its Allocation and cancel/return reservations on
every failed initialization path. Only `plugin/state.bend` may own raw fixed
Array storage. Two 64-cell U32 arrays for group starts/ends plus bounded scanner,
event, copier and partial-read metadata have a provisional minimum 65536 live
charge plus the core's 4096 owner metadata. Inspect generated C and measure this
combined shape before accepting that charge; increase it or change the
representation if measurements fail. Do not claim the existing core profile
already certifies the new parser. No allocation is sized from input counts or
declared payload lengths.

Format counters use pre-increment `used < limit` checks; no wrapping increment.
The stack checks depth before indexing and uses logical depth, never Array's
masked physical indexing as validation. Fixed metadata bookkeeping is not byte
work but is bounded by consumed headers, object/subrecord caps, and per-call
progress. Existing independent 1 GiB process-memory enforcement still applies.

Use a `plugin.error.Diagnostic` wrapping either a numeric format reason or a core
Error, with fixed numeric context: source run/id, absolute failure offset, active
parent start/end, optional owning record start, group depth, and relevant
declared/requested length or count. No input-derived String or ancestry List.
The error describes the first deterministically encountered failure.

Document stable reason identifiers/precedence for at least missing/duplicate
TES4, first object not TES4, truncated initial/object/subrecord header, unexpected
residual trailer, group size below 24, child outside parent, record-payload limit,
dangling/repeated/bad-size XXXX, extended payload outside record, count/depth/
source limit, foreign source, premature adapter EOF, unsupported compressed
access, invalid state, and underlying budget/overflow errors. Distinguish a known
source-range truncation from NeedWindow. Complete group paths are not needed to
locate a fault; parent/record/depth/absolute offset suffice.

All failures return Budget, ByteWindow, and every scanner/copy/output/reservation
owner still held. Cleanup must restore live usage and held reservations to their
pre-operation state; consumed work is not refunded. Libraries never terminate
the process. Tests require successful `budget.finish` after both success and
failure cleanup, not merely a correct error label.

## 9. Test matrix and independent checks

Add test-only synthetic window/refill and sink helpers in `tests/plugin/`.
Fixed authored vectors assert exact metadata, spans, offsets, reason codes,
counts, event order, body validation level, work counters, and cleanup. All
fixtures are project-authored; no Bethesda/master or unlicensed mod files.

### Framing and header vectors

- Minimal TES4; zero-payload records; multiple siblings; multiple root GRUPs;
  nested/empty GRUPs and simultaneous ancestor closure; exact EOF.
- Missing TES4, empty input, first non-TES4 record/GRUP, and second TES4 at root
  and inside a group. TES4-looking bytes inside arbitrary payloads do not count.
- Every 0..23-byte truncated object header position, truncated group/child header,
  incomplete 0..5-byte subrecord header, root/group/record residual trailers.
- GRUP sizes 0, 23, 24, exact parent fit, and parent+1; record sizes zero, exact
  fit, and parent+1; overlapping declared child/group intervals and forged
  signatures that must not trigger resynchronization; near-U32 declared lengths.
- Raw revision/form-version/unknown header words, group labels/types/stamps,
  all flag bits, deleted state, and unknown record/subrecord signatures.
- TES4 flag combinations under fixture labels `.esp`, `.esm`, `.esl` all yield
  identical metadata for identical bytes. Extension labels never enter the API.
- Unknown record with a valid body is scanned; the same record with a malformed
  body fails. Unknown payload bytes are not decoded as strings or nested records.

### XXXX vectors

- Ordinary size 65535; extended 65536; extended zero/small/65535/65536; nonzero
  ignored following u16; adjacent/repeated real fields and stable real ordinals.
- Own size 0/3/5/65535; four-byte length truncated at each byte; escape at record
  end; following real header truncated at each byte; repeated XXXX; length equal
  to remaining payload and remaining+1; U32-max length and no wrapped span.
- Escape/header/payload split at every header/extended-length byte; 65535/65536
  payloads cross the 64 KiB window boundary without requiring a large buffer.
- The escape plus real frame forms one full original span; the next field begins
  at its exact end; the ignored u16 and all escape bytes survive unchanged copy.

### Capabilities, copy, ownership, and budgets

- Arbitrary compressed bytes (including zero/short payload) remain opaque, copy
  identically, produce no subrecord events, and refuse structural-body access.
  Unknown compressed flag combinations do not accidentally enter the subparser.
- Whole-file equality for nested groups, all unusual bytes, real HEDR payloads
  with deliberately unrecomputed count fields, ordered MAST/DATA pairs, OFST/CLSZ,
  unknown data, deleted records, and noncanonical XXXX forms.
- Input chunk sizes 1/2/3/5/6/7/23/24/25/65535/65536 and varying output sizes,
  partial last windows, one-byte final chunks, zero/misplaced windows, interruption
  in every partial read, early adapter EOF, foreign source and reused buffer with
  a new source token. Same input gives the same event sequence and copy bytes.
- Exact cap and cap+1 for source size, payload, records, objects, subrecords,
  depth 0/1/64/65, and caller-lowered limits. Use small limits for exhaustive
  rejection cases and large generated streams for actual high-count bounds.
  Cases at two million records/eight million subrecords must not accumulate
  events or exhaust native call stack. Exercise near-U32 arithmetic helpers
  separately because an above-cap source must fail earlier.
- Exact work and one-less work for header continuation, XXXX, copy read/write,
  and final bytes; live allocation refusal and success; drop while pending,
  errored, complete, copying, and waiting for output; repeated terminal calls;
  failed/incomplete scanner cannot create copier; final budget balance everywhere.
- Compile-negative reuse of Scanner and CopyState plus positive consumption
  controls. Lint controls reject raw state constructors, stack Array access,
  private cursor binding, new budget starts, and unchecked helper calls.

### Independent oracle and metamorphic suite

Python `struct` builds fixtures and independently parses expected valid framing;
do not share production parser tables/control flow with the oracle. A deterministic
seeded corpus combines nested groups, unknown signatures, raw flags, normal/XXXX
subrecords, and compressed opaque bodies. The native Bend test driver emits
bounded event records for small cases and aggregate/digest results for large
cases. Compare event order/metadata/spans and emitted copy bytes. For small
fixtures exhaustively vary split points; for large fixtures use seeded partitions.

Malformed vectors have authored exact expected errors, supplemented by mutations
of lengths, truncation, TES4 placement, and escape grammar. Only mutations known
to violate the grammar must fail: changing arbitrary opaque payload bytes need
not cause rejection. Valid metamorphic changes to unknown payloads must preserve
the new bytes without changing unrelated spans. A full scan's nonoverlapping
wire segments partition the source (group/record headers plus opaque or framed
payload intervals); nested complete spans intentionally overlap by containment
and are not themselves a flat partition. Verify monotone siblings and exact ends.

## 10. Build, CI, evidence, and review gates

Keep the parser gate independent from the ongoing Issue #3/#5 work and frozen
core acceptance inventory. All parser drivers/helpers/fixtures belong in
`tests/plugin/`; tooling in `tools/plugin/`; artifacts in `build/plugin/` and
`runs/plugin/`; documentation/profile in `docs/plugin/`; CI in a new
`.github/workflows/plugin.yml`. The only shared source changes are the additive
`core/cursor.bend` metadata operation, an additive paragraph in `docs/core/api.md`,
and its minimal `tools/core/lint.py` allowlist adjustment. If needed, the latter
also separately permits raw arrays in exactly `plugin/state.bend`, without
granting that module core-private API access. Do not change core manifests,
case inventories, charge constants/profile, or `.github/workflows/core.yml`.

Reuse the locked runtime images, compiler provenance checks, and existing bounded
native supervisor design. Reuse path-independent helper functions where suitable;
when a helper is hard-coded to `build/core`, adapt the small wrapper within
`tools/plugin/` with explicit plugin paths rather than modifying shared tools or
reading a core build manifest as parser evidence. The new tools must enforce:

- `integrity.py`: an exact mandatory manifest covering `plugin/`, `tests/plugin/`,
  `tools/plugin/`, `docs/plugin/`, the new workflow, all imported core/hash and
  reused harness sources, and the existing lock/runtime dependencies.
- `lint.py`: plugin public function/type/pattern and raw-state restrictions,
  checked owner disposal, and positive/negative controls, in addition to running
  the repository's core boundary lint. No blanket parser/core-private trust.
- `case_spec.py`, `build.py`, `checks.py`, `run.py`: exact parser entrypoint,
  compile-negative owner/control, functional-case and independent expectation
  inventories. Check-only, emitted C and native builds use the locked compiler.
- `oracle.py`, `summarize.py`, `test_evidence.py`: exact deterministic seed/case
  inventories and source/binary/fixture identity, with rejection tests for
  omitted, duplicate, stale, mixed-build, or partial evidence.
- `layout.py`, `measure.py`, `docs/plugin/profile.json`: inspect the emitted
  Scanner/stack/copier shape and measure parser-specific live charges and cleanup
  without changing the core's independently accepted shape charges.
- `plugin.yml`: run this complete gate, retain its vectors/resource evidence,
  and use the same pinned CI actions/runtime ceilings. The existing core and
  runtime workflows remain unchanged and run independently on the final commit.

Measure parser-only, copier, and scanner-plus-copier/input/output overlap in three
runs under the same dedicated 1 GiB cgroup, swap=0, one worker, GPU off. Include
depth 0/1/64, 1/16/64 MiB streams, the 256 MiB input-size boundary using bounded
synthetic generation, many tiny records/subrecords, repeated create/drop/error
cycles, and live/work-limit refusals. Account for fixture generator/sink memory
separately and do not hold a huge Python/Bend event list in the measured native
process. Record actual elapsed time, peak RSS/cgroup usage, and source/binary
identity. Apply the existing method for fixed baseline allowances and bounded
streaming growth to the new parser profile. If it fails, fix/calibrate only the
parser representation/charges and independently review the change; do not modify
core charges, omit the failing case, or describe an OOM as a clean budget refusal.

Parser acceptance commands will be:

```sh
python3 tools/core/lint.py
python3 tools/plugin/lint.py
python3 tools/plugin/test_evidence.py
python3 tools/plugin/bootstrap.py
python3 tools/plugin/layout.py
python3 tools/plugin/run.py
python3 tools/plugin/measure.py
python3 tools/plugin/summarize.py
```

The metadata accessor's success/error/window-identity tests and ownership
controls live in the new suite. Also run the existing full core acceptance
commands unchanged (including all core codecs/hash/ownership/resource cases) on
the same final commit to catch regressions from the additive accessor/lint change.

Focused development builds are useful but never full acceptance. No compiler,
Base, generated-C, or runtime patch is part of this task. If local Docker/cgroup
support is absent, record the exact unrun stage and require fresh remote CI
evidence for the exact final commit; absence is not a passing test.
At plan preparation time the implementation owner reports locked local Bend
check/native builds are usable, including a passed core baseline, but Docker is
unavailable. That permits iteration; the Docker/cgroup acceptance stages remain
pending until actually run in CI or another approved supported environment.

## 11. Implementation sequence and completion criteria

1. Obtain independent Astra review of this plan. Correct actionable findings and
   repeat review until a review reports none in the stated scope. Preserve review
   input revision/hash, findings, disposition, and regression requirements.
2. Implement window metadata, fixed storage/limits/errors, and affine API spike.
   Compile/check-only, inspect emitted representation, and test cleanup before
   building the state machines. If a planned representation does not compile on
   pinned Bend, revise/review the plan rather than patching the compiler.
3. Implement record/GRUP scanning, first/unique TES4, immutable spans, and limits.
   Add malformed-boundary and split-window tests alongside the code.
4. Add uncompressed subrecord/XXXX scanning and explicit opaque compressed body
   handling; verify count/occurrence distinctions and metadata-only flags.
5. Add completed-scan-gated no-op copy and exact-byte/ownership/work tests. Do not
   add a rewriting branch, filesystem output command, or host fallback.
6. Finish differential/metamorphic corpus, resource/evidence integration, and
   document `docs/plugin/api.md`, limits, validation levels, measured profile,
   reproduction commands, and explicit compatibility/host/compression gaps.
7. Run the full acceptance suite, obtain an independent Astra implementation
   review, fix all actionable findings, add regressions, and rerun affected plus
   final aggregate checks. Repeat review/fix until no findings remain.
8. Create a draft PR with the exact scope, review records, evidence, and remaining
   product gaps. Verify remote head and all checks for that head. Mark ready only
   after CI succeeds, or after explicitly confirming no CI exists; this repository
   currently does have CI. Do not merge or claim real-game validation.

Issue #4 is complete only when framing/limits/diagnostics, explicit compressed
refusal, and **production-Bend** byte-identical copy all have passing tests and
the final independent review/evidence gate is satisfied. Neither a copied-byte
demo alone nor a parser that only recognizes known records is sufficient.

## 12. Plan review disposition

Revision 3 resolves independent Astra review 1 finding R1 (P2): the metadata
success payload `Range & U32 & U32` is a `Type` tuple, not `Data`, under pinned
Bend 2.0.40. Its `Result` success quantity must therefore be `&1`, not `&2`.
The exact signature in section 3 now uses `Result<&2, &1, ...>` while preserving
the ownership-return and read-only metadata contract. The implementation owner
and independent reviewer both report that the corrected signature passed the
pinned compiler's check-only spike; the implementation owner's temporary source
is `.cache/signature-plan-check.bend`. No production code is changed by this
revision. Keep a permanent accessor type-check/ownership regression in the
plugin suite when implemented. Final independent plan review remains pending.
