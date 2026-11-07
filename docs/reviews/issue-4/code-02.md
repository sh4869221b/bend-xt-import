# Independent Issue #4 implementation review 02

- Date: 2026-11-07.
- Reviewer: independent `gpt-6-astra`, xhigh effort, selected by the coordinator.
- Baseline: `1b0421c15f9724a614a7b7bfae9605ec6456eb05`.
- Input: the frozen working-tree implementation, including the final README
  correction, approved plan revision 3, and plan reviews 01/02.
- Review input manifest: 68 files, SHA-256
  `d8af8e56a6c68fe960256e2bfd0f5fea65383aa0c3a0d7a6b5e5d5f656aba211`.
- Parser acceptance input manifest: 58 files, SHA-256
  `372c34a1bfbdcd9cf16b113392fc0711eadfbfc628ee875fc06a53991a3a92ab`.
- Decision: **No remaining actionable implementation or test findings within
  Issue #4's pure framing and unchanged-copy scope.** Locked acceptance remains
  pending fresh exact-commit CI, as described below.

## Fix verification

All four findings from `code-01.md` are resolved:

1. Copy input termination is available through the supported consumer API and has
   a positive boundary control.
2. Distinct resource repeats require distinct canonical observation paths and
   captured scratch identities. The summary checks both functional and resource
   observations using one shared seen set; duplicate/aliased observations fail.
3. Private state/helper trust is limited to the six named implementation modules.
   An unlisted plugin consumer cannot forge completion through phase helpers.
4. Input enumeration rejects nested directory symlinks before filtering files,
   preventing imported source changes from escaping the manifest.

The reviewer independently reran the direct R1/R3 reproductions and the complete
46-case evidence rejection suite, including R2/R4 regressions. No production
parser/copier change was needed to resolve these findings.

The additional regression requests are also complete. Five explicit tests now
swap source identity before byte-free RecordEnd, GroupEnd, and Complete
transitions and after successful scanner/copier completion. Each test verifies
its starting phase before introducing the foreign source, then requires sticky
ForeignSource and balanced cleanup. The mandatory oracle now includes 26
lowered/zero/invalid-limit configurations at two input chunk sizes, covering all
six caps, exact/over boundaries, zero caps, above-default caps, and inconsistent
record/object limits. Expected refusal reason and offset are authored explicitly.
The README now distinguishes implemented FO4 structural framing/copy from the
still absent XML/import/publication paths.

## Final independent checks

On the frozen reviewed source:

- Core and plugin boundary lints passed.
- All 46 evidence rejection regressions passed.
- All 55 native lifecycle/ownership/budget contracts were independently rerun and
  matched the exact ordered marker inventory.
- All 52 native lowered/zero/invalid-limit invocations were independently rerun.
- Every saved result in the final 1,966-case local oracle run was independently
  revalidated against current source-manifest, native-binary, fixture and argument
  identities, exact event/span/summary expectations, malformed reason/offset,
  copied bytes, SHA-256, and cleanup markers. Its development-only acceptance flag
  remains false and cannot satisfy the locked acceptance gate.
- All eight generated-C stack/ownership shape checks passed. The two stack arrays
  remain fixed at 64 cells, indexes are checked, and disposal retains the expected
  allocation/output owner paths.
- The reviewer independently verified the local Bun binary and unmodified compiler
  tree against `sources.lock` and reran all four affine negative/positive compiler
  controls. Both duplicate-owner programs failed for the expected ownership error;
  both paired single-consumption controls passed.
- `git diff --check` passed. The parser input manifest was unchanged throughout
  final native/evidence revalidation.

Review 01 additionally ran 160 independent seeded valid cases and 240 independent
mutations (72 valid, 168 malformed). Those results remain applicable: the six
production plugin modules and additive core accessor did not change afterward.
These extra cases are reviewer checks, not additions to the mandatory CI inventory.

## Scope and resource/evidence assessment

The reviewer inspected all six new production modules; all plugin test, helper,
negative-control and tooling files; plugin API/profile/validation documents; the
new workflow; and the additive core cursor/API/lint changes. The review included
untracked files, not merely the tracked diff.

The implementation preserves source identity and authoritative total size before
metadata-only transitions, consecutive parent-bounded traversal, first/unique
TES4, original source-bound spans and raw header values, unknown signatures,
noncanonical XXXX encodings, and the distinction between structural and opaque
compressed bodies. Copy authorization consumes a completed affine scanner,
retains its charged state, copies actual source bytes rather than reconstructed
metadata, preserves a read byte after append refusal, and returns cleanup owners.
The inspected code has no source/count-sized production allocation, retained event
tree, unbounded refill loop, or compression/edit/host fallback.

