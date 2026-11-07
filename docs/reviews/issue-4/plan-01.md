# Independent Issue #4 plan review 01

- Date: 2026-11-07.
- Reviewer: independent `gpt-6-astra` review, xhigh effort (selection confirmed by the coordinator).
- Input: `docs/implementation/issue-4-plan.md`, revision 2.
- Input SHA-256: `d0e8a6ffb7d0f2e8825382957ac952c5ea713d881a0d5f28f4886fdee3bb98c4`.
- Baseline: `1b0421c15f9724a614a7b7bfae9605ec6456eb05`.
- Decision: **Changes required: one actionable finding.**

## R1 — P2: Use a Type success parameter for the metadata tuple

Location: plan section 3, lines 101–106, exact `window_metadata` signature.

The planned success value `Range & U32 & U32` is a Bend `Type`, not `Data`.
Consequently, `Result<&2, &2, E.Error, Range & U32 & U32>` fails the pinned Bend
2.0.40 checker with `expected: Data`, `observed: Type` at the success tuple. The
reviewer independently reproduced that failure with a minimal declaration using
the existing core types. This is an executable signature error, not a request to
change the metadata accessor's ownership or visibility contract.

Required fix: change the success kind to `&1`:

```text
window_metadata(window: ByteWindow)
  -> ByteWindow & Result<&2, &1, E.Error, Range & U32 & U32>
```

An alternative is a fixed `Data` metadata variant and a corresponding `&2`
success kind. The tuple/`&1` correction alone passes the same check-only test and
matches the existing `core/cursor.take` result convention.

Regression requirement: type-check the exact public accessor signature, including
success-tuple consumption and failure ownership-return paths, in the affine API
spike before implementing parser state machines. No compiler patch is needed.

## Other reviewed areas

No additional actionable plan finding was identified within Issue #4's scope:

- Full-source identity and authoritative total size are captured from the window;
  later windows are checked even for metadata-only transitions and completion.
- Parent intervals use subtraction-before-addition bounds, exact closures, and
  consecutive siblings. TES4 is first and unique, including nested duplicates.
- XXXX has its own four-byte payload, an immediately following real header,
  ignored following u16 length, retained original spans, and one real occurrence.
- Streaming events and a fixed depth-64 stack avoid count-sized allocation and
  unbounded retained event trees. Counter limits, partial reads, sticky errors,
  cleanup, and generated-representation measurements are explicit gates.
- Copy consumes a successfully completed affine scanner and rereads the same
  source through bounded buffers; partial output is not successful completion.
- Compressed bodies are explicitly opaque and refused for structural-body access.
  Unknown signatures are structurally scanned without semantic permission.
- The dedicated plugin test/build/evidence workflow preserves the core inventory
  and host independence, while still requiring unchanged core regression gates.
- The proposed exact errors, split points, limit boundaries, negative ownership
  controls, independent oracle, and resource-evidence rejection tests cover the
  issue's acceptance requirements at the plan level.

## Sources and limits of this review

Reviewed the live [Issue #4](https://github.com/sh4869221b/bend-xt-import/issues/4),
`DESIGN.md` sections 4, 5, and 10, the merged core API/charge/profile documents,
`core/cursor.bend`, `core/budget.bend`, `core/bytes.bend`, `core/storage.bend`, and
the relevant core lint, representation, integrity, supervisor, measurement, and
CI contracts. The reviewer did not author or modify the implementation plan.

Only minimal ignored scratch declarations were type-checked for R1. No production
implementation was changed or certified. Complete functional/oracle tests,
measured resource calibration, implementation review, and fresh CI for the final
commit remain required. This review does not establish compression validity,
real-game compatibility, or host publication safety.
