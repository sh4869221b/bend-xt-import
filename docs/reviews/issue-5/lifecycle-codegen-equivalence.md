# Independent lifecycle control-flow equivalence review

Verdict: **no actionable source-equivalence finding**. The reviewer did not
author this refactor. This approval concerns the stated test-source changes;
final lifecycle compilation/execution remains blocked separately.

- Previously reviewed lifecycle SHA-256: `e884b89e3cacf422a60798b806f80f3827623162fe8e351b70d87deb65bbac90`.
- Current lifecycle SHA-256: `7a974187dc5acae8c4de91c60715d1c41559a9e4d651dba7562e44ce0606f772`.

Both exact snapshots were compared. Seven existing functions changed, 14 small
helpers were added, and all 48 other original functions are byte-identical.
Imports, owner/state types, fixture bytes, expected values, loop bounds, success
predicates, cleanup, budget operations and the final marker are unchanged.
Every added helper calls only earlier definitions, with no forward-call or
mutual-recursion dependency. Machine-readable checks are recorded in
`lifecycle-codegen-equivalence.json`.

## Reviewed transformations

- The dispatcher preserves ordered decisions 80, then 0, then 30, then fallback.
  The same arguments and affine owners reach failed-call verification,
  abandonment, retention or ordinary stepping. All 168 combinations of phase
  equality class, tested/other mode, zero/nonzero count and start-versus-cut
  relation select the same action and condition.
- Both retry rewrites preserve all four Maybe-reader/Bool combinations. In
  particular, finish(None,True) remains failure, whereas resume(None,True)
  retains the previous True passthrough. False cases preserve the reader and
  current-byte owners without making a new call. The Some/True cases perform
  exactly the former finish or wrong-range resume operation.
- Flattened retained metadata checks still require source (1,42), entry 1 and
  List 0. Other metadata remains ignored as before. All seven retained scalars
  and the terminal None check are unchanged.
- Flattened EOF predicates check every former literal: phase/reason, raw
  position, entry/start, expected/observed, source, and core error. Work 9099
  still requires ResourceLimit (5,9099,9099,1) at byte 178/line 1/column 179;
  the 9100 neighbor still requires lexer EOF at byte 179/line 2/column 1 with
  no core error. Missing or differently tagged core errors cannot match.
- Replacing retained_scalar's fallback by explicit Fail is exhaustive because
  Done(Some) and Done(None) already cover the only other result variants. It
  preserves the returned budget/entry and False outcome.

No expectation, retention-after-resume/abandonment assertion, sticky retry,
cleanup requirement or shared-budget reuse coverage was weakened.

## Text annotation follow-up

`tests/xml/text.bend` changed from independently reviewed SHA-256
`808dc7c5494bb17342a01d4af7af0c38e7d70830286508c7693d8bafd1892689` to
`c4f567158e59b30f19e4f20c9a02b6b74dec6ce3bf165a9e086423401bed48ad`.
Removing the single added `+` from inspected's reads parameter reproduces the
previous hash exactly. This permits reuse of the bounded U32 value for work
comparison and cleanup; it does not duplicate an affine owner or change any
operation, count, expected value or assertion. No actionable finding.

## Separate execution blocker

No compiler was launched for this review. The current lifecycle source has a
reported local C-generation exit -9; see `lifecycle-codegen-diagnosis.md`. That
is not a successful build, a native pass, or proof of a particular OOM limit.
A fixed-environment comparison and successful exact-source lifecycle execution
remain outstanding. Other native markers and differential results do not
substitute for this missing result, locked resource acceptance, or the separate
blocked pinned-producer export gate.
