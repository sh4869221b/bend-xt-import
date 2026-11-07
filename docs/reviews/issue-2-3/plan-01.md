# Independent plan review 01

Reviewed: `bend-issues-2-3-plan.md`, revision 1. Review only; no implementation/runtime success is asserted and no repository/plan file was changed.

Decision: **Changes required: one mandatory finding.**

## R1 — P1: Define retention ownership transfer before generic cleanup

Location: plan lines 112, 118–120 (Retention, lifecycle, cleanup).

The plan permits moving snapshots to a separately created retention directory, but its ledger/state machine excludes only `Published` objects from deletion. It never defines when retained snapshots leave the scratch cleanup ownership set. Keeping a directory descriptor across a rename is intentional here: consequently, an old snapshot-directory descriptor still accesses the retained files. Ordinary error/normal cleanup can enumerate the same names and successfully match every recorded inode, then unlink the intentionally retained snapshots. No identity or no-follow check would detect this as a substitution.

Required revision:

- Define the retain operation's ownership contract and a terminal `Retained` state (or equally explicit separate retention ledger). Successful retention removes the moved directory and **all descendants** from automatic scratch deletion before any subsequent fallible operation. Closing descriptors must not imply deleting retained entries.
- Define `RetentionAttempted`/uncertain outcomes consistently with publication: no deletion or blind retry of potentially transferred entries until authoritative identity reconciliation. A post-rename fsync/close/reporting failure must not reclassify transferred snapshots as scratch eligible for cleanup.
- Specify what the explicit retain policy means on capture failure versus later run failure. Do not return an incomplete/unverified capture as a valid retained snapshot; preserve/report uncertain residuals without claiming successful retention.
- Add deterministic tests for retain-success followed by normal cleanup and by unrelated failure cleanup, retained child accessed through the old dirfd, rename failure before transfer, uncertain completion, and failure immediately after transfer. Assert retained bytes/identities survive, existing retention destinations remain untouched, scratch-only entries are reclaimed when safe, and ownership/reservations/handles settle without double cleanup.

This implements Issue #3's explicit retention-vs-discard acceptance condition and DESIGN §4's separate retained-snapshot contract. It does not require implementing the deferred apply CLI or full bundle publication orchestration.

## Nonblocking coordination correction

Line 8 still says PR #2 targets corrected main. Parent confirmed correction PR #21 is unmerged, so revision 2 should state #2 targets `docs/correct-wsl-scope` at its verified head, and #3 stacks on #2. Retarget/revalidate only after prerequisites merge. Parent already scheduled this change; it is not a second substantive finding.

## Reviewed coverage / remaining implementation gates

The rest of the plan adequately identifies checked ranges/U32 arithmetic, strict streaming codecs, raw-byte SHA, independent six-counter reservations, affine ownership, representation-specific calibration, stock read/close gaps, minimal native ABI feasibility, trusted ancestry and ACL fail-closed checks, protected source namespace, snapshot hash/readback, no-replace semantics, guarded cleanup, and real two-UID/fault-injection evidence. No additional mandatory planning finding was identified in this pass.

Actual charge constants, ownership-return signatures, native marshalling/ABI, filesystem capability results, and complete error paths remain subject to code review and required runtime tests. This review does not certify those not-yet-implemented details.

Sources: GitHub issues https://github.com/sh4869221b/bend-xt-import/issues/2 and https://github.com/sh4869221b/bend-xt-import/issues/3; local DESIGN.md §§4/9/10; docs/runtime/capabilities.md and resource-model.md; pinned Bend Base File/Array API.
