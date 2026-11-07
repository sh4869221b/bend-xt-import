# Publication editorial record

The public plan and selected review reports now use ordinary repository roles,
remove machine-specific checkout paths and omit execution-coordination details.
XML parent-role terminology, requirements, findings, test results and historical
reviewed-source hashes are unchanged. The original approved plan remains
byte-identical; the public copy has a new identity:

- Original approved plan SHA-256: `8e1d6401f2b62a7adaa2d8e7e2611fd04d80929430f2271527748448dc257206`.
- Published plan SHA-256: `8b20f9f9dfa412c0dabb898fe6afc27e8f7aa52e90a4e9ecba4fe550b10d0531`.

`publication-editorial-hashes.json` records each edited document's original and
published hashes. Existing review records still identify the exact historical
source they reviewed; they are not retrospectively attributed to the edited
plan copy. This is a documentation-only change, with no source or test change
and no compiler execution.

The public plan also matches `docs/xml/validation.md`: permitted verification-only
acquisition of an export does not require redistribution permission. Permission
is required when fixture bytes or protected text are vendored or distributed.
Verified pinned-producer identity and intact export evidence are still missing;
`producer_export` remains `blocked_missing_fixture`, and `acceptance_complete`
remains false. This clarification does not turn real-file compatibility or
synthetic results into producer acceptance.

## Independent editorial review

No actionable finding. Compared all nine published documents with the preserved pre-edit copies, verified every before/after hash in the manifest, and checked that all historical 64-hex source-hash literals are unchanged. The original approved plan remains byte-identical. The changes preserve technical requirements, findings, test outcomes, XML parent-role terminology and the separate blocked producer gate. The verification-only permission clarification matches the reviewed validation contract and does not authorize redistribution or claim producer acceptance. No compiler or test execution was performed for this documentation-only review.
