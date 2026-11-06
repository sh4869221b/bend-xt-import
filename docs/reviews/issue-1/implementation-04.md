# Issue #1 independent implementation review 04

- Date: 2026-11-06.
- Reviewer: `/root/issue1_impl_review_4`, fresh independent reviewer assigned for the requested Astra review cycle.
- Base commit: `5b4643c6714e025bc248fbdbe711d54f747d8fc6`.
- Scope: frozen Issue #1 runtime experiments, runtime/build/evidence tooling, Bend probes, native test helpers, locks, workflow, design/plan, prior reviews and reporting documents. No production importer or publication implementation.

## Static disposition

**No remaining actionable static findings were identified in the frozen inputs below. Final native-evidence acceptance is pending.** The coordinator was running the complete 93 API and 98 resource cases when this checkpoint was recorded. Neither a successful build nor the regression checks below certifies that pending full execution, its quantitative documentation, WSL support, or hosted CI.

## Independent checks and conclusions

- Read the current runtime implementation and the previous findings rather than relying on the prior no-findings conclusion. The four review-01 fixes remain present: atomic barrier/result handoff, trace-confirmed interruption during partial IO, actual short-4095 calls with larger payloads and exact successful retry output, and explicit checked range/logical-length guards before the unsafe operation.
- The input fingerprint covers runtime tooling and recipes, native helpers, every Bend probe/control, package manifests, `sources.lock`, and the workflow. Build startup invalidates the preceding manifest before verification/compilation; the new manifest is complete only after the full build, and is replaced atomically. A selected partial build cannot become a complete build. Every launch checks the current source fingerprint and all binary/helper digests.
- Independently called `verified_build()` against the actual current manifest and binaries: complete build accepted, all 16 probe/helper entries verified. The build JSON SHA-256 is `41fd62e392bee1ba6b77a3feddceb3bd4d579cd0267ba79dcfc675ab2801a8e2`. The canonical sorted compact JSON fingerprint of actual runtime inputs is `d26860cc53661fb213c42554d36a56f499c4b4dadded5bc660a48fbb1e8a84fc`.
- Both suite entry points atomically publish an incomplete record before the first probe launches, preserving failure/interruption as incomplete. They require the exact ordered case inventory and unchanged execution inputs before sealing completion. The summary separately checks the complete all-group inventory, current build/input identity and each referenced observation's build/lock/runner/entry identity. Partial prefixes, duplicate identities, stale builds and changed oracles do not satisfy these checks.
- The resource-runner local-variable shadowing fix is present. Independently ran `python3 tools/runtime/test_evidence.py`: **13 tests passed**, including actual resource-runner completion paths and abrupt child-process exit before a first result. All 12 Python runtime source files parse, and both package-file hashes match `sources.lock`.
- The independent byte/integer oracles are meaningful for their stated experiments. Bend performs IO, arithmetic, traversal, ownership and allocation work; Python supplies expected data, orchestration and measurement; C supplies restricted test fault injection and concurrent-create coordination. No product parser, importer or publication path was found.
- Dedicated cgroup membership and memory/swap readback are checked before native exec. OOM requires Docker's OOM flag and a captured counter increase. Native RSS samples, exec-barrier contribution to final ru_maxrss, helper-inclusive cgroup accounting and absent final samples remain distinguished. Synthetic budget counters, the limited U32-array charge profile, and the separately measured raw index allocation are not presented as a general resource-accounting implementation.
- The CI workflow uses pinned actions, read-only repository permissions, bounded job time and failure-time log upload, and executes the same complete suites with no skip-to-success path. Its host assumptions remain a non-root Linux x86_64 user, local Docker socket, cgroup v2 memory control and readable process/cgroup metadata. This review does not establish those assumptions on the hosted runner; exact-head CI must be checked separately.
- Documentation retains explicit blocks for partial-read error transparency, checked close, secure snapshots and atomic/durable publication. WSL remains unverified with its corresponding acceptance condition incomplete. General representations and arbitrary input-size support remain unproven. These honest scope limits are not new implementation findings.

## Evidence boundary

This review performed only source/document reads, hashes, AST/package consistency checks, and the lightweight 13-test evidence regression suite. No native workload, heavyweight test/build, container mutation, external write or implementation-code change was made. `/workspace/fallout-xml-bend` was not accessed. The managed cloud runtime skill was read for environment handling; no networking or Docker operations were required by this review.

