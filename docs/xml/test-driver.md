# XML test driver wire format

`tests/xml/driver.bend` accepts hex-encoded source bytes and a decimal chunk size
from 1 through 131072. Values 1..65536 use a constant chunk size. Values
65537..131072 encode an initial chunk of `value - 65536` bytes and subsequent
chunks of 65536 bytes. For a fixture shorter than 65536 bytes, passing
`65536 + cut` exercises the exact two-chunk split at raw byte `cut`, for every
interior cut from 1 to length minus 1. The original mode value is preserved
across allocations; this changes no parser behavior.

This is a test-only pure input adapter. Its argv transport
is for small corpus cases, not a claim that 64 MiB fits an operating-system argv.
The driver charges source bytes once, constructs bounded `OwnedBytes`, consumes
and releases every provisional entry, and finalizes the reader at EOF. It prints
`balanced` only after all owners are released and `Budget.finish` succeeds.

Accepted output is `ok HASH COUNT LOGICAL WORK balanced`. Rejected input produces
`error PHASE REASON ENTRY BYTE LINE COLUMN LOGICAL WORK balanced`. LOGICAL and
WORK are the final cumulative values returned by `Budget.finish`, not estimates. Harness, cleanup, ownership,
or fuel failures instead exit 70. Usage failures exit 64. Diagnostics use raw
source byte offsets and one-based line/scalar-column positions.

The assertion checksum starts at 2166136261. Each value is a U32, and
`mix(v) = ((hash * 16777619) modulo 2^32) XOR v`. This is not a cryptographic hash.
All fields below are mixed in the listed order:

1. For each provisional entry, in XML order:
   - 0xE001, entry number, List, Partial (absent 0, incomplete 1, locked 2).
   - SID: absent 0 only; present 1, value, original hexadecimal digit width.
   - REC record and field, each packed as four ASCII bytes, big-endian.
   - Occurrence: absent 0 only; present 1, index, maxIndex.
   - Identity: literal 0 only; bracket 1, FormID value; unsupported 2, reason.
   - EDID, Source, Dest field references, each as present 0/1, scalar start,
     scalar length, UTF-8 byte length. Spans are omitted.
   - Fuz: present 0/1, responseId, count. All three are always present, with
     zeros when FuzInfo is absent.
   - 0xE002, every retained entry arena scalar, 0xE003.
2. Once and only once EOF validates the document:
   - 0xD001, entry count.
   - Addon, source language, destination language field references, each in
     the same four-number format above.
   - 0xD002, every retained Params arena scalar, 0xD003.

Arena scalars are in actual XML child order, not canonical field order. The
entry arena retains EDID, Source, Dest only. The Params arena retains Addon,
Source, Dest only. REC, Version, attribute values, and Fuz text are not retained
arena text. Source/run identifiers and all spans are excluded from the checksum;
source-position assertions are separate golden tests. `tools/xml/digest.py`
computes the same serialization from the independent Expat-backed oracle.

## Limit overrides and test-only failures

The optional `FIELD VALUE` argument pair changes one limit for that invocation:
`XML_DRIVER HEX_BYTES CHUNK_SIZE [FIELD VALUE]`. The two-argument form retains
all defaults. Both arguments are unsigned decimal, and VALUE is bounded by U32.
A parser limit above its supported ceiling is passed to `Reader.begin`, which
must reject it. A budget outside the core profile may fail `Budget.start` and
exit 70; resource tests must use a budget at least large enough for its wrapper.

| FIELD | Limit |
| --- | --- |
| 0 | sourceBytes |
| 1 | depth |
| 2 | entries |
| 3 | aggregate decoded UTF-8 entryTextBytes |
| 4 | aggregate decoded UTF-8 paramsTextBytes |
| 5 | nameBytes |
| 6 | referenceBytes, including `&` and `;` |
| 7 | fuzCount |
| 8 | decoded UTF-8 fuzTextBytes per Fuz |
| 9 | cumulative logical budget |
| 10 | cumulative work budget |
| 11 | simultaneous live budget |

Limits are threaded only through startup; they add no persistent harness state.
The aggregate entry text includes numeric attribute values, REC, and Fuz text
that the parser validates but does not retain. Params text includes Version.
Comments and structural whitespace are not logical field text.

