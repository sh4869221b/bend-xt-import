# Issue #2 independent full implementation review 02

Review date: 2026-11-07. Repository: `/workspace/bend-xt-import-issue-2`; branch `issue-2-core`; base/HEAD `da6baa03f97060464658721866d03493fe722540` after PR #21 merged. Issue #2 files are uncommitted in this snapshot.

## Code verdict

**Zero actionable findings in the reviewed source snapshot.** Full runtime acceptance and exact-commit CI are pending; this verdict does not certify either. No production correctness, ownership, arithmetic, codec, hash, evidence-harness or workflow defect was established by this independent pass.

This review read all core/hash modules, all core Bend tests and ownership controls, all tools/core Python modules, docs/core, revision 2 plan and concrete contract addendum, generated-layout inspection notes, and the core workflow. It independently traced checked arithmetic and capacity limits, storage access preflight, six-budget reservation/settlement and disposal, source/window identity and cross-window assembly, scalar width metadata, strict codec transitions and pending output, SHA compression/padding/length/accounting, digest/hex failure ownership, and evidence/build/resource identities and inventories. Issue #3 implementation is outside this review.

The supported API boundary is a repository policy, not hostile-source isolation. Raw constructors and internal transitions are prohibited outside trusted code by the documented lint boundary. The review assessed callers obeying that contract, including maintaining the same input/index while encoder output is pending and using one budget across a run.

## Prior R1 resolution

Review 01 R1 is resolved in source. `tests/core/sha_errors.bend` now exercises update work refusal before any input and after two bytes, checks retained prefix metadata and input content, cancels held validation work, resumes the remaining input, and compares all 32 digest bytes against SHA-256(abc). It also exercises finalize live refusal, digest-initialization work refusal, and refusal of the final 32 writes after a digest owner exists. The latter checks all 32 output bytes remain zero and retains an unpadded SHA state for a successful retry. Each path checks used/held balances and disposes returned owners; an exact-success neighboring case is included.

The mandatory functional suite and three-repeat error-lifecycle resource group both already invoke this entry point. `checks.py` now requires all nine completion lines, including the final `sha-errors-ok`. The reviewed SHA test hash is `d15a3b1eac22241ad2903b0718bbbfd743dc12f988ef7b6a8e439cbb6138d6b4`. Its native result remains to be confirmed by the fresh build/run; source review alone is not that confirmation.

## Evidence hardening review

Mandatory source presence, source/build/binary fingerprints, complete case inventories, observation containment, oracle execution-profile checks, and invalidation of old successful summaries are coherent. The six emitted-C checks are tied to the current build and the final summary re-inspects their exact excerpts. The resource checker keeps cgroup peaks distinct from wait4 RSS, includes the documented launcher baseline, applies the profile allowance and independent 1 GiB ceiling, rejects ceiling/oom events, and requires three repetitions and bounded 1/16/64 MiB streaming growth. None of these code checks substitutes for actual measurement.

Independent commands executed successfully:

- `python3 tools/core/lint.py`: core API boundary lint and policy controls passed.
- `python3 tools/core/test_evidence.py`: 31 evidence rejection regressions and 8 positive controls passed.

No full build, Docker invocation, native test, resource measurement, or shared-output mutation was performed by this reviewer. Existing build output was only inspected for current status; no prior run was promoted to acceptance. No repository source was modified, and Issue #1/upstream/sources.lock were preserved.

## Snapshot and remaining gates

`/workspace/issue2-full-review-02-manifest.json` records 78 source/supporting files with SHA-256 hashes. Manifest SHA-256: `d0e3b322854889bf1456a81f2df2f30193edb7ef2ee90d3f025f2e205533c9fd`. A final comparison before writing this report found no changed file hashes. Build-output files are intentionally excluded from this source manifest.

Remaining acceptance evidence: complete fresh 17-entry-point locked check/C/native build and 16 ownership controls; six generated-layout checks for that build; all 15 functional invocations and 736 independent oracle cases; the full 114-case resource matrix; successful fresh summarize validation and inspection of actual memory/streaming results. Finally, the reviewed commit must receive successful applicable CI before the PR is made ready under the user's workflow. Runtime failures or later source changes require their own review/fix follow-up. Transactional apply remains disabled and Issue #3 remains a separate task.