The evidence tools require exact mandatory input, entrypoint, ownership, fixture
and case inventories; checked compiler provenance; current generated-C/native
identities; distinct measured runs; and fresh observation identities. Failure,
partial/stale/mixed evidence, missing final cgroup observations, timeout, OOM,
wrong resource limits, and ceiling events fail the gate. A source manifest or
self-consistent JSON file is not a cryptographic attestation of an untrusted
machine; this is a reproducible local/CI evidence contract.

The 65536-byte combined scanner/copier charge plus existing owner metadata is
subject to the dedicated three-run resource gate. Its 24 shapes / 72 measurements
include default count/depth/source/payload boundaries and 1/16/64 MiB scan/copy
streams. Static fixed representation and successful local high-count workloads
support proceeding to that gate; they do not replace measured locked-profile
acceptance. The 256 MiB case is a bounded scan/source-size gate, not a claim that
a full maximum-size copy plus every adapter/verification traversal fits the same
work budget. The profile correctly treats all format ceilings independently.

## Remaining acceptance boundary

Docker is unavailable in this review environment. No locked Docker/cgroup
bootstrap, full resource summary, or exact-final-commit CI pass is claimed here.
The unchanged core and runtime workflows and the new complete plugin workflow
must pass for the published commit before the draft PR is marked ready. A later
code/profile/harness change requires affected tests and review again.

This review does not certify edited plugins, decompression/zlib validity, XML,
transactional host publication, the rest of Gate B, or real-game compatibility.
Any subsequently gathered public real-file corpus is additional evidence and is
not part of this review's synthetic/local results.

## Complete reviewed input manifest

The digest above is SHA-256 of the UTF-8 encoding of this mapping serialized with
`json.dumps(mapping, sort_keys=True, separators=(',', ':'))`, without a trailing
newline. It includes all parser acceptance inputs plus reviewed baseline/reference
documents and workflows. Review reports themselves and generated/runtime files
are excluded to avoid self-reference; selected checked local artifact hashes
follow separately.

