# CCW production parity gap and validation plan

Date: 2026-10-14. This is a proposed future validation plan, not an approved
statistical protocol or evidence that any CCW run occurred in this task.
The [benchmark matrix](jar_tte_benchmark_capability_matrix.md) documents
the supplied JAR main text and the audited public implementation.

`CCW_METHOD_CAPABILITY_PARITY = NOT_ESTABLISHED`

The public production registry has only two ATE profiles. CCW development
labels, specification placeholders, installed packages, diagrams, supplied
curves and synthetic publication fixtures do not create CCW execution or
validation evidence. No estimator, registry/readiness field or frozen expected
value is changed by this task.

| Component | Existing implementation/validation | Missing implementation/validation | Independent comparator / known-truth requirement |
| --- | --- | --- | --- |
| Protocol / per-protocol estimand | Frozen-field structural validation for baseline/MI | CCW-specific approved protocol, estimand, unit and time-zero contract | Investigator freezes eligibility, assignment, adherence, grace boundaries, follow-up and causal contrast before code/tests |
| Clone generation | None in audited public execution tree | Original subject-to-clone mapping; one strategy per clone; correct baseline replication | Small hand-enumerated clone tables; exact mapping/count assertions; no double-counted independent subjects |
| Strategy assignment / grace | Description fields and visualization utilities only | Explicit strategy compatibility rules, grace inclusivity and event ordering | Independent state-transition oracle covering entry, before/at/after boundaries and event/treatment ties |
| Repeated adherence / artificial censoring | Timeline can display caller-supplied times | Interval assessment, deviation handling, no post-censor contribution | Hand-enumerated longitudinal histories and externally reviewed transition rules; compare every retained interval |
| IPCW / time-varying model | Baseline treatment-PS weights only | Censoring risk sets, permitted covariate timing, conditional probabilities and cumulative products | Independent logistic prediction/product calculations on tiny known inputs; validate denominators, event order, positivity and temporal information |
| Stabilization / truncation | Baseline truncation helper and sensitivity execution; no CCW validation | Approved numerator model and truncation domain/rules; IPCW invariance and diagnostics | Hand-specified weight vectors/cutpoints and a separate implementation; preserve extreme-weight failures rather than selecting a favorable threshold |
| Subject-level inference | Independent formulas for the two registered profiles | Clone dependence, subject clustering and entire-pipeline uncertainty | Original-subject resampling keeps dependent clones together and refits required stages; independent variance/coverage checks |
| Weighted survival / differences | Supplied survival curves can be plotted | Weighted event/risk sets, survival estimation, contrasts and intervals | Hand product-limit oracle plus a separately implemented weighted estimator using the same frozen rules |
| Weighted CIF / competing risks | Supplied cumulative incidence can be plotted | Cause/event state encoding, weighted multistate risk sets, CIF contrasts and inference | Hand product-integral/Aalen-Johansen oracle; compare all cause probabilities and event-free survival, not 1-KM with competing events treated as ordinary censoring |
| RMST / RMTL | Figure scale labels only | Frozen restriction horizon, integration convention, defined curve/contrast and uncertainty | Independently integrated step curves; clarify all-cause time lost versus cause-specific CIF area before testing |
| Nonparametric bootstrap | No CCW bootstrap implementation | Subject-level complete pipeline resampling; reproducible seed and declared replicate/failure policy | Separate resampling/index oracle; repeat clone/censor/weight/curve/contrast stages; report nonestimable replicates rather than silently dropping them |
| Grace-period sensitivity | Baseline weight-truncation sensitivity only | Caller-prespecified alternative strategies/windows and full CCW re-execution | Independently enumerated transitions for every approved alternative; no automatic choice based on favorable effects |
| Subgroup CCW | Hierarchical supplied-result forest only | Prespecified subgroup pipeline, model/inference rules and interaction estimand if claimed | Original-subject membership oracle and independently verified subgroup estimates; no inference from forest color or CI overlap |
| Missing-data handling | PMM plus weighting/Rubin in continuous ATE is validated | CCW-specific missing-data/imputation and pooling/bootstrap ordering; benchmark RF/Midastouch paths not implemented | Separate completed-data oracle and explicit preservation of temporal roles; do not substitute complete cases or one imputation to get PASS |

## Comparator candidates, not selected implementations

For supported data/weight conventions, `survival::survfit()` can be an
independent reference for weighted product-limit / multistate estimates; its
documentation explains Aalen-Johansen and the single-event KM case.
[Official survival documentation](https://stat.ethz.ch/R-manual/R-devel/library/survival/html/survfit.formula.html).
This does not establish that a generic call reproduces a particular CCW
estimand: time-varying weights, start/stop risk sets, event ties, subject/clone
dependence and uncertainty must match the future frozen specification.

Weighted `n.risk` can be a sum of weights; it must not be rounded or relabeled
as participant counts. Independently validated aggregate counts must identify
the subject/clone/counting unit.
[Official survfit object documentation](https://stat.ethz.ch/R-manual/R-devel/library/survival/html/survfit.object.html).

Known-truth simulations must be original and fixed before evaluation: no
censoring, no treatment effect, controlled nonzero effect, competing events,
informative deviations, boundary/tie cases and positivity failures. Truth,
sample unit, random seeds, repetition counts, bias/coverage/precision tolerances
and failure handling require an investigator-approved validation protocol.
These simulations and comparator calculations were not run in this task.

## Runtime and publication gates

1. Keep CCW absent from the production allowlist until implementation, frozen
   numerical regression, known-truth studies and independent review all exist.
2. A complete pipeline must cover clones, strategies, grace, interval censoring,
   IPCW, stabilization/truncation, subject-level inference, weighted survival,
   competing-risk/CIF analysis, required contrasts, prespecified sensitivities
   and subgroup execution. RMST/RMTL/bootstrap need evidence if claimed.
3. Record which tests use hand oracles, simulations, external implementations
   and real-project validation. Passing a plot test is never statistical parity.
4. Scientific adoption and real-study figure/publication approval remain human
   decisions. No source-file existence, fixture rendering or CI PASS changes
   the current method readiness or establishes JAR-equivalent scientific output.

`FIGURE_CAPABILITY_PARITY_READY` and `CCW_METHOD_PARITY_NOT_ESTABLISHED` can
coexist for the explicitly tested visualization scope.
