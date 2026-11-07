# Issue #2 scoped acceptance-test review and fixes

Status: complete for the delegated scope; all three final tests passed check-only, C emission, native compilation, and native execution, with exact stdout matching. This is a bounded test review, not full Issue #2 acceptance or resource calibration.

## Scope and initial findings

Read the approved revision 2 plan (`docs/implementation/issue-2-3-plan.md`) and concrete contract addendum (`docs/implementation/issue-2-contract-addendum.md`). No applicable AGENTS.md was present at `/`, `/workspace`, or in this checkout; `/workspace/.agents` contained no files. The managed cloud runtime skill and Docker reference were read, and environment readiness/local Docker socket were checked.

Existing tests checked capacity/byte helper results and selected reservation cases, but did not establish the following public API behavior:

1. Logical length versus rounded allocation capacity; invalid-byte rejection and failed access/mutation preservation of the original owner/content and budget.
2. `copy_range` independent allocation while the source stays live, normative read+write costs, and both owners' recovery at each partial failure boundary.
3. `hash/hex.format` exact 32 raw bytes to 64 lowercase ASCII bytes, non-32 preflight rejection, and partial formatting failures.
4. Independent exhaustion/held competition and oversettlement across all six budget dimensions, atomic rejection, and MAX/metadata-overflow preservation.

These gaps were reported to the parent before implementation. No implementation bug was found in the exercised cases. Core/hash/Issue #1/upstream sources were not edited. No commit, push, or PR was made.

## Added deliverables

- `tests/core/buffers.bend`: 0/1/3/65535/65536 logical sizes, power-of-two capacity, invalid indices including MAX, 65537 preflight rejection with no allocation/work headroom, allocation-work rejection, invalid put/append bytes 256/MAX, clear/reuse, get/put/append work rejection, copy range bounds/overflow-sized request, separate source/destination identities and live charges, destination mutation isolation, six partial-copy failure edges, and allocation rejection preserving source.
- `tests/core/hex_format.bend`: literal all-nibble vector (including 00/ff), all 64 output characters and exact work=224 before verification / 288 after it; lengths 0/1/31/33 rejected before destination allocation or byte visits; four partial formatting boundaries with both owners, original source and exact partial output/work checked.
- `tests/core/budget_edges.bend`: five consumable dimensions independently checked at exact limit/+1 with held competition; failed oversettlement returns the same usable ticket and preserves counters; live dimension exact/+1 and cancel; live MAX+4096 overflow leaves an existing ticket intact; atomic multidimension rejection; all six profile MAX requests rejected with exact error context.
- `tests/core/lib/buffer_assert.bend`: assertions only, using public ownership operations and budget inspection. No raw storage access or production mutation was introduced.

For deterministic work failures, tests reserve verification work before exercising the operation. After checking the failure and unchanged used/held counters, they cancel the reservation and read the original owners using the same budget. This verifies actual content and lifecycle after failure without replacing the budget or weakening the limit.

Copy partial cases have setup work 4 initialized source cells + 3 fixture writes + 4 initialized destination cells = 11. Limits 11 through 16 stop before each of the six read/write visits. The source and all three destination cells are then read back; final work equals the failure edge + 6, and each owner is released separately. No successful visits are refunded.

## Validation environment

Private snapshot: `/workspace/issue2-test-build` (all core/hash plus tests). Shared `bend-issue2-build` container was not used. Core/hash snapshot equality against the working checkout was checked.

Fixed image: `sha256:b448b89eed11f6ea1b172a5f1280f8ec76e3932bb52ad01b87af487584a7ac7c` (`bend-xt-runtime:issue1`). Explicit `unix:///var/run/docker.sock`; DOCKER_HOST/CONTEXT/TLS/TLS_VERIFY/CERT_PATH selectors unset. Containers ran network=none, UID:GID=1000:1000, cap-drop=ALL, one CPU, memory=1GiB, memory-swap=1GiB (zero additional swap).

