# Issue #5 lexer code-generation diagnosis

Date: 2026-11-07. This is a compiler-viability investigation, not final parser or resource acceptance.

## Result

The full dynamic lexer compiles after a source-only control-flow rewrite: 20 overlapping numeric/Boolean multi-column matches use ordered Boolean guards, and `close_end` checks its nested context/name conditions in separate helpers. State types, the 26-mode representation, fixed event slots, API, ownership, resource charges, and parser limits are unchanged.

The successful diagnostic C generation used the unmodified pinned Bend 2.0.40 compiler and pinned Bun with `--smol --no-env-file`. It completed in 2.604 seconds with child peak RSS 809,788 KiB and emitted 801,091 bytes of C. Native compilation through that compiler with the shared hash-verified Clang 19 extraction succeeded. All 64 lexical goldens passed against the resulting executable.

No compiler/cache source or generated runtime was changed. The production-path candidate was applied by the implementer only after source and patch hashes were checked. This report records the investigated snapshot, before any subsequent semantic changes.

## Evidence and reduction

The implementer separately reported a cloud reproduction of the original full-lexer snapshot `35f60e0`: exit -9 after 107.9 seconds at a 4 GiB build limit, cgroup `oom=1` and `oom_kill=1`, Docker `OOMKilled=true`, and no C output. That establishes OOM for that cloud run. The local -9 results below are recorded as process kills; their exact kill cause was not independently measured with cgroup counters.

Local probes used one compiler process at a time. Peak RSS is the child `ru_maxrss` value in KiB; elapsed times are wall time. The probes and logs were kept in ignored diagnostic cache, outside the finite acceptance-test inventory.

| Probe | Result | Seconds | Peak RSS KiB | C bytes |
| --- | --- | ---: | ---: | ---: |
| Original direct `open_name` | -9, no C | 14.869 | 2,283,064 | — |
| Original direct `tag_input` | success | 5.131 | 1,362,072 | 173,232 |
| Original direct `attr_name` | success | 6.050 | 2,045,736 | 345,369 |
| Dynamic `Names.finish` alone | success | 0.680 | 236,020 | 90,750 |
| Original direct `open_delimiter` | -9, no C | 8.141 | 1,843,500 | — |
| Direct `emit` with two events | success | 4.049 | 1,193,208 | 96,143 |
| `open_delimiter` with separated ID guard/value switch | success | 3.514 | 1,009,988 | 134,963 |
| `open_name` with only that delimiter fix | success | 3.663 | 1,288,628 | 198,191 |
| Original direct `finish` | success | 4.230 | 1,208,328 | 109,088 |
| Original direct `close_end` | -9, no C | 25.872 | 2,636,592 | — |
| `close_end` with separated depth/name checks | success | 2.742 | 892,868 | 114,370 |
| Full dynamic lexer with final 21-function rewrite | success | 2.604 | 809,788 | 801,091 |

These results isolate failing leaf paths without requiring the full mode dispatch, and show that neither the fixed two-event result nor `Names.finish` alone is inherently unbuildable. Changing `Names.select` to a tail-recursive accumulator did not fix `open_name`; no vocabulary rewrite was adopted. Fixing only `open_delimiter`, or only `open_delimiter` plus `close_end`, did not make the full lexer build. Broad numeric-guard variants that still retained the original nested `close_end` also failed.

The supported diagnosis is expansion associated with overlapping numeric patterns in the compiler's compilation path. The compiler's pattern lowering recursively specializes constructor columns and wildcard rows; U32 patterns add substantial structure. The controlled source rewrites remove that problematic shape while preserving behavior. The exact internal phase responsible for every allocation was not instrumented, and the final patch is a demonstrated sufficient set, not a proof that every changed function individually caused failure.

## Rewrite and semantic priority

Changed functions:

