# Independent review: schema code-generation rewrite

Verdict: **no actionable equivalence findings** for the reviewed patch.
Review performed independently from the patch author. No production source was
changed, and no compiler/native process was started during this review.

## Identities

- Original `xml/xtranslator_v2.bend` SHA-256:
  `2590a4740960bd459bc9e39f9af65cbdf68e1a56f5aff3a96cbc31883e1bcc9b`
- Applied candidate SHA-256:
  `386b3a16ad3f1b84b53b26c0e4b361c60dafd6bdce65c3815a367493e7b1fbdb`
- Patch SHA-256:
  `fd53cc5c772b18cd57627db076a1a3ff13abb894c449f53457d7a765edeef5c0`

The original was reconstructed by reversing the unified patch in memory. Every
candidate hunk was checked against actual working-tree text, and both complete
source hashes were asserted before comparison. No original content was inferred
from function names or the patch author's reported tests.

## Independent checks

The same independently written source-comparison method used for the tokenizer
review was applied to all 15 rewrites. Each predicate was derived from original
numeric/Bool/wildcard arm patterns. The original signature, argument forwarding,
true branch body, fallback body and first-match order were checked separately.
Each modified arm body remains identical except for whitespace.

All **344 equality-based input partition combinations** selected the same arm:
each numeric discriminator was tested at every literal appearing in its original
patterns plus a representative of all other U32 values; every Bool discriminator
was tested both ways. Because the rewritten predicates use only those equalities
and Bool conjunction/negation, these partitions cover branch selection, rather
than merely a set of arbitrary happy-path examples. Detailed per-function counts
are recorded in `schema-codegen-equivalence.json`.

Reviewed functions: depth, allowed, element_bit, attribute_allowed, attr_assigned,
classify, field_assigned, close_field, required_text, start_valid, retained,
leaf_limit, field_character, leaf_semantics, and stored_action.

Priority-sensitive points checked directly:

- Specific container names in depth still precede parent-based leaf fallbacks.
- Partial=0 is rejected only for the Partial attribute; List=0 remains valid.
- A pipe/cache identity still precedes bracket classification when both flags
  are true. Identity text and classification reasons are unchanged.
- Invalid close/start validation still rejects before field-specific actions,
  including self-closing branches.
- `stored_action` with keep=false still charges text without advancing retained
  scalar counts. Retained Params and entry text still select the correct arena
  and counter updates.
- All closed-parent and attribute allowlist pairs, duplicate-bit values, leaf
  limits, and text/REC/EDID semantic calls retain their original exact bodies.

## Scope

All original signatures, imports, types, state/storage shapes and definitions
outside these 15 functions are unchanged. The 86 new definitions are ordered
Bool-guard helpers only. A scan of local calls confirms that each resolves to an
earlier definition; no forward or mutually recursive dependency was introduced.
There is no API, allocation, budget, ownership, or fixed-layout change.

This is source-equivalence review, not a claim of complete parser correctness,
native differential success, or locked resource certification. Those gates remain
independent. The patch author's native/branch results are supporting evidence,
not substituted for the checks above.