Each test is checked, emitted as C, compiled natively, and run with `+RTS --threads 1 --gpu off -RTS`. Compiler command: `/opt/bun/bun-linux-x64-baseline/bun --no-env-file /opt/bend/bend2/main.ts /work/tests/core/NAME.bend --check-only` or `-o /work/build/NAME[.c]`.

Build runner retained at `/tmp/issue2-run-tests.py`. Per-test JSON logs record complete argv, exit code, stdout/stderr, source snapshot SHA-256 values, generated C SHA-256, and native binary SHA-256. Exact ordered stdout expectations are at `/workspace/issue2-test-build/build/expected_stdout.json`.

API boundary lint passed. These tests assert the documented candidate charge constants and logical byte-work; they do not calibrate those constants against RSS/cgroup usage, substitute for the full independent review, or satisfy the remaining measurement/CI gates.

## Final evidence

| Test | check / emit / build / run exits | stdout lines | final marker |
| --- | --- | --- | --- |
| buffers | 0 / 0 / 0 / 0 | 17 | `buffers-ok` |
| hex_format | 0 / 0 / 0 / 0 | 10 | `hex-format-ok` |
| budget_edges | 0 / 0 / 0 / 0 | 15 | `budget-edges-ok` |

All 42 stdout lines match the ordered expectations exactly (39 case markers plus 3 final markers). Final source snapshot and generated artifacts:

| Artifact | SHA-256 |
| --- | --- |
| `/workspace/bend-xt-import-issue-2/tests/core/buffers.bend` | `b35472f5056ada259f480a3eba1439bac97b53763d37bc61dce8fba620d3333f` |
| `/workspace/bend-xt-import-issue-2/tests/core/hex_format.bend` | `b9a7481547af242e4db7bbd5549c34e509fe6a4202a1c373ab2e83fe0ab8e0d1` |
| `/workspace/bend-xt-import-issue-2/tests/core/budget_edges.bend` | `a4c4551f33770cebe5bf68398556d5eca88346523327f6787da357238bc278be` |
| `/workspace/bend-xt-import-issue-2/tests/core/lib/buffer_assert.bend` | `f9307ab2f9913336a928cfcdb4855d942df976b241eb19849830e56d74af4a82` |
| `/workspace/issue2-test-build/build/buffers.c` | `552099e840107fe3991198276976a6370fc8ed41062df2e7e89529d6b95c0491` |
| `/workspace/issue2-test-build/build/buffers` | `a2311909f143cbc7347563b33dd64d5f6d23f140e4963beba27c5df360408458` |
| `/workspace/issue2-test-build/build/buffers.log.json` | `f5e786ef17c51ddb6f94ccaf2f251be0bbbf977c9d59afcb68811a3086f4be43` |
| `/workspace/issue2-test-build/build/hex_format.c` | `b0bce35ef06c6e716271e9020c8f4e955fd484e0abd28112fb2baaf7fb8ac2b3` |
| `/workspace/issue2-test-build/build/hex_format` | `ce51290cf9994cba7e4c935ed8bbe292fbcc832c19814eb41d93543db53423be` |
| `/workspace/issue2-test-build/build/hex_format.log.json` | `f91c9e34eafafdb905013277234632d1245a69dd6edcda03a3f1117294e1c04c` |
| `/workspace/issue2-test-build/build/budget_edges.c` | `417f0f77345f74d6d251c5e9d84455c11a79ecad49728a46353769053c5b582f` |
| `/workspace/issue2-test-build/build/budget_edges` | `a5a2160737408281d4fb4ba846b733aa83715a91bc5ee73106d0fbd3c482fb7e` |
| `/workspace/issue2-test-build/build/budget_edges.log.json` | `b2bbd45435ad243e0fea12c719c0770599a6ef3168e5cd72962817ff36869f56` |
| `/workspace/issue2-test-build/build/expected_stdout.json` | `9fbfe606f748c45bc0ad6ede59e20135b4ad6d009a14eebc8a7312cc47358576` |

No remaining blocker within this delegated test scope. Full-suite integration, exact-head CI, independent whole-implementation review, and resource/layout calibration remain with the parent task. No claim of overall Issue #2 completion is made.
