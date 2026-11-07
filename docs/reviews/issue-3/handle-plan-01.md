# Independent host-handle addendum review 01

Reviewed: `bend-issues-2-3-host-handle-addendum.md`, in full, against the approved revision 2 plan and Issue #3's original filesystem threat model.

Decision: **No mandatory planning findings. The proposed alternative may proceed to its required ABI spike; adoption is not yet approved by runtime evidence.**

## Requirement boundary

The alternative does not add malicious same-process Bend source to the threat model and does not claim static unforgeability. Ordinary affine wrappers, a reviewed whole-program boundary and checked native lifecycle enforcement can satisfy the original requirements without an opaque `law`. No compiler/Base patch is implicitly authorized. Lint is accurately described as accidental-bypass defense, not a sandbox.

## Reviewed invariants

- Native validation covers slot bounds/allocation, generation, constructor shape, kind, rights and lifecycle before effects, including all operands of multi-handle calls. Original-input read-only rights retain OS open-flag enforcement.
- Stale/closed tokens and descriptor-number reuse have explicit negative tests. Generation wrap is forbidden. The concrete spike must select a transition policy and test aliases rather than rely on optional per-effect rotation.
- A secret nonce is not inherently required by this threat model: untrusted data cannot supply tokens, and hostile source is excluded. What matters is non-reuse of accepted token identity. During concrete review, establish the registry identity domain: a process-lifetime singleton must not reset generations while old tokens can exist; any supported multiple-instance/reinitialization scheme must preserve equivalent uniqueness, for example through an instance epoch. Randomness alone would not replace lifecycle checks.
- Borrow/in-flight lifetime is explicitly protected despite one-worker execution. Actual runtime callback behavior, synchronization, completion versus close, and no-reentrant-deadlock behavior remain evidence gates.
- Close invalidates ownership even on Linux close failure, does not retry fd integers, and cannot turn resource disposal into deletion. Partial open/create/result-construction failures preserve both fd-disposition and filesystem-ledger obligations.
- Registry/backing/transient/lock/token memory is bounded, reserved and measured. Retained storage remains charged after handle closure, and allocation/resource failures receive negative coverage.
- No-follow, ancestry/ACL checks, held private source parent, no-replace rename and uncertainty reconciliation are unchanged. Registry rights alone cannot authorize arbitrary unlink; destructive operations retain ledger eligibility. Published/retained/protected-uncertain descendants remain excluded even through old directory handles.

## Evidence and review still required

The reported opaque-law failure and this proposal do not demonstrate that ordinary wrappers/custom effects compile or behave correctly. Require the stated spike, full-width ABI/marshalling checks, syscall-count negative tests, fd/slot reuse tests, exactly-once cleanup, measured budgets and independent concrete-code review before adopting the representation. Real two-UID/ACL/filesystem tests remain required for Issue #3 completion; token-only tests cannot substitute. Transactional apply remains disabled.

Only this requested review report was written. The addendum, implementation plan and repository source were not edited. No implementation tests were run for this review.
