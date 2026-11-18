# Issue #5 independent CI/evidence source review

## Verdict

**No actionable source finding in the reviewed CI/evidence chain.** This is a review of the harness and its fail-closed validation logic, not a claim that the locked build, isolated runtime matrix or GitHub CI has executed successfully. Those measurements remain pending. Producer provenance remains blocked regardless of technical CI results.

Reviewed the exact files listed below, plus their current finite case inventory, native launch barrier, positions/limits sub-suite interfaces and affine control sources. The reviewer did not author this evidence pipeline. The separately authored positions tests receive independent review from another reviewer.

## Checks completed

- Build uses the unchanged locked Bun/Bend tree and package manifest, then separate pinned Clang 19 CPU compilation of the unchanged emitted C. Separating processes avoids retaining the compiler heap during Clang optimization without changing compiler/runtime semantics.
- Source, tool, workflow, profile and fixture identities are captured. Generated C, native binaries, build manifest, environment manifest and actual Git head are cross-checked; partial builds and stale/mixed suites do not produce a successful summary. Native/affine inventory is exact, including positive controls beside each expected affine rejection.
- Every functional/resource case has an explicit finite invocation identity. Missing/duplicate/unexpected cases, reused observation paths/scratch identities/container IDs, failed native processes, stderr, timeout/kill/OOM and invalid or missing final measurements are rejected.
- Resource observations are made by a host supervisor outside the limited native cgroup. The native child is identified at a pre-exec barrier; the kernel limit and swap readback are checked before release. Final wait4 RSS and cgroup peak/events are collected before the launcher releases the container. Compiler memory is not labeled native-program RSS.
- Both runtime paths use no-network, non-root, read-only containers with dropped capabilities and no-new-privileges. The oracle path is independently tied to the probe image/package identity and the built driver/positions hashes. Its limits/positions outputs and typed results are revalidated before summary.
- Successful differential results include independent typed digest/count/logical comparisons. Raw-byte chunk schedules are finite and complete; successful work comparisons subtract only the independently calculated source-buffer initialization cost. Malformed-input diagnostics must be partition invariant. Positions directly checks the source metadata omitted by the typed digest.
- Generated-C checks are correctly described as finite regression anchors, not a general stack proof. The resource matrix separately covers actual schema depth five, lower configured depth refusal, ASCII/Japanese/non-BMP page edges, a maximum-size entry, 200,000 entries, and three independent repetitions of 1/16/64 MiB source streams. Logical charges are not presented as independent RSS measurements.
- Final technical success leaves `complete`, `acceptance_complete` and `issue5_complete` false while the verified pinned-producer fixture is missing. The workflow labels its success as technical validation and preserves evidence even on failure. Synthetic vectors, a cached version-unknown real file and absent CI checks cannot silently clear the producer gate.

## Tests actually run

`python3 tools/xml/test_evidence.py` passed: **116 XML evidence rejection regressions**. These are mocked/local validator unit tests, not fabricated native or Docker measurements. They cover freshness, exact inventory, changed C/binaries, affine controls, runtime identity/isolation, missing/failed measurements, invalid results, source/manifest hashes, resource envelopes, duplicate run identity and false producer acceptance.

The current native positions suite also completed separately with 21 fixtures / 2,946 runs; its exact hashes and local-only status are recorded in `source-positions.md`. No Docker build, cgroup resource execution or remote CI run was performed by this reviewer during this pass.

## Source snapshot

| File | SHA-256 |
| --- | --- |
| tools/xml/build.py | 5cf84e2ddf15cf8817cb0715e93d7785d3938faf9f04a77035315feb75cdecf0 |
| tools/xml/bootstrap.py | 73f199335ac1be45dbc047b51248496d0017afdb6809de8583fd19ceb92b9e11 |
| tools/xml/run.py | e6adf70c4c26ec441a719ec2c4ea98eb2a84128cae27ed4737b8631a7e545225 |
| tools/xml/functional_runner.py | 8fb3b7abd2209914c9716ada6f573c5cb9ab874d41c84d67b37b6d9d7a34042a |
| tools/xml/measure.py | 2ee6f27e17190e78f616a269994b1bf39cd26c192612cc8415bf74e50b99366d |
| tools/xml/summarize.py | bb060d9d51a8e88fc98e15b32d3249dcd5510749ecdd2161db9a00f7028d4a8e |
| tools/xml/validation.py | e600a873ab8145afc31655c1947c7e7383734f2537c3253a23df02607c177a9b |
| tools/xml/layout.py | f9ae7083b70c7fc27cec5962de1ba718cfefcd873a5e90cf87a302828b0a8f94 |
| tools/xml/test_evidence.py | f49e10137506d4ee39bb5775de39fd6362bc92bdcd392ea76eb245b41503a3dc |
| tools/xml/checks.py | 445480ec554d59ad1ff19d3cc8758e80648479f33072ffec77f8a23acf3ec45a |
| tools/xml/resources.py | 5bddab3a1882f30373366466f34862d1c84a74efa368697ca01846fd9e5a7fbc |
| tools/xml/experiment.py | c5feddb147a3e5b76ca12614b1ec3b03f91758901fe51071f41c255b60ac3644 |
| tools/xml/integrity.py | 48dbd9873d26041d9305d12c89e12d2d90f5576f46946f5e32b62f7dc4c2e637 |
| .github/workflows/xml.yml | d41d9594b12cf6f32418af4efa7e976ae5017c2817b167f67be675d584bf63c3 |
| docs/xml/profile.json | 229b95ecdaccefc1416c581120c083b56c2d9685773e536e2c6f724fc2183602 |

## Remaining validation

Run the complete final-source locked build and both isolated suites, then inspect their actual measurements and exact-head CI status. A later source/profile/inventory change requires fresh evidence under the existing identity checks. The producer-fixture gate requires separate permitted provenance and cannot be approved from this source review.

## Producer wording follow-up

Reviewed the clarification that verification-only acquisition does not require redistribution permission, while vendoring/distributing fixture bytes does. This does not relax the missing pinned-producer build identity requirement or create an acceptance override: `producer_status()` remains blocked and exact-value validated. Current reviewed hashes are `tools/xml/validation.py` = `7d1d8c1b2ff687baf545ef70bb4c5b6e1ec2df51f09802d54f65142d1c2af4ad`, `docs/xml/profile.json` = `d8b633f4bc277aa3c87977a40456770a2bcb3777d134110381709832c5be8bcf`, and `docs/xml/validation.md` = `b0eb3e6bc74d9522c74a6006e831b5daf2ecdb081182d0ed09c788e80fcc46e3`. No actionable finding in this clarification. The earlier source-review verdict remains subject to actual locked CI/resource evidence and the separate producer gate.

Reviewed local smoke helper `tools/xml/develop.py` at SHA-256 `d071de3c1ebcaae3f8893788b9eed7528cdffbe0bc02b224b3b603a281e0e125`. Its source/input snapshot, compiler/Bun identity check, explicit per-step exit recording and end-of-run input check preserve the separation from locked evidence. It writes no acceptance manifest and labels the result `acceptance_complete: false`. No actionable acceptance-gate finding. The all-entry local build was not rerun as part of this source review.
