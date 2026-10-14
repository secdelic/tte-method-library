# JAR TTE benchmark capability matrix

Audit date: 2026-10-14. Baseline public candidate: `cbc4424`.
This matrix separates visual style, visualization utilities, and executable
statistical methods. Status describes this repository, not the benchmark's
scientific validity. No paper data, result values, images, icons or code are used.

Benchmark: Liu et al., *Effect of early packed red blood cell transfusion on
sepsis-associated acute kidney injury: A target trial emulation*, Journal of
Advanced Research, DOI [10.1016/j.jare.2026.08.009](https://doi.org/10.1016/j.jare.2026.08.009),
[PMID 42571852](https://pubmed.ncbi.nlm.nih.gov/42571852/).
Title/journal/year/identifiers were verified against Crossref and PubMed.
The researcher supplied the nine-page corrected-proof PDF. Relevant main-text
methods (pp. 2-3), Fig. 1 (p. 3), Fig. 2 (p. 4), Fig. 3 (p. 6) and Fig. 4
(p. 7) were read/rendered locally. Supplemental Data 1/2 and other supplements
were not supplied or inspected. No supplement-specific claim is inferred.

Evidence keys:

- **REG**: [production registry](../runtime/production_registry.csv), only
  `BASELINE_BINARY_RISK` and `MI_PS_CONTINUOUS_ATE`, both ATE.
- **GATE**: [runtime](../R/core/runtime.R), `tte_assert_profile_allowed()` and
  dispatch to only baseline/MI estimators.
- **SPEC**: [specification validator](../R/core/validation.R),
  `tte_required_analysis_fields()` / `validate_analysis_spec()`, and
  [template](../config_templates/analysis_spec.yml). Field placeholders are
  not execution implementations.
- **BASE**: [baseline estimator](../R/estimators/baseline_tte.R),
  [effect formulas](../R/estimands/effect_measures.R).
- **WT**: [propensity weights](../R/weighting/propensity_weights.R), including
  `tte_truncate_weights()`; these are baseline treatment weights, not IPCW.
- **MI**: [imputation](../R/missing_data/multiple_imputation.R) and
  [MI estimator](../R/estimators/mi_ps.R), audited PMM/Rubin path.
- **NUM**: [frozen regression](../validation/run_public_numerical_regression.R),
  [fixtures](../validation/fixtures/baseline_effects.csv), and
  [independent formulas](../R/diagnostics/independent_validation.R).
- **FIG**: [native figure constructors](../R/figures/publication_figures.R).
- **FTEST**: [native figure tests](../tests/test_publication_figures.R).

## A. Statistical methods at cbc4424

| Capability | Benchmark main-text evidence | Repository status | Code/registry/test evidence and scope |
| --- | --- | --- | --- |
| Target trial protocol | Protocol table and design description, pp. 2-3 | PARTIALLY_IMPLEMENTED | SPEC captures researcher-supplied fields; REG/GATE execute only baseline/MI. Clinical design is investigator-owned. |
| Per-protocol estimand | Explicit causal contrast, p. 3 | NOT_IMPLEMENTED | REG only ATE; no CCW per-protocol dispatch or numerical test. |
| Cloning | Duplicate and assign at baseline, p. 3/Fig. 2 | NOT_IMPLEMENTED | No clone generator in public R/runtime; FIG schematic cannot generate analysis clones. |
| Treatment strategy assignment | Assigned clone strategies, p. 3 | NOT_IMPLEMENTED | SPEC stores strategy descriptions; BASE uses existing binary treatment, not clone assignment. |
| Grace period | Prespecified treatment window, pp. 2-3 | PARTIALLY_IMPLEMENTED | SPEC stores grace fields; no grace handling in registered estimators/tests. |
| Repeated adherence assessment | Interval compatibility checks, p. 3 | NOT_IMPLEMENTED | No longitudinal adherence state machine or test. |
| Artificial censoring | Deviation ends a clone's follow-up, p. 3/Fig. 2 | NOT_IMPLEMENTED | No artificial-censoring implementation in public runtime. |
| IPCW | Explicit censoring weights, p. 3 | NOT_IMPLEMENTED | WT fits treatment propensity scores; it is not a censoring-weight model. |
| Time-varying censoring model | Interval logistic model, p. 3 | NOT_IMPLEMENTED | No interval censor-model dispatch; detailed supplement model specification not assessed. |
| Weight truncation | Censor-weight truncation reported, p. 3 | IMPLEMENTED_NOT_PRODUCTION_VALIDATED | WT/BASE implement baseline treatment-weight truncation sensitivity; NUM freezes primary values, not CCW censor-weight truncation. |
| Competing-risk analysis | Competing event accounted for, p. 3 | NOT_IMPLEMENTED | Template label and FIG formatter only; no cause-specific/multistate estimator or comparator test. |
| Weighted cumulative incidence | Reported and displayed in Fig. 3 | NOT_IMPLEMENTED | FIG consumes supplied estimates; no weighted cumulative-incidence estimator. |
| Weighted Kaplan-Meier | Reported and displayed in Fig. 3 | NOT_IMPLEMENTED | FIG consumes supplied curves; no weighted KM estimator. |
| Risk difference | Main-text effect measure | PRODUCTION_VALIDATED | BASE/REG/NUM validate fixed-horizon baseline binary ATE RD only; not CCW/competing-risk RD. |
| Survival difference | Main-text effect measure | NOT_IMPLEMENTED | No weighted survival estimator or survival-difference inference. |
| RMST | Main-text effect measure | NOT_IMPLEMENTED | Recognized figure scale label is not an RMST estimator or test. |
| RMTL | Main-text effect measure | NOT_IMPLEMENTED | No RMTL estimator, integration or inference implementation. |
| Nonparametric bootstrap | Main-text interval method, p. 3 | NOT_IMPLEMENTED | SPEC has a variance placeholder; registered profiles use other variance methods. The paper's resampling unit is not established from supplied main text. |
| Alternative grace-period sensitivity | Main-text sensitivity analysis, p. 3 | NOT_IMPLEMENTED | BASE sensitivity changes baseline weights, not CCW grace strategies. |
| Subgroup CCW | Main-text sensitivity/Fig. 4 | NOT_IMPLEMENTED | No subgroup clone/censor/weight pipeline or validated subgroup inference. |
| Missing-data strategies | Main-text RF; PMM/Midastouch sensitivity, p. 3 | PARTIALLY_IMPLEMENTED | MI/REG/NUM validate PMM plus weighting/Rubin for continuous ATE; no RF/Midastouch CCW pipeline. |
| Subject-level CCW inference | Required parity gate; main-text cluster details incomplete | NOT_IMPLEMENTED | No subject-clustered CCW variance or subject-level bootstrap test. |
| IPCW stabilization | Required if claimed; not established in main text | NOT_IMPLEMENTED | No IPCW numerator/denominator implementation or stabilization validation. |

`CCW_METHOD_CAPABILITY_PARITY = NOT_ESTABLISHED`

The module-readiness document describes CCW development/synthetic scope, but
the audited public tree has no executable CCW estimator or corresponding
production validation. No unseen private implementation is credited here.
Package availability, template choices and figure-scale aliases are not proof
of implemented or validated methods. Future requirements and comparators are
documented separately; no statistical implementation is changed in this task.

## B. Publication visualization at cbc4424

| Capability | Benchmark evidence | Baseline repository status | Code/test evidence or gap |
| --- | --- | --- | --- |
| Participant flowchart | Fig. 1: boxes, exclusions, branches, counts | NOT_IMPLEMENTED | `plot_cohort_flow()` is a bar chart; FTEST does not test connectors/branches. |
| Target-trial research flow | Fig. 2a: population/outcomes/methods | NOT_IMPLEMENTED | No protocol-flow constructor; count bars do not express research stages. |
| Clone-censor timeline | Fig. 2b: strategy/event timelines | PARTIALLY_IMPLEMENTED | `plot_ccw_strategy_schematic()` draws status tiles, without individual clone/event timing. |
| Weighted cumulative-incidence curve | Fig. 3a | VISUALIZATION_ONLY | `plot_cumulative_incidence()` can display supplied estimates; weight provenance/estimation is caller-owned. |
| Weighted KM curve | Fig. 3b-d | VISUALIZATION_ONLY | `plot_survival_risk()` formats caller curves; no KM estimator. |
| Confidence bands | Fig. 3 | VISUALIZATION_ONLY | Native optional ribbons, exercised by FTEST; CIs are caller-supplied. |
| Number-at-risk table | Fig. 3 | NOT_IMPLEMENTED | No risk-table input, alignment or tests. |
| Effect annotation | Fig. 3 | NOT_IMPLEMENTED | No publication wrapper supporting supplied effect text. |
| Multi-time-horizon panels | Fig. 3 | NOT_IMPLEMENTED | No outcome-panel composer or shared strategy/legend tests. |
| Subgroup forest | Fig. 4 | PARTIALLY_IMPLEMENTED | `plot_forest()` accepts flat labeled intervals only. |
| Grouped subgroup labels | Fig. 4 | NOT_IMPLEMENTED | No section headers/indented category structure. |
| Estimate/CI text columns | Fig. 4 | NOT_IMPLEMENTED | Native forest displays intervals graphically only. |
| Multi-panel forest assembly | Fig. 4 | NOT_IMPLEMENTED | No row-aligned composer or scale-configuration checks. |

## C. Style is a separate decision

The researcher explicitly confirmed PASS on 2026-10-14 for the 14 cbc4424
synthetic candidate figures at 85/178 mm. This supports adopting the current
navy/terracotta/teal/gold/slate/charcoal direction, not estimator equivalence
or study-specific publication approval. PR #2 stays STYLE ONLY; implementation
of the visualization gaps belongs on its separate v1.2 candidate branch.

## D. Publication visualization after the separate v1.2 upgrade

Completion review: 2026-10-15. Statistical statuses in A are unchanged.
**CAP** = [new native constructors](../R/figures/publication_capabilities.R);
**CTEST** = [structural/semantic tests](../tests/test_publication_capabilities.R);
**EXP** = [72 actual-file export checks](publication_capability_export_validation.csv);
**DEMO** = [original fixtures](../figure_gallery/publication_capability_fixtures.R)
and [nine selected gallery PNGs](../figure_gallery/publication_capability/README.md).

| Capability | Current status | Code/test/export evidence and boundary |
| --- | --- | --- |
| Participant flowchart | VISUALIZATION_ONLY | CAP `plot_participant_flowchart()` validates explicit connected DAG nodes/edges and supplied counts/reasons; CTEST branches/count labels/cycle rejection; EXP both widths/four formats. |
| Target-trial research flow | VISUALIZATION_ONLY | CAP `plot_tte_ccw_timeline(research_steps=...)` adds supplied box/connector stages; DEMO/EXP show stages above clone lanes. It does not execute the described stages. |
| Clone-censor timeline | VISUALIZATION_ONLY | CAP `plot_tte_ccw_timeline()` renders supplied strategies, grace boundaries, treatment, artificial/natural censor, outcomes, competing events and end times; CTEST exact event x positions and tied-event separation. |
| Weighted cumulative-incidence curve | VISUALIZATION_ONLY | CAP `plot_survival_risk_publication(measure="cumulative_incidence")` displays supplied values/bands/counts; no weight construction or CIF estimation. |
| Weighted KM curve | VISUALIZATION_ONLY | Same wrapper with explicit survival measure; CTEST retains supplied values; weighted KM inputs/provenance remain caller-owned. |
| Confidence bands | VISUALIZATION_ONLY | Existing FIG ribbon layer reused, not re-estimated; DEMO/EXP actual ribbons inspected at both widths. |
| Number-at-risk table | VISUALIZATION_ONLY | CAP explicit integer aggregate table with all displayed strategy/time keys; aligned curve/table widths; CTEST missing-row rejection, count preservation and endpoint placement. No inferred weighted participant counts. |
| Effect annotation | VISUALIZATION_ONLY | CAP caller text below curve; no calculated effects; CTEST/DEMO/EXP exercise it. |
| Multi-time-horizon panels | VISUALIZATION_ONLY | CAP `compose_outcome_panels()` shared color/linetype legend and labels; explicit optional shared x range; CTEST range/mapping/layout checks. Caller determines horizons; no 7/28/90-day hardcoding. |
| Subgroup forest | VISUALIZATION_ONLY | CAP `plot_subgroup_forest()` supplied difference/ratio effects; CTEST raw values and null=0/1; EXP readable intervals/reference/text. |
| Grouped subgroup labels | VISUALIZATION_ONLY | CAP explicit header/category hierarchy, indentation and Overall emphasis; CTEST invalid hierarchy rejection. No inferred clinical grouping. |
| Estimate/CI text columns | VISUALIZATION_ONLY | CAP neutral formatted effect/CI plus optional supplied N/interaction; CTEST text and preserved input values; no P/CI-based benefit labels/colors. |
| Multi-panel forest assembly | VISUALIZATION_ONLY | CAP `compose_forest_panels()` same row structures and common fonts/ranges; independent scales require explicit opt-in; CTEST alignment/scale rules, EXP both arrangements. |

`FIGURE_CAPABILITY_PARITY_READY` applies to the tested information architecture
and native export scope. It is not pixel/layout imitation, paper replication,
real-study validation or statistical-method parity. All new example QC records
remain `publication_ready=FALSE`, `manual_review=PENDING`. Real-data density,
scientific interpretation and adoption require the investigator's review of
the actual study-specific inputs and exports.
