# Core charge profile and required evidence

`profile.json` and `core/charges.bend` define `core-linux-x86_64-c1`. A build is
accepted only when `tools/core/summarize.py` validates complete fresh functional,
ownership, oracle and resource evidence. Constants by themselves are not an
acceptance result. Issue #1's observations remain unchanged and certify none of
these new wrappers/codecs/hash states.

| Owned shape | Charge before allocation (excluding shared budget state) |
|---|---|
| OwnedBytes | max(65536,16*capacity) + 4096 owner metadata |
| ScalarChunk value+width arrays | max(65536,32*capacity) + 4096 metadata |
| SHA state/schedule | 65536 + 4096 metadata |
| SourceOwner | 4096 metadata |
| Outstanding reservation | requested live + 4096 metadata |

Budget state has a fixed 65536 charge. Capacity is a checked power of two, at most
65536. A zero-live settlement returns no owner. Copies overlap with their source
and have a separate full charge. Empty buffers still reserve minimum capacity.
The concrete U32 payload is four bytes per array cell; width metadata doubles the
scalar arrays' payload. Generated C and native binary hashes are in build.json.
The conservative remainder covers wrapper/continuation/allocator overhead for
these measured shapes; it is not a general arbitrary Data/String/List allocator.

The resource matrix runs each shape three times under a dedicated 1 GiB cgroup v2,
swap=0, one worker, GPU off. It includes baseline, 1/2/3 overlapping buffers,
0/1/255/257/65535/65536 logical lengths, repeated allocation/drop cycles, maximum
accepted full/small buffer counts and the next allocation's refusal, scalar
value+width/source/output overlap, retained codec buffers, SHA+buffer/final digest,
error lifecycles, and 1/16/64 MiB streams. A host without observable cgroup enforcement
fails the gate. No unavailable measurement or failed test is a skip-pass.

The host observer establishes the native child and cgroup before releasing the
exec barrier. Compiler and host supervisor are outside that cgroup. The fixed
Python launcher/reaper is inside; wait4 maxrss includes its pre-exec high-water
mark. Native /proc samples are separately tagged. Cgroup memory also includes
kernel/cache/shared-page accounting and is not equal to RSS or logical live charge.

The validator reports every measured peak and baseline. Its fixed-process allowance
is twice the measured baseline rounded to MiB; each shape must remain within that
allowance plus its declared live charge, and below the independent 1 GiB ceiling.
1/16/64 MiB stream peak growth must stay within the profile's 16 MiB bound. These
are empirical acceptance bounds on the locked profile, not mathematical peak-RSS
proofs or measurements of arbitrary large MOD/strings/index shapes. Byte-work
accounting is validated independently of memory observations.

Reproduce from a clean checkout with local Docker access:

```sh
python3 tools/core/lint.py
python3 tools/core/test_evidence.py
python3 tools/core/bootstrap.py
python3 tools/core/layout.py
python3 tools/core/run.py
python3 tools/core/measure.py
python3 tools/core/summarize.py
```

An existing verified locked image can be reused with bootstrap's `--reuse-images`;
all current source inputs are still rebuilt. Never reuse stale native binaries.
New build/evidence files live in `build/core/` and `runs/core/`, independently of
Issue #1's manifests. The CI artifact `core-evidence-<sha>` contains actual results,
compiler/source/binary identity, git head, dirty-checkout flag, platform, limits,
UID, observations and complete inventories. The workflow does not enable apply.

Unsupported until separate measurement/integration: C/List IO bridges, arbitrary
nested indices or full text builders, other architectures/backends, WSL, multiple
workers, larger capacity windows and host snapshot/publication operations. #3 must
repeat calibration with its actual native bridge/ledger/ACL representations.
