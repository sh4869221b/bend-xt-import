# Independent review: strengthened ownership and text tests

Verdict: no actionable source finding. Native compilation/execution of these exact revisions remains the next validation step; this review did not start a compiler.

Reviewed:

- `tests/xml/text.bend`, SHA-256 `3d4c4333ed926d27692f63084fb1ec956e453ab2a9385cc549292b53b8b35447`.
- `tests/xml/ownership.bend`, SHA-256 `1b76ee21e5015e544926f5a7f4b0cd0ca0f79be0c47006f17c0e2bcf309a1450`.

The text test constructs three full linked pages and a one-scalar current page. The period-53 pattern gives each page a distinct starting phase, so the full traversal detects reversal, repetition, replacement and loss rather than accepting identical page contents. It checks every scalar, terminal exhaustion, literal length/byte metadata, and disposal after 0, 1, 4096 and 4097 reads. Independently checked the accounting against current core/XML charges: live 630784, no holds, initial work 28673 and one additional work unit per ASCII read. Each successful case finishes its budget; failure paths cannot turn an incorrect value/accounting check into the sole success marker.

The ownership test checks successful acquisition/release; failed Active release against another run with retained original run/serial and recovery through the original budget; failed settlement converted to a Reserved residual; a second wrong-run cancellation retaining that reservation; and eventual original-budget cancellation. Expected paths finish both budgets. Zero-amount refusal and low-live refusal require literal error shapes and clean budgets. Unexpected branches return false and cannot emit a success marker. No production source was edited during this review.

## Binder-order revision follow-up

Re-reviewed `text.bend` at SHA-256 `808dc7c5494bb17342a01d4af7af0c38e7d70830286508c7693d8bafd1892689` and `ownership.bend` at SHA-256 `b8a2c28baa9bc7c529b1e78df13185e44585a91886c440f49b07c0d1e62ba071`. Moving the fuel match before tuple destruction in text traversal/filling preserves every operation and assertion. Extracting `active_ready` and `started_mode` preserves ownership operation order and residual recovery. No new actionable source finding; these exact test revisions still require their scheduled native validation.
