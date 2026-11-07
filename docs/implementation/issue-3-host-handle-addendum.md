# Issue #3 host handle addendum to implementation plan revision 2

Status: proposed amendment for independent Astra review. This document does not change the approved revision 2 file, authorize a compiler change, or assert that the alternative ABI has compiled or run successfully.

## Reason and requirement boundary

The implementation worker reports that a minimal custom opaque declaration `law H: Type` fails under pinned Bend 2.0.40 with `Error: 1 TODO found.` This result blocks that representation, not necessarily the required filesystem substrate. Preserve the reproducer, exact command, source/compiler hashes and diagnostic in new host evidence. No upstream/compiler/Base/generated-C patch or toolchain upgrade is permitted under this alternative.

Issue #3 (https://github.com/sh4869221b/bend-xt-import/issues/3) requires held directory descriptors, safe OS primitives, input snapshots, trusted private staging, ownership/ACL checks, failure injection and recorded-entry cleanup. Its adversary is another unprivileged account; same-account/admin attackers are explicitly excluded. Neither the issue nor the design requires executing hostile Bend extensions inside the process. The importer is a trusted, reviewed, fixed whole program processing untrusted data, not a sandbox for arbitrary executable Bend code.

Accordingly replace the planned custom opaque-law representation, if the spike passes, with ordinary affine Type wrappers and a checked C registry. This is **not static unforgeability**, and must never be described as equivalent to an unconstructible opaque type. A source author allowed to alter trusted program code could construct a token or invoke native code. Token secrecy, randomness, module naming and lint do not isolate such an adversary. The security claim remains the original external-data/other-UID threat model, with reviewed implementation confinement and dynamic lifecycle checks.

## Representation and trusted boundary

- Distinct ordinary affine `DirHandle` and `FileHandle` Type wrappers contain a bounded registry slot and generation, not a raw fd. Confirm actual quantity behavior in the pinned compiler; do not infer affine behavior from naming.
- The C registry owns fd integers and metadata: generation, resource kind, explicit operation rights, open/busy/closed state and relevant scratch/retention/publication lifecycle. OS identity metadata uses the existing full-width checked limb ABI.
- Constructors, destructuring, token extraction, effect declarations and C marshalling are restricted by repository policy to a small reviewed host implementation module set. Application code calls supported ownership-threading APIs only. Never expose an integer-to-handle conversion or raw-fd accessor. External bytes/arguments/manifests must never supply token fields or registry rights.
- Add API-use lint over all production Bend sources with an explicit trusted-module allowlist; detect constructor and pattern use, raw effect imports/invocations and bypass paths. Include lint positive/negative fixtures and review the full program. Lint is defense against accidental bypass, not a malicious-source security boundary.
- Runtime entry points validate their own inputs even when the Bend caller is trusted. Invalid token handling must not dereference outside the registry, access freed storage or perform an OS operation on a guessed fd.

## Per-effect validation and ownership

Before every effect that accepts a handle, validate slot bounds, allocated entry, generation equality, expected kind, required rights and allowed lifecycle/state. Validate all supplied handles before any side effect in multi-handle operations. Invalid requests return a bounded common error without issuing the target syscall or changing unrelated registry entries. Native marshalling must reject malformed constructor/field shapes rather than interpreting arbitrary terms as valid slots.

Rights distinguish at least input/snapshot read-only file, exclusively created writable scratch file, traversable directory and directories authorized for create/remove/rename. Broad `File` or `Dir` kind checks alone are insufficient. No write/truncate operation may accept an original input handle. The native substrate must preserve OS read-only open flags as a second constraint. Removal/rename remain confined to recorded authorized entries and the protected namespace, not arbitrary names permitted merely by possession of a directory token.

The supported Bend API threads each wrapper exactly once through each call, including recoverable failures. Affinity does not force disposal; all branches need an explicit returned owner or checked-close path. A directory handle borrowed across an operation is returned with the same ownership contract. Registry metadata and in-flight syscall references cannot outlive or conflict with their owners.

At minimum update generation whenever a slot is retired/reused, and reject every stale generation. Never wrap generation: retire the slot permanently or return a resource-limit error at exhaustion. A monotonic nonreusing allocation strategy is also allowed if bounded. Per-effect generation rotation may additionally detect copied extracted tokens; if chosen, perform it consistently for success and recoverable failure, return replacement tokens for all consumed operands, reserve transition resources before effects and test multi-handle aliases. Do not claim such rotation prevents intentional forging by trusted-source modification. The spike must pick and document one concrete transition policy rather than mixing policies silently.

Even with one Bend worker, imported OS effects may execute asynchronously. Protect registry validation-to-syscall lifetime with a tested locking or busy/in-flight discipline appropriate to the pinned runtime. A slot cannot be closed or recycled while an accepted operation uses its fd. Reject duplicate aliases in multi-handle calls when semantics cannot safely support them. Do not hold runtime locks across callbacks that could reenter and deadlock. Verify the actual callback completion model in emitted/runtime C.

