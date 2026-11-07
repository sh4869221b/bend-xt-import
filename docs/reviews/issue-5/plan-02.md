# Issue #5 independent plan review 02

Verdict: no actionable plan findings remain. The reviewed plan is approved for implementation, not as proof of implementation correctness or Issue #5 acceptance.

Reviewed 2026-11-07. Exact plan SHA-256: `8e1d6401f2b62a7adaa2d8e7e2611fd04d80929430f2271527748448dc257206`. The hash was independently verified before and after reading revision 2 at `issue5-plan.md`. Baseline remains `1b0421c15f9724a614a7b7bfae9605ec6456eb05`; the issue, current core APIs/lint, DESIGN and pinned producer source checked in review 01 remain the governing references.

## Findings resolved

- **R1, EOF normalization:** §3.2 now defines finish as the explicit EOF transition, not a demand that the caller somehow drain terminal CR. It finalizes UTF-8, emits pending CR as LF with its raw one-byte span, drains finite state, and then performs completion checks. Failure retains a sticky-failed Reader and its ownership; success consumes Reader and produces only one affine validation token. The test inventory now includes suffix/split/error/work-boundary and repeated-finalization controls. This resolves the original contract flaw.
- **R2, reference contexts:** §§4.1–4.2 now separate ordinary reference-enabled content/attributes from outside-root document whitespace and raw declaration pseudo-attributes. Both invalid whitespace references outside the root and reconstructed declaration values are explicitly rejected. Finite golden vectors and the independent Expat inventory include these cases and positive in-root/ordinary-attribute controls. This resolves the original ambiguity.

## Architecture recheck

The fixed closed-schema parent-role FSM retains exact tag matching and per-container duplicate masks while avoiding dynamic frame allocation. The actual supported depth is five; configurable lower limits still refuse otherwise legal paths. Tests and resource promises no longer pretend there is a valid depth-64 xTranslator hierarchy.

The one-current-entry arena, field spans, bounded provisional-entry yields and final validation token remain coherent. Public ScalarChunk/OwnedBytes metadata supplies source-run checks without private core constructors or identity helpers. Fixed wrapper allocations use the public reserve/settle/release lifecycle, with failure payload ownership explicitly required. The compile spike is the appropriate next step for exact Bend result variants and drop paths; no shared-core bypass is authorized.

Implementation must read the reference-context rules together with the separate comment/CDATA rules: ampersands inside comments (including prolog/epilog comments) and CDATA are literal characters, not illegal outside-root references or reference expansion attempts. This is an implementation watchpoint, not a new plan finding.

Numeric and identity restrictions remain documented and producer-backed; no newly introduced narrowing issue was found. Resource and oracle tooling remain isolated and require fresh source/compiler/binary identities, complete inventories, explicit not-run states, and failure-path verification.

## Remaining acceptance boundary

No parser implementation was reviewed or tested here. Generated-layout/native/resource evidence is future work. The authentic intact permitted pinned-producer export fixture remains `blocked_missing_fixture`; neither this approval nor synthetic/oracle success satisfies that acceptance criterion. Keep that status separate and do not close Issue #5 or claim all acceptance passed without the required fixture evidence or an explicit scope decision.

Proceed to the compile spike and implementation, then request independent implementation review against an exact source manifest and actual results. No additional plan revision is required by this review.
