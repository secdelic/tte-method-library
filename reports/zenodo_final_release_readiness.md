# Zenodo Final-release Readiness

`ZENODO_METADATA_READY_CONNECTION_PENDING = PASS_WITH_PENDING_EXTERNAL_ACTION`

## Verified preparation

- GitHub repository visibility: PUBLIC
- `CITATION.cff`: valid CFF 1.2.0 metadata
- `.zenodo.json`: valid JSON metadata
- title, creator, ORCID, version, release date, repository URL, license and keywords: mutually consistent
- current version: `1.0.0-rc1`
- DOI: intentionally absent and pending

No Zenodo record, upload or DOI was created in this task.

## Required stable-release sequence

1. Make the human decision whether the validated RC1 may become stable `v1.0.0`.
2. Freeze stable version and release date in VERSION, CFF, Zenodo metadata and release notes without changing estimands or validated numerical behavior.
3. Run local and public GitHub Actions validation on the exact stable-release commit.
4. Create a new immutable annotated `v1.0.0` tag; do not move `v1.0.0-rc1`.
5. Connect the public GitHub repository to the researcher's Zenodo account and enable archival for this repository.
6. Create the GitHub `v1.0.0` Release from the validated stable tag.
7. Verify the Zenodo archive, obtain the version-specific DOI and review the deposited source and metadata.
8. Add the real DOI to citation guidance only through a new auditable metadata change; never rewrite the archived tag or invent a DOI.
9. Cite the fixed version DOI in the manuscript.

The preferred formal paper citation remains the future stable `v1.0.0` version DOI. RC1 is a public validation candidate, not the final DOI-bearing release.
