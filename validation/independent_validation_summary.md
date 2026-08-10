# Independent statistical validation summary

`INDEPENDENT_STATISTICAL_VALIDATION = PASS`

Independent formulas were implemented separately from the production estimator paths. Automated checks do not constitute scientific approval of a study specification.

| Profile | Checks | Failed | Largest absolute difference |
|---|---:|---:|---:|
| BASELINE_BINARY_RISK | 6 | 0 | 1.14e-13 |
| MI_PS_CONTINUOUS_ATE | 5 | 0 | 5.69e-14 |

Coverage includes weighted risks, RD, RR, fixed-weight influence-curve standard errors, SMD, ESS, Rubin total variance, Barnard-Rubin degrees of freedom, pooled ATE, pooled standard error and confidence intervals. The registered independent-comparator tolerance is `1e-7`.
