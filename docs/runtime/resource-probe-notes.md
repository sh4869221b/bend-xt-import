> Historical implementation notes for the small initial probe subset. For current full-suite results, use [capabilities](capabilities.md), [resource model](resource-model.md), and `evidence/`.

# Resource probe contracts

These are isolated Issue #1 experiments, not production resource accounting or
an importer library. Their first smoke runs use the pinned Bend source through
`bend-xt-runtime:issue1` (image ID
`sha256:b448b89eed11f6ea1b172a5f1280f8ec76e3932bb52ad01b87af487584a7ac7c`).
Generated binaries and local smoke logs belong under `build/resource/`, not the
coordinator's `build.json`. No measured representation cost is assumed below.

All numeric arguments are decimal U32. Bad argument shapes/numbers or limits
outside the documented workload bounds exit 2. The accepted native prefix is
`+RTS --threads 1 --gpu off -RTS`. Use an external wall timeout as well.

## budget_work

| Arguments | Behavior |
| --- | --- |
| `selftest` | Thirteen fixed reserve/release/multiplication/work boundary assertions; exit 70 on disagreement, 0 on success |
| `reserve LIMIT USED COST` | Reject invalid USED or COST beyond remaining budget before addition; print new used on success; exit 5 on rejection |
| `release USED COST` | Reject underflow; print remaining used on success; exit 5 on rejection |
| `multiply LIMIT COUNT STRIDE` | Check division bound before multiplication, including zero stride and U32 overflow cases |
| `work PASSES BYTES LIMIT` | Construct a List containing `i & 255` for `i=0..BYTES-1`; debit one visit before each actual element visit, without resetting between passes; print remaining and wrapping checksum on success |
| `allocation LIMIT COST CYCLES` | Reserve synthetic COST before each real 1024-cell Array allocation, consume array, release charge, repeat; print reservation, checksum and remaining charge (0) |

Work PASSES and BYTES are each at most 65536; allocation CYCLES at most 1000.
`work 3 4 12` should print `remaining=0` and `checksum=18`; limit 11 must exit 5.
Counter tests near 256MiB, 1GiB and UINT32_MAX are **synthetic accounting tests**,
not allocations of those sizes. COST in `allocation` is deliberately supplied
by the caller: it is not the measured cost of 1024 cells. Rejection must produce
no `reserved=` or `allocated-checksum=` line. No array is allocated in that
branch. Multiple-buffer charge calibration and real 256MiB budget feasibility
remain coordinator measurements.

## memory_shapes

Arguments: `MODE DEPTH CYCLES HOLD_MS`. Capacity/count is exactly `2^DEPTH`,
not DEPTH or a packed-byte count. Bounds: mode 0..7, depth 0..24, cycles 0..1000,
hold 0..10000 milliseconds. A depth of 24 is a **workload guard**, not a promise
that the shape fits the memory ceiling. Use small depths for smoke runs.

| Mode | Live payload at marker | Post-hold checksum |
| --- | --- | --- |
| 0 | Baseline, no payload marker | 0 |
| 1 | Touched `Array<U32>` | sum of `i & 255` modulo 2^32 |
| 2 | `List<&2,U32>` | same sum |
| 3 | `Array<Index>`, three U32 fields: offset=i, size=i&255, flags=1 | sum of all three fields modulo 2^32 |
| 4 | String of ASCII `a`, count codepoints | count |
| 5 | String of Japanese `日`, count codepoints | count |
| 6 | String of non-BMP `😀`, count codepoints | count |
| 7 | Input List + Array + reconstructed output List simultaneously | three times the byte-value sum modulo 2^32 |

Modes 1..7 emit `live=...`, sleep HOLD_MS with the payload needed by the
continuation, then traverse/consume it and emit `released-checksum=...`.
After that they sleep HOLD_MS again before the next allocation cycle.
The trailing marker is `complete`. Thus an observer can sample live and released
phases over repeated cycles and compare allocator retention. "Released" means
the Bend payload has been consumed, **not** that the runtime returned pages to
the OS. RSS/cgroup retention and a bounded long-run plateau still need measuring.

