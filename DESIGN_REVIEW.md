# Design review record

Recorded on 2026-11-06 for [DESIGN.md](DESIGN.md), design revision 0.4.

This repository contains the proposed design and this review record. It does not contain an implementation, executable, or executed test suite. Planned checks in the design are acceptance requirements, not test results.

## Evidence and scope

The coordinating design thread reported five independent Astra design reviews, with fixes incorporated and no additional findings in the final two rounds. The publication workspace received the final design and the coordinator's written summaries. It did not receive the five original review reports, individual reviewer identifiers, or the input hashes for each round. This file records that reported outcome and the available findings; it is not a verbatim transcript or an independently reconstructed per-round audit trail.

The final design was transferred from the designated Library document without modification. Its SHA-256 is `b4a598ef5487e64bcfe7593400866ad6664b46f45f172b0020d29491e6f61386` (60,336 bytes).

| Reported review rounds | Available result |
| --- | --- |
| 1–3 | Findings were addressed in revision 0.4. The design header identifies these rounds; the coordinator supplied the issue summaries below. Individual findings cannot reliably be assigned to a particular round from the material available here. |
| 4 | The coordinator reported no additional design findings. The original report was not transferred. |
| 5 | The coordinator reported no additional design findings. The original report was not transferred. |

These five reviews concern the design. Separate reviews of an earlier limited prototype are not counted here and are not evidence for this design's runtime behavior. The earlier alternative design has not been merged into the designated Library document.

## Findings and recorded design changes

| Finding | Required behavior now specified | Design location |
| --- | --- | --- |
| Localized source validation was liable to be confused with checking whether the destination already contains the translation. `Source == Dest` does not imply a no-op when the destination-language baseline differs. | Validate XML Source against the source-language table, then compare encoded Dest with the destination baseline independently. Allocate a new ID only for an actual change. A stale source still fails even if the destination already matches. | §6; localized acceptance cases in §10 |
| A published bundle can contain durable files but an undurable `Strings` directory; output consistency alone does not establish correspondence with the original input. | Sync every file and directory bottom-up, including `Strings`, before publication, and sync both publication parents afterward. Separate bundle integrity verification from provenance verification using original plugin, XML, and table inputs. | §§8–10 |
| Retaining opaque position-dependent metadata can leave offsets or layout information stale after a translation changes the plugin. OFST and CLSZ are concrete hazards. | Scan the whole file using a versioned relocation-safety catalog. Refuse nonidentical plugin rewrites with known hazards or unaudited relevant forms, including equal-length edits; require explicit audited handlers before lifting a restriction. | §5; acceptance cases in §10 |
| String-table aliases and overlapping references can multiply work or allocation far beyond the input size. | Bound physical storage and logical decoded size separately; account for aliases, reject partial overlaps, cache identical spans, and enforce cumulative byte-work, live-allocation, and process-memory limits. | §§4, 8, 10 |
| A process able to write the staging parent can substitute the source name between verification and rename. No-replace rename protects the destination name but does not resolve this source race. | Hold a protected staging-parent directory descriptor, restrict effective write access, use directory-relative operations, and state the trusted namespace and same-user/admin threat boundary. Verify publication and cleanup behavior with fault-injection tests before enabling the capability. | §9; acceptance cases in §10 |

The regressions associated with these changes are specified in the design. No claim is made here that they have been implemented or executed.

## Outstanding evidence

- Preserve and publish the original five review reports if a complete per-round audit trail is required. Reviewer identity, exact input revision/hash, severity, and per-round dispositions remain unavailable in this publication workspace; they must not be invented.
- The runtime, filesystem publication primitives, resource enforcement, compression, and localized bundle handling still require the engineering gates in §11.
- Supported Fallout 4 header versions, contextual fields, repeated-field indexes, and locale mappings require real producer fixtures and independent validation.
- Real MOD, xTranslator, xEdit, and in-game verification remain future work. A scoped design review with no further findings is not proof of compatibility or absence of defects.

The authoritative design and its acceptance gates remain [DESIGN.md](DESIGN.md).
