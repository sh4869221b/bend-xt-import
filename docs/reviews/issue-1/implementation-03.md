# Issue #1 independent implementation review 03

- Date: 2026-11-06.
- Reviewer: `/root/issue1_impl_review_3`, fresh independent review assigned for the requested Astra review cycle.
- Base commit: `5b4643c6714e025bc248fbdbe711d54f747d8fc6`.
- Scope: Issue #1 runtime experiments, complete current tools/probes, lock, CI, design/plan and reporting documentation. No production importer or publication implementation.

## Disposition

**Two actionable findings were identified and corrected during this review. No remaining actionable static findings were found after checking the corrections.** This is not a native-evidence acceptance review. The coordinator was rebuilding and preparing final native execution; this report does not certify that pending evidence. Both findings were sent promptly so the coordinator could correct the source before another full run. Changes to runtime inputs invalidate the current build and require a fresh build and complete execution before sealing evidence.

## F01 — High: resource suite cannot complete because the inventory function is shadowed

Locations at the reviewed checkpoint: `tools/runtime/measure.py:67,129`.

`main()` assigns the shape stdout string to `expected`. That makes `expected` a local variable throughout `main()`, shadowing the imported `case_spec.expected` function. The final inventory check calls `expected('resource', args.group)`. An `all` or `shapes` run reaches this with a string and raises `TypeError`; `budget`, `stress` and `stream` reach it with an unbound local and raise `UnboundLocalError`. Consequently no resource group can finish with `complete=True`, and the CI resource step always fails even if every native case succeeds.

The AST check found the local assignment at line 67 and the function call at line 129. This is a deterministic Python scope error; it does not require native execution to demonstrate.

Required correction: rename the shape stdout variable or alias the imported inventory helper. Add a lightweight orchestration check that exercises the actual end-of-suite sealing path for every group; tests of `case_spec.validate` alone cannot catch this integration error. Rebuild and rerun the corrected source.

## F02 — Medium: invalidate prior suite success before starting a new attempt

Locations: `tools/runtime/run_probes.py:24–31,185` and `tools/runtime/measure.py:27–34,135`.

Each runner writes its suite manifest only in `finally`. That protects ordinary exceptions and `KeyboardInterrupt`, but not SIGKILL, host loss, or abrupt interpreter exit. Starting a new run while a previous complete manifest exists, then hard-terminating the new runner, leaves the old complete manifest available. With unchanged inputs/build it remains acceptable to the summary. This misses the explicit start-invalidation requirement from implementation review 02 and can present prior success as the outcome of the interrupted attempt.

Lightweight reproduction: for each module, create an isolated temporary root with a pre-existing complete suite JSON, replace `inputs` with a fixture snapshot, and stub `run_probe` to call `os._exit(99)` in a child Python process. Both runners exit 99 and leave the prior complete JSON byte-for-byte unchanged. No native probe, Docker operation, workload or working-tree implementation change is involved.

Required correction: atomically publish an incomplete start record (or remove the preceding success record) before the first case can launch. Seal the new completed manifest only after all checks pass, preferably using atomic replacement. Add an abrupt-exit regression for both actual runner entry points. Failed or interrupted attempts must not retain a prior success marker as their current suite result.

## Other review conclusions and practical limits

