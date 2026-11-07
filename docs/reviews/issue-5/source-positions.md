# Issue #5 source-position tests and reference EOF correction

## Scope and contract

This change implements an independent native assertion probe for the original-byte metadata that the existing typed-value digest intentionally omits. The approved plan's Input, Locations and XML Semantics sections require original half-open byte spans, one-based source line/scalar columns, CRLF as one newline, a BOM occupying bytes but no column, and malformed references diagnosed at their opening ampersand.

Production change: one added `MReference` arm in `xml/tokenizer.bend:finish`. Unexpected EOF keeps phase 2 / reason 6 / expected 0 / observed 0, but uses the reference's saved opening position instead of the end-of-file position. Existing broken-state diagnostics still take precedence. No schema, input, reader, text, ownership, storage, limits or runtime changes were made for this task.

## New independent assertions

- `tests/xml/positions.bend` reuses the existing test-only driver's affine source adapter and cleanup operations, but intercepts Entry and Params metadata before their digest handling. It directly compares all exposed Entry spans, EDID/Source/Dest field spans, FuzInfo spans, Params/container/Addon/language spans, source keys and entry numbers against literal coordinates. Field scalar ranges and canonical byte lengths are also checked.
- `tests/xml/positions-golden.json` contains two project-authored synthetic documents with literal source-coordinate tables and twelve reference-EOF diagnostic vectors. These are not producer exports. Expected coordinates were derived from the authored source bytes, not sampled from the Bend parser.
- `tools/xml/positions.py` supplies the fixtures, validates native framing and expected diagnostics, checks partition-invariant semantic/logical results, and records each run and the binary/fixture/manifest/probe/runner hashes. Work is recorded but not asserted to be partition invariant.
- Valid documents cover BOM and no BOM; two entries; Content before Params; CRLF, lone CR and final epilog CR; Japanese and supplementary-plane UTF-8; numeric/predefined references; comments; CDATA; reordered fields; self-closing/explicit-empty leaves; present/absent Fuz metadata. References that produce CR/LF do not increment source line numbers.
- EOF vectors cover `&`, `&amp`, `&#`, `&#x`, decimal and hexadecimal digits in content and attributes. A separate terminal-CR vector preserves the existing malformed-reference reason 4 while requiring the same ampersand position.

## Actual local results

All proofs check for `tests/xml/positions.bend` with pinned, unmodified Bun/Bend and `--smol --no-env-file --check-only`.

C generation succeeded in 8.70 seconds, child max RSS 2,633,936 KiB, producing 9,624,812 bytes. The generated C was compiled unchanged with the hash-verified shared Clang 19 extraction and the compiler's CPU flags (`-std=c11 -O3 -lpthread -lm`). This is local development evidence, not Docker/cgroup acceptance.

Command:

```
BEND_NO_TELEMETRY=1 python3 tools/xml/positions.py --binary build/xml/positions --output .cache/diagnosis/positions-local.json --all-boundaries
```

Result: **14 fixtures, 2,939 native runs passed**, comprising 849 metadata assertions and 2,090 reference diagnostics. Each fixture ran at chunk sizes 1, 2, 3, 7, 31 and 65536 and every exact two-chunk cut. All runs released owners and finished their budgets.

Three additional assertion-sensitivity controls also passed: removing the BOM, replacing `A&#x42;C` with the same decoded `ABC`, and inserting whitespace only before Params all produced the expected test-only assertion failure with balanced cleanup. The last control specifically exercises the Params assertion path. These mutations are not parser rejection expectations; they prove that stale literal coordinates are detected.

`python3 tools/xml/lint.py` passed.

## Exact hashes