```json
{
  ".github/workflows/core.yml": "9f5c86f9b5227224245d4ed0f8704262c2ebd5c3d0bfde24d1d6b563c22801c2",
  ".github/workflows/plugin.yml": "2eab93aab7a6f18e8817fe7a58ae60abb759572d27e2464cfb3749c012b09a31",
  ".github/workflows/runtime-probes.yml": "b10e451c44b61a5dbdc02d5260f88dff7687ba2787af9151951bb027d09acef4",
  "DESIGN.md": "5a4a5e14de8e38b3d4f3befd02ee6202e2f4102c1a8cd57418cf4dd78b8b91ff",
  "README.md": "49edfd08698c4f9ab02cf76edd4b2693e03c0ddc0e81010f8c9ec2c9a08acaf3",
  "core/budget.bend": "33bbd749063709ce7c1aa527697b8c3d07a0fbf660181ea264bc0b5fc91fe0d3",
  "core/bytes.bend": "4eab2b8ffbd494bf0e035e9fba96ee791f7d07b35f4d56c07f0dabe3e0e2fa19",
  "core/charges.bend": "7c49c4b3170528c180beaa37da11d24ef4b1bf7c343c97affa8152937c74fe0a",
  "core/checked.bend": "cde05faeabb60c4b3c23aca076aa7a8a41c7afc1b674d5c6abe0a409ab60da0c",
  "core/codec.bend": "753164e773519d78c8da1b940f7a9936808fac1ef4a5c4fee022bd6b75313080",
  "core/cp1252.bend": "e2aad8856e1ebf4407f7cc0f6684245da1d57f2d042ff362a85e3b8c145a3c63",
  "core/cursor.bend": "a314732e03802f90a9f27c1759b1174d5f7efb5138d779f880ce4a9c6979aae6",
  "core/error.bend": "a9b729b4b0386f66e8ead1ab1f2734162c1a8706fc76fe7d6b035902e5452e9f",
  "core/scalars.bend": "45ff4ec87ddcf3fe0639ce7eac6eb8b633bc153145853b874325cb5674d58f22",
  "core/storage.bend": "3ae01d24475b251bfd54c19f6b71ff603213c48f0d459c8375f09e01c9e5d989",
  "core/unicode.bend": "0477cf7f9852a0bc3285f34cd98ba877e8ce568ae106b11f43af5b69820ce63d",
  "core/utf8.bend": "c83c428117457f9b0a71ba86607c7770793edb09331ec4d2bb531c4c46df3c54",
  "docs/core/api.md": "5c97cdacbdb3b1678f6978b97596a7de87576b361fa069845d3b83e7dda40c4e",
  "docs/core/charges.md": "a97530c3a4f77bcfc6de0d0c8664e15f98223f7e7ee57ace8ecbd48786fd5403",
  "docs/core/profile.json": "8ac73630ce110abbdb216ef125328e40f0451468d56bc33ce18b3d6349e8f6db",
  "docs/implementation/issue-4-plan.md": "63e1c55368b4b71e7d9dbe6120b0ca54ee1270f61fab1bc308b9a15030c7d8cb",
  "docs/plugin/api.md": "7e4ba90deaa4846777a318098717ec62d08e8ca609d14c7b0fad055849c07434",
  "docs/plugin/profile.json": "65c4f04eb9ca06382a718531ed9be48b439566953c1b6452fd8a44f702c1379c",
  "docs/plugin/validation.md": "4c724dd1ad5ca4607bea63f7b6f4425b7c1373e9098c892ad51215a34dfe396b",
  "docs/reviews/issue-4/plan-01.md": "c133bd267937e1ece68c282e183c254bca4a871a4d7853d15adef9ca84242ada",
  "docs/reviews/issue-4/plan-02.md": "f9e57985e927b3eec2188d523f58050c53372a8c36dc9537ef0d3f637600e769",
  "hash/hex.bend": "85e0eef5b209f0b6e1eab7e95dc6cee26de0b45d6f24101316bd59217bf66812",
  "hash/sha256.bend": "bcc756f5d937fe064ff3169fae100a4afcd85fc0244bfce6ae56fcce496bf756",
  "plugin/copy.bend": "1d1f1c9e88dee73ef946105bfd4ceaf3be573eaee646cb3937d1ae2b930abadd",
  "plugin/error.bend": "c7dffaf3a458845c580ce0ab6c887ca7c51f687c74cd1f0e6155d70b1b2b1e4f",
  "plugin/frame.bend": "c84491ff8255a93207412238b6afe71bcfe7a8ec827ac364777e7d1de8f53251",
  "plugin/state.bend": "42f20863eb40421c4cfe96c8dc6032ba7393391d5b5e325e1bf4823d128d4ea6",
  "plugin/subrecords.bend": "6df24e3835bde09a92dc22585a69efd29adbb9afae4d4c688610b8b2eb532a16",
  "plugin/types.bend": "b4392c942867cc1b9ef327006f95ace1dcb33db27feffa2de91522c20a99ab33",
  "sources.lock": "c693e483f90bd8fa08c41f47315f39c7e87c3567869a3940d26758647755b1da",
  "tests/plugin/contracts.bend": "864d11410f53d9f3bb6789cbfc832946e21b5f6cd7099fc4aa60a5b234540cd4",
  "tests/plugin/driver.bend": "4f89607c72d0721e32f3e47e886848dc718a0e85331ec626e300f541fe6840c3",
  "tests/plugin/negative/copy.bend": "5e3de28a396318b8bbbdf6b4886ec132f6160f9be0f6445439dba327944334ba",
  "tests/plugin/negative/copy_control.bend": "74bddc4ae6c5f489d726e9c086493a2ba078fff2075e92183ad6a2d9d43fcc69",
  "tests/plugin/negative/scanner.bend": "63f08f8624a36aed16729697771a95ed0f7b34706b12e30133850badd43e1d05",
  "tests/plugin/negative/scanner_control.bend": "9637f8e86c1376bcf8684789ff289da71dfab025ccf7026f2bf31ad36525c37b",
  "tests/plugin/report.bend": "d453cc052866d2e982db5ba88ae88c2ca0e41b81137e679190fe2808ec1b96cf",
  "tests/plugin/resource.bend": "5c4171496878360e323dac967d05507ca1b23b93d0decb8a3948d29b15e0377b",
  "tests/plugin/runner.bend": "34d6a70709fb42e8461c61d6375f2bd1d25e0a92b3d5c20c6b30b887074fe12d",
  "tests/plugin/support.bend": "cf4c5d521b621a81fa79a0723211949e7fb903ba093844eef4e3b0ac33add967",
  "tools/core/lint.py": "7c346c68b72aadeb5dcbc30578eeadbe9971cc8e7b171002157ffbe83b9cde3e",
  "tools/plugin/bootstrap.py": "2e07a36ca5a8a0c25392afdee56f9e8a709ba60372875ac373c58754a6136643",
  "tools/plugin/build.py": "da83760c010e423925cfcf88f07e45b1e31c890224eae92ae0edfaf5c0080c73",
  "tools/plugin/case_spec.py": "a1527085923ecaf079ddf835d40a1d45c6cd8cc4bde02da0ff337f4cb49f2b6e",
  "tools/plugin/checks.py": "c6f220968062500262110ddc87cc3fc0096b4742d9ea325a881b329cc2eeb8a6",
  "tools/plugin/develop.py": "344570b2cdcc64c08311cf2993af2ae4b8e79b5f67cfc8c8442131268f59d330",
  "tools/plugin/experiment.py": "5fa98121ef4611d5dcb07b50ed7963388ab13435f897fd5dfe2fc952d45aa7a7",
  "tools/plugin/fixtures.py": "33fc98d4029eeac2a9e838f75cf0f89503639b2839695dd0e7a9abbdc9497fa5",
  "tools/plugin/integrity.py": "047c99f0503af61c60f30c5f7a35d52ac2dc866fd45cb6e8edc46313b4de6e37",
  "tools/plugin/layout.py": "a0c24cf7b8156e86f12c3048ce2b8fabfd2bc7184a8f20f01b8e1036f9e86074",
  "tools/plugin/lint.py": "ea76590d06079ccd5be8ee95058f5c009d7eb34549e85c89c6f0037c24e42b0e",
  "tools/plugin/measure.py": "b54a0a4eeb6a12c40ab897bd278e1f59f14fcda01ca29f549ab6ae4854fbbc36",
  "tools/plugin/native_entry.py": "d659510563852c3da45865fc941c407c5621422a0f5319d2ae0b12f39fcf70c4",
  "tools/plugin/oracle.py": "7bc60287c80b411759cc39b5560c40e471e94082ce0ac29dc6e293eebbf19580",
  "tools/plugin/run.py": "cd546f5cf3555da52f8e96d72b20f048b76b8a25b1159f4bcfdaf0dc7cf36db3",
  "tools/plugin/summarize.py": "669dcdc47f45beeba06e86ea089184bd722d14094d0ace0baee8d40fb6795eb4",
  "tools/plugin/test_evidence.py": "764a3116624512b09e0177fc50956726a9213604b889e40bf512dfd52934e3c2",
  "tools/plugin/validation.py": "ab414b4f26b8df5399104279669b02799cbb9130d61dd7dc77c82f63ba447586",
  "tools/runtime/Dockerfile": "b8287ac2fc8719b83a69281f0b5ffa144bda85f94c6dac5f90d1b62190fa4edc",
  "tools/runtime/fetch_toolchain.py": "13b77171a14ca20ccb0f5893569db14aff15e4684ce2a09740f0a4add22102b9",
  "tools/runtime/packages.lock": "b8efb4b896d72aa32227c88527c2f10d6fadf8147b7da50d43ee06ef82f99fcc",
  "tools/runtime/probe-packages.lock": "bf7d367329bf606aa493b21308294b3cae259d45360d0dda06095c60567b640b",
  "tools/runtime/verify_lock.py": "b0cf0aa43214c596efa9244cdf1c1dab2f52f2ced4bbb90845b8a84269e42ca4"
}
```