Phase 5 is **test-adapter-only**, never a production parser phase. Its reasons
identify core refusal during (1) entry text iteration, (2) document text iteration,
(3) chunk allocation, (4) chunk writing, or (5) initial source-byte charging.
These paths retain and release the affected owners, then report the core refusal
only after `Budget.finish` proves balance. Unknown positions and entry numbers
are zero/initial values. A cleanup failure still exits 70 with a residual owner;
it must never print `balanced`.

WORK includes the test adapter's writes and consumer traversal. To test its
boundary, run the same fixture and chunk mode normally, rerun with field 10 set
to the returned WORK (must accept), and rerun at WORK-1 (must refuse and remain
balanced). The exact refusal may occur in phase 5 after Reader accepted the XML;
this tests the shared budget, not a claim that parsing rejected the document.
LOGICAL is additionally checked against independent decoded-field byte counts.

`tests/xml/limit-cases.json` is a project-authored literal expectation manifest,
independent of the Expat oracle's acceptance decisions. Its small fixtures and
boundary counts are reviewable directly. Generated-layout/live calibration and
large streaming resource certification remain separate acceptance gates.

## Bounded generated-source resource adapter

`tests/xml/stream.bend` takes `TOTAL_BYTES PAYLOAD_BYTES UTF8_MODE` as decimal
arguments. It never builds a source String, byte list, complete source file, or
unbounded source buffer. A fixed arithmetic profile generates one byte at its
absolute offset into the current OwnedBytes chunk (at most 65536 bytes). Only
small fixed XML fragments use numeric byte lookup tables. It shares the normal
driver's read/yield/drop/EOF/final-budget lifecycle, replacing only chunk fill.

The source consists of:

- A 118-byte root/Params/Content prefix. Params is Addon `A.esp`, Source `en`,
  Dest `ja`, Version `2`, in that order.
- Repeated entries with a 59-byte opening fragment:
  `<String List="0"><EDID>A</EDID><REC>WEAP:FULL</REC><Source>`.
- PAYLOAD_BYTES bytes of a repeated unit: mode 1 is `a` (U+0061, UTF-8 61),
  mode 3 is `日` (U+65E5, E6 97 A5), mode 4 is `😀` (U+1F600, F0 9F 98 80).
- A 25-byte closing fragment `</Source><Dest/></String>` per entry.
- The 29-byte suffix `</Content></SSTXMLRessources>` and literal ASCII spaces
  until exactly TOTAL_BYTES bytes have been generated.

Bounds: 147 <= TOTAL_BYTES <= 67108864; 0 <= PAYLOAD_BYTES <= 1048565;
mode must be 1, 3, or 4; PAYLOAD_BYTES must be divisible by the selected width.
No silent rounding occurs. Inputs outside those bounds exit 64 before allocating
the shared budget. A valid small total can contain zero entries and only padding.

Independent expected-profile arithmetic, with T=TOTAL_BYTES, P=PAYLOAD_BYTES,
W=UTF8_MODE:

- Entry byte size S = 84 + P.
- Entry count N = min(200000, floor((T - 147) / S)).
- Suffix starts at raw byte 118 + N*S.
- Trailing padding length = T - 147 - N*S.
- Each Source contains P/W Unicode scalars and P UTF-8 bytes.
- Each entry's logical text charge is 11 + P: List 1, EDID 1, REC 9,
  Source P, empty Dest 0. Params contributes 10 bytes including Version.
- Final logical charge = 10 + N*(11 + P).

For checksum expectations, each entry number is 1..N, List 0, Partial absent,
SID absent, REC `WEAP:FULL`, occurrence absent, identity literal, Fuz absent.
EDID's field reference is (1,0,1,1); Source is (1,1,P/W,P); Dest is
(1,1+P/W,0,0). The entry scalar arena is U+0041 followed by P/W copies of the
unit scalar. Params references are (1,0,5,5), (1,5,2,2), (1,7,2,2), and its
scalar arena is `A.espenja`. The checksum framing is the same as the small driver.
WORK is measured from the shared budget; it includes generation writes,
allocation, parsing and consumer traversal, not a guessed function of T alone.

Suggested resource profiles are 1/16/64 MiB with payloads 4096 (ASCII or
non-BMP) and 4095 (Japanese), payloads just below/at/above 4096 arena scalars
including EDID, and a 2 MiB source containing an ASCII payload of 1048565 bytes
(one entry at the exact aggregate 1 MiB entry-text ceiling). Retaining previous
entries is a separate lifecycle/resource scenario; this adapter drops each one.
These are test inputs, not locked-runtime resource certification by themselves.
