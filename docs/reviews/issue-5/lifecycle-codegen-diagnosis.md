# Lifecycle compiler isolation

This is a diagnostic-only review, not an implementation or acceptance approval. The final lifecycle test is unchanged at SHA-256 `7a974187dc5acae8c4de91c60715d1c41559a9e4d651dba7562e44ce0606f772`. No production parser, assertion, budget, toolchain or test inventory was changed. Diagnostic copies live only in ignored `.cache/diagnosis/` and are not acceptance tests.

## Observed separation

- The old lifecycle source, adapted only for the mandatory `Diagnostic.source` field, also fails locally. The newly strengthened retained-scalar and EOF assertions are not necessary for the failure.
- Removing the retained-scalar traversal from reachability also fails. This deliberate diagnostic stub is not proposed as a test revision.
- A minimal `begin -> D.step -> from_step -> finished` entry succeeds. It reaches the parser, creates/returns the same `State` owner wrapper, and retains the final assertion helpers. The wrapper alone is not sufficient to trigger the failure.
- `retry_harness` separately succeeds. Sticky retries alone are not sufficient either.
- `inspect_phase` fails without the recursive lifecycle loop. `dispatch_entry` also fails without sticky retry or abandonment, narrowing the failing reachability to the retention branch.
- `retain_harness` alone succeeds. `retain_first`, which combines it with `from_step(Some{held}, checked, D.step(harness))`, fails. A helper extraction of that `Some` branch still fails.
- A separate presence-inspection/Bool dispatch preserves the whole `Maybe<Entry>` owner across `D.step`. This produced a fresh complete C file, but the compiler process subsequently exited -9. It is not recorded as a successful compiler run or an approved fix.

These results identify a small failing composition, not the exact internal compiler phase or an independently measured OOM. In particular, local -9 exits do not establish that a fixed 4 GiB build limit was exceeded. The separately observed child RSS values cluster near 2.51 GiB for failures, while successful calls also approach that range. An unchanged-source comparison in the fixed Docker build environment is recommended before a larger test representation rewrite.

## Local commands and measurements

All probes were serialized and used the unchanged pinned command:

`BEND_NO_TELEMETRY=1 .cache/bun/bun-linux-x64-baseline/bun --smol --no-env-file .cache/bend/bend2/main.ts .cache/diagnosis/NAME.bend -o .cache/diagnosis/NAME.c`

Python `subprocess.run` recorded the exit status and `resource.getrusage(RUSAGE_CHILDREN).ru_maxrss`; these are local diagnostic observations, not isolated locked resource results. None of the probe binaries was executed. The probe entries intentionally isolate reachability and do not claim a valid complete lifecycle test.

| Probe | Exit | Seconds | Child max RSS (KiB) | Emitted C bytes |
| --- | ---: | ---: | ---: | ---: |
| lifecycle-no-retained | -9 | 27.48 | 2512384 | none |
| lifecycle-old-updated | -9 | 94.29 | 2513524 | none |
| lifecycle-from-step-probe | 0 | 9.114 | 2510160 | 9909911 |
| lifecycle-retry-probe | 0 | 8.767 | 2232472 | 8442325 |
| lifecycle-inspect-probe | -9 | 19.214 | 2506580 | none |
| lifecycle-dispatch-entry-probe | -9 | 40.7 | 2511920 | none |
| lifecycle-retain-harness-probe | 0 | 2.456 | 777952 | 998789 |
| lifecycle-retain-first-probe | -9 | 59.413 | 2513664 | none |
| lifecycle-split-retain-probe | -9 | 93.111 | 2513180 | none |
| lifecycle-choice-retain-probe | -9 | 26.196 | 2507936 | 9968290 |

Exact source and generated-C hashes for each probe are recorded in ignored `.cache/diagnosis/lifecycle-probe-matrix.json`, SHA-256 `73533fd6ac00a19f46b6f03690428f4e036aea1286962b62f65749f93fb19d26`. The current-module snapshot imported by the minimal probes is `fc2f58a86735d52a9952dae38c07d72e5706811be44de0695e61d765fa96a435`.

## Next decision

Keep the current test unchanged pending a fixed-environment comparison. If a source workaround is needed, preserve all assertions, retention across subsequent parsing and abandonment, sticky retries, cleanup and shared-budget reuse. Holding the first entry outside the repeated reader loop is a reasonable representation alternative, but is not yet an implemented or verified fix. Splitting sticky tests alone is insufficient for the already-failing retention-only probe.
