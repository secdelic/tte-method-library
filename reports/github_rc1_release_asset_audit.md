# GitHub RC1 Release Asset Audit

`GITHUB_RC1_RELEASE_ASSET_AUDIT = PASS`

- Release: `https://github.com/secdelic/tte-method-library/releases/tag/v1.0.0-rc1`
- Release type: GitHub pre-release
- Tag: `v1.0.0-rc1`
- Tagged commit: `df33cb71d5fc40ea8737cc8d98771ee5465db296`
- Uploaded custom assets: `0`
- Automatically generated source ZIP: `369484` bytes; SHA-256 `a0ac2e5745fec209717fc112ff4838928e53c86d086448507bc41ff724606b00`
- Automatically generated source TAR.GZ: `333090` bytes; SHA-256 `c988aa989244d743cb6c47783bd2ee29b904b150e9315f80058badd8d872313f`

The tag tree, ZIP and TAR.GZ each contained the same 99 repository files. Path-set differences were zero. Neither archive contained private governance YAML, patient data, credentials, internal rights material or private provenance.

The raw identifier-pattern scan returned five strings, all located only in the defensive pattern definitions in `validation/scan_public_repository.R`. They were scanner self-definitions and not source identifiers, local paths or course-derived content. The scanner excludes its own definitions from confirmed-hit counts.

Confirmed findings:

- private governance assets: `0`
- confirmed secrets: `0`
- non-synthetic patient CSV files: `0`
- nonessential source identifiers: `0`
- unexpected uploaded binary assets: `0`
