# Issue #2 concrete contract additions

Status: implementation work; independent review pending. This complements the approved revision 2 plan and does not claim acceptance.

## Logical source and window ownership

A reusable byte buffer's allocation ID is not a source identity. The core now mints a separate affine `SourceOwner` with run/id/totalSize and a live reservation. `ByteWindow` owns that source token, an `OwnedBytes` buffer and an absolute base. Public reads thread the complete window. Root ranges use the token's totalSize, and binding checks base<=totalSize and length<=totalSize-base before forming an endpoint.

Binding/unbinding is a trusted stream-adapter operation, not a general client API. The adapter must establish that replacement bytes came from the same logical source. The #2 adapter exists only in synthetic tests; later #3's verified snapshot adapter supplies actual bytes. Reusing the physical buffer for a different source requires a new source token, so the prior ReadState is rejected. Raw constructors, unchecked helpers and adapter binding are covered by the repository API lint. This is not a language-level module privacy guarantee.

## Scalar inspection preflight

Each ScalarChunk owns both a bounded Array<U32> of Unicode scalar values and an equally bounded Array<U32> of their canonical UTF-8 widths. These arrays share one live reservation. New initializes value=0/width=1; put/append/decode update both; clear retains storage with logical length zero. Width metadata is used only to preflight access, so no scalar value is visited before its full canonical width has been charged. Encoder pending state retains an already inspected scalar and does not repeat inspection on output-full resumption.

Width metadata lookup is a bounded bookkeeping operation, not a logical byte visit; scalar inspection/emission and encoded byte reads/writes retain the plan's normative costs. It is included in allocation charge and performance/layout measurements. Internal emitted-scalar methods are callable only by the trusted codec module after capacity and work preflight. Invalid scalar values cannot enter through supported APIs. Arbitrary raw access would bypass that invariant and is rejected by repository lint outside trusted modules.

This changes the concrete representation and therefore requires separate generated-C inspection, overlap measurements, error-path/exact-limit tests, and calibrated charges. The existing provisional scalar charge is not accepted until those tests pass.

## Settlement with no live owner

Reservation settlement returns `Maybe<Allocation>`. When actual live usage is zero, it returns None and releases ticket metadata. Positive live settlement returns Some with its retained metadata charge. Cancellation cannot leave an uncharged no-op owner. Failure returns the original affine Reservation and unchanged budget.

## Unchanged boundaries

Six aggregate counters, affine ownership and explicit cleanup remain normative. No library helper terminates the process. Error results return owners required for disposal. Codec/hash/format logic remains Bend. This addition does not enable file IO, production CLI, transactional apply or any #3 capability.
