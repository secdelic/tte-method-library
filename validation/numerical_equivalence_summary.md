# Numerical equivalence summary

`PUBLIC_ESTIMATOR_NUMERICAL_EQUIVALENCE = PASS`

The internal frozen implementation and the public project implementation were run on identical fixed-seed synthetic inputs. The pre-existing `1e-8` numerical tolerance was not relaxed.

| Profile | Comparisons | Failed | Maximum absolute difference |
|---|---:|---:|---:|
| BASELINE_BINARY_RISK | 22 | 0 | 0 |
| MI_PS_CONTINUOUS_ATE | 13 | 0 | 0 |
| Total | 35 | 0 | 0 |

The comparison covered propensity scores, weights, unweighted and weighted SMD, maximum absolute SMD, ESS, weighted treated and control risks, RD, RR, standard errors, confidence intervals, imputed datasets, within-imputation estimates and variances, pooled ATE, pooled standard error, Barnard-Rubin degrees of freedom and pooled confidence intervals.

Detailed synthetic comparison rows are retained in `validation/numerical_equivalence.csv`. No real patient data were used.