- The new complete input fingerprint covers runtime tools, Docker/package recipes, tests, `sources.lock` and workflow. `verified_build()` checks it and current binary digests for each launch. The build invalidates its prior manifest before verification/compilation and atomically writes its completed manifest. This addresses the prior stale-lock/build path by inspection.
- Exact ordered API/resource inventories and execution snapshots reject truncated, duplicate, failed, wrongly scoped or changed-input suites at summary time. The review-02 interrupted-prefix path is addressed for exceptions that reach `finally`; F02 above covers the remaining start-invalidation gap.
- Review-01 corrections are present: atomic ready/result handoff, trace-confirmed interruption during partial IO, substantive 8192-byte split-4095 cases with exact successful retry output, and explicit caller range/logical-length guards. Their corrected final native results remain to be checked.
- Bend performs the exercised IO, arithmetic, representation and allocation work; Python supplies independent byte/integer oracles, orchestration and measurements, while C supplies bounded test injection and race coordination. No product parser, importer or publication implementation was found.
- The launcher checks dedicated cgroup identity, child PID and memory/swap readback before releasing exec. OOM requires both Docker's OOM status and a counter increase. Native sampling, helper-inclusive cgroup memory, pre-exec ru_maxrss contribution, missing final samples and virtual-address allocation are correctly distinguished in the documentation.
- Resource claims remain limited to the tested shapes/profile. The raw 256 MiB index case is separate from the charged U32-array case; synthetic accounting is not presented as a general measured allocator. Partial-read error transparency, checked close and safe publication remain blocked.
- CI is configured for an unprivileged Linux x86_64 runner with local Docker, cgroup v2 and readable process/cgroup metadata, pinned action commits, read-only repository permissions, a bounded job and failure-time evidence upload. F01 prevents the inspected workflow from succeeding. After correction, actual exact-head hosted CI is still necessary; static review is not CI verification.
- WSL remains explicitly unverified and its Issue acceptance condition incomplete. No WSL, game, importer, full Gate A or PR-readiness claim is certified here. Final quantitative documentation must be reconciled with the newly generated complete evidence.

## Checks and evidence boundary

Read the complete design, design review, Issue #1 plan/plan review, prior implementation reviews, current runtime Python/Docker/package inputs, native test helpers, Bend probes and negatives, workflow and runtime documentation. Python sources passed AST parsing; both package-manifest hashes match `sources.lock`. The only executed checks were lightweight static/isolated orchestration checks described above. No heavy tests, builds, container changes, external writes or old implementation access were performed. `/workspace/fallout-xml-bend` was not accessed.

The following map captures the reviewed source/document checkpoint, excluding generated evidence and this report. Its sorted compact JSON SHA-256 is `365b85bece51d18dbd1956b229b6ed6686bef99a992950247bca855cf15ad275`. Later coordinator corrections are not implicitly certified by these hashes or this disposition.

