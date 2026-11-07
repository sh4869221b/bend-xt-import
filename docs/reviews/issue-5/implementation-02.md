# Issue #5 independent production review 02

## Verdict and scope

**No remaining actionable source finding in the reviewed scope after the two corrections below.** This is a source-review verdict for Reader, Input, text arenas, ownership and charges, including their public diagnostic boundary. It is not overall implementation approval or a claim that locked resource/CI/provenance gates passed.

The reviewer did not author the reviewed Reader/Input/text/ownership/charges implementation. The reviewer did author the separate positions probe and the one-arm lexer EOF-location correction; those receive a separate independent review rather than self-approval here. Full lexer/schema semantic review and lifecycle-test review are separately assigned.

Compared against the approved Issue #5 plan, the public API documentation and the unchanged core storage, scalar, codec and budget contracts. The pass covered public begin/resume/finish/metadata/iteration/drop operations, every failure-owner return, chunk rebinding and source identity, fixed pending-state fuel bounds, EOF drain order, sticky errors, arena page reversal/traversal/release, cumulative logical/work charging and the provisional-entry/full-document boundary.

## Findings and verified corrections

### R1: Entry-wrapper resource errors discarded their actual source position

Before correction, `yield_claim` and `entry_sealed` reported `X.zero_position()` for phases 4 / reasons 6 and 5. The closing-tag event position was available in `execute_action`, but was not forwarded.

Concrete native counterexample: the 239-byte base fixture, chunk size 7, live cap 552959 returned `error 4 6 1 0 1 1 ... balanced`. Cap 552960 succeeded. The resource refusal occurs while yielding the String whose closing tag starts at byte 201, not byte zero.

The implementer threaded the event position unchanged through `yield_entry`, `yield_claim` and `entry_sealed`. Both failure paths now use it. The new literal live-neighbor test verifies byte 201 / line 1 / column 202 and entry start byte 118 / line 1 / column 119. It passes natively with balanced cleanup. The seal failure path is defensive: ordinary successful parsing does not presently make `Text.seal` fail, but its residual-owner branch also preserves the supplied position.

### R2: Public diagnostics omitted source identity required by the plan

`X.Diagnostic` originally contained position and entry context but no SourceKey. The same malformed bytes parsed from two different origins therefore produced indistinguishable standalone public diagnostics. An initialization error could also have no residual Reader from which to recover context.

The implementer added a SourceKey to Diagnostic and a bounded `with_source` helper. Internal input/lexer constructors remain source-neutral; the public Reader boundary attaches its trusted root identity. `Schema.context` injects the schema source before adding entry context. All distinct Reader initialization-failure paths now attach source identity. Sticky errors preserve the already-complete first diagnostic.

Checked the invalid-limits, root-claim failure with/without residual, Input-init failure, ordinary Reader failure, schema rejection, pending-error and finish-error paths. Native position tests directly assert source identities run 1/origin 42 and run 7/origin 43, including invalid depth, low-live root claim, root/budget run mismatch, lexer EOF and schema rejection. They also directly assert diagnostic entry-start positions, not only the error location. All pass.

## Ownership, budget and lifecycle checks

No additional defect was found in these paths:

- Init failure retains any reader claim, scratch storage or reservation needed for cleanup. Cleanup failures return the remaining owner, including an allocation whose payload has already been disposed, rather than discarding accounting obligations.
- Input stores no borrowed byte pointer. Before exhaustion, it requires the same allocation/range/length. After exhaustion, only the next contiguous positive-length range may replace the owner. Run/origin/root bounds and logical lengths remain checked. Pending CR/lookahead scalars are value-only.
- UTF-8 finalization precedes pending-CR emission at EOF. The finite drain consumes pending events/scalars before final schema validation. Starting finish prevents subsequent resume; failed Readers retain their first full diagnostic. Only successful finalization consumes Reader and transfers one ValidatedDocument owner.
- Entry yields transfer the current arena and an entry claim, replacing Reader's entry store with an empty arena. A retained entry remains independently charged while later parsing proceeds. A yielded entry alone is not a successful-document token.
- Text storage uses bounded 4096-scalar core pages and separately claimed links. Reversal is one linear pass; iteration is monotonic and moves existing links without copying payloads. Drop covers unread pages, visited pages, the current tail and residual claims. Every release failure preserves all remaining owners.
- Parser operations use the caller's shared budget. Source acquisition stays with the trusted adapter. Input inspection, text writes and traversal use public charged core operations. Logical bytes are charged before storage and for discarded metadata. No per-entry budget reset or hidden source-wide text collection was found.
- Source/entry/text ceilings keep scalar counts, page counts and finite pump arithmetic bounded. XML wrapper charges remain explicitly provisional pending generated-layout and locked-runtime measurements; this review does not infer physical RSS from logical byte counts.

## Tests actually run for this pass

- Reproduced R1 with the previously built diagnostic Reader binary at live caps 544768, 548864 and 552959; each refused at the incorrect zero position. Cap 552960 succeeded.
- Final positions source passed pinned Bun/Bend check-only and C generation, then native Clang 19 compilation without generated-C or runtime edits.
- Final positions suite: **21 fixtures / 2,946 native runs passed**, including exhaustive two-chunk cuts for the original metadata/reference vectors and seven literal live/source neighbors. Report identity is in `source-positions.md`.
- The earlier source-position assertion-sensitivity controls detected source-coordinate mutations while cleaning up successfully.
- `tools/xml/lint.py` passed on the preceding position-test revision; the complete final source inventory is being validated separately. No claim is made here that every final standalone input/text/lifecycle binary or locked matrix was rerun by this reviewer.

## Reviewed source identities

| Source | SHA-256 |
| --- | --- |
| xml/reader.bend | 7aacd2cd63fea30141b75c586240de0d1e9ff7ff297c242d9276616d70219cf1 |
| xml/input.bend | 4796d5ed4a8a6d8c75f60b01e0a8ee2a413b5f8f3738e94fc513ad004d2ad83f |
| xml/text.bend | 5e7863a464bea9c9538a6646d1462f5961f910acb6637c1825c8e819a08b96c2 |
| xml/ownership.bend | 45ec0b1b9d643e015a4518e5a8281a13e63037febf38b4d721a458412012c052 |
| xml/charges.bend | 8d42421fbf83da53ca3bbe3883932c11a145c8c51c81edb38b502c7e6fb251ee |
| xml/types.bend | 9a492e94bde3b9ce1b6d3c1adfd17a4d5c86ff0d62d3793613bb68d1bc2fc2fa |
| xml/xtranslator_v2.bend, source-context correction | 6f42134d4b2f5a542a036d69cc2b526eaa121fd02e43dc3404bc18c86f25b669 |

## Remaining gates

Final full-inventory native/affine checks, independent lifecycle/evidence review, locked isolated runtime/resource measurements and CI must complete separately. No intact permitted fixture tied to the pinned producer has been established; synthetic success and the cached version-unknown real XML do not clear that acceptance gate.
