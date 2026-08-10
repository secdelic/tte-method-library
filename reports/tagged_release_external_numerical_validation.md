# Tagged-release External Numerical Validation

`TAGGED_RELEASE_NUMERICAL_REPRODUCIBILITY = PASS`

- Source: anonymous clean clone of `v1.0.0-rc1`
- Commit: `df33cb71d5fc40ea8737cc8d98771ee5465db296`
- Internal canonical repository read during this test: no
- Private validation object read during this test: no
- Frozen public tolerance: `1e-8`
- Independent-comparator tolerance: `1e-7`

The external clone ran `validation/run_public_numerical_regression.R` with exit code `0` and reported `PUBLIC_NUMERICAL_REGRESSION=PASS; checks=14`.

| Profile | Public regression checks | Largest public-regression absolute difference | Independent checks | Largest independent absolute difference | Status |
|---|---:|---:|---:|---:|---|
| `BASELINE_BINARY_RISK` | 6 | `5.11e-15` | 6 | `1.14e-13` | PASS |
| `MI_PS_CONTINUOUS_ATE` | 8 | `5.33e-15` | 5 | `5.69e-14` | PASS |

Compared quantities covered propensity scores, weights, estimates, standard errors, confidence limits, SMD, ESS, completed imputation values, within-imputation estimates and variances, pooled ATE, pooled standard error and pooled confidence intervals. The independent formulas covered weighted risks, RD, RR, fixed-weight influence-curve standard errors, SMD, ESS, Rubin total variance and Barnard-Rubin degrees of freedom.

No tolerance, expected value, estimand, estimator or production registry entry was changed.