| Path | SHA-256 |
| --- | --- |
| `.github/workflows/runtime-probes.yml` | `b10e451c44b61a5dbdc02d5260f88dff7687ba2787af9151951bb027d09acef4` |
| `.gitignore` | `eb7a031b51421b933604229439a8ac96647e997d669bbcfb47099d54bc8ac9b7` |
| `DESIGN.md` | `b4a598ef5487e64bcfe7593400866ad6664b46f45f172b0020d29491e6f61386` |
| `DESIGN_REVIEW.md` | `114274a1f8e92e5a65fe3697e9702328040a8e1fa4e3fdf94bb079b7cfc7999e` |
| `README.md` | `41c1f4da952e7022686c74e64890b1343855467a3abb665179705193f883f311` |
| `docs/implementation/issue-1-plan.md` | `81b2d5e7ac18c192a8cff7c9abd0cf54541c297c498f708a1c67b2c83c997b62` |
| `docs/reviews/issue-1/implementation-01.md` | `6753befd164d6d27cbe291a120bfcc826530a6bd465a8da9e737a16bcfb4eb0d` |
| `docs/reviews/issue-1/implementation-02.md` | `e1716d6db81ea2fb80f83c1317824e4d2ebe767b0ff4f42163cdf90bbf915e5a` |
| `docs/reviews/issue-1/plan-01.md` | `d6b945cbad5fe5369e1bda6aec3a63f6f27401dc20209f897ef7283f5320ecf8` |
| `docs/runtime/README.md` | `3b5ebcc230f3410ed8243736ca94c0ac79ae60920fd7cb3a15800d6f3fa95d65` |
| `docs/runtime/capabilities.md` | `5a885771c52d7399a7f8c8ad8baeb2b8a0162ade7a3f8753c7e4f3d3ed48f116` |
| `docs/runtime/resource-model.md` | `9fef070b25f4cd179ebc42e5216ce991834d1accc3339b74a5fbc26f7bdd89d7` |
| `docs/runtime/resource-probe-notes.md` | `713d20d4ec5d193bbf79591517790895abfccd4360a253b2090cad4f2b7704d8` |
| `sources.lock` | `c693e483f90bd8fa08c41f47315f39c7e87c3567869a3940d26758647755b1da` |
| `tests/runtime/native/exclusive_race.c` | `3dd7655f53f5f09692aca05ed1fcf3aea68964befc76d1b0dde11cfc742ec3a4` |
| `tests/runtime/native/fault_inject.c` | `e2221bbbef688f3ec34884b52c364fc73c37bdffa6562eaf55a29ca9788058c9` |
| `tests/runtime/negative/array_reuse.bend` | `c3c955f67d6b0cf8d97ee237373f40fce3b4ed28ba058f72bdb27f14467d84e9` |
| `tests/runtime/negative/array_reuse_control.bend` | `92a442c18df032b80f73d0b4ef2e88cd7b8ea3fefd7b33e13015c806bcf4ffa4` |
| `tests/runtime/negative/file_reuse.bend` | `9d8c76e08697999bb3f1ff79e01a238a9efcca7b5ee8ad717c16316d5088d5dd` |
| `tests/runtime/negative/file_reuse_control.bend` | `7852a941cf7784fc05ef13a93fefd3de0039812a7f35958125cc3004ff7abb74` |
| `tests/runtime/probes/Support.bend` | `0d11534c3dee9c981b7b8c9ca98b4ffe10f5997884f19692528b1235089e2afb` |
| `tests/runtime/probes/affine_arrays.bend` | `e0830237b29f1b7e5be2cacbed717c96b0f4a5893c7bf4f71d7a6b203c35e115` |
| `tests/runtime/probes/argv_exit.bend` | `2fd705bcf68f2c1033451b033552de9987946ba5930a240331bdaaf76492ebf4` |
| `tests/runtime/probes/binary_roundtrip.bend` | `ed14c19a28707943bbf006794d753476c012a7c41ff1880e4115784fa0176422` |
| `tests/runtime/probes/budget_work.bend` | `17e9938f0d049b51fc76501d68c4edd3aa558fe2741558ad84bc323e2a74e0e9` |
| `tests/runtime/probes/charged_array.bend` | `be63c17d8f86dbbb84fbfb997b5f1400e14d76bb7958ff18296803525f13002f` |
| `tests/runtime/probes/chunk_stream.bend` | `2075e18a68fe8883f59598063af4049faeb751f56503ac8c4a679464a239c1b0` |
| `tests/runtime/probes/exclusive_create.bend` | `bfcff7ad24c2262f871ca39ad48b4f72ddb5de7877dc2e51bf1a84b7cb98e0c0` |
| `tests/runtime/probes/io_errors.bend` | `70fc133d5b32fa82330ba19de52b90c967063d79ec55ea186786030742d91b90` |
| `tests/runtime/probes/memory_pressure.bend` | `03d2a295df4cf310c0e0957c7b091b65d9363d30670570799c156331232041c8` |
| `tests/runtime/probes/memory_shapes.bend` | `6c46ef09bcdd1398a34d344ed1a33a8960b24f3db6ccd06eb167566b93013ce0` |
| `tests/runtime/probes/offsets.bend` | `a24838890d6bea0f0afea501c1b4a3fd3f167acd735519176aac828b234fe2d6` |
| `tests/runtime/probes/range_guard.bend` | `ec93d104d3bc2c325089114589b97ff101494ec7e7773d538eb103d3681db359` |
| `tests/runtime/probes/sha_primitives.bend` | `589c007b61ebd15f75d84f54e0687da7745c4e7a1f0770a0b7c7e36409dd0946` |
| `tests/runtime/probes/short_io.bend` | `2c870171b435bd2565e35c5b838c490031692cf94e926813ca1ae1e48f870074` |
| `tools/runtime/Dockerfile` | `b8287ac2fc8719b83a69281f0b5ffa144bda85f94c6dac5f90d1b62190fa4edc` |
| `tools/runtime/bootstrap.py` | `d24ca344da53f8d5415f522844a10454e90090f5653f46459328318d64653420` |
| `tools/runtime/build_probes.py` | `c485f1b064285bf1d0757a21a73f248cb2ad3b6138bedfd7b65d1b9486e8082b` |
| `tools/runtime/case_spec.py` | `1ec30a5a89c5ce5ac8f696c04d584efe9a9d7e0de58dd51855b1175a5f3e6b5e` |
| `tools/runtime/experiment.py` | `f9f391c588846e362448582ec1dc65c144d5460ed354b3a5348e0a1a409cbf11` |
| `tools/runtime/fetch_toolchain.py` | `13b77171a14ca20ccb0f5893569db14aff15e4684ce2a09740f0a4add22102b9` |
| `tools/runtime/integrity.py` | `f0ca5181f06002d2ff7dab3a7cfecfa668cf367db188d28ef74ff5d8a0a3f6bf` |
| `tools/runtime/measure.py` | `3b6755e7a0430ec6c4750d6b7b26c0e8e5592e220ce4c70cb362bc734184213a` |
| `tools/runtime/native_entry.py` | `d659510563852c3da45865fc941c407c5621422a0f5319d2ae0b12f39fcf70c4` |
| `tools/runtime/packages.lock` | `b8efb4b896d72aa32227c88527c2f10d6fadf8147b7da50d43ee06ef82f99fcc` |
| `tools/runtime/probe-packages.lock` | `bf7d367329bf606aa493b21308294b3cae259d45360d0dda06095c60567b640b` |
| `tools/runtime/run_probes.py` | `16ea3490674b881a3a5041dc544d25f392278cb82cc9b4ba0c0a661b9dc8e1c5` |
| `tools/runtime/summarize.py` | `b4a2002c8a88f45de8f76720a28f7b5f352c5c4c020a7b36497fad2964ad5fec` |
| `tools/runtime/test_evidence.py` | `e29e1fb99546869ad2b884cd4af28cbd133ad72507b6c813e84b328f9866a035` |
| `tools/runtime/verify_lock.py` | `b0cf0aa43214c596efa9244cdf1c1dab2f52f2ced4bbb90845b8a84269e42ca4` |

