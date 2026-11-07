# Bounded FO4 framing and unchanged copy

This pure Bend library implements Issue #4 against the merged Issue #2 core. It
performs structural framing and an optional byte-identical copy, not translation,
editing, compression validation, host IO, transactional publication, or game
compatibility certification. No operation takes a filename or extension. A
successful scan supplies no edit capability or semantic target classification.
Unknown signatures, raw flags, and payload bytes are preserved.

## Public boundary and owners

The supported API is enforced by the core and plugin boundary lints. Bend itself
does not enforce module privacy. Raw Scanner/CopyState constructors, machine
transitions, stack access, and helper functions are private. Scanner and CopyState
are affine Type owners. Metadata and diagnostics are fixed-size Data observations;
retaining an unbounded collection of events requires separate budgeted storage.

Use one existing core Budget throughout acquisition, scanning, copy, and disposal.
The synthetic adapters in tests alone create sources and bind/unbind windows.
An adapter guarantees immutable authoritative bytes from the same snapshot. Numeric
run/source identity is not a digest, filesystem provenance, or protection from a
dishonest adapter.

`types.Limits{source,payload,records,objects,subrecords,depth}` defaults to
256 MiB, 32 MiB, 2,000,000, 2,000,000, 8,000,000, and 64 respectively. Callers may
lower any cap, including to zero. Records cannot exceed the object cap; no cap
may exceed its default. The subrecord cap bounds both real fields and at most one
XXXX per real field, so twice the maximum is safely representable. These are
independent format ceilings, not a promise that all maxima fit one work budget.
Limits/source size are checked before allocating scanner storage.

## Scan lifecycle

Imports below use F=plugin/frame, S=plugin/state, T=plugin/types,
D=plugin/error, C=core/cursor, B=core/budget, Bytes=core/bytes.

- `F.start(budget,window,limits)` returns Budget, ByteWindow, and F.StartResult.
  `Started{scanner}` owns the fixed stack and scanner state.
  `StartFailed{diagnostic,reservation}` returns any unsettled reservation on an
  invariant failure; normal format/resource refusals have None. Cancel a returned
  reservation, preserving its owner if cancellation itself fails.
- `F.next(budget,window,scanner)` returns all three owners and S.Status:
  `Yield{event}`, `NeedWindow{offset}`, `Complete{summary}`, or `Failed{diagnostic}`.
  Supply a window covering the exact requested absolute offset. Empty/misplaced
  windows return NeedWindow once per call. Never infer source EOF from a window.
- `F.input_ended(scanner)` turns an outstanding window request into sticky reason
  25. Invoking it while active without a request gives reason 26. It preserves an
  already completed or failed terminal state and cannot declare successful EOF.
- `S.drop(budget,scanner)` releases scanner storage. Its result follows core
  release: failure returns Error and Allocation for cleanup with the correct
  budget. It is legal while active, awaiting input, failed, or complete.

Every next call checks authoritative source identity and total size, including
metadata-only group closures, record ends, and completion. A foreign refill
before or after successful completion becomes sticky reason 23. An existing
failure remains the first failure. Successful completion and failure otherwise
repeat without new events, work, or counter changes.

Each next call uses at most 64 fixed transitions. Header words are assembled from
checked width-one core reads. A partial word retains its bytes and next absolute
position; no consumed prefix is reread, even with one-byte windows. One-byte read
states cannot consume a partial byte. Payload skipping inspects no payload bytes.
At most one GRUP is closed per GroupEnd event.

## Metadata and ordering

Every Range is obtained through checked core subrange operations on the captured
full source range. Offsets are absolute half-open byte intervals bound to run and
source ID. Root parent_start is zero. Inside GRUP, parent_start is its body start
(group header start plus 24); parent_end is the group's complete end.

`T.ScanEvent` has five variants:

- GroupStart carries Group{label,group_type,stamp1,stamp2,header,full,
  parent_start,parent_end,depth}. Label/type/trailing words remain uninterpreted.
  Group depth is the number of open groups after its push; an outer group is 1.
- GroupEnd carries the original group header start, complete end, and that same
  depth. Empty groups and simultaneous ancestor endings close individually.