## Checked local artifact identities

These identify local development results only, not portable/locked acceptance.

```json
{
  "build/plugin/contracts": "d2cb4a23f95a9a820569b49e94be904bd1b21483403997f7d47d4b2adc857b8a",
  "build/plugin/contracts.c": "e9b2c1816bbe7f867c989b18b480d4c1ce6131d021febccc61f9ff44004ebc1d",
  "build/plugin/driver": "ac9bce706fd3e9ff8495a3eab5deebc851867df834c790a453d95436e5984480",
  "build/plugin/driver.c": "9d0d9efe526e69c32122761705646154dc1d2c01e25e758f0dcdf190b11a6aa4",
  "build/plugin/oracle-suite.json": "f1aa75c15c65617bf4c48be8e8ce86fa0fa0dd983ad4eb94cafe96a7b01b9246",
  "build/plugin/resource": "47659e867327d51ddd2c73c35594859bfff9d6c2778af2873c2b178c75755d2a",
  "build/plugin/resource.c": "8df1a19dca1311849cdd0d093e4dc67ef843782fc3ad3bf14a72cc42bbb239f4"
}
```

## External-file documentation addendum

After the frozen source review, the reviewer independently checked
`docs/reviews/issue-4/external-validation.md` (SHA-256
`bcecc2115fd3529445db15b0ad9d80a0af229c9424f5dc357cf35609ea29db65`) and its local result
`build/plugin/external-validation.json` (SHA-256
`7ffd9901b60041434ed289f19907e458e665de3a293854c5d56736b4df58c0a9`). The downloaded 285-byte ESP and MIT license
hashes match the report. Using the unchanged reviewed native driver, the reviewer
reran all four documented input/output chunk pairs and independently verified
every event/span, the 2-record/1-group/11-subrecord/0-compressed summary, exact
285-byte copied output, SHA-256, and balanced cleanup against the Python reference.
All passed; the original 68-file reviewed manifest remains unchanged.

No additional finding. This checks the downloaded file and report, not an
independent network provenance retrieval. The report correctly limits the result
to one small author-published test plugin and makes no representative-mod, game,
compression, host-publication, or locked-resource acceptance claim. No third-party
plugin or executable is added to the repository.
