# Independent review: lifecycle probe, revision 1

Verdict: **changes requested**. These findings concern regression-test strength,
not a newly demonstrated production ownership defect. The reviewer did not author
this lifecycle probe and has made no fixes to it.

Provenance correction: the initial findings below were sent against the preceding
source, identified by the quoted `Bool.or(U32.is_eq(mode,2),checked)` predicate
and the 4845-work epilog-CR fixture. Its hash was not frozen before concurrent
owner edits. The hash originally printed here,
`c0b0dfe7da34e2510cdf8c1d08de408f4dd6b6c9c61f442e56d916bb05c33384`,
was captured after the fixes and must not be used to attribute these findings.
The closure review records an exact stable revised-source hash.

## R1: Positive lifecycle modes can pass after an unexpected early parser failure

`finished` accepts mode 2 solely through `Bool.or(U32.is_eq(mode,2),checked)`.
It does not require an error-free validated document, two consumed/yielded
entries, or a nonempty retained-owner slot. Thus an early parser failure can
follow the sticky-error path and still satisfy the retained-entry test without
retaining any entry or reaching the second one.

Mode 1 similarly uses the same `checked` flag for reaching the requested abandon
cut and for successful sticky-error retries. An error before the requested cut
can therefore produce a passing abandonment result for that cut. The 392 cuts
cover raw offsets 0..391 of a 391-byte fixture, but the predicate does not prove
that each cut was actually reached without an earlier error.

The retained fixture also uses identical entries and never reads back the held
entry after processing its successor. Holding and finally dropping an owner
checks bookkeeping, but cannot detect replacement/corruption of its typed value
or text after resume.

Required: track successful cut abandonment separately from failure verification.
For retention, require error=None, final validated count=2, held=Some, and actually
check the earlier entry after the later one has been processed. Distinct entry
content makes that observation capable of detecting accidental replacement.
Unexpected early rejection must fail both positive modes.

## R2: The advertised EOF-CR work refusal occurs before EOF, and any failure passes

`work_refusal` supplies a complete document followed by literal CR, with work
limit 4845, then uses the generic mode-0 sticky-error predicate. The fixture's CR
is epilog whitespace. `Input.end` flushes that already-decoded CR without fresh
byte/scalar work; the lexer discards the whitespace, so no retained-text append
occurs at EOF.

A separate existing native driver was executed on exactly this fixture at chunk
size 1:

- Default work: `ok 1777605405 0 10 4855 balanced`.
- Work 4845: `error 1 10 0 148 1 148 10 4845 balanced`.
- Work 4846: `error 5 2 0 0 1 1 10 4846 balanced`.

The 4845 refusal is input-phase work exhaustion while acquiring/inspecting the
last scalar, before finalization; 4846 reaches test-adapter document iteration.
The generic predicate checks neither the expected phase/reason/core error nor
the pending-CR EOF path, so an unrelated earlier sticky error would also pass.

Required: use a pending terminal CR whose normalized LF must append to retained
field text during finish, set the budget at that exact append boundary, and
assert the specific resource diagnostic, core dimension/context, original byte
position, and balanced cleanup after repeated failed finish. A neighboring
successful-append or expected subsequent syntax-failure control should prove
that the refusal is really at that boundary.

## Other reviewed behavior

The source correctly preserves owners through ordinary retry/drop paths and
requires Budget.finish for passing cases. Sticky retries compare all diagnostic
fields through the test checksum (including the newly added SourceKey), compare
all used/held budget dimensions before/after retries, and deliberately supply a
wrong range after finish. The same-budget reuse loop genuinely performs 1000
begin/drop operations without starting a new budget inside the loop.

Negative/invariant-failure branches may abandon owners only while returning a
failed test result; none of the inspected such branches can print the successful
marker. This is not approval of all production parser behavior or resource gates.

## Evidence limitation

The native diagnostic probe used for R2 has SHA-256 `67a126e2c2c9fa33765e7ce34985006f9af791ec0b5203a6fd038eebb505cc1e`.
It predates Diagnostic.source addition. Its wire-format/work observation is
supporting evidence for the unchanged input/EOF charging path, not a claim that
the current source was rebuilt or validated. No compiler was launched for this
review. Current-code reruns are required after fixing the tests.
