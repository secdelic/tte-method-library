# Visualization v1.2.0

Version 1.2.0 of the Target Trial Emulation Statistical Analysis Method Library provides publication visualization with fourteen native figure variants and six publication APIs. Production-validated estimation remains limited to BASELINE_BINARY_RISK and MI_PS_CONTINUOUS_ATE (ATE); CCW visualization does not establish CCW statistical production validation.

## Visualization source and capabilities

The visualization source is frozen at
`f35e4ea00031cee0dfd1b5b6045fa39d5479f8f9`. Release preparation changes
metadata and its version-aware validator, not visualization or statistical code.
The SCI semantic palette and publication theme, fourteen native figure variants,
six publication APIs, nine synthetic scenes and existing figure QC are retained.

- `plot_participant_flowchart()`
- `plot_tte_ccw_timeline()`
- `plot_survival_risk_publication()`
- `compose_outcome_panels()`
- `plot_subgroup_forest()`
- `compose_forest_panels()`

The export contract remains PDF/SVG vector and 600-DPI TIFF/PNG at 85/178 mm,
with minimum 7-pt text and the existing grayscale/CVD accessibility checks.
See the [publication API guide](../figures/publication_capability_guide.md).

## Production and scientific boundaries

`PUBLICATION VISUALIZATION CAPABILITY` is distinct from
`PRODUCTION VALIDATED ESTIMATORS`. Only `BASELINE_BINARY_RISK` and
`MI_PS_CONTINUOUS_ATE` are approved production ATE profiles.
`CCW VISUALIZATION ONLY` does not mean `CCW STATISTICAL PRODUCTION VALIDATION`.
Timelines, caller-supplied weighted curves and competing-event displays do not
execute a newly validated CCW estimator. PR #4 is excluded.

The researcher approved the nine synthetic scenes at two widths for source HEAD
`bbbabc83afc290f7a885702dcd71c1327c88ff7d`; see the
[gallery acceptance record](https://github.com/secdelic/tte-method-library/pull/3#issuecomment-6206656777).
This component-level approval does not cover arbitrary real-data density, long
labels or study-specific scientific content. Real-study figures retain their
individual QC and human review; no blanket `publication_ready=TRUE` is granted.

## Citation and historical identity

`cff-version: 1.2.0` denotes the Citation File Format schema. The separate
software version is 1.2.0 in VERSION, DESCRIPTION, CITATION.cff and .zenodo.json.
Authors, ORCID, MIT license, software title and repository identity are preserved.

The immutable v1.0.0 tag points to
`998e3c0a83656eae5e3ee8dae909e2edcd2625ec`. Its original CFF predates the DOI
addition in commit `01c49c1`. The validator accepts that exact five-file snapshot
by fixed SHA256 (CRLF normalized to LF), or the historical v1.0.0 identity with
its assigned DOI `10.5281/zenodo.21879884` and date `2026-08-11`.
Those identifiers belong to v1.0.0 and must not be assigned to v1.2.0.

The historical tag, GitHub Release and Zenodo records are preserved. See the
[archival plan](https://github.com/secdelic/tte-method-library/blob/v1.2.0/docs/releases/visualization-v1.2.0-archival-plan.md)
for the separate publication authorization and post-archive verification steps.