The full native rerun and evidence/quantitative-document reconciliation were still pending. A follow-up to this same review must inspect the final complete manifests and evidence before adding an acceptance disposition. Any change to runtime inputs invalidates this build/run checkpoint and requires a fresh complete build/run. Documentation-only evidence reconciliation must be captured separately by its final hashes. PR readiness must additionally follow the user's latest-head CI condition; this static review is not that condition.

## Exact review input hashes

The following source/document map excludes generated evidence and this report. Its sorted compact JSON SHA-256 is `6fc5ca71e5de906827dc242d70aa13218130bdd3c4bc0476415060d487902ad1`.

| Path | SHA-256 |
| --- | --- |
| `.github/workflows/runtime-probes.yml` | `b10e451c44b61a5dbdc02d5260f88dff7687ba2787af9151951bb027d09acef4` |
| `.gitignore` | `eb7a031b51421b933604229439a8ac96647e997d669bbcfb47099d54bc8ac9b7` |
| `DESIGN.md` | `b4a598ef5487e64bcfe7593400866ad6664b46f45f172b0020d29491e6f61386` |
| `DESIGN_REVIEW.md` | `114274a1f8e92e5a65fe3697e9702328040a8e1fa4e3fdf94bb079b7cfc7999e` |
| `README.md` | `41c1f4da952e7022686c74e64890b1343855467a3abb665179705193f883f311` |
| `docs/implementation/issue-1-plan.md` | `81b2d5e7ac18c192a8cff7c9abd0cf54541c297c498f708a1c67b2c83c997b62` |
| `docs/reviews/issue-1/README.md` | `a7b833e9f79edf3fb7eb60d07333e0958a5fabf793342849765edbf2b6d0704d` |
| `docs/reviews/issue-1/implementation-01.md` | `6753befd164d6d27cbe291a120bfcc826530a6bd465a8da9e737a16bcfb4eb0d` |
| `docs/reviews/issue-1/implementation-02.md` | `e1716d6db81ea2fb80f83c1317824e4d2ebe767b0ff4f42163cdf90bbf915e5a` |
| `docs/reviews/issue-1/implementation-03.md` | `48fb9c622ed3d7068ca38b1a0456ae2937b66865a89ed93b606d578a6fc55c1a` |
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
| `tools/runtime/integrity.py` | `38384136a823c87f22b856d5a249015139388f5a01740d512e039c93b7bc01b0` |
| `tools/runtime/measure.py` | `44098242dd9a91f5fcf50e3b2ac09b5d3267323b380cde0beaafce014dd53764` |
| `tools/runtime/native_entry.py` | `d659510563852c3da45865fc941c407c5621422a0f5319d2ae0b12f39fcf70c4` |
| `tools/runtime/packages.lock` | `b8efb4b896d72aa32227c88527c2f10d6fadf8147b7da50d43ee06ef82f99fcc` |
| `tools/runtime/probe-packages.lock` | `bf7d367329bf606aa493b21308294b3cae259d45360d0dda06095c60567b640b` |
| `tools/runtime/run_probes.py` | `270b5105bdee9e6f94a0cd675f0e1da4bc5765d11837db98285aa16df8bcf7e3` |
| `tools/runtime/summarize.py` | `b4a2002c8a88f45de8f76720a28f7b5f352c5c4c020a7b36497fad2964ad5fec` |
| `tools/runtime/test_evidence.py` | `f4d2347b0a44aa09ac7209a211bdc505a08dbe696fd6bb8dfb94adcc16206ce8` |
| `tools/runtime/verify_lock.py` | `b0cf0aa43214c596efa9244cdf1c1dab2f52f2ced4bbb90845b8a84269e42ca4` |

## Final local evidence acceptance — 2026-11-06

**No additional actionable findings. The frozen implementation and its completed local Linux evidence are accepted within the Issue #1 experiment scope.** This completes review 04's previously pending native-evidence review. It does not certify WSL, hosted CI, importer functionality, safe publication, or completion of every Issue #1 acceptance condition. WSL remains unverified and the Issue must remain open; PR/latest-head CI checks remain the coordinator's next step.

The current runtime-input fingerprint and complete build digest are unchanged from the static checkpoint above. Independently inspected both completed all-group suite manifests: exactly **93 API cases and 98 resource cases**, in the required order, with complete=true and matching execution inputs. Every case is present once and marked pass under its expected outcome, including intentional errors and known capability gaps. The summary's build and environment files exactly match the local originals, and all observations identify the recorded Linux kernel and one of the recorded image IDs.