Mode 7 deliberately retains the input across conversion, calls explicit
`Array.clone`, converts the second array through `Array.to_list` (quantity &1),
and reconstructs the result as quantity &2. Conversion temporaries and clone
may peak before the live marker, so use process/cgroup peak data as well as phase
samples. This is a conservative simultaneous-representation experiment, not a
zero-copy implementation or a proven upper bound for all IO paths. C effect
scratch buffers are **not** represented here; measure the real binary/chunk IO
probes separately. General nested/boxed index shapes, all tuple widths, all
non-power-of-two logical lengths and large producer data are uncalibrated.

For DEPTH=8, expected checksums are: mode 0=0; modes 1/2=32640; mode 3=65536;
modes 4/5/6=256; mode 7=97920. The fixture lengths, string codepoints and expected
integer sums must also be checked by the external harness, not only by Bend.

## memory_pressure

Arguments: `ARRAY_COUNT DEPTH HOLD_MS`, bounded to 512 arrays, depth 24 and
10000ms per pause. It is finite even if the external observer fails. Each array
has `2^DEPTH` cells, explicitly written with `i xor array_index`. Each is retained
in an affine List of Arrays; the program emits `retained=N` and pauses after
each allocation. At the end it emits `all-live=N`, pauses, traverses every
array, prints the wrapping sum as `released-checksum=...`, then `complete`.
The arrays remain needed until that final traversal; previous arrays are not
discarded to simulate growing memory use.

**Never run a stress case outside a dedicated, verified 1GiB memory.max,
swap.max=0 container/cgroup.** Finite fuel does not make the maximum invocation
safe on an unconstrained host. The Bend program cannot verify that OS isolation;
the coordinator's launcher must enforce and read it back before exec. An OOM
or signal may prevent final output; stdout alone does not distinguish them.
Correlate exit/signal with cgroup events and peak memory externally. The small
smoke `2 8 1` should finish with checksum 65280 and does not test OOM.

## Affine negative controls

`negative/array_reuse.bend` and `negative/file_reuse.bend` must fail check-only
with `consumed more than once` for the intended Array/File binder. Their
`*_control.bend` counterparts must **pass**, establishing that each failure is
ownership-related rather than malformed syntax. Do not classify every source
under `negative/` as expected failure. The controls were check-only, not run;
the File control requires an `input.bin` if someone chooses to run it.

## Evidence and remaining work

All three probes built natively with the pinned image. Array/File negative
cases rejected the intended binder, and both controls passed. Small native smoke
runs passed: all modes at depth 8/two cycles returned the checksum table above;
`selftest` printed all thirteen labels; work 3/4/12 returned 0/18 and work
3/4/11 exited 5. Two initial docker invocations timed out **before exec**
(container inspect showed Created, PID 0, zero StartedAt); starting those same
containers completed both cases with the expected results. They are not counted
as runtime timeout tests. No probe process was left running.

`build/resource/final-smoke.json` records the final subset: reserve/release/
multiply rejection (exit 5), two real allocation/release cycles (checksum 4096
each), allocation rejected before its marker (exit 5), invalid work size (exit
2), and small pressure (checksum 65280). Other smoke outputs are in the session
tool transcript. These uncommitted build artifacts are local evidence, not a
long-term CI record. The coordinator should capture equivalent results through
its evidence runner and independent oracle.

No representation charge formula, maximum supported input size, 256MiB live
budget feasibility, long-run retention plateau, OOM, allocation-failure
injection, kill cleanup or WSL result is established by the small smoke tests.
Native process RSS, virtual size and cgroup charged memory remain distinct.
Publication code is absent; these probes do not prove atomic publication.
