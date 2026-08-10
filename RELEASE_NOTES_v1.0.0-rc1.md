# Target Trial Emulation Method Library v1.0.0-rc1

This release candidate provides two registry-controlled production paths:

- `BASELINE_BINARY_RISK`: propensity-score weighting, balance, ESS, weighted treatment-specific risks, RD, RR, fixed-weight influence-curve standard errors and confidence intervals.
- `MI_PS_CONTINUOUS_ATE`: PMM multiple imputation, within-imputation WeightIt M-estimation, Rubin pooling and Barnard-Rubin degrees of freedom.

Both paths reproduce the internal frozen implementation on identical synthetic inputs within the pre-existing tolerance. Independent formula checks cover weighted risks, RD, RR, SMD, ESS, Rubin pooling and the pooled continuous-outcome ATE.

The release also contains synthetic examples, unified configuration contracts, aggregate publication tables, SCI-compatible figure export and reproducibility metadata. It contains no real patient data.

CCW, LMTP, longitudinal TTE, PATH, three-timepoint TTE and multilevel propensity-score workflows are not production-approved by this RC1. Availability in the broader method library does not imply production approval.

The GitHub URL, GitHub Actions remote run and Zenodo DOI remain pending until repository creation and release archival.
