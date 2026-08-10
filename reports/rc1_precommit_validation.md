# RC1 Precommit Validation

`RC1_PRECOMMIT_VALIDATION = PASS`

Validation date: 2026-08-10

| Gate | Result | Evidence |
|---|---|---|
| Branch and history | PASS | `main`; zero commits before root commit |
| Local Git identity | PASS | `reports/git_identity_precommit_check.md` |
| Cached diff check | PASS | `git diff --cached --check` returned no errors |
| Private YAML exclusion | PASS | Both prohibited filenames have zero tracked hits |
| R parse | PASS | 30 R files parsed |
| Synthetic tests | PASS | Four public test entrypoints |
| Production Quick Start | PASS | Fixed-seed synthetic baseline analysis |
| Estimator numerical equivalence | PASS | 35/35 comparisons; maximum absolute difference 0 |
| Public numerical regression | PASS | 14/14 registered checks |
| Independent statistical validation | PASS | 11/11 independent formula checks |
| Figure validation | PASS | 14 figure types and four formats |
| Table validation | PASS | Table 1, main effects and sensitivity outputs |
| Input contract | PASS | Includes path-traversal negative control |
| Metadata and CFF structure | PASS | Remote URL/date/DOI intentionally pending |
| Documentation links | PASS | Local link validator |
| Privacy, secret and patient scan | PASS | All confirmed-risk counts are zero |
| Course/source identifier scan | PASS | Nonessential identifier hits are zero |
| Private absolute path scan | PASS | Zero hits |
| SQL/database runtime | PASS | No connector/query capability; detected terms are only guards or comments |
| Writing/reviewer runtime | PASS | No writing or reviewer capability; detected terms are only release exclusion guards |
| Aggregate release dry run | PASS | 89 repository files; 31 aggregate payload files |

No real patient data were read or executed. No numerical tolerance, frozen expected value, estimand, statistical method or module-readiness designation was changed.
