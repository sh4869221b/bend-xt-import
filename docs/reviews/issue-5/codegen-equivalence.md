# Independent review: tokenizer code-generation rewrite

Verdict: **no actionable equivalence findings** for the reviewed transformation.
This review was performed independently from the patch author, against the actual
applied source, not by accepting the author's reported test counts.

## Reviewed identities

- Original `xml/tokenizer.bend` SHA-256:
  `b76b35e93a37ca673730de8a09e3b10533419b1ed32cddfb158c797ad238227e`
- Candidate SHA-256:
  `df557a0a10228956272e79a91b09af3745cc3fda8eed5f896c142bf99574a965`
- Patch SHA-256:
  `ad2eb01b8d4909a1932a5011d62aa475bb6cccdc723574060f3d48e6f297bfd5`

The original was read from repository HEAD and the candidate from the working
tree. Both hashes were asserted before comparison. Structured results are in
`codegen-equivalence.json` beside this report.

## Method and results

Independently parsed original function definitions and candidate guard chains.
For each of the 20 numeric/Bool multi-match rewrites:

1. Compared the original public signature exactly.
2. Derived each predicate from the corresponding original arm's literal,
   wildcard, and Bool patterns, without using the patch author's predicates.
3. Verified each helper's true branch has the original arm body, modulo only
   whitespace, and each false branch passes unchanged arguments to the next
   guard in original arm order. The final fallback body is unchanged.
4. Enumerated every equality-based input partition: each distinct numeric
   literal and one value representing all remaining U32 values, plus both Bool
   values. All **211 partition combinations** select the same original arm.

Reviewed functions: open_delimiter, attr_selected, attr_equals, attr_quote,
close_space, comment, cdata_prefix, cdata, reference_body, reference_valid,
decl_xml, decl_space, decl_allowed, decl_selected, decl_equals, decl_quote,
decl_char, decl_variant, decl_length, and decl_after.

The partitions are sufficient for these branch predicates because they use only
literal equality and Bool conjunction/negation. Preserved branch bodies retain
all positions, event counts, event ordering, modes, reference handling and errors.
In particular, unknown names still take precedence over delimiters; comment
closing `-->` precedes the double-hyphen error; CDATA bracket cases preserve held
span order; and declaration whitespace/closing/question-mark priority is intact.

## Constructor-sensitive close_end

Reviewed separately rather than treating a Context constructor pattern as a
numeric wildcard. Context has one constructor. The original priority is:

1. depth == 0: context error 5, with the original name as observed value;
2. otherwise name == 0: unknown-name error 2;
3. otherwise emit the same close event, decrement depth, clear canDeclare.

The candidate checks unsigned depth > 0 before unsigned name > 0, then calls an
identical emit body. These guards are exactly the complements of the original
zero checks. Nine combinations using 0, 1 and U32 maximum for depth/name also
matched. No decrement can occur on depth zero, and the depth-zero error retains
priority even when the name is also zero.

## Scope and call order

- All original function signatures are unchanged.
- Imports and every type/storage declaration are byte-for-byte unchanged.
- Original functions outside the 21 reviewed rewrites are unchanged.
- The 72 added definitions are only guard/close helpers.
- Every local helper call resolves to an earlier definition; no forward or
  mutual-recursion dependency was introduced.
- State, Mode, event representation, ownership, and budgets are unchanged.

No Bend compilation or native execution was launched for this independent
review. The patch author's
64-vector native lexer result is useful separate evidence, not a substitute for
this source review. Full reader differential/resource testing remains required.
This review makes no claim that unchanged pre-existing XML behavior is complete;
the previously noted unterminated-reference EOF diagnostic location is unchanged.
