# Stable Release Diff Scope

`STABLE_CODE_BASE = RC1_VALIDATED_IMPLEMENTATION`

`STATISTICAL_CODE_DIFF = 0`

| File | Classification | Permitted change |
|---|---|---|
| `VERSION` | VERSION_METADATA | `1.0.0-rc1` to `1.0.0` |
| `DESCRIPTION` | VERSION_METADATA | stable project version |
| `CHANGELOG.md` | RELEASE_NOTES | stable history entry |
| `PUBLIC_RELEASE_STATUS.md` | VERSION_METADATA | stable candidate status |
| `validation/validate_metadata.R` | VERSION_METADATA | assert stable metadata only |
| `governance_public/public_release_checklist.csv` | VERSION_METADATA | stable release gate state |
| `CITATION.cff` | CITATION_METADATA | stable version and real release date |
| `.zenodo.json` | ZENODO_METADATA | authoritative archival version and date |
| `README.md` | README_CITATION | stable version and citation instructions |
| `docs/software_citation_guide.md` | OTHER_DOCUMENTATION | stable tag and pending DOI guidance |
| `RELEASE_NOTES_v1.0.0.md` | RELEASE_NOTES | formal stable release description |
| `reports/v1_0_0_rc1_evidence_freeze.md` | OTHER_DOCUMENTATION | immutable RC1 evidence |
| `reports/stable_release_diff_scope.md` | OTHER_DOCUMENTATION | diff allowlist |
| `reports/stable_metadata_alignment.md` | OTHER_DOCUMENTATION | metadata audit |

Forbidden diff classes are estimators, weighting, imputation, estimands, formulas, expected results, numerical tolerances, production registry entries and module maturity. Any such diff blocks the stable release.
