# Reproduce the Issue #4 framing gate

The pure framing/copy API is documented in [api.md](api.md). This gate is separate
from core, host IO, XML and stock-runtime evidence. It adds no CLI or publication
path. Only the final exact-commit CI artifacts establish locked acceptance; local
native development runs are explicitly marked incomplete.

## Mandatory checks

On a non-root Linux x86_64 host with local Docker and observable cgroup v2:

```sh
python3 tools/core/lint.py
python3 tools/plugin/lint.py
python3 tools/plugin/test_evidence.py
python3 tools/plugin/bootstrap.py
python3 tools/plugin/layout.py
python3 tools/plugin/run.py
python3 tools/plugin/measure.py
python3 tools/plugin/summarize.py
```

Bootstrap verifies the existing compiler/Bun/package locks without changing Base
or the compiler. `--reuse-images` permits existing verified locked images; current
sources and all native entrypoints are always rebuilt. The original core and
runtime workflows remain independent required regressions for the same commit.

The parser workflow retains `build/plugin/*.json`, observations and stdout/stderr
under `runs/plugin/`. Every suite is bound to an exact input manifest, generated
C/native binary hashes, build and image identity. Missing, duplicate, partial,
mixed-build, modified or development-only evidence cannot pass the final gate.

## Coverage and limitations

- 177 authored/seeded wire fixtures include TES4 placement, raw/unknown metadata,
  nested and empty groups, bounds/trailers, ordinary and XXXX framing, deleted
  records, opaque compressed records, HEDR counts and original master order.
- 174 small fixtures run with eleven input/output chunk-size pairs: 1,914 native
  differential cases. They compare every event field and source span, exact
  malformed reason/offset, complete copied bytes and independent SHA-256. Large
  65535/65536 fixtures use a bounded native synthetic generator instead of a huge
  argv/List representation. Resource copies are verified byte-by-byte in the
  native sink and again against independently generated Python digests.
- 26 authored lower/zero/invalid-limit configurations run at input chunks 1 and
  25, including exact/over source, payload, record, object, subrecord and depth
  ceilings. Together with the structural matrix this is 1,966 oracle runs.
- Affine negative checks reject duplicated Scanner and CopyState owners, with
  paired positive controls. 55 exact lifecycle contracts exercise ownership-return, terminal,
  source/refill, capability and budget behavior, including foreign-source windows
  before byte-free record/group/end transitions and after successful scan/copy. Every expected parser error
  must clean up to successful `budget.finish`; a correct diagnostic alone fails.
- 24 resource shapes run three times each (72 measurements). These include depth 0/1/64/65,
  1/16/64 MiB scan/copy streams, the 256 MiB source boundary, two million records,
  eight million subrecords across several records, the next item/byte refusals,
  the stored-payload boundary, 65535/65536 encodings, and repeated contract/error
  lifecycle runs.

The scanner retains two fixed 64-cell U32 arrays, fixed metadata and one event.
The copier retains that same scanner allocation and one reusable output buffer;
it does not retain a full file or event tree. `profile.json` reserves 65536 bytes
for the combined scanner/copy shape plus the core's 4096-byte allocation metadata.
The independent shape measurement adds existing core buffer/source/SHA charges.

Measurements establish a dedicated 1 GiB cgroup with swap disabled before native
exec. The supervisor is outside the cgroup; a small launcher/reaper is inside.
Final wait4 RSS includes its pre-exec high-water mark, while cgroup peak includes
kernel/cache/shared-page accounting. Neither metric equals the logical live
budget. Each shape must fit twice the measured baseline rounded to MiB plus its
declared live charge, and the 1/16/64 MiB streaming peak variation must remain
within 16 MiB. An unavailable measurement, timeout, OOM or memory-limit event is
not a passing budget refusal.

The limits are independently checked ceilings, not a promise that every maximum
can be combined within one cumulative work/live budget. A full 256 MiB no-op copy
plus acquisition/verification may exhaust the shared work budget; the size gate
uses a bounded scan, while measured full copy streams are at most 64 MiB. No
compression stream validity, game compatibility, host snapshot integrity or
publication safety is certified here. All test fixtures are project-authored.

For a local smoke build without Docker, use `tools/plugin/develop.py` with the
locked Bend/Bun paths and a local Clang, then `tools/plugin/oracle.py --local`.
The development manifest is deliberately not accepted by the CI summary.
