# Independent review: EOF reference location and source-position evidence

Verdict: **clear for the reviewed changes**. No actionable finding remains after
adding Diagnostic.source and explicit diagnostic entry-start/source assertions.
This reviewer did not author the EOF arm, source injection, or positions probe.

## Frozen reviewed sources

| File | SHA-256 |
| --- | --- |
| xml/tokenizer.bend | 0c108bbe397372ee2413a19d9ed50f0797ba8a404307132b115a18a9ff73ce4a |
| xml/types.bend | 9a492e94bde3b9ce1b6d3c1adfd17a4d5c86ff0d62d3793613bb68d1bc2fc2fa |
| xml/reader.bend | 7aacd2cd63fea30141b75c586240de0d1e9ff7ff297c242d9276616d70219cf1 |
| xml/xtranslator_v2.bend | 6f42134d4b2f5a542a036d69cc2b526eaa121fd02e43dc3404bc18c86f25b669 |
| tests/xml/positions.bend | 48ec57d77bc68fe2545460de9623f638ffbee359d6c123e30abc12ed0d2e309a |
| tests/xml/positions-golden.json | 422b9fd2dbb2c0b6221a39399792d6de9817f8820ad56117bc9314d3399c98b8 |
| tools/xml/positions.py | bded1b1b1c4ff5b59af0c784f68b25967d36c235f5bf7e2477faa8223997b07d |

## EOF reference change

Relative to independently reviewed tokenizer hash df557a0a10228956272e79a91b09af3745cc3fda8eed5f896c142bf99574a965,
the only change is an MReference arm in finish that reports stored `opening`
instead of the generic EOF position. Existing LexBroken precedence preserves the
first failure. The successful closed-document MText arm is disjoint. Every
unfinished reference remains rejected with reason 6; acceptance, allocation,
reference decoding and normal non-reference EOF handling are unchanged.

Twelve literal EOF cases cover content and attribute targets, bare ampersand,
named, decimal and hexadecimal prefixes, and terminal raw CR. The last case
expects malformed-reference reason 4 at the ampersand rather than generic EOF:
it verifies that Input.end flushes pending CR and the lexer consumes the resulting
LF before EOF validation. The regular incomplete cases expect reason 6 at the
ampersand, with original bytes and scalar line/column coordinates.

## Source identity and sticky diagnostic contract

The approved design requires source identity in public diagnostics. Appending
SourceKey to Diagnostic meets that contract; with_source preserves all existing
fields. Internal input/lexer helpers intentionally create source-neutral values.
The public Reader stamps its trusted root identity rather than a caller-supplied
resume range or the diagnostic's previous source.

Inspected boundary paths include invalid limits, wrapper claim failure with and
without a residual claim, input initialization failure with retained cleanup
state, ordinary read failures, EOF input/lexer/schema failures, and final owner
cleanup/seal failures. All initialize or route through source-stamped context.
The first stored diagnostic is returned unchanged on later calls, so stamping
cannot overwrite sticky failure context. Schema.context also preserves the
active entry number and original String opening position. Plain core Error
returns from arena iteration/drop are not XML Diagnostic returns and remain
associated with their owned entry/document metadata.

The added tests use source (7,43), not only the default (1,42), and cover lexical,
schema, invalid-limit, wrapper-live-refusal and input-init mismatch paths.
The low-live neighboring cases assert refusal at 552959 and success at 552960
without deriving expected acceptance from the implementation. Diagnostic checks
now explicitly assert source and entryStart before normal output. Assertion
failure produces test-only phase 6 and cannot match the runner's expected
production error or successful result.

## Literal metadata and error expectations

Independent checks used Expat solely for structural element/text extraction,
plus a separately implemented raw Unicode byte/line/scalar-column mapper. They
recomputed every manifest span and matched it to the Bend literal assertions:
22 populated spans and 15 field references across two valid documents. The probe
also checks the absent-Fuz sentinel and all entry/Params source identities.
Every exposed entry, EDID, Source, Dest, FuzInfo and Params span is covered; REC
and attributes have no separate public span field to omit.

Fixtures exercise BOM and no BOM, CR/LF/CRLF, Japanese and non-BMP characters,
character references, comments, CDATA, self-closing and explicitly empty text,
reordered fields, Content before Params, repeated entries, and Fuz absence or
presence. Retained scalarStart/length/UTF-8 byte counts are independently checked
against normalized text, not inferred from the production parser's output.

All 12 reference ampersand positions and 18 error source/entryStart literal
expectations were independently checked. The runner performs six regular chunk
sizes and every two-chunk cut for its original 14 fixtures, plus seven explicit
source/live neighbors. It requires balanced cleanup, exact expected result and
partition-independent semantics; work is intentionally allowed to depend on
chunk scheduling. The fixture's source/start values are asserted in Bend, not
present in the generic driver's abbreviated printed diagnostic.

## Scope and validation limitations

`positions-lifecycle-literals.json` records the lightweight independent checks.
This review did not launch the Bend compiler or rerun the new native positions
suite. Native and locked/CI
results must be attached separately for these exact hashes. This is an approval
of these bounded source/test changes, not a claim that synthetic fixtures are
real producer exports or that the complete parser has passed every acceptance
gate.
