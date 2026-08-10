# Known limitations

- Only the two profiles in `runtime/production_registry.csv` are production-approved.
- The baseline profile is restricted to the registered fixed-horizon binary-outcome ATE path in RC1.
- The MI+PS profile is restricted to continuous-outcome ATE with the audited PMM, within-imputation WeightIt M-estimation and Rubin pooling path.
- No real-data canary is distributed with the repository.
- Diagnostics do not constitute scientific approval of time zero, confounders, treatment, outcome or causal identification.
- Figure machine checks do not constitute final visual approval for a manuscript.
- GitHub Actions and Zenodo archival remain remote-stage checks for this RC1.
