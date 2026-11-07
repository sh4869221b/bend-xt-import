# Independent plan review 02

Reviewed: `bend-issues-2-3-plan.md`, revision 2, in full, against review 01 and the previously inspected Issue #2/#3 requirements, DESIGN and pinned-runtime constraints.

Decision: **No mandatory findings. The implementation plan may proceed.**

## Review 01 R1 — resolved

Revision 2 explicitly freezes deletion eligibility before retention transfer, transfers the complete descendant ledger to terminal non-deleting `Retained` ownership before subsequent fallible operations, and reserves transition resources beforehand. It forbids cleanup through old dirfds and prevents fsync/close/reporting failures from restoring scratch ownership.

Definite transfer failure and uncertain outcomes preserve the affected verified captures as protected residuals. Reconciliation requires authoritative identity evidence, existing destinations are never adopted/deleted, and incomplete captures cannot be reported as valid retained snapshots. Tests now cover normal/error cleanup after transfer, old-dirfd access, before/after-transfer faults, uncertain outcomes, and one-time handle/reservation settlement. These changes address the identified data-loss route.

## Prerequisite coordination — resolved

The plan now stacks #2 on the verified PR #21 branch/head while unmerged, and #3 on #2, with review and exact-head CI after retarget/rebase. No automatic merge is authorized.

## Review boundary

No additional mandatory planning findings were identified. This approves the plan, not implementation correctness or runtime capability. Native ABI compilation, measured allocation charges, supported filesystem/ACL behavior, dedicated cgroup enforcement, real two-UID evidence, fault coverage and final code review remain required implementation gates. Transactional apply remains disabled pending later integration.

Only this requested review report was written; source and plan files were not edited. No new runtime tests were performed for this plan review.
