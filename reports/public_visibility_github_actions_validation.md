# Public Visibility GitHub Actions Validation

`PUBLIC_VISIBILITY_GITHUB_ACTIONS = PASS`

- Workflow: `public-rc1-validation`
- Run ID: `31409980016`
- Attempt: `2`
- Job ID: `93527227086`
- Commit SHA: `df33cb71d5fc40ea8737cc8d98771ee5465db296`
- Status: `completed`
- Conclusion: `success`

All required steps passed after the repository became public: R parse, synthetic tests, production Quick Start, `BASELINE_BINARY_RISK`, `MI_PS_CONTINUOUS_ATE`, numerical equivalence, independent validation, figures, tables, input contracts, metadata and documentation, CFF schema, privacy, secrets, patient-data patterns, private-governance gate and release dry run.

Non-blocking runner warnings were recorded for the `actions/checkout@v4` Node runtime transition and an unsuccessful dependency-cache tar restore. The clean runner continued through a successful environment restore and every required gate passed. No statistical or privacy requirement was relaxed.
