# Issue #5 independent plan review 01

Verdict: changes requested. Two actionable plan findings remain; this is not an implementation review or acceptance result.

Reviewed 2026-11-07 against the final plan SHA-256 `da154d6ff237b42f8453483561f457fc78cdddc8fcf9aa7e62abd1bdd2f04b22` at `issue5-plan.md`. The implementer confirmed this is the final arena-refined draft, and the hash was independently rechecked. Baseline: repository main `1b0421c15f9724a614a7b7bfae9605ec6456eb05`, Issue #5, DESIGN §§4/6/10, current core APIs/lint, and pinned xTranslator revision `9aa38d60860273401f8bb0dd1557c82a295c41b3`.

## R1 — Define EOF flushing before requiring buffered input to be drained

Priority: medium. Plan §3.2, line 64, and §4.1, line 85.

`finish` is said to be legal only after all buffered scalars/tokens have been drained. The normalizer intentionally holds a literal CR to decide whether a following LF belongs to CRLF. A valid complete document ending in a lone CR, such as a valid xTranslator document followed by `\r`, therefore reaches the declared byte count with a pending CR and no further byte that can drain it. There is no defined public transition to resolve that state. The same issue matters for correct final locations and error precedence on truncated constructs followed by CR.

Required revision: make `finish` the explicit EOF transition. Once the exact declared byte count is consumed, it must finalize the UTF-8 decoder, resolve a pending literal CR as one LF with the original one-byte span, drain finite pending normalization/lexer/parser state without requiring another input owner, and only then check document completion. Define how a finalization failure returns the reader and all allocations, and prevent repeat finalization from producing a second document token. Alternatively, specify an equivalent explicit EOF-resume operation, but do not leave draining as an unsatisfiable caller precondition.

Required tests: complete document with no suffix, LF, CRLF, and lone CR at EOF; split between CR/LF and a final CR in its own chunk; incomplete markup/comment/entity followed by CR; exact work boundary at EOF flush; failure cleanup and repeated finish. Expected outputs/diagnostics must not depend on partitioning.

## R2 — Restrict entity handling to XML contexts where references are legal

Priority: medium. Plan §4.1, lines 85–89, and §4.2, lines 93–95.

The plan defines general reference expansion and says to reject *non-whitespace* prolog/epilog text, but it does not distinguish literal document whitespace from a character reference that decodes to whitespace. XML forbids references outside the root even if the result is space, TAB, LF, or CR. Likewise, XML declaration pseudo-attribute values are not ordinary XML attribute values and cannot contain entity/character references. Reusing the ordinary attribute/text decoder would accept malformed XML such as `&#32;<SSTXMLRessources>...`, `...</SSTXMLRessources>&#x20;`, or `<?xml version="&#x31;.0"?>...`.

Required revision: explicitly state that only literal XML S and comments are allowed outside the root (plus the initial declaration); reject `&` there before reference expansion. Give XML declaration pseudo-attributes their restricted raw lexical grammar, with no entity expansion or ordinary-attribute normalization. Preserve ordinary reference semantics inside element content and normal attributes. This can use context flags in the existing lexer; a separate parser is unnecessary.

Required tests: referenced whitespace in both prolog and epilog; character/predefined references in version, encoding and standalone; positive literal surrounding whitespace; positive referenced whitespace in an element-only container and a normal attribute; all relevant chunk splits. Local independent Python Expat probes confirmed rejection of the former cases and acceptance of literal terminal CR and in-root referenced whitespace.

## Non-blocking simplification

A generic 64-frame tree parser is not required to satisfy this closed dialect. Its accepted hierarchy has maximum element depth five (`SSTXMLRessources/Content/String/FuzInfo/Fuz`). A closed-schema parent-role FSM with a fixed small frame/seen-mask representation can enforce exact nesting and lowered configured depth limits without allocating arbitrary frame chains. Unknown/deeper nesting should still be refused at the offending start tag. If adopted, update the depth-64 resource measurement promise to exercise the configured ceiling/refusal and actual maximum supported schema depth, rather than claim a valid depth-64 xTranslator document. Keeping the planned generic stack is also defensible if its additional ownership/resource tests are implemented.

## Verified non-findings and acceptance boundaries

- The one-current-entry arena with field spans is a sensible refinement. It avoids a minimum core buffer for every small field while keeping retention visible in the global live budget. Streaming 200,000 entries is correctly distinguished from retaining them all.
- sID 6–8 hex digits and id/idMax 0–65535 are deliberate pinned-producer restrictions backed by `IntToHex(..., 6)` and Word fields. They must remain documented as dialect/profile restrictions, not universal XML numeric rules. No numeric narrowing finding is raised for those choices.
- `Partial=0` is not emitted by the pinned exporter, while absent/1/2 are preserved without selection. REC case and full bracketed FormID retention are correct. Do not broaden underscore heuristics into VMAD rejection.
- Public reserve/settle/release and core buffer APIs preserve the existing core lint boundary in the proposed design. The compile spike should explicitly prove begin/resume source-run checks without private Budget/Allocation destructuring. Caller attestations about unchanged chunk bytes remain necessary; allocation identity alone does not prove contents.
- Provisional entry yields plus a final validation token correctly prevent a parsed prefix from being presented as a validated document. The later planner still must honor that boundary.
- The authentic intact permitted pinned-producer export fixture remains unavailable. This is correctly disclosed as blocked and is not an implementation bug that synthetic data or Expat can clear. No claim of full Issue #5 acceptance or readiness to close it is approved by this review.

Re-review the revised final hash after R1 and R2 are addressed. No implementation should be inferred to have passed from this plan review.
