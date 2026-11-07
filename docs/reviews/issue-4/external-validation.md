# Additional externally published FO4 file check

Date: 2026-11-07. This is a local development check, separate from the locked
synthetic CI/resource gate. It adds no third-party file to this repository.

The requested example site, <https://fallout4.2game.info/>, returned HTTP 403 to
this environment. No login, access-control bypass or unofficial mirror was used.
An independently published, author-provided Fallout 4 test plugin was used instead:

- Repository: <https://github.com/louisthird-git/FO4StringUtils>.
- Exact revision: `7f5736eabbbf04ac1f6ad28a10c656b0727bf3fd`.
- File: [Test/Data/FO4StringUtils_Test.esp](https://github.com/louisthird-git/FO4StringUtils/blob/7f5736eabbbf04ac1f6ad28a10c656b0727bf3fd/Test/Data/FO4StringUtils_Test.esp).
- Author's [usage documentation](https://github.com/louisthird-git/FO4StringUtils/blob/7f5736eabbbf04ac1f6ad28a10c656b0727bf3fd/TEST_USAGE.md)
  identifies this as the ESP for its Fallout 4/F4SE in-game test harness.
- [Repository license](https://github.com/louisthird-git/FO4StringUtils/blob/7f5736eabbbf04ac1f6ad28a10c656b0727bf3fd/License.txt):
  MIT, with copyright/permission-notice retention required for distribution.
  Downloaded data was used read-only for this check and is not redistributed.
- Original size: 285 bytes.
- Original SHA-256:
  `ca4e20cb62592004da9de3a56eeb620dd81bf826948df4dc2d71e3c229a364b1`.
- License SHA-256:
  `1927183113d3e8d83ee1face9fa7f2027b274ee0677a0831410e5017fcbdbce8`.

The unmodified file was supplied as hex to the existing pure-input native driver,
using input/output chunk pairs `(1,1)`, `(7,23)`, `(24,25)` and `(65536,65536)`.
All four executions exited successfully with balanced cleanup. The independent
Python reference and the Bend scanner agreed on two records, one group and eleven
subrecords, including all exposed header fields and spans. Each completed Bend
copy matched all 285 source bytes and the original SHA-256 exactly.

This small third-party test plugin is a useful real published input, not a claim
that a representative selection of production mods or large game masters has
been tested. It has no compressed records. No DLL, Papyrus program or game was
run or installed. It does not establish game compatibility, translated output,
host IO/publication safety, compressed-body validity or locked cgroup acceptance.
The repository's mandatory CI remains deterministic and network-free at probe
execution time; it does not download or redistribute this external plugin.
