# Independent review: generated-C layout correction

Verdict: no actionable finding. The checker correction is approved at the exact hashes below. This is not native functional/resource acceptance or overall Issue #5 approval.

## Reviewed changes

- `tools/xml/layout.py`: `b71baa6e4e520455616afd303c51763e9f231e855f0f904f5ad2e7ddcff53159`
- `tools/xml/test_evidence.py`: `91204affb59daaf69ca331a926d2cc2efbcb706bf1510bf7564613bb4a4a9bda`
- Explanation, `docs/reviews/issue-5/layout-ci-fix.md`: `3878030c7827c9cfb8208fb0c6eb378473fe717dde0ab960949fbe4437d2b7a5`

The old single substring required a direct accumulator store. The actual pinned full-driver output uses `rfc_seal(e, _acc_0)` at that same tail slot; standalone text output uses the direct store. Inspected both complete generated functions and the pinned emitted runtime's `rfc_seal`: it preserves existing reference-counted terms and wraps an unsealed constructor, without changing the Page-chain operation.

The replacement is stricter than a relaxed substring or optional-wrapper regex. It compares the entire ordered function body against exactly two observed forms, ignoring only indentation and empty lines. Both require all 21 loads with exact types, preservation of slots 0–19, the accumulator in slot 20, advancement over the original tail, Page reconstruction, and the tail-loop control. The reference-count-aware variant additionally requires the exact fixed scratch extent, `ctr_take` width, node-reuse/allocation expression and seals. Wrong values, changed slots, added operations, mixed forms or altered control flow are rejected. The other seven checks and the fixed-scratch check remain present. `summarize.py` recomputes the full inspection, including the new variant field, so a stale/changed layout record is not accepted.

## Independently executed checks

- `python3 tools/xml/test_evidence.py`: **149 rejection regressions passed**, including 33 new layout mutations and both positive forms.
- All **eight** layout checks passed on the current full-driver generated C.
- The standalone text reverse body passed the direct-form check; driver passed the reference-count-aware form.
- Eight additional mutations applied to those actual C bodies were rejected: incorrect empty-list output, incorrect original-tail hop, changed return value and replacing `break` with `continue`, each in both variants.
- No Bend/C compilation, native parser execution or Docker resource run was performed for this review.

Inspected C identities, independently matched to the downloaded CI build manifest:

| File | C SHA-256 | Reverse-body SHA-256 |
| --- | --- | --- |
| `build/xml/driver.c` | `d4e385bc584a7c12f06d7bd0154babb863ede43ddc912fc3ac081d2b1176ab4b` | `4aa69e1bde395f5788e2b60688d214c1ef3d75a6a7b7f1b01392691f57942a29` |
| `build/xml/text.c` | `d0d95a92603f800f901a5c1f7ca217ab00a184916f7f7a67ad21994cdf22f695` | `3a19a724a203b9e4959cfe1dffd08a4a0d3e2fb8861c96435bd752976dfeca24` |

The older local stream C does not match CI's final stream hash and is not treated as final-stream evidence.

## CI evidence boundary

For run `42338187534`, the downloaded build manifest SHA-256 is `c9651937686c8b80abc8e8209704ef2a3e63b46442de05a823ce10f657b2b340`; the environment record is `64342563d51a4e90a034e70446ed764b05bfd0192865dc2e900f965942fd6d02`. Verified their build/input linkage, exact inventory, current test-source hashes, and exit records: all 13 probes completed typecheck, C generation and native compilation; four affine misuse controls failed as expected and their four positive counterparts passed. The environment records clean PR test-merge head `f340a5541aaf34ac9995974824ad580698527a42`.

This clears the prior final-source build blocker in the fixed build environment, including lifecycle. That CI run stopped afterward at the old layout check. The correction still requires a new exact-head CI run; neither these build records nor the checker regressions establish native functionality, physical resource bounds or pinned-producer acceptance. The separate producer gate remains blocked.

Also reviewed the subsequent-CI appendices in `docs/xml/build-diagnosis.md` (SHA-256 `05a627f291af42aed6edb4143cf12cc909694cae13a5d4317ca2c7b01ddb6140`) and `docs/reviews/issue-5/lifecycle-codegen-diagnosis.md` (`deaf6a48a5d22ff082b95b83b6a3ff81090c26b4410ffa8674e5bb80edf54841`). Their inventory, lifecycle source identity, successful build-stage records and merge-head identity agree with the downloaded manifests. They preserve the historical local observations and correctly distinguish build success from skipped later validation. No actionable finding. The archive digest was supplied with the artifact download; this review independently checked the extracted manifest identities rather than re-downloading the archive.
