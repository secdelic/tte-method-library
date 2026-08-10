# Target Trial Emulation Method Library v1.0.0-rc1

Release date: 2026-08-11

This release candidate provides two registry-controlled production paths:

- `BASELINE_BINARY_RISK`: propensity-score weighting, balance, ESS, weighted treatment-specific risks, RD, RR, fixed-weight influence-curve standard errors and confidence intervals.
- `MI_PS_CONTINUOUS_ATE`: PMM multiple imputation, within-imputation WeightIt M-estimation, Rubin pooling and Barnard-Rubin degrees of freedom.

Both paths reproduce the internal frozen implementation on identical synthetic inputs within the pre-existing tolerance. Independent formula checks cover weighted risks, RD, RR, SMD, ESS, Rubin pooling and the pooled continuous-outcome ATE.

The release also contains a fixed-seed synthetic Quick Start, unified configuration contracts, aggregate publication tables, SCI-compatible figure export and reproducibility metadata. The table system covers Table 1, primary effects and sensitivity results; the figure system covers 14 registered figure types with PDF, SVG, TIFF and PNG export. It contains no real patient data, credentials or private governance files.

CCW, LMTP, longitudinal TTE, PATH, three-timepoint TTE and multilevel propensity-score workflows are not production-approved by this RC1. Availability in the broader method library does not imply production approval.

The RC1 source repository is `https://github.com/secdelic/tte-method-library` and is licensed under MIT; dependencies retain their own licenses as documented in `THIRD_PARTY_NOTICES.md`. Cite a fixed commit during private validation. A version-specific Zenodo DOI remains pending until an approved GitHub Release is created and archived.

This RC1 does not claim that every method-library module is production-ready, that target trial emulation methods are original to this project, or that use of the software guarantees publication outcomes.