## Checked close and failures

Close consumes the wrapper and atomically removes its entry from usable state before/while performing the single close under the in-flight discipline. Save errno immediately. On Linux, close failure including EINTR/EIO must not cause retry against a potentially reused fd. Mark the entry terminal regardless; any underlying uncertain resource condition is reported, never repaired by closing the same integer again. Record errors without restoring a usable token. Distinguish close-only disposal from deletion of filesystem content.

Open/create/register failure paths must not leak newly acquired fds. Reserve a registry slot before acquiring an fd where practical; if acquisition succeeds but result construction cannot complete, checked-dispose the acquired descriptor and report the primary/cleanup error. Creation may already have produced a filesystem entry: preserve the existing ledger/uncertain-residue rules rather than assuming closing the fd removed it. Error results must not silently discard ownership of other valid operands.

## Registry and bridge budget

The registry is bounded and has an explicit measured live-allocation charge. Reserve slots/backing storage before allocation, checked-size growth and construction; include entry metadata, any free-list/index structures, token wrappers, locks/in-flight records and transient result marshalling. Preallocated storage remains charged for its entire lifetime; closing one handle does not refund memory still retained by the registry. Dynamic storage is released only when actually disposed. Exhaustion fails before fd acquisition or external mutation where possible.

The existing six-budget contract, buffer/bridge charges and 1 GiB cgroup enforcement remain in force. Registry size/count/generation arithmetic is checked. A stale-token rejection does not allocate an unbounded error. Leak/balance tests cover success, partial creation, recoverable failure, terminal close and cancellation. Process termination releases OS fds but does not prove application cleanup or durable publication.

## Filesystem and cleanup invariants remain unchanged

No weakening of component-wise no-follow traversal, secure held source parent, owner/mode/access/default ACL checks, same-FS staging, short-IO/error transparency, fsync, no-replace rename or identity reconciliation is authorized. Token indirection does not replace any of these requirements. Two-UID namespace attacks are still tested on the real kernel; token tests alone do not satisfy them.

Input entries can never enter the deletion ledger. `Published` objects are never automatically deleted. RetentionAttempted/RetentionUnknown/protected retention-failure residuals and Retained objects, including all descendants, remain excluded from scratch cleanup even through old dirfds. On transfer success, non-deleting ownership is installed before any subsequent fallible operation. The C registry must not independently offer a generic unlink route that bypasses these policies; enforce destructive-operation eligibility through the reviewed registry/ledger boundary. Closing retained/published handles only releases resources and never deletes data. An uncertain rename/retention outcome must not restore cleanup eligibility or authorize blind retry.

## Required ABI spike and review gate

Before broader #3 implementation, use only the existing locked compiler/Base plus new separately hashed shim sources:

1. Check-only, emit C, compile and run a minimal ordinary affine wrapper with one custom effect. Inspect term packing/unpacking, CID registration, returned ownership and scalar round trips. Demonstrate an actual opened directory is retained through a subsequent relative operation, then checked-closed.
2. Positive and compile-negative tests establish supported wrapper consumption: normal return threading succeeds; direct duplicate wrapper use fails with the expected ownership diagnostic. Separately acknowledge that deliberate field extraction/reconstruction is controlled by trusted code/lint, not by static opacity.
3. Native negative tests: invalid constructor, out-of-range/unused slot, wrong kind, wrong rights, stale generation, closed token, duplicate close, busy/in-flight misuse, alias operands and generation exhaustion. Each rejected operation has zero target-syscall count and leaves unrelated fixture data/handles unchanged.
4. Force OS fd-number reuse after closing a handle, then replay the old token. Verify it cannot read, mutate, close or unlink through the replacement descriptor. Force slot reuse and generation boundary separately.
5. Test prefix IO failures, close-error injection, failure after create before result return, registry exhaustion and allocation failure, and asynchronous completion versus close if the runtime permits overlap. Assert exactly-once disposition and no input write path.
6. Test retention/publication lifecycle rejection even when an old directory token still refers to the inode. Existing two-UID, ACL, no-replace, cleanup-substitution and uncertain-outcome suites remain mandatory later.
7. Record source/lock/compiler/Base/shim/generated-C/binary hashes and actual commands/results. Preserve stock Issue #1 gap evidence unchanged. Review the concrete transition/rights/locking implementation independently with Astra and resolve all findings before adopting the ABI.

This amendment is eligible for adoption only after independent plan review and a successful measured spike. If ordinary wrappers or the custom effect itself are also rejected by the fixed compiler, preserve that distinct failure and report the exact remaining blocker; do not silently modify the trusted Base or substitute a weaker filesystem boundary. Full transactional apply remains disabled pending its original downstream integration gates.