`open_delimiter`, `attr_selected`, `attr_equals`, `attr_quote`, `close_space`, `comment`, `cdata_prefix`, `cdata`, `reference_body`, `reference_valid`, `decl_xml`, `decl_space`, `decl_allowed`, `decl_selected`, `decl_equals`, `decl_quote`, `decl_char`, `decl_variant`, `decl_length`, `decl_after`, and `close_end`.

For the first 20 functions, each nonfinal original arm becomes an ordered Boolean guard. A true guard executes the original arm body; false advances to the next arm. Numeric equality, Boolean predicates, and wildcard omission preserve the original conditions. The original final body is reached only after earlier arms fail. No scalar is reread, no payload is copied, and the comparisons remain bounded metadata operations.

Examples of preserved priority:

- `open_delimiter` rejects name ID zero before handling `>` or `/`.
- `reference_valid` rejects an exceeded token limit before recognizing a semicolon.
- `decl_space` handles whitespace before stage-specific `?` checks.
- `close_end` first rejects depth zero with the original context diagnostic, then rejects an unknown name, then decrements a positive depth and emits the original close event. The depth-zero diagnostic therefore still wins when both depth and name are zero.

A source-level priority audit checked 328 representative input combinations across the 20 mechanically rewritten functions, using each numeric pattern constant, zero, U32 maximum, and both Boolean values as applicable. All selections agreed. This audit checks representative branch priority and unchanged action bodies; it is not exhaustive runtime validation. `close_end` was reviewed separately as described above.

## Exact identities

| Artifact | SHA-256 |
| --- | --- |
| Original production `xml/tokenizer.bend` | `b76b35e93a37ca673730de8a09e3b10533419b1ed32cddfb158c797ad238227e` |
| Applied production-path candidate | `df557a0a10228956272e79a91b09af3745cc3fda8eed5f896c142bf99574a965` |
| Source patch | `ad2eb01b8d4909a1932a5011d62aa475bb6cccdc723574060f3d48e6f297bfd5` |
| Diagnostic lexer copy, adjusted relative imports | `3a8a05aa1597a4336d79dc87764f765492194414057380580e8c2d6d4b218f52` |
| Diagnostic dynamic driver | `57685800cf7346879eda0748b1373ac8990ea2326b00c919c9b2b343c3a48aa0` |
| Generated diagnostic C | `107f4b3781d5ed414e84ff8694869b1f166d10188eedf23a2ef15d78fcda0205` |
| Clang 19 diagnostic executable | `581c80d40077e5acd0f528733f3111f6d1d66ec2a990a5157d351c2ccf7c58bc` |
| 64-case native result JSON | `9ee5a2907e30ba49e374d04c6c41f81e5a0289e1aa0605341d91ab4ed6b42258` |
| Priority-audit JSON | `7ab46a693e0f8980d794d3336a6ad999ec3df42a04f57ea279a5f69aad6809b3` |

The patch and candidate were saved as `.cache/diagnosis/tokenizer-codegen.patch` and `.cache/diagnosis/tokenizer-proposed.bend`. Other local evidence is in that same ignored directory. The repository diff and this report preserve the change and its identities; cache artifacts are not acceptance-manifest inputs.

## Validation limits

- Native golden comparison used exact UTF-8 stdout bytes. An initial Python text-mode comparison falsely flagged two CR cases because universal-newline translation changed CR to LF; byte comparison passed all 64 cases.
- A preliminary GCC 14 attempt rejected the unchanged generated C's Clang `musttail` statement attribute. It produced no executable and is not successful evidence. The successful executable used the shared Clang 19 extraction, with `CC` and its library path set, through the pinned Bend compiler. No attribute-stripping workaround was used.
- These are local lexical smoke results, not locked-container resource measurements or full XML-schema acceptance. Full Reader compilation/execution, typed differential tests, partition/resource/ownership gates, and real-producer validation remain separate.
- The compiler workaround intentionally makes no semantic change. The planned correction to point an unterminated reference's EOF diagnostic at its opening ampersand is separate and is not included in the candidate hash above.

No overall implementation approval is implied.
