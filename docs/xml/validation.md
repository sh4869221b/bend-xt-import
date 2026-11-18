# XML validation and acceptance status

The production `xml/` modules consume owned byte chunks and perform no IO.
Synthetic test adapters construct bytes in memory. File acquisition and publication
are separate host responsibilities; parsing never modifies a plugin.

## Reproduce the locked technical gate

Run as an unprivileged Linux x86_64 user with local Docker access and observable
cgroup v2. The compiler/build container is separate from every native measurement.

```sh
python3 tools/core/lint.py
python3 tools/xml/lint.py
python3 tools/xml/test_evidence.py
python3 tools/xml/bootstrap.py
python3 tools/xml/run.py
python3 tools/xml/measure.py
python3 tools/xml/summarize.py
```

`bootstrap.py --reuse-images` verifies existing locked images instead of rebuilding
them. It still rebuilds the exact XML inventory and verifies compiler, package,
Base, source, generated-C and native-binary identities. It uses separate C
emission and Clang processes with the pinned compiler's exact CPU flags; see
[build diagnosis](build-diagnosis.md). No compiler or runtime source is patched.

The GitHub `Bend XML` workflow runs these commands and uploads `build/xml/*.json`
and native observations in `runs/xml/`. Runtime probes use one worker, GPU off,
1 GiB cgroup memory, swap zero, no network, a read-only root filesystem and no
privileges. The observer runs outside the program's cgroup and records its exact
process, image, pre-exec limits, exit, RSS, memory peak and OOM counters. The
resource matrix repeats each case three times. Compilation has its own 4 GiB cap.

The finite inventory includes:

- Input/UTF-8 normalization, exhausted-chunk handoff and invalid replacements.
- Lexical syntax, independent Expat decoding plus a separate closed-schema
  specification, fixed adversarial cases and seeded generated cases. Every short
  corpus fixture is tested at every two-chunk boundary, plus uniform schedules.
- Literal original-byte Entry/Field/Fuz/Params spans, source keys and error entry
  starts, including BOM, multibyte text, CRLF, CR, references and CDATA.
- Exact source/depth/entry/text/name/reference/Fuz limits, replayed exact and
  one-under cumulative work, and independently searched live-budget neighbors.
- Affine negative controls with matching valid controls, every-byte caller
  abandonment, failed-call retries, retained entries and repeated create/drop.
- Streamed 1/16/64 MiB sources, page boundaries, ASCII/Japanese/non-BMP text,
  a one-MiB entry, 200,000 promptly released entries, and the actual grammar
  depths. This is not a claim that arbitrary depth-64 XML is valid.

Generated-C anchors check the fixed FSM, owned pages, reversal and tail-oriented
loops. They are regression observations, not an independent general stack proof.
Native measurements must also pass the fixed plus charged-shape allowances and
the bounded stream-growth check in [profile.json](profile.json).

Evidence validation rejects partial, missing, duplicate, stale or mixed reports,
changed inputs/C/binaries, failed measurements, reused process observations and
forged producer status. Test-adapter input initialization is accounted separately
when comparing work across chunk schedules: core buffers initialize a
power-of-two capacity, so raw total work need not be partition-identical.

## Local development is not locked acceptance

```sh
python3 tools/xml/develop.py --cc /path/to/clang-19 --library-path /path/to/clang-libraries
python3 tools/xml/differential.py --all-boundaries
python3 tools/xml/limits.py
python3 tools/xml/positions.py --all-boundaries --output runs/xml/positions-local.json
```

The developer runner verifies the locked Bend/Bun bytes but does not certify the
host userland or cgroup limits. Missing Docker/cgroup facilities mean **not run**,
not pass. Rebuild after any production or harness change. Large generated source
checks use `stream`, never an oversized command-line argument or whole-file DOM.

## Separate producer-export gate

The actual pinned-producer export requirement remains blocked. No captured,
intact export with a verified xTranslator 1.6.0 build identity is currently
available. Public real-file compatibility was checked separately; the file's
producer version and redistribution permission are unknown. Its bytes are not
included in the repository. See [provenance research](producer-fixture-research.md)
and [comparison metadata](real-file-comparison.json).

A successful technical summary therefore records
`technical_validation_complete: true`, but keeps `complete`,
`acceptance_complete` and `issue5_complete` false, with an explicit producer
blocker. A green technical workflow does not silently satisfy that requirement.
A future real fixture requires a reviewed capture manifest, permitted verification
access, producer identity, input/output hashes and the same independent comparisons.
It may remain outside the repository: redistribution permission is needed only
if its bytes or protected text are distributed. The earlier plan's redistribution
wording applies to vendored fixtures, not a verification-only public download.
This PR remains draft unless that requirement is satisfied or its scope is
explicitly resolved. No merge is performed by this work.
