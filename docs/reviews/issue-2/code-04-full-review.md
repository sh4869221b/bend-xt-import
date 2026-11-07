# Issue #2 independent full implementation review 01

Review date: 2026-11-07. Target: `/workspace/bend-xt-import-issue-2`, branch `issue-2-core`, HEAD/base `bbcac8fac627ce258099f8241c577bf4e5054b11`, new Issue #2 files uncommitted.

## Verdict

**One actionable P2 test-coverage finding (R1). No P0/P1 implementation defect found in the reviewed source.** This is not acceptance approval: the complete fresh native/ownership/oracle/resource gates and generated-C layout inspection still require evidence. The absence of completed runs is not itself the R1 finding; R1 concerns cases absent from the checked-in test matrix, which a successful run of the present matrix would not cover.

No repository code/documentation was changed. No Docker/container invocation was made, and the parent's build container was not accessed. Issue #1 files, lock, stock evidence and upstream checkout were left untouched. Issue #3 is outside this review.

## R1 — P2: SHA budget-failure ownership and processed-prefix contracts have no regression cases

Location: `tests/core/sha_errors.bend:58` (its complete two-case main), with affected branches at `hash/sha256.bend:217`, `:304` and `:310`; inventory at `tools/core/case_spec.py:14` and `:38`.

The only SHA failure tests exercise an invalid input range and injected 64-bit length overflow. Both fail before processing bytes and finish with work=1. The successful SHA fixtures and Python oracle verify digest values, but `tests/core/sha.bend:41` immediately terminates on any `HashFailed`; they cannot verify returned owners or balances after a resource refusal. There is no test that exhausts SHA's byte-work after a successful prefix, nor a test of either `HashFailed{...,None{}}` or `HashFailed{...,Some{digest}}` cleanup. The resource group's name `error-lifecycles-sha_errors` therefore does not cover those allocation/partial-work lifecycles.

These are distinct promised contracts: `docs/core/api.md` says update retains exactly the processed prefix after partial work failure, and finalization returns the state and any digest owner on failure. Revision 2 plan line 78 requires exact work, no work after rejection, and live/held lifecycle verification on partial failure. The finalization implementation has a real two-stage boundary: `Bytes.new(32)` consumes initialization work and owns a digest, then a separate 32-byte charge may fail. A wrong return variant, lost digest/state owner, premature padding or refunded/extra work in these branches would currently escape all successful native/oracle cases.

Required addition before treating Issue #2 acceptance as complete:

- Exhaust update work before the first byte and after a nonempty prefix; assert ResourceLimit fields, exact counters, unchanged input, and the retained state's prefix (by funded subsequent finalization against an independent expected digest, or bounded test-only state assertions).
- Refuse finalize before digest allocation, including live-limit refusal and initialization-work refusal; assert original state ownership and unchanged counters.
- Permit digest initialization but refuse its final 32 writes; assert `Some{digest}`, the expected 32 initialization visits, unchanged unfinalized state, and release all returned owners until `Budget.finish` succeeds. Include the exact-success neighboring limit.
- Put the cases in the mandatory functional suite and the error-lifecycle resource shape, update completion expectations, then rebuild/re-run fresh evidence. Existing held-work-ticket/cancel techniques in the buffer tests can fund readback without introducing a second budget.

This is a concrete missing assurance test, not a claim that the current SHA branches are wrong. Static inspection found their ownership threading consistent.

## Reviewed source and checks

Read all `core/*.bend`, `hash/*.bend`, `tests/core/**/*.bend`, `tools/core/*.py`, `docs/core/*`, `.github/workflows/core.yml`, revision 2 implementation plan and the contract addendum. Reviewed checked arithmetic/capacity rounding, affine owners, ticket settlement/release, source identity/window bounds, scalar-width preflight, strict UTF-8/CP1252 mappings and carry, encoder pending behavior, SHA length/padding/compression, hex ownership, mandatory inventories, cgroup observer/barriers, fresh-build linkage, resource formulas and CI fail-closed sequencing.

The 70-file read snapshot is recorded in `/workspace/issue2-full-review-01-manifest.json`. Its SHA-256 is `ca2af47361e3fe064220cb6301313ee6c7099c8b6264bb324e33db512e029e60`. A second comparison after reading found **no changed file hashes**. This includes the source/tests/tools/profile reviewed, not generated binaries from the parent's concurrently running build.

Executed independently, both successful:

- `python3 -B tools/core/lint.py`: API boundary lint and policy controls passed.
- `python3 -B tools/core/test_evidence.py`: 21 evidence rejection regressions and four positive controls passed.

These Python checks are not native acceptance. I did not assume earlier development test results or previous review conclusions were acceptance evidence.

## Remaining acceptance evidence

The parent was running the fresh 17-entry-point build and 16 ownership controls during this review, with full functional/oracle/resource runs next. I have not certified their outcomes. Actual calibration output must be separately inspected when available: complete three-run resource inventory, 1/16/64 MiB streams, RSS/cgroup peaks and baseline allowances, byte/scalar overlap, bounded slope, exact live refusal and no ceiling events. Generated-C layout inspection must cover the new concrete wrappers and scalar value+width arrays; a C hash alone is not that inspection.

No further source correctness, ownership, arithmetic, codec, hash, or CI blocker was established from this snapshot. Full acceptance and exact reviewed-commit CI remain pending; #3 remains separately blocked by its ABI/compiler gate.
