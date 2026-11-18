# Issue #5 interim implementation review 01

Date: 2026-11-07. Independent source review.

## Scope and verdict

Reviewed `xml/input.bend`, `xml/text.bend`, `xml/ownership.bend`, and `xml/reader.bend`, with the shared core APIs, XML types, schema interfaces, and existing input/text tests as context. Lexer/schema correctness is outside this review's primary scope.

Three actionable findings were reported and their fixes were subsequently inspected. No further actionable source defect was found in the reviewed ownership, cleanup, input normalization, or Reader lifecycle paths. This is **not overall implementation approval**: full Reader compilation, native integration, differential validation, failure-injection coverage, and locked-profile resource gates remain pending.

## Findings and verified fixes

### R1: Exhausted chunks remained pinned after a scalar or entry result

Original locations: `xml/input.bend:196-198,234-244` before the fix.

The active allocation/range was cleared only by a later call returning `NeedInput`. A scalar could consume the final byte and return `ScalarReady` with `index == length`, while its old chunk remained pinned. At Reader level, a `String` closing `>` exactly at a chunk boundary could therefore produce `EntryReady` with the fully consumed index, yet replacing that owner with the contiguous next chunk failed with input phase 1/reason 3.

Verified fix: `xml/input.bend:236-255` permits a replacement range only when the old index equals the old length and the new start equals the raw consumed offset. `current_chunk` resets the index for that new range. Reusing the same exhausted owner still supports the existing drain-to-`ReadMore` flow.

The surrounding `chunk_valid` check at lines 263-273 still independently enforces run/source identity, positive length, exact range length, and root bounds. An unfinished chunk requires the identical allocation/range/length. An exhausted same-range replacement with a different allocation cannot pass the new arm: the old range has positive length, so its start cannot equal its consumed end. Pending scalars are detached values, not storage borrows. No alias-acceptance regression was found by source inspection.

`tests/xml/input_handoff.bend` was reviewed: it actually drops the byte owner on `ScalarReady` at `index == length`, rather than waiting for `NeedInput`, across chunk sizes 1 through 13. The fixture covers BOM, split UTF-8, CRLF, CR lookahead, and terminal CR. Its native build/run was not performed by this reviewer.

### R2: Reader initialization accepted a zero depth limit

Original locations: `xml/reader.bend:97-123` before the fix.

`Reader.begin` checked only `depth <= 64`, while `Schema.valid_limits` also required a positive depth. Calling `begin` with depth zero could return `ReaderReady` and allocate its state, contrary to the approved requirement to reject that invalid configuration before parsing. Rejection was deferred until schema processing or finish.

Verified fix: `xml/reader.bend:102-105` now checks `depth > 0` as well as `depth <= 64`, before `begin_valid` acquires the Reader claim or input scratch owner.

### R3: Later API misuse could replace the returned first diagnostic

Original locations: `xml/reader.bend:71-75` before the fix, together with the resume stage/size guards.

The old `failure` function preserved the stored first diagnostic but returned the newly supplied diagnostic. For example, calling `resume` after `FinishFailed` could return phase 4/reason 20 from the stage guard instead of the original failure. A stage-zero failed Reader resumed with a chunk larger than 65536 bytes could similarly return reason 11. The Reader stayed failed, but the observable diagnostic was not sticky.

Verified fix: `xml/reader.bend:71-80` selects the existing diagnostic through `first_error` before both storing and returning it. Fresh diagnostics receive schema context only when no prior error exists.

## Reviewed source identities

These SHA-256 values were checked after the fixes and before saving this review:

| File | SHA-256 |
| --- | --- |
| `xml/input.bend` | `4796d5ed4a8a6d8c75f60b01e0a8ee2a413b5f8f3738e94fc513ad004d2ad83f` |
| `xml/reader.bend` | `13c38c41241d19268a0130204f45f89286853242015e2af620fd50bd326bf858` |
| `xml/text.bend` | `5e7863a464bea9c9538a6646d1462f5961f910acb6637c1825c8e819a08b96c2` |
| `xml/ownership.bend` | `45ec0b1b9d643e015a4518e5a8281a13e63037febf38b4d721a458412012c052` |

## Checks actually performed

Source inspection covered literal EOL normalization and original byte spans, finite pending-scalar/EOF handling, chunk identity guards, monotonic arena iteration, allocation/reservation retention after cleanup failures, ownership transfer to entries/documents, and preservation of failed Reader state.

The reviewer ran these already-existing native artifacts, all with exit status zero:

- `build/xml/input`: `input-splits-balanced`.
- `build/xml/input_errors`: `input-errors-balanced`.
- `build/xml/text`: `text-balanced`.
- `build/xml/ownership`: `ownership-balanced`.

No compiler was run for this review. These executions are smoke evidence for the existing binaries, not proof that the source hashes above compile or pass: the input artifacts predate the exhausted-chunk fix, and the `input` binary also predates an earlier input source modification. The text and ownership tests exercise ordinary successful cleanup, not injected cleanup failures. The existing text fixture uses 4097 identical scalars and is not sufficient to establish ordering across multiple full pages.

## Remaining validation

- Rebuild and run the latest input tests, including `input_handoff` and same-owner drain behavior.
- Add negative chunk tests for mid-chunk allocation replacement, an exhausted same-range replacement with a different allocation, overlap/replay, gaps, source/run mismatch, and invalid range lengths. Assert sticky rejection and balanced cleanup. Positive handoff coverage alone does not demonstrate these negative guards.
- Add Reader-level tests for an entry boundary exactly at chunk end, depth-zero rejection before allocation, repeated failed finish/resume, and first-error stability even when subsequent arguments violate stage or chunk-size constraints.
- Exercise distinct scalar patterns across at least three arena pages, page-boundary reads, early iterator disposal, exact text limits, and injected allocation/work/release failures with residual-owner cleanup.
- Complete full Reader type checking and native execution, the complete EOF/partition/typed-output suite, independent differential tests, affine negative compilation controls, and resource accounting/calibration on the locked profile. Compiler termination remains an unresolved validation blocker, not a successful check.
- Keep real-file compatibility evidence separate from the still-open identified pinned-producer acceptance condition; this review does not clear either native fixture validation or producer provenance.

The fixes are source-reviewed. Final implementation approval requires the outstanding gates and a review of the integrated result.