## Correction check before final native rerun

The coordinator renamed the shape output variable to `expected_stdout`, added atomic incomplete start records before the first case in both suite runners, and used atomic replacement for their final records. The reviewer inspected these changes and independently ran `python3 tools/runtime/test_evidence.py`: **13 tests passed**. The new tests exercise actual resource-runner sealing paths for budget and shapes (with native assertions stubbed only for orchestration), and abrupt child-process exit in both suite entry points. Both F01 and F02 are addressed by source inspection and these lightweight regressions. No additional actionable static finding was identified.

The coordinator was notified that the implementation could be frozen for a new build/full run. Final native results, evidence reconciliation and exact-head CI remain pending; these checks do not certify them. The original input table above preserves the finding checkpoint. Corrected runtime-file hashes are:

| Path | SHA-256 |
| --- | --- |
| `tools/runtime/measure.py` | `44098242dd9a91f5fcf50e3b2ac09b5d3267323b380cde0beaafce014dd53764` |
| `tools/runtime/run_probes.py` | `270b5105bdee9e6f94a0cd675f0e1da4bc5765d11837db98285aa16df8bcf7e3` |
| `tools/runtime/integrity.py` | `38384136a823c87f22b856d5a249015139388f5a01740d512e039c93b7bc01b0` |
| `tools/runtime/test_evidence.py` | `f4d2347b0a44aa09ac7209a211bdc505a08dbe696fd6bb8dfb94adcc16206ce8` |
