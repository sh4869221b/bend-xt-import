# Issue #2 independent acceptance evidence review

2026-11-07. Supplemental to full source review 02. **All current local acceptance gates verified; zero actionable findings.** This verdict covers the post-whitespace source inputs and fresh artifacts identified below. Exact reviewed-commit CI remains the PR readiness gate; this is a precommit build recorded honestly as base `da6baa03f97060464658721866d03493fe722540`, dirty=true.

## Source identity and build

Compared all 78 files in the full-review-02 manifest. Only the four announced trailing-newline changes differ: budget.bend had three final LF bytes, the other three had two, and each now has one. Reconstructing those final LF bytes reproduces every old reviewed SHA-256 exactly, establishing no semantic source changes. All other reviewed hashes remain unchanged. Current hashes:

- `core/budget.bend`: `33bbd749063709ce7c1aa527697b8c3d07a0fbf660181ea264bc0b5fc91fe0d3`
- `hash/sha256.bend`: `bcc756f5d937fe064ff3169fae100a4afcd85fc0244bfce6ae56fcce496bf756`
- `tests/core/cursors.bend`: `6374e6069910d157ddd6d7a11772f9a4269154d1d5595a0a1028eab89b9582c4`
- `tests/core/sha_errors.bend`: `64c3542d8317354b56a1e3165539e0ace35e7feefc876c9c794cbec9a103effa`

Verified current source/build/environment identity, all 17 mandatory entry points and three successful check/C/native build steps per entry point, current emitted-C/native binary digests, and all 16 ownership controls (eight positive successes; eight duplication failures with expected diagnostics). Compiler-tree, Bun and build-package digests match sources.lock. Six current layout excerpts match emitted C and current build identity, covering scalar value/width blocks and their disposal, SHA state/schedule, source/window preservation and fixed budget/ticket representation. Prior manual layout inspection remains applicable; the cleanup does not alter algorithms or declarations.

## Functional and oracle evidence

Verified all 15 distinct mandatory functional invocations against actual observations and exact completion output, including nine-line expanded sha_errors coverage. Native/client exits succeeded, stderr is empty, and no timeout/kill/OOM/ceiling events occurred. Observation file hashes, binaries, lock, harness, image and build match current evidence. The complete functional record uses the current input and environment fingerprints.

Verified oracle report hashes, image/profile/subprocess identities, counts and results. Independently recomputed all 705 stored codec outcomes against strict UTF-8/CP1252 behavior and all 31 SHA digests with hashlib. SHA length/partition inventory includes empty, padding/block boundaries, 65535/65536/65537 and million-a. All pass. This inspects actual output, rather than trusting stored pass flags alone.

## Resource evidence and calibration

Independently inspected all 114 observations: 38 shapes, each repeated three times, with exact keys, arguments, groups and repeats. Both the complete resource record and complete final summary match current source/build/environment fingerprints. Every resource row has UID 1000, external and pre-exec barrier memory.max=1,073,741,824 and memory.swap.max=0, successful native/client exits, empty stderr, no timeout/external kill/OOM kill, and no increase in cgroup max/oom/oom_kill counters.

Maximum wait4 RSS including launcher: **69,238,784 bytes**. Maximum cgroup peak: **74,215,424 bytes**. Both are far below the independent 1 GiB ceiling.

The nine baseline observations yield RSS=13,312,000 and cgroup=8,560,640 bytes. Twice the respective baseline rounded up to MiB gives fixed allowances of **27,262,976 RSS** and **18,874,368 cgroup** bytes.

Independently recomputed each shape's charge and allowance comparison as well as the validator's full measurement object. All 114 pass. Formulas use the 65,536 budget state, checked power-of-two capacity, bytes max(65,536,16*capacity)+4,096, scalars max(65,536,32*capacity)+4,096, and SHA 65,536+4,096, including actual overlapping lifetimes. Error-lifecycle cases use the declared bounded 1 MiB test cap. These are empirical bounds for the documented shapes, not arbitrary structures.

Maximum peaks across three repeats, bytes:

| Stream | Size MiB | RSS including launcher | Cgroup peak |
|---|---:|---:|---:|
| SHA | 1 | 13,312,000 | 8,495,104 |
| SHA | 16 | 13,025,280 | 8,269,824 |
| SHA | 64 | 13,324,288 | 8,384,512 |
| Codec | 1 | 13,402,112 | 8,323,072 |
| Codec | 16 | 13,066,240 | 8,527,872 |
| Codec | 64 | 13,152,256 | 8,466,432 |

Across all nine observations per family, max-minus-min variation is:

- SHA: RSS **679,936**, cgroup **753,664** bytes.
- Codec: RSS **856,064**, cgroup **376,832** bytes.

Every variation is below the required 16,777,216-byte bound. The observed 1/16/64 MiB series supports bounded streaming memory in the tested profile; it is not an asymptotic proof.

Actual outputs match the independent expectations for capacity/overlap/repeated-drop cases. The live ceiling accepts 254 full buffers at 267,444,224 and refuses the 255th with request=1,052,672; it accepts 3,854 small buffers at 268,427,264 and refuses the 3,855th with request=69,632. Each repeat includes three allocation/drop cycles and ends with expected checksum/work and balanced ownership. Codec source/scalar-value+width/output overlap and all three error-lifecycle groups, including expanded SHA failure/retry tests, have all required observations.

The final summary's complete measurement object equals recomputation from actual records. Counts are 15 functional, 736 oracle, 114 resource and 16 ownership controls. Summary references current build/layout/functional/resource hashes; no stale prior-snapshot record was accepted.

## Current evidence fingerprints

- `build.json`: `3c3ab4c1f6db05732fbbe85408f7093ee303fc590ea786e43637ac80cbb5fb51`
- `environment.json`: `e319adcdbc48a8c94441d21704cf0055f7ecd1d3546a610e5eecf1f5cb980d7c`
- `layout.json`: `f4a41a37bf4553dc4ff1acab8e5c04d6d189f3f87fa8ce3f1d346d46476582ad`
- `functional.json`: `9e4db1892b03d316933e8458b2f6572cb1a3fd52a5c28d86c3cddaa81d29c502`
- `resource.json`: `a16bbcde845f10dfff6d05a6dc883cdea06fcbff6bc489a00020e892312a4e00`
- `summary.json`: `290730a1aa33e337d282283d2c0bef507bd70d869fa50794310a8677273a15ac`

Machine-readable inspection measurements and fingerprints are saved in `/workspace/issue2-current-acceptance-inspection.json`. The preceding pre-whitespace run also passed, but the acceptance verdict above uses the fresh post-whitespace rerun exclusively.

Reviewed the subsequent README diff: its core API/charge/review/plan links resolve, and its revised scope accurately describes the bounded common core while retaining the absent importer/parser/publication and Linux-versus-WSL distinctions. No documentation finding. README is outside the core acceptance input set and does not invalidate these measurements.

No remaining local code or acceptance-evidence blocker was established. Proceeding to commit and draft PR is supported by this review. Making the PR ready still requires the user's applicable exact-commit CI condition; no CI result is asserted here. Issue #3 and transactional apply remain outside this acceptance scope.

This reviewer reran no Docker/build/native/resource jobs and did not mutate shared evidence. Only review reports and their supporting inspection JSON were written.