| Artifact | SHA-256 |
| --- | --- |
| positions.bend | a43bf5501d9bfcc4aa8120eee355b2fc167ce838618fd5da4280821e1d2e8554 |
| positions-golden.json | bba319c3716fb1da85390ca992bc1b32d7845e46207acdce6e42f53d0944a396 |
| positions.py | 7ff35fc8229cdcaedea776ddd2105ed753e2db71ce236e4ed85f4c7349bd6123 |
| tokenizer.bend after EOF fix | 0c108bbe397372ee2413a19d9ed50f0797ba8a404307132b115a18a9ff73ce4a |
| reader.bend at build | ab061f578d109bb30c221ceebfec9f243a8027b818bb8c28ee33ff4e8eb40e03 |
| input.bend at build | 4796d5ed4a8a6d8c75f60b01e0a8ee2a413b5f8f3738e94fc513ad004d2ad83f |
| xtranslator_v2.bend at build | 386b3a16ad3f1b84b53b26c0e4b361c60dafd6bdce65c3815a367493e7b1fbdb |
| build/xml/positions.c | 5b018b12c3982d48aff2f42c7faa89af8ea04d1496f116267bacee6313293a05 |
| build/xml/positions | 484f2b5fe35c91434555375a3ade0d61a2aa9b59084acc63e5059f8ba7d4fe91 |
| positions-local.json | 1c4d7ac2e2b36cbe5accf0de1a878efc4c662d9bb69dc4d4f7f40f9eb4cdde91 |
| positions-controls.json | 72cc299861d8849693f347992b3c23b16cdc06f141102a598b7feec3fb06538c |

## Limits of this result

This closes the known missing source-span assertion coverage for the listed fixtures; it is not overall implementation approval. Locked runtime/resource acceptance and the actual identified-producer fixture gate remain separate. Independent review of this production EOF fix and the new tests is still required.

## Final-source extension: diagnostic identity, entry start and live neighbors

After the source review found missing diagnostic source identity and a zero-byte entry-wrapper refusal position, the implementer fixed `xml/types.bend`, `xml/xtranslator_v2.bend` and `xml/reader.bend`. Those production fixes were independently reviewed. The probe now directly checks `Diagnostic.source` and `Diagnostic.entryStart` before reporting; these fields are intentionally not inferred from the existing driver's text protocol.

The final inventory has **21 named fixtures / 2,946 native runs**, all passed. The original exhaustive 2,939 runs remain. Seven additional fixed chunk-7 neighbors cover:

- Base fixture live cap 552959: phase 4 / reason 6 / entry 1 at byte 201, line 1, column 202, the opening `<` of `</String>`; entry start byte 118, line 1, column 119. Source is run 1 / origin 42.
- Cap 552960: successful typed result, count 1, digest 19054367 and logical bytes 23.
- A separate run 7 / origin 43 for ordinary reference EOF and schema rejection.
- That same source for invalid-depth configuration, initial reader-claim refusal and input-initialization run mismatch. The mismatch deliberately uses budget run 1 with root run 7; cleanup still balances.

The test adapter overrides only its own resume range for the second source. Shared driver framing and production state/storage remain unchanged. Three successful build stages were repeated for final source: check-only, pinned Bend C generation (8.71 seconds, max RSS 2,776,616 KiB) and unchanged C compilation with shared Clang 19. Earlier hashes above identify the initial validation, not this final extension.

Final-source hashes:

| Artifact | SHA-256 |
| --- | --- |
| positions.bend | 48ec57d77bc68fe2545460de9623f638ffbee359d6c123e30abc12ed0d2e309a |
| positions-golden.json | 422b9fd2dbb2c0b6221a39399792d6de9817f8820ad56117bc9314d3399c98b8 |
| positions.py | bded1b1b1c4ff5b59af0c784f68b25967d36c235f5bf7e2477faa8223997b07d |
| build/xml/positions.c | 3329dca57731bcadb560ac382a02e82fd7ec3d1ff51afbdadd0cde0b857d9944 |
| build/xml/positions | 5f27e31321e9a071c4521a232837a43b14a57ad54868babc4dfe81869295a24f |
| positions-final-local.json | cd25542a11dd0bf3f3c3f7e4402b198fa70bd6f48cbf93b5c3a9a559cec2fc03 |

The production source identities are recorded in `implementation-02.md`. Locked CI/resource measurements and identified-producer acceptance are still separate gates.
