# Independent Issue #4 implementation review 01

- Date: 2026-11-07.
- Reviewer: independent `gpt-6-astra`, xhigh effort, selected by the coordinator.
- Baseline: `1b0421c15f9724a614a7b7bfae9605ec6456eb05`.
- Design input: approved implementation plan revision 3, SHA-256
  `63e1c55368b4b71e7d9dbe6120b0ca54ee1270f61fab1bc308b9a15030c7d8cb`,
  and its independent plan reviews 01 and 02.
- Initial decision: **Changes required: four actionable findings.**
- Disposition: all four were fixed by the implementation owner. The independent
  fixed-snapshot rereview and complete input manifest are in `code-02.md`.

## Findings and dispositions

### R1 — P2: Public copy input-termination operation rejected by lint

Original location: `tools/plugin/lint.py`, `FUNCTIONS['plugin/copy.bend']`.

`Copy.input_ended` was implemented and documented as public but absent from the
public-function allowlist. A normal consumer's call was rejected as a private
parser API, preventing use of the documented premature-input cleanup path.
The reviewer reproduced this with `lint.problems` against a consumer outside
the plugin modules.

Fix: add `input_ended` to the exact public allowlist and a positive consumer
control. The reviewer reran the original reproduction successfully. Resolved.

### R2 — P2: One resource observation could count as three runs

Original location: `tools/plugin/summarize.py`, resource observation loop.

The summary required distinct case keys, including repeat numbers, but did not
require distinct captured observations. Repeat 1 and 2 could reference repeat
0's observation path/hash while retaining their own valid keys. Invocation,
binary, case, and resource checks would still pass, so the mandatory three-run
measurement could be certified from one actual run.

Fix: the summary now uses a shared `claim_run` set. Every observation must have
a unique canonical path and scratch/run identity, with the scratch name matching
the observation's parent directory. Reused paths, normalized aliases, mismatched
scratch names, and renamed duplicates have rejection controls. The reviewer
verified that both functional and resource observation paths call this check.
Resolved.

### R3 — P2: Unlisted plugin modules inherited private state privileges

Original location: `tools/plugin/lint.py`, `relative.startswith('plugin/')` trust
branch.

Any new file under `plugin/` could call private state helpers and construct a
`Finished` phase. For example, an unlisted consumer could call
`S.replace(scanner, S.with_phase(machine, S.Finished{summary}))`, bypassing the
completed-scan requirement without constructing a raw Scanner. The same call
outside `plugin/` was rejected. This was broader than the reviewed implementation
module boundary and made the helper-access checks ineffective for new consumers.

Fix: trust is now an explicit set of the six reviewed production modules; raw
Scanner/CopyState constructors remain confined to their defining modules. A
negative control places the completion-forgery call in an unlisted plugin module.
The reviewer reran this reproduction and confirmed rejection. Resolved.

### R4 — P2: Nested directory symlinks escaped the input manifest

Original location: `tools/plugin/integrity.py`, mandatory-directory traversal.

The traversal filtered to files before checking for symlinks. Because `rglob`
does not descend a directory symlink, a nested linked directory and its contents
were silently omitted. The reviewer reproduced an accepted `plugin/linked`
directory pointing to another repository directory: changing its helper source
left `inputs()` unchanged. An imported helper through that path could therefore
change without invalidating prior build/evidence identities.

Fix: reject every enumerated symlink before filtering file entries, including
nested directory symlinks. A dedicated nested-directory-symlink rejection control
now supplements the root-directory check. The reviewer verified the changed
traversal and passing regression. Resolved.

## Additional regression requests

The reviewer requested explicit source-identity checks at metadata-only
RecordEnd, GroupEnd, and Complete transitions and after successful scan/copy
completion. The implementation already checked these paths, but the original
foreign-source tests only exercised the first byte-reading operation. The
reviewer also requested a mandatory caller-lowered/zero/invalid-limits matrix,
separate from the actual default-ceiling resource workloads. Both requests were
implemented: five identity-timing contracts and 26 authored limit configurations
at two input chunk sizes. The reviewer independently reran all 55 final lifecycle
contracts and all 52 limit invocations successfully; see `code-02.md`.

## Review scope and independent checks

The review covers every new production plugin module, all new plugin tests and
tools, plugin documentation/profile/workflow, and the additive core metadata
accessor, core API documentation, and core boundary lint changes. Untracked files
were enumerated directly rather than relying on `git diff`.

Production inspection covered authoritative source identity and size, absolute
source-bound spans, parent-boundary arithmetic, first/unique TES4, unknown
signatures and raw flags, XXXX framing and ignored following u16, opaque
compressed bodies and explicit structural-access refusal, fixed stack/count
bounds, sticky failures, scanner allocation ownership, and production-Bend
unchanged copying including pending-byte retention and output handback.

Independent local checks performed during review:

- Core and plugin boundary lints; the evidence rejection suite.
- The 177 authored/seeded fixture grammar self-check.
- 160 additional native differential cases generated with seed `0xA57A`, input
  chunks 7 and output chunks 25. Every event, span, summary, exact copied byte and
  SHA-256 matched the independent oracle.
- 240 additional deterministic source mutations, source seed `0xCAFE` and mutation
  seed `0xBADF04`, with input chunks 5 and output chunks 3. The independent grammar
  classified 72 as valid and 168 as malformed; all native results agreed. Valid
  cases retained exact copy bytes and digests, and malformed cases returned
  format failures with balanced cleanup.

These are local development checks, not locked Docker/cgroup acceptance. Docker
is unavailable in this review environment. Fresh exact-commit plugin, core, and
runtime CI evidence remains required before marking the PR ready. Neither this
review nor the local runs certify compression validity, host IO/publication,
editing, complete Gate B, or real-game compatibility.
