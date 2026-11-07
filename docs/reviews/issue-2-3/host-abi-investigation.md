# Issue #3: literal opaque-law failure and feasible registry design

2026-11-07, revision 2. Investigation only: no registry/alternative production
implementation, compiler/Base/#2 changes, or new runtime claims. The earlier
analysis is archived in `ALTERNATIVES.literal-plan-v1.md`; its broader blocker
conclusion is superseded below. The only added execution remains the reduced
law failure, in the fixed offline image used by the isolated report `/workspace/issue3-abi-gate/REPORT.md`.

**Recommendation: review the affine ADT + private fd registry design below
under the original Issue #3 threat model, keeping the pinned compiler/Base.**
This is a feasible architecture candidate; no compiler modification is shown
necessary for it. It is not yet implemented or validated. Adoption of the
revised host contract/gates requires independent Astra review first. The parent
planning agent owns that addendum; this document is investigation evidence,
not a second implementation plan.

The parent's fresh reading of GitHub #3 confirms protection against other
nonprivileged UIDs, with same-user/admin attacks excluded. It does not require
language-level unforgeability against malicious code inside the same process.
The approved plan likewise explicitly uses trusted implementation modules,
documented APIs, and lint/tests rather than module visibility as a security
boundary (`issue-2-3-plan.md:37`, currently written for #2); its filesystem
threat model is stated at `:102`. Extending that supported-API discipline to
host handles is an explicit reviewable clarification/revision, not an
implicit compiler workaround.

Three separate claims must remain distinct:

1. The exact `law H: Type` encoding is rejected, as measured below.
2. A public scalar-bearing ADT is not absolutely constructorless/unforgeable
   against arbitrary hostile Bend code. Registry validation does not change
   that language fact; the revised contract must not claim otherwise.
3. Neither fact proves original Issue #3 impossible. Audited, lint-enforced
   trusted program code can use affine ADTs without exposing raw fd authority;
   other-UID filesystem attackers do not execute replacement Bend/native code
   inside that process. OS permission/ACL/dirfd guarantees remain mandatory.

## Smallest reproduced failure

`alternatives-evidence/Minimal.bend` contains only this declaration (no Base
import, main, effect or C implementation is needed):

```bend
law H:
  Type
```

The pinned Bun/CLI was invoked separately with `--check-only`, `-o Minimal.c`
and `-o Minimal`. All three exit 1, stdout empty, with exactly:

```text
SOME PROOFS FAIL
Error: 1 TODO found.
The code is incomplete, and not a valid proof yet.
```

No output C/binary exists. Full argv and diagnostics are in
`/workspace/issue3-abi-gate/alternatives-evidence/minimal.json`.
Source SHA-256:
`8a5d5bfc6d2c5530f4cf9423c93331074504fb7b05594a34c522b842a36c2417`.
This is a minimal declaration-level reproducer, not an attempted runnable
resource program. The earlier full handle/effect program fails identically.

At upstream revision `266b02ee40a2ad0c42608db32c08c5c7b6a8f5ae`,
`bend2/bend.ts:3992` counts an unfilled, non-builtin, non-foreign law as a
hole. `main.ts:1064` validates the book and `:1065` rejects the hole;
`:312` does this before output generation. `bend.ts:1034` gives only actual
Base declarations the builtin exemption. This is a loader/checker constraint,
**not an observed emitter rejection of a custom handle**.

Emitter/runtime constraints visible by inspection: `comp.ts:729` gives
non-ADT types a generic BOX layout; `:5358`/`:5359` provide `io_hand` and
`io_hand_v`, with 40 location bits plus 16 auxiliary bits (`:3838`/`:3842`).
That representation is not an arbitrary 64-bit token channel: a proposed
token must fit 56 payload bits, and metadata must continue to use U32 limbs.
The candidate below instead uses ADT fields/limbs and does not use `io_hand`
for registry tokens, so it need not squeeze its generation into this encoding.
`term_triv` (`:3845`) and `term_drop` (`:3926`) do not close a packed handle.
Affine means at most once; dropping a value does not guarantee checked close.
No emitter change is currently demonstrated necessary or sufficient: the
opaque program never reached it. Scalar custom effects already emit/run.

## Proposed representation and authority boundary

Use distinct ordinary `is Type` ADTs for directory/file handles (and separate
read/write roles where helpful). Constructors contain only a registry slot,
session epoch and generation, each U32 or explicit hi/lo limbs. They contain
no fd, pointer, encoded fd or user-supplied path authority. Their constructors,
patterns and token accessors are available only to allowlisted, audited bridge
modules by enforced lint. All supported operations consume an input handle
and return its successor with the result, or explicitly consume it on close.
No public clone, raw-token constructor, raw field accessor or token import
from files/CLI/environment exists. Persisted tokens are not accepted across
processes. Tokens need not be secret or probabilistically unguessable for this
threat model; they must be bounded, validated and never mistaken for fds.
The deployed executable, allowed native code and configuration are trusted
inputs protected from the other UID; the design does not accept attacker-
supplied plugins or replacement program code.

The private native registry stores `{fd, kind, epoch, generation, state}` and
bounded accounting/in-flight data. Only the audited native adapter touches
fd integers. Never cast a token to an fd or pass it to stock File effects.
The registry handles descriptor mechanics; copying/hash/policy/deletion
orchestration and the ownership ledger stay in Bend as planned.

A wrapper can theoretically be destructured and re-created with duplicate
scalar fields, because module aliases are not privacy (`GUIDE.md:504`). Under
the revised contract that code is a lint violation, not supported client
behavior. This is analogous to #2's raw allocation/Array restriction. Registry
checks additionally reject malformed, stale, consumed and wrong-role tokens;
they are defense against bugs/replay, not a sandbox for malicious same-process
native/Bend code. The earlier conclusion requiring a trusted Base extension
does not follow under this supported-program model.

## Concrete bounded registry protocol for review

1. **Initialize.** Allocate a fixed-capacity table and bounded per-effect work
   storage after charging the finalized #2 live budget. No growth on external
   input. A session epoch is allocated monotonically within the process; it is
   not caller-controlled or silently reset. Slots start `FREE`, generation 0;
   zero is never issued. Epoch exhaustion fails before new work. No reuse of
   an epoch while its tokens may exist; no persisted-token API after restart.

2. **Validate before authority use.** Check exact constructor/field shape,
   U32 ranges, slot bounds before indexing, epoch, exact generation, expected
   native kind/permissions, and `LIVE` state. Only after all checks retrieve
   the private fd. Arbitrary/wrong/stale input yields `InvalidHandle` and zero
   syscalls; it must never close, rotate, or settle an unrelated live slot.
   A forged/stale wrapper carries no reservation-settlement authority.

3. **Claim an operation.** Preflight bounded request/result storage and all
   required successor generations before syscalls. Atomically claim involved
   entries `LIVE -> BUSY`; for multi-handle effects validate every operand
   first, reject disallowed same-slot aliases, then claim all or none. Do not
   assume one Bend worker serializes native asynchronous work: protect table
   state with a lock, keep stable bounded work records, and prevent close/reuse
   while any operation owns that slot. Release the lock for blocking syscalls;
   completion retains the exclusive claim until result handoff is committed.

4. **Return ownership on every recoverable result.** Ordinary success, EOF,
   short transfer, EIO/ENOSPC or fsync failure commit `BUSY -> LIVE` with the
   pre-reserved successor generation and return the new handle plus exact
   count/error. The old generation is then invalid. Preflight failure before
   claiming/doing work returns the original handle unchanged. For multiple
   operands, return every surviving owner; do not hide one in an ignored error
   branch or call IO.die. Generation rotation is an extra runtime defense;
   static affine API use plus lint is still the supported ownership discipline.

5. **Open/create capacity and rollback.** Reserve registry slot, creation-ledger
   capacity, result storage and budget before opening/creating. Table full
   means `Capacity` before the syscall. A successful fd is immediately owned
   by its `RESERVED` native record, before later fallible fstat/validation or
   packing. Establish flags, kind and identity before issuing a live token.
   If validation fails, close that new fd exactly once, retire/release its
   record, and report both primary and close errors. Return parent handles.
   For a created namespace entry, Bend records intent before creation and
   records identity as soon as available; identity capture failure leaves an
   uncertain protected residual rather than guessing it is safe to unlink.
   Descriptor rollback is not authorization to delete an entry.

6. **Close is terminal.** For a valid live token, atomically claim `CLOSING`,
   invalidate its authority, call Linux close once, save errno immediately,
   mark `CONSUMED` and settle its native live ownership once on either success
   or error. Never retry close on EINTR/EIO; never restore a live token after
   close failure. A duplicate close fails validation without a syscall, so it
   cannot close a subsequently recycled OS fd. fsync failure still returns the
   live owner for explicit close; neither error permits a success artifact.

7. **No wraparound or ABA.** Use checked unsigned 64-bit generations, carried
   as hi/lo across Bend. Every reuse and rotation requires a strictly new
   value. At maximum generation, ordinary operations fail before syscall and
   return the owner unchanged; terminal close remains possible without
   increment, then the slot becomes permanently `RETIRED`. Exhausted epochs
   similarly prevent reinitialization. No wrap, counter reset, slot reuse with
   the same token, or generation conversion through floating point.

8. **Bridge allocation is part of the proof.** Preallocate bounded return
   terms/error records and effect storage before acquiring new OS resources
   or committing ownership transitions; keep success/close commits allocation
   free. Prefer bounded errno/status fields to allocating error strings. This
   must be demonstrated for the actual generated-C bridge, not assumed from
   a host-only mock. If such handoff cannot be made safe under the actual
   runtime allocation rules, it is a new concrete unmet gate. Process kill/
   runtime-fatal failure closes fds via the OS but cannot promise cleanup or
   a delivered residual report, consistent with the existing crash nonclaim.

## Cleanup and retention remain independent of token validity

Registry liveness authorizes use/close of a held descriptor, **not deletion**.
The Bend creation ledger remains authoritative for exact owned entries,
parent identity, no-follow identity, cleanup eligibility and retention state.
It is bounded/reserved before each creation. Filesystem trust/ACL checks and
recorded dev/ino/type/nlink rules remain unchanged. No registry destructor or
shutdown routine automatically unlinks a path.

Before retention/publish rename, freeze source/subtree deletion eligibility.
On confirmed success, transfer the whole descendant ledger to protected
ownership synchronously before any fallible fsync/close/reporting. Unknown
outcome protects all potentially transferred entries; reconcile through held
descriptors, not absence of a name. Old dirfds never restore deletion rights.
Close errors release descriptor ownership without restoring scratch ownership.
Failed cleanup reports residuals and never targets original inputs, retained
data or a foreign destination. On orderly abort, Bend reconciles outstanding
effects and closes remaining native owners exactly once through an explicit
abort/drain path; the C registry supplies descriptor cleanup, not filesystem
deletion policy. Outstanding/uncertain I/O cannot race drain or reuse.

## Enforced source boundary and validation gates

The lint must analyze the full transitive build/import closure with canonical
name/path resolution, not merely grep for a constructor spelling. Allowlist
the exact bridge files and reject raw construction/pattern/access outside them,
role conversion, duplicate token reconstruction, stock production filesystem
effects, unauthorized foreign imports, and unsafe/dynamic escape routes.
Include adversarial aliases, transitive imports and renamed files in tests.
Audit the small allowlisted Bend/C surface itself; being allowlisted is not
proof. Hash the complete linted source set and compile those exact bytes with
TOCTOU checks. All ordinary and error API paths must have explicit ownership
and reservation accounting. No local/CI bypass or unreviewed native extension
may enter a supported build.

Required gates, still unexecuted for this candidate:

* Pinned check/emit/native probe of distinct affine ADTs, constructor packing,
  full token/metadata limbs and native kind checks. Positive controls plus
  double-use, use-after-close, wrong-role and forbidden-copy/lint negatives.
* Separate pure-wrapper check-only tests from host effect trust. The unchanged
  CLI's `--check-only` rejects custom foreign promises (`main.ts:929`–`:942`);
  emit/build still runs `book_valid`. Record that exact proof rejection and
  separately require successful validated emit/native build. Explicitly revise
  the host gate criteria; do not suppress errors or claim a proof verdict pass.
* Registry tests for stale/forged/out-of-range tokens, kind mismatch, repeated
  close, real fd recycling, small forced generation/epoch exhaustion, table
  capacity, multi-handle rollback, overlapping/in-flight claims and abort/drain.
  Invalid-token tests must assert zero syscalls and unchanged live owners.
* Fail every acquisition, packing preflight, read/write/fsync/close and result
  path; assert handle returns or terminal consumption, exact errno/prefix,
  one-time reservation settlement, and no leaked or wrongly closed descriptor.
  Mock fault tests plus real kernel integration; C sanitizer/warnings layer.
* All original syscall/FS tests: CLOEXEC, no-follow raw-byte traversal, regular
  type rejection without blocking, short/EINTR/EIO behavior, ACL/mode/uid checks,
  no-replace rename, directory fsync and unsupported-profile fail-closed results.
* Actual two-UID namespace attack tests with unsafe negative control, source
  immutability, retention/post-transfer failure/old-dirfd cleanup cases, and
  uncertain outcomes. Registry success does not substitute for these tests.
* Production registry/result-buffer/ledger charge calibration and finalized
  #2 integration with bounded capacity, dedicated cgroup evidence and one
  worker. Separate source/build/extension evidence; keep Issue #1 unchanged.

## Alternatives and final disposition

Raw fd wrappers, tokens encoded as Base File handles, and empty datatypes
remain inappropriate. In particular stock `file_close.c:5` directly calls
`close((int)io_hand_v(f[0]))` without registry validation/status. The recommended
ADT token bridge avoids that entire route rather than trusting callers with
raw fds. A trusted Base extension is an optional different design only if
literal constructorless language-level types are deliberately retained as a
requirement; it is not shown necessary for original #3 and is not recommended
as the next step here.

Measured facts remain limited: custom law fails before emission, double-use
diagnostic appears without an accepted opaque normal control, and independent
scalar foreign effects emit/build/run eight vectors successfully while their
check-only proof verdict fails. The proposed registry/ADT architecture has no
ABI/OS/security/memory validation yet. Recommendation is **independent review
of the corrected contract, then the smallest ADT/registry gate if approved**,
with fixed Base/compiler and no production implementation in this investigation.
