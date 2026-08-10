# Pre-public Remote Tree Audit

`PRE_PUBLIC_REMOTE_TREE_AUDIT = PASS`

- Repository visibility during audit: `PRIVATE`
- Audited remote commit: `bb5e152e4ea7fdf17dff4d8d9f223dd1081571d5`
- Remote tracked blobs: `95`
- Missing required roots: `0`
- Prohibited remote paths: `0`
- Nonzero public content-scan gates: `0`

Confirmed present: `README.md`, `LICENSE`, `CITATION.cff`, `.zenodo.json`, `VERSION`, `R/`, `runtime/`, `examples/`, `tests/`, `validation/`, `docs/` and `.github/workflows/`.

Confirmed absent: private rights YAML, release-human-metadata YAML, internal rights audit assets, private provenance, canonical migration history, patient data, credentials and course-specific identifiers. The public-safe secret-scan report is intentionally retained as audit evidence and contains no secret.