- RecordStart carries Record{signature,flags,form_id,revision,form_version,unknown,
  header,payload,full,parent_start,parent_end,depth,ordinal,body}. Record ordinal
  is zero-based globally, including TES4. Header is exactly 24 bytes; final-word
  low/high halves are form_version/unknown. RecordStart does not validate its body.
- Field carries Subrecord{signature,original_size,length,header,payload,full,escape,
  record_start,ordinal}. Its header is the actual six-byte real header; escape is
  the optional original ten-byte XXXX. Full includes XXXX when present. Ordinal
  counts real subrecords from zero within this record, not escapes or globals.
- RecordEnd carries record_start,end,count,body. It follows all real fields, or
  the untouched opaque body, and confirms only that record's stated scan level.

All signatures are little-endian raw U32 words. GRUP is special only at object
level; XXXX only at subrecord level. The first object must be TES4 at zero and
no later TES4 record is allowed at any depth. No HEDR or semantic field is required.
Residual bytes are errors rather than padding. All size arithmetic establishes
position<=end and length<=end-position before addition. Siblings are consecutive;
the scanner never searches ahead or resynchronizes around malformed frames.

XXXX must have its own u16 size four, four available extended-length bytes, and
an immediately following complete non-XXXX real header in the same record. The
real header's original u16 is preserved but ignored, including nonzero values.
Extended zero/small lengths are permitted. XXXX contributes no separate field
or ordinal. Real-subrecord limits are checked before another attempted field.

`T.Summary{source,records,objects,subrecords,opaque,all_bodies}` is emitted only at
complete root EOF with no unfinished frame. Objects includes records and GRUPs;
subrecords counts real fields globally. `all_bodies` is true exactly when opaque
is zero. A summary alone cannot initialize the copier.

## Flags and capability limits

