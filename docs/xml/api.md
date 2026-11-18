# Pure streaming XML API

Status: implementation in progress. This page describes the intended supported
API, not completion of Gate B. The locked full native build, differential suite,
resource certification, and pinned-producer export gate must pass before release.

## Trust and ownership

Import `xml/reader.bend` and `xml/types.bend`. Other XML modules and owned-value
constructors are implementation details enforced by `tools/xml/lint.py`; Bend
module visibility is not a security boundary. The parser contains no IO. The
host adapter owns files, snapshot identity, and the claim that a chunk contains
the bytes at the supplied `core/cursor.Range`. A range alone cannot authenticate
bytes supplied by a malicious caller.

- Start one shared `core/budget.Budget` for the entire operation. Charge source
  bytes once at acquisition, as with the core's trusted source adapter. Decoding,
  text storage and traversal consume cumulative work. Logical XML text is charged
  before storage, including metadata text that is validated then discarded.
- `begin(budget, rootRange, limits)` requires a source range starting at raw byte
  zero, and limits within the tested ceilings. Source/run identity, contiguous
  chunk ranges, allocation identity, length, and progress are checked.
- `Reader`, `ProvisionalEntry`, `ValidatedDocument`, byte owners, and the budget
  are affine. Never duplicate or reconstruct their constructors. Public fixed
  metadata is `Data` and may be copied.
- A caller may retain an entry while resuming the reader. Its memory remains
  charged to the same budget. The parser retains no collection of past entries.

## Feeding chunks

`resume(budget, reader, range, bytes)` returns the budget, reader, same byte
owner, next byte index within that chunk, and a result:

- `EntryReady{entry}` yields one provisional typed entry. Consume or retain it,
  then call resume again. Pending lexical events are drained before more bytes.
- `ReadMore{}` means that chunk has been drained. Drop its owner and supply the
  next positive-length contiguous chunk, at most 65,536 bytes.
- `ReadFailed{diagnostic}` is sticky. Every public diagnostic carries the root
  `SourceKey{run,origin}`, including `ReaderInitFailed`. Internal lexer/input
  helpers are source-neutral until the Reader attaches this trusted identity.
  Every later resume/finish reports the first error. Owners remain available for cleanup.

A chunk whose reported index equals its length can also be dropped immediately
at an entry boundary and replaced by the next contiguous chunk. Already decoded
lookahead is value-only; it contains no borrowed byte storage. Before exhaustion,
resuming with a different allocation, range, or length is rejected. Mutation of
the same allocation is forbidden by the trusted-adapter contract.

`finish(budget, reader)` marks source EOF and drains finite pending events,
finishes UTF-8 validation, and flushes a final literal CR. It returns:

- `FinishEntry{reader,entry}` if a pending provisional entry remains. Consume it
  and call finish again. Resume is no longer permitted after starting finish.
- `Finished{document}` only after the closing root and the complete input are
  validated. The reader is consumed; a second successful finish is not typable.
- `FinishFailed{reader,diagnostic}` preserves the failed reader for cleanup.

A provisional entry alone does not authorize planning or modifying a plugin.
The downstream planner must require the final validated-document token. A later
malformed suffix invalidates the document even after entries have been yielded.
No plugin is changed by any XML API.

## Typed data and text

Entry metadata preserves List, Partial (absent/1/2), optional sID value and its
hexadecimal width, exact case-sensitive RECORD/FIELD signatures, paired decimal
occurrence index and maximum index, EDID identity classification, Fuz metadata,
and source positions. sID is always hexadecimal, including digits-only input.
idMax is a maximum index, not a count. Partial selection belongs to the planner.
VMAD, pipe/cache tuples, and unsupported identities are explicitly marked and
must not be silently resolved as literal editor IDs.

`entry_metadata` and `document_metadata` return their owner unchanged along with
fixed metadata. `entry_next` and `document_next` traverse the sealed arena once
in encounter order, returning an optional Unicode scalar. Each FieldRef stores
its scalar start, length, decoded UTF-8 byte length, presence, and source span.
Empty text is present with length zero; missing required elements are errors.
Only EDID/Source/Dest and Addon/source-language/destination-language text is
stored. Numeric, REC and Fuz text is validated and charged without retaining
unneeded copies.

The parser applies XML 1.0 literal CR/CRLF normalization. Character references
are decoded exactly once; `&#13;` remains CR, and `&amp;lt;` becomes `&lt;`, not
`<`. Text is not trimmed. Literal attribute whitespace is normalized as XML
requires; whitespace supplied by a character reference remains that character.

Positions use zero-based raw byte offsets and one-based line and Unicode-scalar
columns. Spans are half-open. A UTF-8 BOM advances the byte offset but not the
column. Literal CRLF counts as one source newline. Reference syntax occupies its
literal source columns, even when its decoded value is a newline.

## Failure and cleanup

`drop`, `drop_entry`, and `drop_document` release all owned storage. Each returns
any residual owner and error if cleanup cannot complete, rather than abandoning
allocation accounting. Preserve that residual for a permitted retry. After all
owners are released, `core/budget.finish` must succeed with no live/held charges;
spent cumulative work is intentionally not refunded.

Diagnostic phases are 1 (input/UTF-8), 2 (XML syntax), 3 (closed schema), and 4
(reader/resource/lifecycle). The diagnostic includes the root SourceKey, raw position, current
entry number and start, expected/observed values when relevant, and an optional
core error. Numeric reason codes are not yet a stable external ABI.

## Closed dialect and limits

UTF-8 XML 1.0 only. BOM, optional declaration, either quote, self-closing
leaves, comments, CDATA, predefined entities and numeric references are supported.
DTD/entity declarations, external resolution, other PI targets, namespaces,
XInclude, unknown elements/attributes and other encodings are rejected.

Default ceilings are 64 MiB source, configured depth 64 (positive), 200,000
entries, 1 MiB aggregate decoded UTF-8 text per entry, 4 KiB Params text,
64-byte names/references, 4,096 Fuz paths and 4 KiB per path. The valid closed
schema is at most five elements deep; depth 64 does not imply support for an
arbitrary XML hierarchy. Addon is a basename, and its limit is 1 KiB; each
language is nonempty and at most 256 bytes. Limits can be lowered, not raised
beyond the certified ceilings.

Memory claims are not byte-count guesses: wrapper/page charges require generated
layout inspection and dedicated locked-runtime cgroup measurements. Until that
suite completes, the current charges remain provisional.
