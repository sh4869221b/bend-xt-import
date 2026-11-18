# Issue #5 schema code-generation diagnosis

Date: 2026-11-07. This extends the lexer investigation in `codegen-diagnosis.md`; it is not final implementation approval.

## Result and scope

After the lexer workaround, the implementer reported that the full Reader native build still exited 137 without diagnostics. A diagnostic-only schema copy applied the same source-level technique to 15 numeric/Boolean multi-column matches. The candidate preserves schema types, fixed storage, APIs, actions, numeric limits, ownership, and resource charges.

With this diagnostic schema:

- Dynamic `Schema.apply` C generation succeeded in 1.433 seconds, peak child RSS 371,460 KiB, emitting 3,096,531 bytes of C.
- The full dynamic Reader driver generated C in 10.567 seconds, peak child RSS 2,406,520 KiB, emitting 9,334,367 bytes of C.
- Native compilation through the unchanged pinned Bend/Bun toolchain with the shared hash-verified Clang 19 extraction succeeded.
- Independent differential comparison passed 165 project-authored synthetic vectors and one cached public real XML, six chunk schedules each: 996 native executions.
- A further 62 targeted schema cases passed three chunk schedules each: 186 executions. These covered all 24 Params-child permutations, all 24 required-entry-field permutations, nine identity forms, and five reordered FuzInfo response/boundary cases.

The implementer applied the production-path candidate after verifying its hash. No production source was edited by this reviewer. This report records the tested candidate, before subsequent semantic changes or integration revisions.

## Transformation and equivalence checks

Changed functions:

`depth`, `allowed`, `element_bit`, `attribute_allowed`, `attr_assigned`, `classify`, `field_assigned`, `close_field`, `required_text`, `start_valid`, `retained`, `leaf_limit`, `field_character`, `leaf_semantics`, and `stored_action`.

Each nonfinal arm is represented by an ordered Boolean guard. True executes the unchanged original body; false checks the next original arm. Only after all previous guards fail does the final original body run. This avoids overlapping numeric-pattern expansion without introducing dynamic containers or changing field representations.

A source-level priority audit checked 463 representative combinations across these 15 functions, using all numeric pattern constants, zero, U32 maximum, and both Boolean values as applicable. All arm selections agreed, and the original action bodies were retained. This is representative source-equivalence evidence, not exhaustive runtime testing.

Priority examples:

- `attr_assigned` rejects explicit Partial zero before the generic Partial-assignment arm.
- `close_field` rejects invalid required text before assigning REC occurrence metadata or a response ID.
- `classify` preserves pipe/cache identity precedence over bracket recognition.
- `stored_action` preserves the discard-and-charge action when text is not retained, independently of the Params flag.

This is a sufficient working rewrite set. Individual schema helpers were not each independently demonstrated to fail before rewriting, and no assertion is made that every changed helper was necessary.

## Independent semantic review and exercised behavior

The schema was inspected against the approved plan and independent Expat-based typed oracle, including role/parent transitions, seen masks, required/duplicate fields, ordering, depth checks, numeric attributes and occurrence bounds, retained-field offsets, identity classification, and Fuz metadata handling. No additional actionable schema source defect was identified in that inspection.

The main differential run compared acceptance, typed digest and entry count, decoded logical-byte totals, stable rejection phase/reason/entry/raw-byte/line/column across partitions, and successful cleanup framing. Chunk sizes were 1, 2, 3, 7, 31, and 65536. The targeted extension used 1, 7, and 65536.

The cached `AE_en_ko.xml` remained outside the repository and its text was not copied into reports. Its successful result is real-file compatibility evidence only: producer version and redistribution permission remain unverified. It does not satisfy the identified pinned-producer gate.

## Exact identities

| Artifact | SHA-256 |
| --- | --- |
| Original production `xml/xtranslator_v2.bend` | `2590a4740960bd459bc9e39f9af65cbdf68e1a56f5aff3a96cbc31883e1bcc9b` |
| Applied production-path candidate | `386b3a16ad3f1b84b53b26c0e4b361c60dafd6bdce65c3815a367493e7b1fbdb` |
| Schema source patch | `fd53cc5c772b18cd57627db076a1a3ff13abb894c449f53457d7a765edeef5c0` |
| Diagnostic schema with adjusted relative imports | `624fbfa7ee97bf5b2102b00f3fe91c3ff8fd0458007412e252db228188f4d850` |
| Diagnostic Reader with redirected schema import | `faa3d42eee39600e8350c6d4e2834a2c455e3339e8ed4ccf3b975bcb484a64bb` |
| Diagnostic full driver | `2e14d60ab319d07b0379894fce3db8129bfc75c1dcf2851a451abf0a1e137804` |
| Generated full-driver C | `bc3f9ff47f41268a1a84ab02f25cd9e4b2ac66cab13ac5f5a016738a02ca9b2d` |
| Full-driver native executable | `67a126e2c2c9fa33765e7ce34985006f9af791ec0b5203a6fd038eebb505cc1e` |
| Patch manifest and 463-case priority audit | `fd3a00e6d22a4b6a18275dcb59dc924e5b9803c3de6d3846f748277ce6ff73d9` |
| Main differential result JSON | `b2234a7515ee2813d061925e8b6588c963f859a9be52ec04a35bd3e6031cf4b9` |

Local diagnostic artifacts are under ignored `.cache/diagnosis/`, principally `schema-codegen.patch`, `xtranslator-proposed.bend`, `schema-patch-manifest.json`, `schema-differential.json`, and `schema-extra-differential.json`. They are not finite acceptance-manifest inputs.

## Remaining limitations

- The current typed digest intentionally omits source keys and entry, field, Params, and Fuz source spans. These runs validate arena scalar offsets/lengths and text, but do **not** establish those omitted metadata fields. Dedicated source-position assertions are still needed.
- The main run used six fixed chunk sizes, not every possible two-chunk boundary. The targeted extension used three sizes. Exhaustive short-boundary, limit, failure-injection, affine-negative, and locked-profile resource suites remain separate gates.
- The generated diagnostic driver and schema were import-adjusted copies. Integration must build and test the applied production sources directly and preserve source/toolchain provenance.
- The compiler and runtime sources were unchanged. The successful local builds use the pinned Bun/compiler plus the shared Clang 19 extraction; they are not a locked Docker/cgroup resource certificate.
- No claim is made that all parser maxima fit simultaneously, that peak compiler RSS establishes runtime memory, or that the pinned-producer provenance gate is cleared.

No overall implementation approval is implied.
