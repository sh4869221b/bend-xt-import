# Issue #1 independent implementation review 02

- Date: 2026-11-06.
- Reviewer: `/root/issue1_impl_review_2`, fresh independent Astra review requested by the coordinator.
- Base commit: `5b4643c6714e025bc248fbdbe711d54f747d8fc6`.
- Scope: Issue #1 runtime experiments, lock, test helpers, evidence pipeline, CI and documentation. Production parser/importer/publication work is excluded.

## Disposition

**Changes required at the reviewed checkpoint: two actionable findings.** This is not an acceptance review. The full native suite was running concurrently against frozen implementation inputs; the reviewer did not interrupt it or run additional native workloads. Final generated evidence was not present when these findings were recorded. Its absence is pending work, not an additional defect. A successful native run does not by itself resolve the stale/incomplete-evidence paths below.

## F01 — Medium: bind runnable builds to all build inputs and invalidate failed attempts

Locations: `tools/runtime/experiment.py:51–64`, `tools/runtime/build_probes.py:20–24,69–77`, `tools/runtime/bootstrap.py`.

`verified_build()` checks the complete flag, `tests/runtime` hashes and binary hashes, but does not bind those binaries to the current `sources.lock`, compiler provenance, package manifests, Dockerfile or build scripts. `build_probes.py` also leaves the preceding successful `build.json` in place while verification or compilation can fail. Thus a changed compiler lock followed by a failed bootstrap/build can leave an old build acceptable to the runner. The resulting observation records the current lock hash next to the old binary/build identity, which misrepresents the attempted toolchain transition.

Lightweight reproduction, using an isolated temporary copy of the current test/tool files and real build manifest, with read-only symlinks to the existing binaries: replace only the copied lock's `compiler_tree_sha256` with 64 zeroes, redirect the imported `experiment.ROOT` to the copy, clear its verification cache, then call `verified_build()`. It accepted all 16 binary/helper entries. No native program, container mutation or working-tree implementation edit was involved.

Required correction: persist a complete build-input fingerprint (including the lock and build recipe/tooling), validate it before native launches, and invalidate the old success marker before a new bootstrap/build attempt can fail. Publish the new completed manifest atomically only after all required build and provenance checks succeed. A partial selection or failed verification/build must not leave a preceding success usable as the current attempted build. Add small regression checks for changed lock/build inputs and failed attempts.

## F02 — Medium: reject interrupted or stale suites before publishing a summary

Locations: `tools/runtime/run_probes.py:175–177`, `tools/runtime/measure.py:125–128`, `tools/runtime/summarize.py:12–41`.

Both suites write their accumulated records in `finally`, but record neither successful full completion nor the execution-time input snapshot. A `KeyboardInterrupt` after some passing cases bypasses the `except Exception` case record and leaves an all-pass prefix. The summary accepts any nonempty all-pass list; it does not validate the required case inventory/group. It also hashes the current test/tool files and lock into its output without comparing those values with the build inputs or the suite/oracle versions that produced the results. Only the build-manifest digest and two launcher files are compared. Changing a Bend probe, `run_probes.py`, `measure.py` or the lock after a run can therefore produce a new-looking summary from stale results.

Lightweight reproduction in the same temporary copy: create a one-pass-case prefix for each `suite-all.json` and `measure-all.json`, supply observations with the currently required build/launcher hashes, and change the copied `argv_exit.bend` and lock after the supposed execution. `summarize.main()` completed and printed `wrote 2 cases with observation digests`; the output represented both prefixes and stamped the changed inputs. These synthetic JSON records demonstrate validation behavior; they are not claimed as native experiment evidence.

Required correction: record suite identity/group, a success-only completion flag, the exact expected case identities, and an execution-time input/build fingerprint. Invalidate prior success at start; preserve interrupted/failed runs explicitly as incomplete. The summary must reject missing/duplicate/unexpected cases, incomplete runs and input/lock/build/oracle mismatches rather than attaching current hashes to older observations. Exercise interrupted-prefix and changed-input rejection with small local fixtures.

## Checks and scope assessment

- Read DESIGN and its review, the entire Issue #1 plan and plan review, prior implementation review, all runtime Python/Docker/package-lock files, all positive/negative Bend probes, native injection/race helpers, workflow and runtime documents. The old `/workspace/fallout-xml-bend` directory was not accessed or reused.
- All runtime Python files passed `ast.parse`; both package-manifest SHA-256 values matched `sources.lock`.
- The four previous review findings are addressed in the inspected source: atomic ready/result rename; trace-confirmed partial IO cancellation; substantive 8192-byte tests for split 4095 plus exact successful retry output checks; and checked range/logical-length/capacity guard probes. Actual final execution of those changes is not certified here.
- Native operations and representation work remain in Bend. Python supplies independent arithmetic/byte oracles, orchestration and measurement; C supplies test fault injection and process coordination. No product parsing or publication implementation was found.
- The launcher fails closed on missing cgroup identity/readback and checks a dedicated memory.max/swap.max before releasing native exec. OOM requires Docker state plus a cgroup counter increase. External signals, timeout, allocation failure and virtual-address failure are distinguished. The helper's cgroup overhead, pre-exec contribution to ru_maxrss, and missing samples/final rusage are disclosed. No strict instantaneous RSS theorem follows from this experiment.
- The CI workflow has read-only repository permission, pinned action commits, bounded job time, and always-on evidence upload. It runs the same suites with no skip-to-success fallback. Static compatibility depends on a non-root Linux x86_64 runner, local Docker socket, cgroup v2 memory control, readable process/cgroup metadata and compatible private cgroup namespace behavior; an actual exact-head CI result is still needed. This review did not execute hosted CI.
- The fixed U32-array charge profile and raw 256 MiB index allocation are correctly separated. General nested/index/conversion charges and arbitrary maximum input sizes remain unproven. Three measured stream sizes can establish behavior only for that tested range. The documentation keeps partial-read error transparency, checked close and production publication blocked.
- WSL2 is explicitly untested and its acceptance condition remains incomplete. Linux evidence must not be used to check off WSL support. No PR readiness or Issue completion is certified by this report.

