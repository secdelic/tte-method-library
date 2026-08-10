# Zenodo GitHub Integration Blocker

`ZENODO_GITHUB_REPOSITORY_ENABLED = TRUE`

`V1_0_0_TAG_CREATED = TRUE`

`V1_0_0_GITHUB_RELEASE_CREATED = TRUE`

The initial authentication blocker was resolved by the researcher. Zenodo displayed `secdelic/tte-method-library` as enabled, recognized GitHub release `v1.0.0`, published the software record and assigned version DOI `10.5281/zenodo.21879884`.

## Resolution evidence

1. Repository row displayed `ON` under Enabled Repositories.
2. Zenodo repository detail displayed `v1.0.0` as Published.
3. The release linked to the expected GitHub `v1.0.0` Release.
4. Public Zenodo API record `21879884` returned version `1.0.0`, the expected creator, ORCID, MIT license and GitHub repository relation.

## Frozen resume point

- Stable candidate SHA: `998e3c0a83656eae5e3ee8dae909e2edcd2625ec`
- Stable GitHub Actions: PASS
- External smoke: PASS
- Stable tag: `v1.0.0`
- Stable GitHub Release: published
- Version DOI: `10.5281/zenodo.21879884`
- Concept DOI: `10.5281/zenodo.21879883`
