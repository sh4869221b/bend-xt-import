# Issue #1 independent implementation review 01

- Date: 2026-11-06
- Reviewer: `/root/issue1_impl_review_1`, independent Astra reviewer requested by the implementation coordinator.
- Base: `5b4643c6714e025bc248fbdbe711d54f747d8fc6`.
- Scope: Issue #1 experiments, tooling, source lock and CI only. No production importer or filesystem substrate is requested by this review.
- DESIGN SHA-256: `b4a598ef5487e64bcfe7593400866ad6664b46f45f172b0020d29491e6f61386`.
- Plan SHA-256: `81b2d5e7ac18c192a8cff7c9abd0cf54541c297c498f708a1c67b2c83c997b62`.
- Plan-review SHA-256: `d6b945cbad5fe5369e1bda6aec3a63f6f27401dc20209f897ef7283f5320ecf8`.

## Disposition

**Changes and verification required; this is not an acceptance review.** Four actionable findings were sent to the coordinator during inspection. Two received code changes while this review was still running; those changes have only been inspected statically here. Final suites, immutable evidence and reporting documents were explicitly still in progress at review start and their absence is not recorded as a new defect. A fresh review should inspect the finished implementation and its evidence after the fixes.

## Findings

### F01 — Medium: publish barrier records atomically

Paths: `tools/runtime/native_entry.py`, `tools/runtime/experiment.py` (ready/result handoff).

The initial implementation used `Path.write_text()` directly on `ready.json` and `native-result.json`. The supervisor tests existence and immediately parses JSON. Creation/truncation occurs before the bytes are completely written, so a valid run can be rejected with a JSON decode error if the supervisor runs during that interval. The final-result handoff is especially exposed because the host polls it directly.

Action: write each record to a separate file and atomically replace its final name, or use an equivalent completion protocol; keep the native child behind the verified pre-exec barrier.

Disposition during this review: the coordinator added `record()` using a temporary file and `Path.replace()`, and both handoffs use it. This addresses the observed race by inspection. Rerun the final suites with this launcher; earlier results do not test the corrected handoff.

### F02 — Medium: exercise cancellation during real file IO

Paths: `tools/runtime/measure.py`, `tests/runtime/native/fault_inject.c`, `tests/runtime/probes/short_io.bend`.

Initially SIGTERM, SIGKILL and timeout tests ran only `memory_pressure`. They therefore did not exercise the plan's read/write interruption cases, partial scratch output, or termination before the IO probe's completion marker. The interposer already supported a `stall` mode but no case selected it.

Action: add bounded, dedicated-cgroup cases that reach a trace-confirmed read/write stall after partial progress, then terminate or time out. Check the actual signal/termination classification, incomplete output, unchanged input/sentinel, empty publication directory, and absence of the success marker. These remain experiment-only cases.

Disposition during this review: `M-IO-read-SIGTERM`, `M-IO-write-SIGKILL` and `M-IO-write-timeout` were added. They require a stall trace and check unchanged input or the exact written prefix. The shared supervisor checks the sentinel/publication directory. Successful execution with the final launcher remains to be verified.

### F03 — Medium: make short-4095 and successful write retries substantive

Paths: `tools/runtime/run_probes.py` (P06 matrix), `tests/runtime/probes/short_io.bend`, `tests/runtime/native/fault_inject.c` (`inject`).

The P06 short-I/O matrix uses a 64-byte read fixture and an eight-byte write payload for every split size, including 4095. For writes, `count <= split`, so the interposer does not shorten the request but still records `short`. For reads, the 64-byte fixture reaches EOF before a 4095-byte boundary. These cases cannot establish correct retry behavior across that boundary. In addition, successful EINTR write/pwrite cases assert only `complete` and exit status; a corrupt, duplicated or missing output could still pass those particular cases.

Action: use a payload larger than 4095 for the 4095 split cases, require trace evidence of an actually reduced request and subsequent progress, and compare exact output bytes for every successful write/pwrite retry case. Do not treat the existence of an arbitrary trace line as proof that the named fault actually changed a syscall result.

Disposition: sent to coordinator; fix and rerun required at the time of this report.

### F04 — Medium: cover the promised caller-side range guards

