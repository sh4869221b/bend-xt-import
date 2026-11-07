# Independent lifecycle re-review, revision 2

Verdict: **clear for this change set**. R1 and R2 from revision 1 are resolved;
no new actionable source-review finding remains. This reviewer did not author
or modify the lifecycle probe. Native execution of this final revision is a
separate required validation step.

Reviewed `tests/xml/lifecycle.bend` SHA-256:
`e884b89e3cacf422a60798b806f80f3827623162fe8e351b70d87deb65bbac90`.

## R1 closure: positive modes cannot pass via an unrelated parser failure

- Mode 1 requires both the reached-cut flag and error=None. Thus the same flag
  being set by sticky-error verification cannot make an early rejection pass.
  The 391-byte fixture is tested at all 392 cuts, including zero and EOF.
- Mode 2 requires error=None, final count=2, and a retained Some entry. The first
  entry's source (1,42), number 1, List 0, all seven text scalars, and iterator
  exhaustion are checked after the second entry and reader/document cleanup.
- The first arena must contain `[65,26085,10,38,120,128512,10]`; the successor is
  distinct `[66,90,81]` (EDID B, Source Z, Dest Q). Independent XML parsing of the
  literal fixture confirms these sequences. Unexpected absence, replacement,
  truncation, extra text, or early iteration failure cannot pass.
- Additional mode 5 retains that first entry, abandons the reader at byte 241
  (exactly after the first closing String tag), then performs the same complete
  readback/drop. It requires error=None, count=1, reached-cut=True, held=Some.
  This separately checks the retained owner after reader abandonment rather
  than only after successful document validation.

Both retained paths finish only after all reader/current-byte/document owners
are absent, the held entry is dropped successfully, and Budget.finish confirms
no live or reserved allocations. A failure in verification remains a failed
test, including a failed cleanup. The fixed eight iterator calls require seven
Some values and then None; premature None or an eighth value fails.

## R2 closure: a literal pending-CR EOF refusal and adjacent control

The new 179-byte fixture ends inside Source with `X` followed by raw CR. Its
String starts at byte 118, line 1, column 119. The CR starts at byte 178, line 1,
column 179; normalized EOF is byte 179, line 2, column 1. These positions were
independently recomputed from the literal raw fixture.

Mode 3, work limit 9099, requires the complete expected diagnostic: reader phase
4/reason 3, CR's original position, entry 1 and its start, expected/observed zero,
ResourceLimit dimension 5/limit 9099/used 9099/requested 1, and source (1,42).
Mode 4, work 9100, requires the subsequent lexer EOF failure at byte 179, line 2,
column 1, with the same entry/source context and no core error. These two
predicates cannot pass merely because some unrelated rejection occurred. The
neighbor proves the normalized scalar can append with one more work unit before
normal syntax finalization rejects the intentionally incomplete XML.

## Remaining lifecycle coverage

Nine negative fixtures exercise sticky failures. Repeated finish and an
intentionally wrong-range resume must return the same complete diagnostic
checksum; all used/held budget dimensions must remain unchanged. The positive
and exact-EOF predicates prevent those generic sticky checks from masking their
own expected outcomes. The same invocation budget is genuinely reused for 1000
begin/drop cycles and then finished. Failure-only branches cannot print the
successful `lifecycle-balanced` marker.

## Scope and evidence

Lightweight independent fixture checks are recorded in
`positions-lifecycle-literals.json`. No Bend compiler or native lifecycle binary
was launched by this reviewer for this revision. These findings approve the
specified source/test changes, not all parser behavior, locked resource
measurements, or final CI. Revision 1 includes a provenance correction because
its source hash was captured after concurrent fixes rather than before them.
