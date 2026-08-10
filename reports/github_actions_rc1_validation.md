# GitHub Actions RC1 Validation

`GITHUB_ACTIONS_RC1_VALIDATION = PASS`

## Successful remote run

- Workflow: `public-rc1-validation`
- Run ID: `31402453048`
- Run URL: `https://github.com/secdelic/tte-method-library/actions/runs/31402453048`
- Event: `push`
- Tested commit SHA: `6aebce29224ebac6e9b5d46ed022f6f51539fec6`
- Status: `completed`
- Conclusion: `success`
- Job: `validate`
- Failing jobs: `0`
- Uploaded artifacts: `0`

## Confirmed successful gates

| Required gate | GitHub Actions evidence |
|---|---|
| R parse | `Parse R sources` - success |
| Synthetic tests | `Tests` - success |
| Production Quick Start | `Production Quick Start` - success |
| BASELINE_BINARY_RISK | Quick Start and numerical regression - success |
| MI_PS_CONTINUOUS_ATE | Numerical regression - success |
| Numerical equivalence | `Numerical and independent validation` - success |
| Independent validation | `Numerical and independent validation` - success |
| Input contract | `Tests` - success |
| Figures | `Tests` - success |
| Tables | `Tests` - success |
| Documentation links | `Metadata and documentation` - success |
| CFF schema 1.2.0 | `CITATION.cff schema` - success |
| Privacy scan | `Privacy, secrets, identifiers, and private governance` - success |
| Secret scan | `Privacy, secrets, identifiers, and private governance` - success |
| Patient-data scan | `Privacy, secrets, identifiers, and private governance` - success |
| Private-governance-file gate | `Privacy, secrets, identifiers, and private governance` - success |
| Absolute-path and identifier scan | `Privacy, secrets, identifiers, and private governance` - success |
| Release package dry run | `Release dry run` - success |

## Environment and CI defects corrected

Earlier remote attempts exposed CI-only defects before a complete successful run:

1. The workflow defaulted to R 4.6.1 although the lockfile declares R 4.5.1. The workflow now pins R 4.5.1.
2. The public lockfile referenced the withdrawn and non-archived Rcpp build `1.1.1-1`. It was corrected to the nearest archived CRAN revision `1.1.1-1.1`; all local numerical regression checks passed again before push.
3. Ubuntu system requirements declared by the restored packages were installed explicitly.
4. SVG export now selects the base-R SVG device explicitly, preserving vector output without an undeclared optional package.
5. Documentation, privacy and release validators now inspect the Git-tracked release tree instead of CI-generated dependency caches.

No estimator, estimand, expected numerical value, numerical tolerance, module maturity, privacy gate, patient-data gate or figure-quality threshold was relaxed or removed. No real patient data were used.