`T.compressed(flags)` tests 0x00040000, and `T.deleted(flags)` tests 0x00000020.
Deleted records are still structurally scanned; later translation targeting must
exclude them. For TES4 only, `tes4_master`, `tes4_localized`, and `tes4_light` expose
0x1, 0x80, and 0x200. Callers must not assign those TES4 meanings to arbitrary
records. Raw flags remain authoritative. These meanings follow the pinned
[xEdit FO4 definitions](https://github.com/TES5Edit/TES5Edit/blob/9058a79437367c2cb1b757a9021ab443d743012d/Core/wbDefinitionsFO4.pas)
and the [FO4 framing reference](https://tes5edit.github.io/fopdoc/Fallout4/Records.html).
Exposing form_version does not establish a supported game/form-version profile.

BodyKind is Structural or OpaqueCompressed. `D.body(record)` returns the payload
range only for Structural and otherwise fails explicitly with
UnsupportedCompressedPayload (24) at the record location. Compressed bytes are
not read as subrecords, an expanded-size prefix, or zlib. Even an empty, short, or
invalid compressed stream remains opaque framing-only input. Copy can preserve
it; this library cannot translate or certify it.

Unknown uncompressed records receive the same structural subrecord checks as
known records. No unknown field becomes a string/translation target. OFST, CLSZ,
optimized-file flags, master order, HEDR counts, and all raw values remain
unchanged. Their safety under future nonidentical rewriting is out of scope.

## Unchanged-copy lifecycle

Use Copy=plugin/copy. `Copy.start(scanner,output)` consumes a completed scanner
and an empty OwnedBytes buffer with capacity 1..65536. Success returns CopyState;
failure returns Diagnostic, original Scanner, and output. Active/failed scanners
are refused. The scanner allocation and identity remain owned until copy disposal.

`Copy.pump(budget,window,copy)` returns those owners plus an affine CopyResult:

- CopyNeedWindow{offset} retains partial output and requests that exact byte.
- ChunkReady{bytes,final} returns the completed chunk and retains the continuation.
  Consume a nonfinal chunk, then use `Copy.resume(copy,Bytes.clear(bytes))` or an
  empty replacement. Resume returns both owners on refusal. Pumping a waiting
  copier without handback becomes a sticky InvalidState error.
- CopyFailed{diagnostic} retains partial output for disposal. A read byte whose
  append failed is retained as pending metadata and is not reread or emitted as
  success. The failure cannot be resumed into success.
- CopyDone repeats after a final ChunkReady without emitting duplicate bytes.

A final ChunkReady means every source byte was produced in order, not written to
a host artifact. It does not need a handback. Drop the returned chunk and copy.
`Copy.drop(budget,copy)` returns Budget, optional retained output, and the scanner
release result. The caller must dispose that optional output and any allocation
returned by a failed release. `Copy.input_ended` mirrors the scanner rule above.
Every pump checks window source identity/total size, even at completed/failed or
waiting states. A failed copy remains the first failure.

The copier reads each original byte and appends it unchanged. It does not rebuild
headers, normalize XXXX, reorder records, or inspect payload meaning. Each pump
has a fixed bound of 131074 internal transitions, enough for a full 65536-byte
output chunk. Only fixed parser state and one caller-owned output buffer are kept.

## Charges and diagnostics

Scanner reserves and settles 65536 live bytes plus core owner metadata (4096).
This covers two depth-64 U32 stacks plus combined scanner/event/copy metadata;
parser-specific generated-layout and resource evidence must validate this charge.
No array is sized by source length, declared payload, record count, or field count.
Metadata/range bookkeeping consumes no byte work. Scanning visits 24 bytes per
object, six per real field, and ten additional bytes per XXXX. Opaque bodies add
no visits. Copy costs one input read and one output append per byte, in addition
to separately metered buffer initialization. Acquisition, adapter transport,
verification, and SHA traversal have their own real costs. This internal copy
never charges final-artifact output; a future host sink charges successful writes.

Diagnostic contains Cause (Format{reason} or Core{error}), run, origin, offset,
parent_start, parent_end, optional record start, depth, and declared. No input
String or ancestry list is retained. First failure is deterministic and sticky.
Format reason IDs:

| ID | Meaning |
|---:|---|
| 1 | MissingTES4 at empty root EOF |
| 2 | FirstObjectNotTES4 |
| 3 | DuplicateTES4 |
| 4 | TruncatedInitialHeader |
| 5 | TruncatedObjectHeader inside a group |
| 6 | UnexpectedResidualTrailer at root |
| 7 | GroupSizeBelow24 |
| 8 | ChildOutsideParent |
| 9 | RecordPayloadLimit |
| 10 | TruncatedSubrecordHeader |
| 11 | SubrecordPayloadOutsideRecord |
| 12 | BadXXXXSize |
| 13 | TruncatedXXXXLength |
| 14 | DanglingXXXX at record end |
| 15 | TruncatedFollowingXXXXHeader |
| 16 | RepeatedXXXX |
| 17 | ExtendedPayloadOutsideRecord |
| 18 | RecordCountLimit |
| 19 | ObjectCountLimit |
| 20 | RealSubrecordCountLimit |
| 21 | GroupDepthLimit |
| 22 | SourceSizeLimit |
| 23 | ForeignSource |
| 24 | UnsupportedCompressedPayload |
| 25 | PrematureAdapterInputEnd |
| 26 | InvalidState |
| 27 | InvalidLimits |

Initialization checks metadata, then limit validity, then source size, then live
reservation. Object processing checks header availability, TES4 placement, size
containment, payload cap (records), then depth/count limits. Record counts precede
object counts; group depth precedes object count. Subrecord EOF precedes count,
which precedes header availability. XXXX own-size precedes length availability;
dangling escape precedes following-header availability; repeated XXXX precedes
its own-size interpretation. Header/size faults point at that header start;
truncated-following-header points at its expected start. Count/depth `declared`
is the current used count/depth before the prohibited increment. Length errors
report the offending wire length or required header width. Foreign/premature/core
read failures point at the next unread position. Core errors preserve their exact
variant and numeric fields. Copy append errors point at the already-read byte.

Known source-range truncation fails immediately, while a missing window requests
more input. No library terminates the process. After either success or failure,
clean up every owner and require `budget.finish`; consumed work is not refunded.
