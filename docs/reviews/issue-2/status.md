# Issue #2 review tracking

Local implementation and validation are complete. Exact-commit CI is a separate PR readiness gate.

- Approved plan review 01: one P1 retention ownership finding, resolved in revision 2.
- Approved plan review 02: no mandatory planning findings.
- Code review 01, core contracts: two P1 findings repaired. Zero-live settlement returns None; SourceOwner/ByteWindow separate logical-source identity from reusable storage. Boundary, source-reuse and ownership controls cover the changes.
- Code review 02, algorithms: one P1 and one P2 repaired. Scalar width metadata permits exact work preflight before scalar inspection; SHA input bounds use actual logical size and bit-length overflow has its own error. Targeted scalar/pending/SHA regressions were added.
- Plan addendum review 01: no mandatory findings in the SourceOwner, scalar-width and zero-live allocation contract changes.
- Code review 03, tests: added buffer, hex and six-budget failure/boundary tests; isolated check/C/native runs passed.
- Code review 04, first complete review: one P2 missing SHA failure-lifecycle matrix. Added update-prefix exhaustion/resume, finalize None/Some refusal cleanup and exact-limit neighbor cases; isolated locked check, C generation, native build/run passed with exact nine-line output.
- Code review 06, second fresh complete review: zero actionable source findings; R1 resolved. Independent lint and 31 evidence rejection / 8 positive controls passed. The final fresh native/resource validation and independent evidence inspection passed.

PR #21 is merged. The branch was fast-forwarded to main da6baa03f97060464658721866d03493fe722540; the merge introduced no content difference from its reviewed correction head. Final review and fresh CI apply to this base.

The generated-C inspection has a separate report and fresh-build checked excerpts. Evidence validation additionally refuses missing mandatory inputs, mixed binary identities, invalid oracle execution profiles and stale summaries. These checks do not replace actual cgroup measurements.

SourceOwner/ByteWindow bind/unbind belong only to trusted stream adapters. #2 uses a synthetic adapter; snapshot-backed refill remains #3. No MOD/XML parser, OS snapshot pipeline or transactional apply is delivered here. The current core-linux-x86_64-c1 profile passed the full fresh summary and independent evidence review; see code-07-acceptance.md and code-07-evidence.json. This certifies only the documented measured shapes.

Final validation: 17 locked check/C/native builds, 16 ownership controls, 6 generated-C checks, 15 native functional invocations, 736 oracle cases, 114 real resource observations, 31 evidence rejection / 8 positive controls, and git diff --check all passed. Four trailing-blank-line removals triggered a complete fresh rerun; the final reviewer verified the new source hashes and results. Peak cgroup memory was 74,215,424 bytes. No compiler/Base/stock probe or Issue #1 evidence changed.
