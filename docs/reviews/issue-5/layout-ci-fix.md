# Issue #5 generated-C layout gate correction

Date: 2026-11-07. Follow-up to PR #24, Actions run `42338187534`, commit `16d5720d0c87c92dff96fbe35600b03fd507fb7a`.

## Failure and cause

The locked build completed all 13 native entrypoints and all eight affine ownership controls. Bootstrap then stopped at the `xml_text_reverse` layout check, before functional or resource acceptance ran. The rejected anchor was the literal store:

```c
e.mem[_nd_0 + 20] = _acc_0;
```

The current generated `driver.c` instead contains:

```c
e.mem[_nd_0 + 20] = rfc_seal(e, _acc_0);
```

This is the pinned compiler's reference-count-aware representation, not a changed XML algorithm. Its function also has the generated `q0`/`q1` parameters, fixed `Term _fb_0[21]` scratch, `ctr_take(e, _pages_0, 21, _fb_0)`, and the emitted conditional node-reuse/allocation expression. The standalone `text.c` uses the direct representation. The old checker had only been exercised against the latter form and incorrectly treated that specific store spelling as the complete contract.

Both inspected forms retain the same 21-slot Page representation. Slots 0–19 preserve the payload/claim fields. Slot 20 becomes the accumulator. The old slot 20 advances the input tail; a Page constructed at the reused/result node becomes the accumulator; `WL_AGAIN(spin_______xml_text_reverse)` performs the tail loop. The reference-count-aware `ctr_take` copies 21 fixed metadata terms to scratch, not the scalar-page payload. The generated runtime's `rfc_seal` preserves existing reference-counted terms and wraps an unsealed constructor as required.

## Narrow correction

`tools/xml/layout.py` now accepts exactly those two complete, ordered function shapes, ignoring indentation and empty lines only. It checks the signatures, fixed loads and field types, exact payload/claim preservation, node-reuse expression, accumulator store, input-tail advancement, Page reconstruction, and tail-loop control together. It does not accept an arbitrary call to `rfc_seal`, an arbitrary tail store, a mixed representation, or extra operations.

The other seven shape checks, fixed-size scratch check, generated-C and binary freshness checks, source/compiler/container identities, functional inventory, cgroup measurements, and producer gate are unchanged. The selected shape variant is included in the reviewable layout record. No Bend source, test Bend, compiler, runtime, resource limit, CI requirement, or acceptance requirement was changed by this correction.

## Checks

- 149 evidence rejection regressions pass: the existing 116 plus 33 new layout mutations.
- Positive controls accept both reviewed emitted forms.
- Negative controls reject wrong accumulator slot/value, changed preserved field/type, missing or wrong input-tail hop, wrong Page constructor, changed loop-variable assignment, missing tail loop, recursive-call replacement, changed empty-list branch, extra drop, changed scratch extent, changed `ctr_take` width, wrong sealed value, changed allocation/reuse expression, and mixed direct/reference-counted stores.
- Python bytecode compilation and `git diff --check` pass.
- All eight shape checks pass on current local `driver.c`. The standalone `text.c` reverse function passes the direct-form check. Independent review confirmed both C files match the failed CI build's recorded hashes.
- The older local `stream.c` also passes, but its hash differs from CI's final stream. This is supplemental local-only coverage, not certification of the final CI stream.

No compiler was run for this correction. A new locked CI run must rebuild and revalidate the final source snapshot. Resource acceptance remains unrun by this correction, and pinned-producer acceptance remains blocked.

## Inspected generated-C identities

- `build/xml/driver.c`: `d4e385bc584a7c12f06d7bd0154babb863ede43ddc912fc3ac081d2b1176ab4b`
- `build/xml/text.c`: `d0d95a92603f800f901a5c1f7ca217ab00a184916f7f7a67ad21994cdf22f695`
- Reverse function bodies, including original indentation:
  - Direct: `3a19a724a203b9e4959cfe1dffd08a4a0d3e2fb8861c96435bd752976dfeca24`
  - Reference-count-aware: `4aa69e1bde395f5788e2b60688d214c1ef3d75a6a7b7f1b01392691f57942a29`
