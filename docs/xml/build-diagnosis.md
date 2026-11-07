# Fixed-compiler build diagnosis

2026-11-07, diagnostic snapshot
`35f60e094d18c18b9419fa7a2f1f02cb9df4e9a9` on
`wip/issue-5-codegen-repro`. No runtime/compiler/Base edits.

The repository's locked Bend 2.0.40 and Bun 1.3.2 were used. The full entrypoint
is `tests/xml/tokenizer_driver.bend`; the small entrypoint is
`tests/xml/lexer_text_shape.bend`. Both use a dynamic command-line input and the
same full lexer State/LexResult types. C generation uses the normal compiler CLI
with `--no-env-file`, `BEND_NO_TELEMETRY=1`, and `-o <name>.c`.

An independent comparison in the existing locked cloud Docker environment ran
small then full, with other heavy project work paused:

- Small: C generation succeeded in 17.9 seconds; build cgroup peak
  1,187,766,272 bytes.
- Full: no C emitted, exit -9 after 107.9 seconds; build cgroup peak
  4,294,967,296 bytes, `oom=1`, `oom_kill=1`, Docker `OOMKilled=true`.

This confirms a build-time memory failure for the full reachable lexer, not a
native parser RSS measurement. It does not establish that the compiler's layout
alone is the cause: the small probe returns the same full result shape.
Reachable leaf functions are being isolated before production restructuring.

The larger Reader import also exceeded local build memory with ordinary Bun,
but its complete typecheck passed using the pinned Bun's documented `--smol`
option after resolving reported source errors. This does not substitute for C
or native generation. The full lexer had also failed local C generation with
`--smol`; no cloud `--smol` comparison has been run.

## Source-only resolution

Independent isolation found pathological C generation for overlapping
multi-column numeric patterns with wide returned states. The lexer and schema
now use ordered boolean guards preserving first-match priority. Types, state
storage, ownership, vocabulary, budgets, compiler, and Base were unchanged.
Independent equivalence reviews checked each rewritten signature, predicate,
argument order and arm body; see `docs/reviews/issue-5/*codegen*`.

The full lexer emitted C in 2.60 seconds at 809,788 KiB local build peak RSS;
all 64 native lexical goldens passed. The full Reader emitted 9,334,367 bytes of
C in 10.57 seconds at 2,406,520 KiB local peak RSS, then compiled with Clang 19.
It passed 996 differential invocations (165 synthetic inputs and one cached
public real XML, six chunk schedules), plus 186 independent targeted schema
invocations. These are development observations, not locked resource acceptance.
The cached real file is not identified as a pinned-producer export.

Build harnesses use the pinned Bun's `--smol` flag and separate C emission from
Clang compilation. The latter uses exactly the pinned CLI's CPU flags:
`clang-19 -std=c11 -O3 FILE.c -lpthread -lm -o FILE` (`main.ts:508`).
This avoids retaining the JavaScript compiler heap during C optimization.
No alternate runtime, source patch, reduced optimization, or increased native
memory cap is used. The original reproduction branch remains unchanged.
