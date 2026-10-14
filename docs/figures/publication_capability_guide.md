# Publication figure capabilities - v1.2 candidate

These utilities express investigator-supplied aggregate results and schematic
events. They do not estimate survival, competing risks, CCW effects, RMST/RMTL,
bootstrap intervals or interaction P values. The production registry and
software version remain unchanged. Use the current SCI palette/theme only.

## Participant flowchart

`plot_participant_flowchart(nodes, edges)` uses explicit nodes with `id`,
`label`, integer `n`, and `kind` (`start`, `inclusion`, `exclusion`, `analysis`).
Optional `reason` text can describe inclusion/exclusion steps. Edges contain
`from` and `to`; branches are actual graph edges. The graph must be connected
to one starting population and acyclic. Counts are supplied, never calculated
from paper numbers or silently reconciled. The older cohort bar chart remains.

## Research flow and clone/censor timeline

`plot_tte_ccw_timeline(clones, events, research_steps=NULL)` requires clone
records with `subject_id`, `clone_id`, `strategy`, `followup_start`,
`followup_end`, and `grace_end`. Use deidentified schematic display IDs;
optional `display_label` controls concise row labels. Event records contain
`clone_id`, numeric `time` and `event_type`: `treatment`, `artificial_censor`,
`natural_censor`, `outcome`, `competing_event`. Treatment/event times are not
jittered. Coincident events are separated vertically within the same lane.
Grace shading is limited to each clone's supplied follow-up, while the explicit
boundary remains visible. Square endpoints mark the supplied follow-up end.

Optional `research_steps` supplies a generic box/connector process header.
These stage labels describe the caller's intended process, not methods executed
by this library. Supply an explicit unit with `time_label` for a real figure.

**Visualization support does not establish CCW production readiness.**

## Survival/risk publication wrapper

`plot_survival_risk_publication(data, measure, number_at_risk=NULL,
time_breaks, effect_annotation=NULL)` preserves the simple native constructors.
The explicit `measure` is `survival`, `risk` or `cumulative_incidence`.
Curve data use `time`, `strategy`, `estimate`, optional `ci_lower`/`ci_upper`.
Confidence limits are supplied, not inferred or recalculated.

Risk-table data require `strategy`, `time`, integer `n_at_risk`, with a record
for every displayed strategy/time break. No image-derived estimates, filled
counts or extrapolation are allowed. The counting unit and upstream provenance
must be established by the investigator. Weighted risk-set mass is not an
integer participant count. `effect_annotation` is literal caller-supplied
text, displayed outside the data panel; no effect or clinical interpretation
is derived from the curve. `time_label` allows explicit time units.

## Outcome panels

`compose_outcome_panels(panels, ncol=2, align_x=FALSE)` accepts native publication
wrappers or ggplot panels. It uses shared strategy colors/linetypes, one legend,
panel labels and a restrained gutter. Horizons and outcomes come entirely from
the supplied panels. No 7/28/90-day values are hardcoded into the composer.
Set `align_x=TRUE` only when time units/ranges are scientifically appropriate;
unobserved curve segments or risk counts are not extrapolated.

## Clinical subgroup forest and assembly

`plot_subgroup_forest(data, effect_scale)` requires `subgroup`, `label`,
`row_type` (`overall`, `header`, `category`), `estimate`, `ci_lower`, `ci_upper`.
Header effect fields are NA; categories follow their matching header.
Optional `n` is caller-supplied integer N. Optional `p_interaction` is supplied
on header rows. Point/CI values remain unchanged; formatted text is display
rounding only. Header/category hierarchy, indentation, Overall rows, optional
alternating shading, estimate/CI text and neutral null lines are supported.
Difference null=0; ratio null=1. Ratio fixtures are independently supplied,
not converted from difference effects. No beneficial labels or P-based colors
are generated.

`compose_forest_panels(panels, independent_x_scales=FALSE)` requires identical
subgroup row structures. Shared x ranges include every supplied CI. Different
effect scales require explicit `independent_x_scales=TRUE`; null values stay
attached to their respective scale. The composer never changes effect values.
For an 85-mm figure use a single column when full forest tables are dense;
the provided demo stacks two forests. The 178-mm demo places them side by side.

## Export, fixtures and review

Native composite figures are vector-safe grid/gtable grobs accepted by the same
`export_publication_figure()` contract. `gtable` is already a locked ggplot2
dependency; `grid` is part of R. No statistical dependency lockfile is changed.
PDF/SVG and 600-DPI TIFF/PNG retain 85/178-mm requests and minimum 7 pt fonts.
The native R whole-point vector canvas rounding remains explicitly documented.
Avoid reducing text to fit crowded real data; increase height or change the
panel arrangement, and inspect the actual final outputs.

All original generic fixtures are `SYNTHETIC_DEMONSTRATION_ONLY`. They are
independent toy inputs, not a joint estimated study or a reconstruction of the
benchmark cohort. The supplied CIF example is independent of the survival
example, not a 1-KM calculation with competing events censored. The full
72-output matrix and 36 CVD/grayscale previews stay
under ignored `output/publication_capability/`; selected PNGs document the APIs.

```text
Rscript tests/test_publication_capabilities.R
Rscript figure_gallery/render_publication_capabilities.R
Rscript validation/validate_publication_accessibility.R
python validation/validate_sci_style_exports.py --capability-gallery
```

Machine and AI-assisted visual checks do not grant scientific/publication
approval. Every new QC row remains `publication_ready=FALSE`,
`manual_review=PENDING`. See the [benchmark matrix](../../reports/jar_tte_benchmark_capability_matrix.md)
and [CCW gaps/validation plan](../../reports/ccw_production_parity_gap_and_validation_plan.md).
