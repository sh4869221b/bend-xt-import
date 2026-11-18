# Unterminated-reference EOF correction review

Independent review of the isolated lexer correction, 2026-11-07.

The new `finish` arm applies only to an unbroken `MReference` state, after the
existing valid-document arm and before the generic incomplete-markup arm. It
preserves lexical phase 2, reason 6 and expected/observed values, while reporting
the stored opening ampersand position instead of the end of input. Broken states
still return their original diagnostic. Both attribute and content references
share this state; no decoding, accounting or ownership behavior changes.

Removing this single arm reproduces the independently reviewed tokenizer SHA-256
`df557a0a10228956272e79a91b09af3745cc3fda8eed5f896c142bf99574a965` exactly.
The independent literal position suite includes content and attribute EOF
references and terminal-CR controls, across every two-chunk boundary.
No actionable finding in this correction. This is not overall acceptance.
