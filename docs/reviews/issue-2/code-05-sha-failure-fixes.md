# Issue #2 SHA failure lifecycle repair

Finding addressed: R1 (P2) in `/workspace/issue2-full-review-01.md`. Scope is `tests/core/sha_errors.bend` only; the existing shared assertion helper is reused without changes. No core, tool, repository documentation, Issue #1, or upstream source was changed.

The previous two range/length-overflow tests remain. Added tests cover:

- Update refusal before the first byte and after two bytes of `abc`. Each checks all ResourceLimit fields, exact used/held counters, pending/high/low state metadata, and input `abc` through public reads. After cancelling held verification work, only the unprocessed suffix is passed to update; the complete raw digest must match the independent SHA-256(abc) vector. Final work is exactly 109 and all live/held charges are released.
- Finalize live refusal before digest allocation: `HashFailed(...,None)` with live limit=used=204800 and requested=69632. State/input/counters are retained. Dropping the input makes room to retry, and the returned state finalizes to the known digest.
- Finalize initialization-work refusal: only 31 visits are available for a 32-cell allocation. Exact error is ResourceLimit{5,151,120,32}; used work stays 10, and no digest owner is returned. After cancelling the verification ticket, the original state retries successfully.
- Finalize write-work refusal: allocation succeeds and charges 32 initialization visits, then the separate 32 output writes are refused with only 31 visits available. Exact error is ResourceLimit{5,183,152,32}; `Some{digest}` must be returned, used work=42, used live=274432, and held live/work=4096/110. Every one of the 32 partial digest bytes is read back as zero. Its owner is released separately; the unfinalized state is retried and must produce SHA-256(abc). Final work=173 includes the first allocation, all readback, and the successful retry; no consumed work is refunded.
- Exact-success neighbor: exactly 64 available work units cover digest initialization plus output writes. The successful result releases the SHA state, retains the digest/input owners, and leaves the reserved verification work untouched. Cancel and verify consume the remaining 35 visits, ending exactly at work limit 109.

The fixed literal expected digest is `ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad`, independently checked with Python hashlib. Python is used only for test expectation generation, never product hashing.

Every failure keeps the same affine budget and owners. Verification work is reserved before the operation and cancelled after inspecting failure counters. State metadata inspection is bounded and test-only; resume/retry digest verification establishes the state contents. Failed digest cleanup plus successful retry finalization release each original owner once, verified by intermediate live counters and `Budget.finish`.

Validation uses private snapshot `/workspace/issue2-sha-test-build` and fixed image `sha256:b448b89eed11f6ea1b172a5f1280f8ec76e3932bb52ad01b87af487584a7ac7c`, explicit local Docker socket with endpoint/context/TLS selectors unset, network none, UID:GID 1000:1000, all capabilities dropped, 1 CPU, memory 1GiB and no extra swap. Compiler: `/opt/bun/bun-linux-x64-baseline/bun --no-env-file /opt/bend/bend2/main.ts`; native runtime: `+RTS --threads 1 --gpu off -RTS`.

Status: PASS. Final check-only, C emission, native compilation, and native execution all exited 0. All 9 stdout lines matched the golden exactly. API boundary lint passed; core/hash snapshot and final test/helper hashes match the working checkout. The complete commands, return codes, stdout/stderr, and source/C/binary hashes are written to `/workspace/issue2-sha-test-build/build/sha_errors.log.json`. Expected output is `/workspace/issue2-sha-test-build/build/expected_stdout.json`.

No production defect was found while writing the regressions. A test-authoring affine capture error was corrected before final validation. The tests do not replace the required fresh independent review, full mandatory suite/resource rerun, or exact-head CI.

## Exact stdout golden

```text
sha-error-unchanged
sha-error-unchanged
sha-update-work-prefix-resume-abc
sha-update-work-prefix-resume-abc
sha-final-live-refusal-none-retry-abc
sha-final-initialization-refusal-none-retry-abc
sha-final-writes-refusal-some-zero-output-retry-abc
sha-final-exact-neighbor-abc
sha-errors-ok
```

## Evidence SHA-256

| Artifact | SHA-256 |
| --- | --- |
| `/workspace/bend-xt-import-issue-2/tests/core/sha_errors.bend` | `d15a3b1eac22241ad2903b0718bbbfd743dc12f988ef7b6a8e439cbb6138d6b4` |
| `/workspace/bend-xt-import-issue-2/tests/core/lib/buffer_assert.bend` | `f9307ab2f9913336a928cfcdb4855d942df976b241eb19849830e56d74af4a82` |
| `/workspace/issue2-sha-test-build/build/sha_errors.c` | `dcbf2fd2292f34384ba1c5392f85068057351ff949eef6ea0ca82e8398c7d585` |
| `/workspace/issue2-sha-test-build/build/sha_errors` | `ff254ee6bb7ca38e5b1df48e38552f8703b0f4c3eeae555bab8e95fb6e75694a` |
| `/workspace/issue2-sha-test-build/build/sha_errors.log.json` | `931328a3d7cb5677000a0136076b2199b08bb17b6b21b44e966d90bfedabaa13` |
| `/workspace/issue2-sha-test-build/build/expected_stdout.json` | `04f436552c7648fcea3cff91024fc58399c21a8df78559c6f532972b6c7fe471` |

No remaining blocker in this scoped repair. Parent must refresh its mandatory-suite golden and rebuild/rerun fresh evidence before the planned independent re-review.