Paths: `tests/runtime/probes/offsets.bend`, `tests/runtime/probes/affine_arrays.bend`, `tests/runtime/probes/chunk_stream.bend`, `tools/runtime/run_probes.py`.

The approved plan explicitly calls for checked offset/length preflight and logical-length/capacity guard experiments. The current offset probe tests native API behavior only. The affine-array probe usefully demonstrates masked indexing at 65536, but there is no checked caller guard whose rejection is observed. Partial chunk output tests establish length preservation for those fixtures, not rejection of invalid caller ranges. Consequently the planned checked-boundary behavior remains unverified.

Action: add small experiment-only positive/negative cases for `position <= end` followed by `size <= end-position`, including U32 wrap candidates, and array access below/at logical length and capacity. Ensure invalid accesses are rejected before the unchecked native operation. Alternatively explicitly record these planned checks as unverified and do not include them in a completed P03/P07/P08 claim. No shared production bytes library is needed.

Disposition: sent to coordinator; implementation or an explicit narrowed evidence claim is required.

## Cgroup and scope assessment

The inspected launcher creates a dedicated Docker container with memory and swap limits, drops capabilities, uses an unprivileged UID, disables networking, and keeps the host supervisor outside the container. Before releasing `.go`, the host identifies the container cgroup, locates the child using namespace PID information, and independently reads back `memory.max` and `memory.swap.max`. The small Python parent remains charged inside the cgroup, waits for the actual native child with `wait4`, and holds the cgroup open for final event/peak collection. This is a reasonable experiment design; its helper overhead must remain included in cgroup measurements and distinguished from native RSS. Direct binary execution does not acquire those guarantees.

The OOM assertions require both Docker's OOM flag and an increased cgroup OOM-kill counter. This avoids equating every exit 137 with OOM. External termination is classified separately. A cgroup charged-memory limit is not a strict instantaneous RSS theorem, and this review does not certify one.

No production parsing, importing or publishing code was found in the reviewed scope. Python generates/checks fixtures and orchestrates experiments; C provides test injection/co-ordination; the Bend probes perform the exercised arithmetic, ownership, IO and allocation work. Absence of publication code is not proof of a future publication implementation.

## Review evidence and limits

Read DESIGN, the implementation plan, plan review, `sources.lock`, all current Python runtime tools and Dockerfile, package locks, workflow, native test helpers, positive/negative Bend probes and resource probe notes. Work was read-only except for this review record. No heavyweight tests, builds, container changes, external writes or old implementation access were performed. `/workspace/fallout-xml-bend` was not used.

Small read-only checks: every runtime Python file parsed with `ast.parse`, and both package-manifest SHA-256 values matched `sources.lock`. These checks passed; they do not execute or certify the probes.

The coordinator was editing concurrently. These are checkpoint hashes after the F01/F02 code edits were observed, not a claim that all reviewed files formed an immutable tested release:

| File | SHA-256 |
| --- | --- |
| `sources.lock` | `c693e483f90bd8fa08c41f47315f39c7e87c3567869a3940d26758647755b1da` |
| `tools/runtime/experiment.py` | `3f72d5bd59ea53c2422f2d9e2a512cf4d6c4fc2498de7ba25fc4a7fbc0716e2b` |
| `tools/runtime/native_entry.py` | `d659510563852c3da45865fc941c407c5621422a0f5319d2ae0b12f39fcf70c4` |
| `tools/runtime/run_probes.py` | `86e36aace1adb4d5ff94f1b2ffca9c2a836a4fb6f593701fcd3e9ce831f4b155` |
| `tools/runtime/measure.py` | `9e643371a9f3b5a86358f7873df2eab3efc4570070af2b39af5ab2f958ec6fa0` |

Final evidence must establish the actual build/run source linkage, final native results, resource measurements and platform limitations. CI and WSL success have not been established by this review.

The coordinator subsequently supplied `docs/runtime/README.md`, `capabilities.md` and `resource-model.md`; these were also read before closing this review. They distinguish the helper/barrier RSS contribution, cgroup charge, native sampling, synthetic accounting, the limited measured Array charge, unavailable production primitives and unverified WSL. No additional actionable finding was identified in those documentation boundaries. Their quantitative claims still need reconciliation with the final evidence summaries and corrected suite results; this review does not substitute for that check.
