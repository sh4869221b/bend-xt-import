# Issue #5 implementation plan: strict xTranslator v2 XML in Bend 2

Status: revision 2, addressing independent plan review 01 (R1 EOF finalization, R2 reference contexts, and the closed-schema FSM simplification). Ready for re-review. No implementation is claimed by this document.

## 1. Verified baseline and scope

- Repository: `sh4869221b/bend-xt-import`, Issue [#5](https://github.com/sh4869221b/bend-xt-import/issues/5), inspected on 2026-11-07.
- Main was `1b0421c15f9724a614a7b7bfae9605ec6456eb05`. Implementation branch: `feat/issue-5-xml-parser`. Keep unrelated worktrees and parallel Issue #4 changes separate.
- Governing material: main `DESIGN.md` §§4, 6, 10; `docs/core/api.md`; `docs/core/charges.md`; actual core implementation and API lint.
- Runtime: locked Bend 2.0.40 C backend, Linux x86_64, one worker, no GPU. Production parsing, normalization, validation, and typed conversion are Bend. Python XML is a test-only oracle.
- Pure library only: no files, paths, network, entity resolution, plugin mutations, matching, translation selection, output publication, or CLI are implemented here. #3 supplies actual snapshot input later; #4's FO4 framing remains independent.
- Own `xml/`, `tests/xml/`, `tools/xml/`, `docs/xml/`, `docs/implementation/issue-5-plan.md`, and `docs/reviews/issue-5/`. Avoid changing `core/`, shared core tooling, shared CI, README, DESIGN, or sources.lock unless separately coordinated. A dedicated `.github/workflows/xml.yml` can be added after the project owner approves that isolated path.

## 2. Producer evidence and real-export acceptance gate

Reference only: [MGuffin/xTranslator](https://github.com/MGuffin/xTranslator/tree/9aa38d60860273401f8bb0dd1557c82a295c41b3) at `9aa38d60860273401f8bb0dd1557c82a295c41b3`. The repository's sources.lock already pins it. Implement the observed format, not a translation of Pascal source; do not copy producer source into this project.

The pinned `TESVT_XMLFunc.pas`, `XMLExportbase`, establishes:

- Optional XML declaration emitted as `version="1.0" encoding="UTF-8" standalone="yes"`.
- Root `SSTXMLRessources`; Params children Addon, Source, Dest, Version (`2`); then Content containing String entries.
- String attributes: required List; optional sID from `inttohex(strId, 6)`; Partial only emitted as `1` or `2`.
- Plugin exports contain EDID, REC, Source, Dest. REC/@id and @idMax are emitted together when IndexMax > 0.
- REC text is two four-byte signatures separated by one colon.
- FuzInfo, when present, contains responseId and one or more Fuz children. These are metadata, not file requests.
- `TESVT_typedef.pas` defines index/indexMax as Word (0..65535), strId as a 32-bit value, and cache EDID export as eight hex digits, pipe, eight hex digits, pipe, decimal index, pipe, decimal maximum. VMAD property names can be joined to an editor ID with an underscore, which is not distinguishable from an ordinary editor ID by spelling alone.

Actual fixture availability is currently **blocked**, not passed:

1. Main's recursive Git tree contains no XML exports.
2. The complete pinned producer tree contains no .xml exports, plugin fixtures, or runnable producer binary; the GitHub releases collection is empty (verified during fixture research).
3. Fixture research inspected a public 1.6.0 issue excerpt, but it is deliberately truncated/malformed and lacks an explicit reuse license. It is not a valid fixture and must not be silently repaired and called an actual export.
4. The relevant local producer checkout contains source, not a captured export. No user-provided permitted export has been supplied. The checks and source links are retained in `docs/xml/producer-fixture-research.md`.

Implementation and source-derived synthetic/oracle tests may proceed. Keep `producer_export: blocked_missing_fixture` distinct from functional/native/resource status. Before claiming Issue #5 complete, obtain a captured export from the pinned producer built from this revision, using a project-owned tiny synthetic plugin and project-authored translations, or obtain an existing complete export with verified producer version and permitted verification access. Verification-only acquisition does not require redistribution permission; permission is needed only if fixture bytes or protected text are vendored or distributed. Record producer revision/build identity, export options/mode/languages, input fixture identity/license, capture procedure, raw XML SHA-256, and expected typed output. Never bundle game masters or third-party mod content without permission. A later producer version is a separate compatibility fixture, not proof for the pinned producer.

A draft PR may describe this blocker and completed implementation. Do not close Issue #5 or claim its real-producer acceptance condition satisfied without this evidence. The project owner should obtain the fixture or make an explicit scope decision before calling the work fully complete; synthetic tests must never substitute invisibly.

## 3. Public contract and streaming architecture

### 3.1 Modules

- `xml/types.bend`: limits, bounded positions/spans, numeric error codes, element/attribute IDs, typed metadata/entries, result/status variants.
- `xml/ownership.bend`: fixed-shape XML owner reservation/settlement/release helpers using public core budget APIs; no raw Array or private core calls.
- `xml/text.bend`: affine, chunked current-entry text arena, field spans, and consuming iterator/drop operations.
- `xml/input.bend`: pure chunk/codec bridge, raw byte positions, UTF-8 and XML-character validation, literal EOL normalization.
- `xml/tokenizer.bend`: bounded streaming lexer for the accepted XML subset.
- `xml/parser.bend`: well-formed nesting, document/prolog/epilog state, fixed closed-schema parent-role FSM, event production.
- `xml/xtranslator_v2.bend`: fixed schema adapter, numeric validation, entry builder/yields, final document validation.
- `xml/charges.bend`: XML-only candidate charges, finalized only after generated-layout and resource evidence.

Do not build a DOM, materialize the entire input as Unicode, append to immutable Strings, or store a full list of tokens. Names use fixed numeric vocabulary IDs. Unknown names are rejected with an unsupported-name diagnostic at their start; no attacker-controlled diagnostic String is retained.

### 3.2 Input boundary

Use `OwnedBytes` chunks of at most 65536 bytes and core `Range` values. The caller supplies a root source range created by the trusted snapshot/synthetic adapter and matching chunk subranges. The XML library checks range run/source identity, contiguous absolute byte ranges, declared total <= limit, logical chunk length, and progress. At begin, compare the root range run to the run returned by public metadata on the newly allocated reusable scalar scratch owner; at resume, also compare input OwnedBytes metadata run. This proves the run checks without destructuring private Budget/Allocation constructors or calling private identity helpers. A mismatch returns all just-created owners for cleanup. On partial consumption it returns the exact same input owner plus the next index. Pin the active chunk's allocation identity/range until exhausted; replacing it mid-chunk or skipping/repeating a source range is an error.

As with the existing core's trusted bind contract, the caller must attest that the provided bytes actually belong to the stated source range. This pure library does not prove file provenance from an arbitrary OwnedBytes value. The future #3 adapter may unwrap its window under its existing trusted privileges and call this boundary. XML modules must not mint SourceOwner/Range, unbind ByteWindow, or gain private core privileges to fake that connection. Tests create synthetic sources explicitly. No #3 implementation dependency is introduced.

Proposed operations (exact Bend tuple syntax can be finalized during the compile spike):

- `begin(budget, rootRange, limits)` returns the same budget and an affine Reader or bounded diagnostic. Root range starts at byte 0 and covers the complete declared XML source.
- `resume(budget, reader, chunkRange, bytes)` returns budget, reader, bytes, next chunk index, and one of NeedInput, EntryReady, Failed. It stops at an entry boundary rather than retaining prior entries internally.
- `finish(budget, reader)` is the explicit EOF transition once exactly the declared source bytes have been consumed; a pending normalization/lexer state is not a caller error or a requirement to provide another input owner. First call public `utf8.finish` on the decoder state. If it succeeds, resolve a pending literal CR as one LF with the original CR's one-byte source span, then drain the finite pending normalization/lexer/parser transitions without reading more bytes. Only then check completed root/prolog/epilog state and all required schema fields. EOF in an incomplete UTF-8 sequence, token, element, or required schema field fails. Decoder-finalization errors take precedence over subsequent EOF syntax checks; otherwise pending normalized characters are processed before diagnosing an unterminated construct.
- Finalization failure returns the same budget and a sticky-failed Reader with every remaining allocation/partial entry for explicit cleanup. Successful finalization consumes Reader and transfers its retained ownership into exactly one affine ValidatedDocument token plus Params/count; it does not return a resumable Reader. Reusing a successfully consumed Reader must fail an affine negative compilation test, and repeating finish on a sticky-failed Reader must return that failure rather than a document token.
- `drop_reader`, `drop_entry`, `drop_text`, and `drop_document` release all XML/core owners through the same budget on success, abandonment, or failure.

Entries yielded before EOF are explicitly `ProvisionalEntry`, tagged with run/source ID and original entry number. They may be inspected/collected by a pure planner, but do not authorize an import. Only successful `finish` produces an affine ValidatedDocument token for that source/count; a trailing syntax error invalidates the entire stream. No callback can perform plugin IO through this parser, and no result type is named successful-document before final validation. The later planner must require the matching final token; this issue documents that integration requirement rather than implementing apply.

Every failure returns all still-owned reader/input/partial-entry resources. Parser errors are sticky: resumption cannot convert a Failed reader into success. No library `IO.die`/exit, silent owner abandonment, per-entry budget reset, or success from a parsed prefix.

### 3.3 Core codec and source locations

Use the public `codec.decode(0, ...)` API and a reusable one-scalar ScalarChunk initially. This deliberately simple bridge makes byte-position preservation and error order unambiguous without private `utf8.step` access. Clear and reuse the scalar scratch buffer; do not allocate it per scalar. Call `scalars.get` before lexical inspection. Do not optimize to larger decoded batches until all split/position/work tests pass; such an optimization must preserve the same contract.

Maintain the raw start offset of the pending scalar and the absolute consumed-byte count across chunks, including partial UTF-8. Every scalar carries raw `[start,end)` byte offsets before BOM stripping, EOL normalization, or entity decoding. UTF-8 errors retain core's offending/start byte position. Check scalar validity against XML 1.0 Char: TAB/LF/CR, U+0020..D7FF, E000..FFFD, 10000..10FFFF. Reject NUL, forbidden controls, surrogates, FFFE/FFFF, overlong UTF-8 and >10FFFF; do not reject otherwise legal supplementary scalars.

Consume a single UTF-8 BOM only at raw byte zero. An embedded U+FEFF remains ordinary text where text is allowed; a second leading BOM is not silently stripped. UTF-16 BOM/signature is rejected, never decoded. Other malformed leading sequences use the UTF-8 diagnostic.

Track one-based raw XML line and scalar column as useful secondary locations; byte offsets are authoritative. Literal CRLF counts as one newline, CR alone and LF alone as one newline. A reference that expands to LF/CR does not change the source file's line count. Entry numbers are one-based String order; errors outside a String have entry=0. Every entry and field carries source start/end spans. Errors include source identity, byte offset, line/column, entry number and entry start, phase/reason, expected/observed numeric IDs as applicable, and an optional nested core Error. Do not retain arbitrary source excerpts.

## 4. XML subset rules

### 4.1 Normalization and text

Normalize literal CRLF and lone CR to LF before XML syntax/text interpretation, including CDATA. Preserve original byte spans over both bytes of CRLF. Hold at most one pending literal CR across input chunks; finish resolves a final lone CR to LF even if it is the last byte of epilog whitespace. EOF flushing never rereads/recharges that raw byte or its already-inspected scalar. Any actual retained-text append caused by the flush must still precharge its scalar write/logical bytes and may fail with a cleanup-preserving resource error. Entity references are expanded only inside element content or ordinary attribute values, **after** literal EOL handling; `&#13;` and `&#xD;` remain CR. Preserve a reference/literal origin distinction long enough for attribute normalization: literal TAB/LF/CR become spaces in attributes, whereas referenced whitespace remains the referenced character. No further trim, whitespace collapse, case folding, Unicode normalization, encoding fallback, or second entity decode.

In reference-enabled contexts, recognize exactly amp, lt, gt, apos, quot and numeric decimal/hex references. Prolog/epilog and XML declaration pseudo-attribute values are not reference-enabled: reject an ampersand there before trying to expand it, even if a reference would yield whitespace or a legal declaration character. Numeric references require at least one digit, semicolon, ASCII digits (hex permits A-F/a-f), lower-case `x` introducer as XML requires, checked accumulation, and an XML-legal resulting scalar. Leading zeros are allowed within the configured reference-token limit. Unknown entity names and malformed references fail at the ampersand. `&amp;lt;` becomes the literal five-character text `&lt;`, never `<`. Raw `<` starts markup and cannot appear in attribute values. Raw `&` must begin a valid reference. Literal `]]>` is forbidden in ordinary character data, even across chunks, but escaped/reference-generated equivalent text is legal.

Leaf text is the exact concatenation of ordinary text and CDATA segments with comments omitted. Self-closing and explicit empty leaves both mean present-empty. Missing fields are separate builder states, never defaulted to empty. Text inside element-only containers must be XML whitespace only (space/TAB/LF/CR after the XML normalization rules); character references yielding such whitespace are legal there. This does not apply outside the root, where only literal XML whitespace is legal. Non-ASCII whitespace such as NBSP is text, not structural whitespace.

### 4.2 Markup

- Optional XML declaration occurs only at the start after the optional BOM, with no preceding whitespace/comment. Require version='1.0', then optional encoding, then optional standalone, in the XML-specified order; single/double quotes and XML whitespace are supported. Declaration pseudo-attributes have raw lexical values, not the ordinary XML attribute decoder: version is the literal ASCII bytes `1.0`; encoding, when declared, is the raw ASCII case-insensitive spelling UTF-8; standalone is raw yes/no. No entities/character references, CDATA, embedded whitespace, ordinary-attribute whitespace normalization or reconstructed values are allowed inside these quotes. XML whitespace is permitted only at the declaration grammar's separators/around equals. Duplicate/unknown pseudo-attributes, XML 1.1, wrong order, missing version and unsupported encodings fail.
- General processing instructions are deliberately unsupported, not silently ignored. The reserved xml target is recognized only as the initial declaration; another declaration or case-variant target fails.
- Require exactly one root. Prolog/epilog permit only literal XML S (space/TAB/LF/CR, with literal EOL normalization) and comments, plus the declaration at its initial position. Reject `&` immediately outside the root: decimal/hex/predefined references are illegal there even when they would decode to whitespace. Also reject all other prolog/epilog text, CDATA outside the root, second roots, and stray closing tags.
- Start/end tags match exact case-sensitive IDs. Enforce required whitespace between attributes, equals sign, quotes, legal closing delimiters, and no attributes on end tags. Support `<x/>` and `<x />`.
- Duplicate attributes are rejected before overwrite using a fixed seen mask. Unknown attributes, all xmlns declarations (including empty), colon-bearing names, namespaces and XInclude are unsupported.
- Comments require `<!-- ... -->`, cannot contain `--`, cannot end with a stray hyphen, and must close. CDATA requires exact `<![CDATA[` and closes at the first `]]>`; its contents are not entity-decoded.
- On `<!`, only comment or CDATA openers are allowed. Reject DOCTYPE, ENTITY and every other declaration immediately, including internal/external subsets and parameter entities. There is no external resolver or base URI API.

No unchecked scans to a delimiter: each byte/scalar has been charged, token counters are bounded, and every loop consumes input or advances a finite pending state. Pauses preserve all delimiter prefix state, including `<?`, `-->`, `]]>`, entity references and multi-byte scalars.

## 5. Typed xTranslator adapter

The adapter enforces a closed vocabulary and no mixed element/text content in leaves. It validates the complete document, including entries a future selection policy might exclude. Structural/numeric corruption is never hidden by Partial status.

Use a fixed parent-role FSM and fixed small frame/seen-mask fields, not a dynamically allocated general XML stack. Roles distinguish document/root, Params/its leaf, Content, String/its leaf, and FuzInfo/its leaf; closing tags must match the exact active role/name before returning to its recorded fixed parent role. At most five elements can be open in this grammar: SSTXMLRessources/Content/String/FuzInfo/Fuz (responseId is the same depth). Root/Params/Content/String/FuzInfo seen masks remain in their fixed reader fields so returning from a leaf cannot erase duplicate detection. Wrong-parent, repeated container, unknown or deeper nesting fails at the offending start tag. Check configured depth before entering an otherwise legal child; a lower caller ceiling can reject a valid depth-five document, while an invalid depth-six path is still unsupported schema even when the configured ceiling is 64. No depth-dependent owner allocation or unbounded recursion is introduced.

Order policy: root must have one Params and one Content; either order is accepted because identification is by names, not position. Required Params children and required String children may appear in any order, each at most once. The producer's normal order is included in positive tests. A content-before-params stream still yields provisional entries only; final validation requires valid Params. FuzInfo's responseId may occur before or after Fuz children, exactly once.

| Element | Attributes | Required children / value |
| --- | --- | --- |
| SSTXMLRessources | none | exactly one Params and one Content |
| Params | none | exactly one Addon, Source, Dest, Version |
| Addon | none | nonempty basename text; reject slash/backslash, NUL/control, `.`/`..`; never use as a path |
| Params/Source, Params/Dest | none | nonempty exact language text; preserve case/text; later locale/CLI agreement is planner/profile work |
| Version | none | exact text `2`, no surrounding whitespace |
| Content | none | zero or more String |
| String | List required; Partial and sID optional | exactly one EDID, REC, Source, Dest; at most one FuzInfo |
| EDID | none | nonempty exact text, classified below |
| REC | id and idMax optional as a pair | exactly four ASCII signature bytes, colon, four ASCII signature bytes, no extra text |
| Source, Dest inside String | none | present text, possibly empty/whitespace-only |
| FuzInfo | none | exactly one responseId and one or more Fuz |
| responseId | none | checked nonnegative decimal <= 2147483647; nonmatching metadata |
| Fuz | none | bounded text, may be empty; never interpreted as a path |

Schema failures name the missing/duplicate element ID and its parent/entry span. Source/Dest missing is an explicit MissingRequiredField diagnostic, different from a present empty value. Dictionary/sID-only documents lacking EDID/REC are rejected as unsupported plugin-import dialect rather than guessed into record entries.

Numeric/identity rules:

- List is exact ASCII `0`, `1`, or `2`, producing STRINGS/DLSTRINGS/ILSTRINGS enum. No signs, spaces, other decimal spellings, or default.
- Partial absent, `1`, `2` produce Translated/Incomplete/Locked status plus presence metadata. Explicit `0` or any other spelling is unsupported for this pinned producer profile. Do not filter these entries here; planner selects statuses later.
- sID, if present, is 6..8 ASCII hex digits; lower/upper hex accepted, digits-only still hexadecimal. Accumulate into U32 with checked arithmetic, retain supplied width and value, and do not interpret as decimal or a FormID. Leading zeros are preserved by width. Zero is representable here; a localized-field nonzero-ID policy belongs to matching. Prefixes, sign, whitespace, <6 or >8 digits fail the named dialect-width check.
- id/idMax are decimal digits only; leading zeros accepted, no sign/whitespace. Check U32 accumulation before enforcing producer Word range 0..65535. Both absent becomes UnspecifiedOccurrence. Both present require id<=idMax and become ExplicitOccurrence(index,maxIndex). One missing fails. Explicit (0,0) is unambiguous and accepted even though this producer omits that pair. Max is never incremented or treated as count; tests include 65535 and reject 65536. Later matching checks actual profile-specific occurrence count/max.
- REC is exactly nine ASCII characters, colon at position 4; each signature byte must be printable ASCII excluding colon/whitespace, and case is preserved. It is not checked against a FO4 translation-field allowlist here. Unsupported record/field handling belongs to the profile/planner; `VMAD` is marked unsupported-target metadata, not accidentally treated as an ordinary supported field.
- EDID literal remains exact; a precise `[8 hex digits]` form is classified as BracketFormId with raw 32-bit value and original text, not a low-24-bit ID. The parser cannot know whether an actual record has a literal bracket EDID; matching must reject ambiguity later.
- Cache/pipe forms are recognized as unsupported identity, not ordinary EDIDs; non-ASCII/invalid literal editor IDs are marked UnsupportedIdentity for the later planner rather than transliterated. Preserve bounded original EDID text and reason. Do not claim arbitrary underscores identify VMAD: the producer source proves this spelling is ambiguous. The REC/profile gate handles known VMAD targets.

Fuz metadata is structurally validated and measured, then discarded as text. Retain only presence, responseId, Fuz count and source span in the entry. Its bytes count toward per-entry text/logical/work limits, and each Fuz is bounded; never open any value or match on it. Unknown descendants/attributes still fail, rather than hiding an arbitrary subtree behind a skip.

## 6. Ownership, resource limits and accounting

Use the same invocation Budget supplied by the caller. Never call budget.start from production XML. Public core APIs only: reserve_many/settle/cancel/consume/release and owned byte/scalar operations. No raw Array, Array-to-List conversion, copied core constructors, private B.allocate, private scalar writes or private utf8 transitions. Add `tools/xml/lint.py` that invokes the unchanged core lint and adds XML public-boundary, no-IO/no-unbounded-String/List, ownership-constructor and progress-policy checks. Lint is a repository contract, not a malicious-code sandbox.

Retained text uses one affine arena per current entry, plus one small Params arena for the document, not one core buffer per field. An arena is a chain of owned ScalarChunk pages with a separately owned current tail. Start with 4096-scalar pages; each full page is linked after charging a small XML link owner. EDID/Source/Dest carry explicit present/empty states and scalar spans into their entry arena, plus canonical byte lengths and original source spans. Field values are contiguous because leaf text completes before another field begins. Whole-entry text may exceed 65536 bytes by adding pages; no page exceeds core capacity. Finalization reverses links once without copying scalar payload. Consuming iteration walks pages linearly; no random indexing through a linked prefix, whole-text clone, or repeated concatenation. A fully empty arena needs no payload page. Params/entry arena ownership transfers, never duplicates. Do not allocate pages for discarded Fuz metadata or bounded numeric/name accumulators.

The parser does not retain 200,000 entry arenas. Its streaming test consumer disposes each provisional entry after checking it. A later planner retaining many small entries will need a compact shared document/selected-text arena, rather than blindly retaining a minimum core page per entry; that collection representation is not claimed by this streaming parser. Retention by any caller remains visible in the same global live budget, with safe refusal before exhaustion. The 200,000-entry limit is validated using streaming consumption; it is not a claim that 200,000 independent arena owners fit the live cap.

Reserve/settle XML state, page-link and provisional-entry wrapper charges before constructing each affine wrapper, using public budget APIs. The fixed parent-role/seen-mask representation is included in the reader charge; there are no separately allocated dynamic frames. Retain every Allocation token until the wrapper is disposed. If page allocation fails after link reservation, cancel/release the link and return the existing builder. If settlement fails, return its ticket for cleanup. State owns fixed pending lexer/normalization values and the fixed five-level schema context; no fresh reservation per processed character. Candidate charges are recorded separately and must be calibrated, not assumed covered by core ScalarChunk measurements.

Initial parser limits, constrained to tested maxima:

- Total source 64 MiB; configured depth default/ceiling 64, with only schema depth <=5 accepted; String entries 200,000. Configured depth may be lowered to 1..64 and is enforced for otherwise legal children. A zero or above-ceiling depth configuration is rejected before parsing.
- Aggregate canonical UTF-8 text within each entry 1 MiB, including EDID/REC/Source/Dest/attributes/Fuz metadata, not 1 MiB independently per field. Counters are checked before emitting text. Also separately bound each field by this ceiling.
- Params aggregate text 4096 bytes, Addon <=1024, each language <=256. These are explicit XML profile limits, not silent truncation.
- Name length <=64 raw ASCII bytes, attribute count <=8 per tag, reference token <=64 raw bytes, numeric attribute token <=16 bytes; overlong tokens produce a resource/dialect-limit diagnostic before overflow/allocation. XML structural whitespace/comment/CDATA can stream to the file ceiling without a token-sized allocation.
- Fuz child count <=4096 per entry and Fuz text <=4096 bytes apiece, additionally subject to the aggregate entry-text ceiling.
- Limits cannot exceed these tested maxima; callers may lower them for exact-boundary tests. Do not imply all 64-level structures are valid in the much shallower xTranslator schema.

Accounting ledger:

- Input bytes are charged once by snapshot acquisition/synthetic adapter, not again by XML resume. XML verifies its per-file ceiling against declared source and actual consumed bytes.
- Core codec charges input reads and scalar emission; scalar.get charges inspection. Cached already-inspected pending scalar/delimiter state is not charged again just because a chunk boundary pauses it.
- Writing retained text pages charges scalar emission; later text traversal/comparison/copy consumes actual canonical-width visits through ScalarChunk APIs. Counts and exact costs are asserted in small hand-computed tests.
- Logical dimension consumes canonical UTF-8 bytes when field text is emitted, including discarded Fuz metadata; repeated source spans/text remain separately charged. Work is cumulative across the entire document and caller's later phases. No final-output/expanded charges for internal parsing.
- Constant vocabulary comparisons, short numeric accumulators and fixed flags are bounded metadata bookkeeping; they do not justify repeatedly rescanning uncharged text. All allocations and byte/scalar visits have a documented charge point before the action.
- Shared core caps remain in force. Hitting live/work before a larger declared parser ceiling is a safe refusal, not evidence that the parser supports all maxima simultaneously.

Measure new shapes on the locked profile: the fixed reader/FSM at actual schema depths 1..5, configured-depth exact/refusal cases (including 4 versus the valid depth-five Fuz path), rejection of an illegal sixth level, and validation of configured ceiling 64/65 without constructing a depth-64 document, text page boundaries, ASCII/Japanese/non-BMP text, Params plus entry plus caller-retained previous entry, 1 MiB entry, repeated create/drop/reuse, all failure cleanup paths, and 1/16/64 MiB streams with entries consumed promptly. Inspect generated C for actual recursion/closure/ownership shapes and stack growth; do not merely extrapolate UTF-8 byte count to RSS. Tail-oriented input loops, fixed parent-role storage and configured-depth guards must be visible in implementation. Do not claim to measure or support a valid depth-64 xTranslator hierarchy. Use the existing observer model (separate compiler, native process identity, cgroup v2 1 GiB/swap=0, three repeats). A missing Docker/cgroup facility is **not run**, never pass. Local native smoke may use verified toolchain files read-only from the Issue #4 cache, but it is not locked container resource acceptance.

## 7. Tests and independent XML oracle

### 7.1 Deterministic Bend suites

Create separate test entrypoints for input/UTF-8 positions, lexical syntax, nesting, schema, numeric/identity semantics, text semantics, resource limits, lifecycle, and split equivalence. Test-only input adapters may use host IO/fixture construction but production `xml/` must not.

Cover at least:

- BOM/no BOM, declaration variants, both quotes, attribute order, self-closing leaves, comments, CDATA, Params/Content and field order permutations, empty Content. Golden EOF vectors: a complete document with no suffix, LF, CRLF, and lone CR; a CR/LF split and a final CR in its own chunk must produce identical validated content/count and correct final raw position. Incomplete markup/comment/entity followed by terminal CR must fail at documented positions after the EOF flush; include exact work limits at the flush, cleanup after a finalization resource failure, repeated failed finish, and the negative affine control for repeated successful finish.
- ASCII, Japanese, non-BMP scalars; invalid UTF-8 lead/continuation/overlong/surrogate/out-of-range/truncation; XML-forbidden raw and referenced scalars.
- Missing versus empty versus whitespace-only Source/Dest, leading/trailing spaces, CR/LF/CRLF in text and CDATA, referenced CR/LF/TAB, attribute literal versus referenced whitespace, adjacent CDATA/comment/text, all five entities and no double decoding.
- Comment `--`/untermination, CDATA termination/truncation, `]]>` raw versus escaped, raw `<`/`&`, malformed tags/quotes/equals/separators, duplicate attributes/elements, mixed leaf children, mismatched case/nesting, multiple roots, trailing content, declaration in wrong position. Golden context vectors reject `&#32;` and `&#x20;` before/after the root, and predefined/numeric references in version, encoding and standalone (including `version="&#x31;.0"`, `encoding="UTF&#45;8"`, `standalone="&#121;es"`). Positive controls cover literal surrounding XML S, in-root container `&#32;`, and ordinary attribute references (e.g. `List="&#48;"` => List 0). Run all relevant two-chunk splits and independent Expat accept/reject comparisons.
- All DTD/entity declaration/external entity variants including file/http/system/public/parameter-entity forms, XInclude with/without namespaces, xmlns declarations, unknown elements/attributes, unsupported PI and encoding. No production import of any effectful module; test hostile external references against sentinel files and an isolated no-network process to ensure no access attempt can occur.
- List boundaries, absent/1/2/invalid Partial, sID six/seven/eight digit forms (including digits-only `123456` => 0x123456, `FFFFFF`, `1000000`, `FFFFFFFF`), widths 0/5/9, prefixes/overflow/nonhex; id/idMax absent/pair/half pair, (0,0), id=max, id>max, 65535,65536, long digits, signs/whitespace.
- Exact REC signatures/case and malformed lengths/colon/Unicode; literal EDID, bracketed full FormID, cache identities, known VMAD target without heuristic underscore rejection; bounded Fuz metadata and unknown nested nodes.
- Exact source offsets after BOM, multi-byte UTF-8, CRLF, references, comments and CDATA; entry indexes and first failing token/byte; EOF positions.
- Exact-limit and one-over source, entries, configured depth, field/entry text, name/reference length, metadata count and aggregate work/live. Depth tests cover the fixed grammar maximum five, a lower configured cap four, illegal sixth-level nesting, and configuration ceiling 64 versus 65; do not generate an allegedly valid depth-64 dialect fixture. Huge arithmetic cases are rejected without actually allocating huge data.
- Every owner creation/failure transition: retained partial text, pending UTF-8/CR/entity/comment, resource refusal, failed finish, duplicate calls, wrong source/range/allocation, and caller abandonment. Drop everything and require budget.finish success with no live/held leaks; consumable counters remain spent. Negative affine compilation tests have matching positive controls.

For every short fixture, test every two-chunk split and selected 1-byte/irregular multi-splits. Larger fixtures use 1,2,3,7,4095,4096,65535,65536 chunk schedules and exact boundaries inside UTF-8/entity/CRLF/delimiters. Typed output and diagnostics must be partition-independent; work equality compares parser visits while separately accounting for different test input-buffer initialization sizes. Empty resumes cannot loop forever or reset state.

### 7.2 Independent oracle, not a second copy of Bend grammar

Use Python stdlib Expat (`xml.parsers.expat`) only under `tools/xml/`. Record Python/Expat versions. Configure handlers to refuse DTD declarations and external entities, leave external resolution disabled, and independently reject unsupported namespaces/PI/encoding. Never enable entity substitution/network access for tests. Keep oracle security preconditions explicit; generic Expat acceptance alone is not dialect acceptance.

There are two distinct comparisons:

1. XML semantic overlap: for supported, well-formed constructs, compare Expat's decoded character sequences/attributes/element structure to Bend's event/text output. Include R1 EOF suffix/terminal-CR golden vectors and R2 legal/illegal reference-context vectors explicitly in the finite oracle inventory, not only in randomized coverage. This independently validates XML EOL, entity, CDATA and attribute normalization rather than echoing the Bend lexer.
2. Dialect acceptance: apply a small independent Python schema specification to Expat events, compare expected typed values/rejection category with Bend. Label valid-XML-but-unsupported-subset cases as deliberate differences (e.g. general PI or Unicode names). Do not require Expat's human error wording or exact error byte convention to match Bend; Bend diagnostic positions have their own checked golden vectors.

Fixed adversarial cases specify expected accept/reject and reason before running either engine. Seeded generated tests produce valid documents with random text/escaping/CDATA/attribute quotes/order/chunking, plus single-edit malformed mutations. Persist seed, raw bytes/hash, expected result, actual normalized result and first difference for replay. Keep raw input identity identical on both sides. Fail on unexplained acceptance differences; do not infer expected behavior from Bend. The actual producer fixture has its own manifest/status and must join this suite when available, without replacing synthetic provenance labels.

### 7.3 Evidence tooling

Implement isolated `tools/xml/{build,run,oracle,measure,summarize,test_evidence,lint}.py` and a finite case inventory/fixture manifest. Reuse locked runtime verification and observer code through explicit imports/wrappers where feasible, without changing core artifacts. Store build/results separately in `build/xml/` and `runs/xml/`; record source/compiler/generated-C/binary/input hashes, git head/dirty status, runtime limits, complete expected inventory, oracle counts/seeds, owner negative controls, and resource observations.

Evidence validator rejects missing/duplicate cases, stale source/binary/fixture hashes, incomplete oracle runs, failed/absent measurements and falsified producer status. Unit-test these rejection paths by mutating reports. A local development summary may say functional smoke passed with resource/producer not run/blocked. Only the complete gate may say all acceptance passed. Never reuse stale native binaries after an edit.

## 8. Execution and review sequence

1. Independent review of this plan; amend it and repeat review until no actionable findings remain. Keep review reports and exact reviewed plan hash.
2. Compile spike: public codec input bridge, one charged XML state wrapper, empty text/one text page, ownership-preserving error/drop. Confirm actual Bend syntax and API lint before broad lexer implementation. Any required core API change must be proposed/coordinated rather than bypassing lint.
3. Implement input/position/XML character rules, tokenizer and well-formed event parser with lexical/split tests.
4. Implement typed adapter/text ownership/numeric validation with schema and lifecycle tests. Keep entry yields provisional until EOF.
5. Implement oracle, randomized corpus, security/limit/diagnostic cases and evidence validator. Obtain real producer fixture in parallel if available; otherwise preserve the blocker explicitly.
6. Run all local applicable lint, type checks, native tests and oracle tests on final sources; run locked build/resource/complete acceptance through dedicated CI when local Docker is unavailable. A verified development toolchain cache may be reused read-only for smoke tests; this does not authorize modifying unrelated caches.
7. Independent implementation review with full source/artifacts, fix findings, rerun affected/full tests, repeat until no actionable findings. Evidence and missing acceptance are review findings too, not just code style.
8. Open PR in draft, with precise passed/failed/not-run/blocked status and reference Issue #5. Do not merge. Check CI/check-runs and status contexts on the exact pushed head. Mark ready only after the requested CI condition (no checks or all applicable checks passed) **and** truthful disclosure/resolution of any outstanding scope/acceptance blocker; absent checks are not evidence for unrun resource/producer requirements. If the real-export gate remains blocked, keep the PR draft pending the project owner's scope decision rather than falsely claim Issue #5 complete.

## 9. Definition of done and exclusions

Done means the bounded pure Bend parser, typed entries and full-document validation boundary are implemented, independent review is clear, final-code tests and locked resource evidence pass, and actual pinned-producer fixture acceptance is demonstrated with permitted provenance. Diagnostics preserve original source byte positions and entry identity. All hostile syntax and unsupported dialect paths fail without external IO. PR is created and made ready only under the user's stated CI condition; it is not merged.

Still excluded: UTF-16, general-purpose XML/namespaces/DTD/PI support, cache tuple matching, VMAD translation, deciding which Partial statuses to import, choosing repeated FO4 occurrences, Addon-to-plugin/language agreement, encoding destinations, plugin/table reads or writes, full planner, and transactional apply. Parsing a file or marking an entry unsupported must never be described as changing a plugin.
