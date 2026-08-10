# Target Trial Emulation Method Library v1.0.0

Release date: 2026-08-11

## Scope

This stable release is a statistical execution library for target trial emulation and related causal-inference analyses using researcher-prepared data and frozen analysis specifications.

## Production-validated profiles

- `BASELINE_BINARY_RISK`
- `MI_PS_CONTINUOUS_ATE`

## Validation

The stable implementation is identical to the publicly validated RC1 statistical implementation. Validation evidence includes public GitHub Actions, an anonymous external clean clone, canonical-to-public numerical equivalence, independent statistical formulas, the fixed-seed synthetic Quick Start, publication table and figure tests, and privacy, secret, patient-data and private-governance gates.

## Figures

The figure layer exports PDF/SVG vectors and PNG/TIFF rasters at 600 DPI, with 85-mm and 178-mm configurations. Machine checks do not replace project-specific human visual approval.

## Mixed readiness

`AVAILABLE IN LIBRARY != PRODUCTION-APPROVED`

CCW, LMTP, longitudinal TTE, PATH, three-timepoint TTE and multilevel propensity-score workflows retain their existing mixed-readiness classifications and are not production validated by this release.

## Scope boundary

Scientific study design, database extraction, causal-variable definition and manuscript writing remain outside this software's scope and are the investigators' responsibility. This release does not claim that target trial emulation or the implemented statistical methods originated with this project, and it does not guarantee any publication outcome.

## License

Project-owned implementation is released under the MIT License. Dependencies retain their own licenses as listed in `THIRD_PARTY_NOTICES.md`.

## Citation

The immutable GitHub `v1.0.0` tag provides the fixed source reference. After Zenodo archives the formal GitHub Release, use the version-specific Zenodo DOI for formal software citation. No DOI is populated before the archive is created.