## Subsequent coordinator work

After the findings were sent, the coordinator began changing the integrity/build/suite implementation and added `integrity.py` and `case_spec.py`. Those subsequent changes are not covered by this review's disposition or hashes. The appendix preserves the exact pre-fix inputs used for the reproductions. A fresh review must assess the completed correction and its new execution evidence; this record does not certify those changes by inference.

## Review input hashes

The table hashes the source/document inputs inspected before the coordinator's new fixes, excluding generated evidence and this report. The canonical sorted compact JSON mapping of these path/digest pairs has SHA-256 `929bfc496fc932802010adc2677f8c0a4d761020e81a00cfc206607037b6e48a`.

| Path | SHA-256 |
| --- | --- |
| `.github/workflows/runtime-probes.yml` | `34b20184a230aa573a5b670e176ff0c297796a194309c68fe19f5fe5e2db1556` |
| `.gitignore` | `eb7a031b51421b933604229439a8ac96647e997d669bbcfb47099d54bc8ac9b7` |
| `DESIGN.md` | `b4a598ef5487e64bcfe7593400866ad6664b46f45f172b0020d29491e6f61386` |
| `DESIGN_REVIEW.md` | `114274a1f8e92e5a65fe3697e9702328040a8e1fa4e3fdf94bb079b7cfc7999e` |
| `docs/implementation/issue-1-plan.md` | `81b2d5e7ac18c192a8cff7c9abd0cf54541c297c498f708a1c67b2c83c997b62` |
| `docs/reviews/issue-1/implementation-01.md` | `6753befd164d6d27cbe291a120bfcc826530a6bd465a8da9e737a16bcfb4eb0d` |
| `docs/reviews/issue-1/plan-01.md` | `d6b945cbad5fe5369e1bda6aec3a63f6f27401dc20209f897ef7283f5320ecf8` |
| `docs/runtime/README.md` | `3b5ebcc230f3410ed8243736ca94c0ac79ae60920fd7cb3a15800d6f3fa95d65` |
| `docs/runtime/capabilities.md` | `5a885771c52d7399a7f8c8ad8baeb2b8a0162ade7a3f8753c7e4f3d3ed48f116` |
| `docs/runtime/resource-model.md` | `9fef070b25f4cd179ebc42e5216ce991834d1accc3339b74a5fbc26f7bdd89d7` |
| `docs/runtime/resource-probe-notes.md` | `63b7cf1d130ba217370e0bf3255b552db02dcbcf3fceda3080fe51d7aa1a043b` |
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
| `tools/runtime/bootstrap.py` | `2f12f73ee99845655c3686e28a8ffab813b77457beadf686167070ac5f3835b0` |
| `tools/runtime/build_probes.py` | `80058c2eeb1cbc3abc12f6fce2655003cf305ec054dd21d82ba084835fb13da7` |
| `tools/runtime/experiment.py` | `7768e1c54982caaaf7d6f9a510b4c59536e87b6a17f8715507949e486af9a056` |
| `tools/runtime/fetch_toolchain.py` | `13b77171a14ca20ccb0f5893569db14aff15e4684ce2a09740f0a4add22102b9` |
| `tools/runtime/measure.py` | `9e643371a9f3b5a86358f7873df2eab3efc4570070af2b39af5ab2f958ec6fa0` |
| `tools/runtime/native_entry.py` | `d659510563852c3da45865fc941c407c5621422a0f5319d2ae0b12f39fcf70c4` |
| `tools/runtime/packages.lock` | `b8efb4b896d72aa32227c88527c2f10d6fadf8147b7da50d43ee06ef82f99fcc` |
| `tools/runtime/probe-packages.lock` | `bf7d367329bf606aa493b21308294b3cae259d45360d0dda06095c60567b640b` |
| `tools/runtime/run_probes.py` | `51a14817d155f7a226e9eb9109f6ae316e5b2dbcd8a948805eb0d0d30823cd94` |
| `tools/runtime/summarize.py` | `75514b7de914dbbda53fd260a46e2f577e97ba4706c9ae9641699e3e99da4b3e` |
| `tools/runtime/verify_lock.py` | `b0cf0aa43214c596efa9244cdf1c1dab2f52f2ced4bbb90845b8a84269e42ca4` |