Checked all **191 raw observation files** against their published observation hashes, frozen build/binary/lock/runner/entry identities, package fingerprint, raw stdout/stderr and applicable fault trace. Checked every surviving destination sentinel and empty publication-monitor directory. Recomputed every resource metric from native samples and final rusage, then independently recomputed all shape/stream min/median/max aggregates; they match the summary. Four deliberately SIGKILL/timeout-terminated observations lack final native rusage, and those values remain null rather than fabricated zeroes.

Additionally replayed both complete suites' existing oracle/assertion paths against the saved observations and scratch fixtures, replacing only native launch with ordered readback and suppressing manifest writes. All 93 API and 98 resource cases passed this **read-only replay**. This exercised expected bytes, output strings, exits, short-IO traces, cancellation prefixes, OOM classification, and stream input/output digests. It was not a second native execution or new performance measurement. No build, native workload, Docker change or runtime source edit was performed during this follow-up.

Representative results reconcile with the evidence README:

- The limited 256MiB charged U32-array profile completed all three cycles with checksum 2,139,095,040, sampled VmHWM 69,578,752 bytes and final cgroup peak 74,514,432 bytes. A one-byte-smaller limit exited 5 with no allocation marker. The separate raw 256MiB index case has sampled VmHWM 270,974,976 and cgroup peak 276,135,936 bytes and is correctly excluded from the live-charge acceptance claim.
- Both 128MiB and 1GiB OOM experiments exited 137, have Docker OOM=true, no supervisor kill, and oom_kill increasing from 0 to 1. The 1GiB case has sampled VmHWM 1,063,223,296 and final cgroup peak 1,073,741,824 bytes. The separate address-space limit case exited 1 without OOM and is not counted as RSS-limit success.
- The read SIGTERM and write SIGKILL/timeout cases reached the trace-confirmed stall after seven bytes. Read input remains exact; writes contain precisely the seven-byte prefix. Their signals/timeouts remain distinct, with no complete marker or publication artifact.
- The 1/16/64MiB streams each have three successful runs with equal input/output digests. Their sampled VmHWM ranges are 5,734,400–5,767,168; 5,664,768–5,668,864; and 5,599,232–5,795,840 bytes. These support only the documented tested-range observation. The 64MiB maximum cgroup sample peak of 79,093,760 includes helper/file-cache accounting and is not labeled native RSS.
- Four observations explicitly retain verified_gap: read/pread partial-error loss, transient read error loss despite later complete bytes, and unavailable checked close. Successful reproduction of these defects does not enable those capabilities or publication.

Read the final evidence README and the updated review index. Their scope and quantitative statements match these observations. Both fresh download-cache directories contain Bend/Bun artifacts matching the lock; this check confirms the cached contents, not an independent observation of their earlier network fetches. The report explicitly discloses Docker layer-cache use and makes no general bit-for-bit build guarantee. Existing runtime documentation remains unchanged from the static checkpoint and keeps unsupported platforms, uncalibrated representations, and production primitives separate.

### Accepted evidence hashes

The summary binds the individual observation digests; the raw scratch/observations remain local and are not claimed to be the future CI artifact. The following hashes identify this acceptance checkpoint. The review index is expected to change subsequently to reflect this completed disposition.

| Path | SHA-256 |
| --- | --- |
| `docs/runtime/evidence/README.md` | `abba9eb6dd29c0cc15bcabc8c560b2c0f1e9e4492a71937ce86736846bf0342a` |
| `docs/runtime/evidence/linux-build.json` | `41fd62e392bee1ba6b77a3feddceb3bd4d579cd0267ba79dcfc675ab2801a8e2` |
| `docs/runtime/evidence/linux-environment.json` | `9ec80665eb553dd3cb36f1f61825d766e1da0785a082f8a6c11b8efc71c02cbe` |
| `docs/runtime/evidence/linux-summary.json` | `b4077c31f4d3ff44aa972c52ed700a5186e3ca14708c5fbfb8164c8695294ea9` |
| `runs/suite-all.json` | `5f65216c90995f361708bc0204926e25199c7a1cb5666624ffe115e2f06a1124` |
| `runs/measure-all.json` | `85bfe2b010bbce914d0a5c410f674c7d565b9c3e8b06908908920efcf96284c4` |
| `docs/reviews/issue-1/README.md` | `4fd11696484d3c1356cd3c59ab75a916907f6b5de14928ebbbd7c90ffaf0fc6e` |
