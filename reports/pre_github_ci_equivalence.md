# Pre-GitHub CI equivalence

`LOCAL_CI_EQUIVALENCE = PASS`

Executed locally on 2026-08-10 before creation of the fresh RC1 Git history:

| Check | Result |
|---|---|
| R parse | PASS — 30 R files |
| Synthetic tests | PASS — 4 test entrypoints |
| Figure system | PASS — 14 figure types, PDF/SVG/TIFF/PNG |
| Table system | PASS — Table 1, main effects, sensitivity, CSV/HTML |
| Production Quick Start | PASS |
| Public numerical regression | PASS — 14 checks |
| Input contract | PASS, including path-traversal negative control |
| Private governance file gate | PASS |
| Metadata/CFF structural validation | PASS; remote fields pending |
| Documentation links | PASS |
| Privacy/secret/patient/identifier scan | PASS |
| Aggregate analysis release dry run | PASS — 31 payload files |

The GitHub Actions workflow has not run remotely and remains `PENDING_REMOTE`.
