# Optional Word analysis reports

The reporting entry assembles existing aggregate results, caller-written study definitions, tables and images into one editable Word document. It does not fit models, read patient-level inputs, choose an estimand or create manuscript interpretations. It is separate from the R analysis runtime and is disabled by default.

The report has three body sections: **Methods**, **Results** and **Next Steps**. Chinese labels are available with `language: "zh-CN"`. This template is for research analysis reports; it is not a manuscript, protocol or grant template. It adds no Discussion, Conclusion, scientific approval, publication decision or execution log.

## Run the saved synthetic example

Use Python 3.11 or later and install the optional dependencies. Existing R analyses do not need these dependencies.

```text
python -m pip install -r reporting/requirements.txt
python runtime/render_report.py --config examples/word_reporting/report_config.json
```

The second command leaves reporting disabled and writes no report. Explicitly enable it to assemble the existing synthetic continuous-outcome fixture:

```text
python runtime/render_report.py --config examples/word_reporting/report_config.json --enable --output output/reports/continuous_analysis.docx --internal-dir output/reporting_checks
```

Only the DOCX is intended for the report recipient. Keep the internal directory separate; it holds input identity and repeat-run checks. No Markdown or PDF report is delivered by the entry.

The example reads [the frozen MI result](../validation/fixtures/mi_effects.csv), without rerunning imputation or propensity weighting. It deliberately has no figures. Rendering a report does not change the fixture's synthetic or audit status, or grant scientific approval.

## Supply an analysis report configuration

The [example configuration](../examples/word_reporting/report_config.json) is the minimal reusable starting point. Set `report_enabled` to `true`, or use the explicit `--enable` flag. The only supported `report_format` is `docx`, and the only supported `report_template` is `methods_results_next_steps`.

Supply `title`, `language` (`en` or `zh-CN`), and a `study` object containing the actual `design` and `population`. Other available study fields are `eligibility`, `time`, `exposure`, `comparator`, `outcome`, `models`, `adjustment`, `missing` and `uncertainty`. These are caller-authored descriptions, not inferred from a profile name. Omit inapplicable fields; describe actual unresolved information explicitly when it matters. Do not supply invented dates, ethics statements or clinical decisions.

The `methods`, `results` and `next_steps` arrays contain ordered blocks:

| Block | Required content | Behavior |
|---|---|---|
| `paragraph` | `text` | Inserts caller-written prose. |
| `heading` | `text` | Inserts a subsection within one of the three sections. |
| `table` | `path`, `columns`, `caption` | Imports the named CSV columns as an editable Word table. Each column has `key` and `label`; optional `digits` controls display rounding. |
| `effects` | `path`, `caption` | Adapts the existing effect-result CSV schema to an editable results table. |
| `figure` | `path`, `caption` | Embeds an existing local image. It never calculates or invents a figure. |

Tables and effects can include `note`. Table `column_widths` and figure `width_inches` are optional layout hints. Paths are resolved relative to the configuration file, not the shell's working directory. An asset may include `sha256` to enforce a frozen input identity. Explicitly declared missing assets fail; omitting a figure block produces no figure.

### Existing method-library results

The `effects` adapter accepts the output from `tables/primary_effects.csv` and the frozen result fixtures. It recognizes `effect_measure` or `effect`, `standard_error` or `se`, and `ci_lower`/`ci_upper` or `conf_low`/`conf_high`, alongside `estimate`. Supplied analysis labels remain visible so primary and sensitivity rows are not conflated. It copies supplied estimates and interval endpoints; it never derives a confidence interval from a standard error. Missing uncertainty stays unavailable, and a partially populated interval is rejected. When an interval is present, supply an accurate `interval_label`, including its level and method in the note or study definition.

`decimals` controls display precision (default 4). `scale` defaults to 1; changing it explicitly scales estimates, standard errors and interval endpoints together. A risk difference on a probability scale can be displayed in percentage points using 100 only when the caller labels that unit correctly. Never apply that conversion to a ratio or mean difference without a defensible unit definition. Source values are not modified.

For a baseline or diagnostic table, explicitly map only the intended aggregate columns. For example, a generated `tables/table1.csv` can map `Variable`, `Group`, `Unweighted`, `Weighted` and the SMD columns. The report does not read the runtime's `internal/` objects or reproduce the complete statistical release directory.

### Aggregate input boundary

An enabled report requires `data_classification` equal to `AGGREGATE_ONLY_CONFIRMED` or `SYNTHETIC_CONFIRMED`. Tables with patient-capable identifier columns are rejected even if those columns were not selected for display. This is a guardrail, not automatic proof of de-identification. The caller remains responsible for reviewing the prose, tables, figures and supplied paths before use. Keep private configurations, source material and rendered clinical reports outside the repository.

Only declared assets are read. There is no folder-wide asset discovery, remote download, statistical execution or default figure generation. Internal paths and checks are not inserted into the document.

## Author edits and repeat runs

An optional `author_reference` object binds `path` and `sha256` to the actual local author reference. A hash mismatch stops generation. It also requires `wording_reviewed: true`: the caller must first compare accepted author wording against the supplied report content. This is an editorial alignment declaration, not scientific approval and not an automated semantic check. The reference does not automatically rewrite the report or treat an editorial change as approval of new scientific content. Tracked deletions and insertions are read as such rather than as undifferentiated extracted text. Unresolved comment markup stops generation.

Existing output is never silently replaced. An unchanged output with matching internal identity may be reused. If a researcher edits the output Word, the entry preserves it and stops rather than restoring older configured prose. Reconcile the author edits into a reviewed configuration or explicitly use a new output filename. This bounded behavior avoids a second editable report becoming the hidden authority; automatic semantic merging of arbitrary Word edits is not supported.

## Validation and limits

Run the separate reporting tests:

```text
python -m unittest discover -s tests -p test_word_reporting.py -v
```

These tests check aggregate input contracts, saved effect schemas, missing uncertainty, document structure, editable tables, real embedded images, input protection and repeat-run behavior. They do not fit any statistical model. The existing R regression suite remains separate and unchanged.

Before adopting a report, render its DOCX using an available document renderer and inspect every page for clipping, font issues, table breaks and orphaned captions. The command-line assembly and CI structural checks do not establish visual quality on every Word version, font set or operating system. Rendering files and visual-review notes belong in the internal working directory. The standalone entry does not require Word or LibreOffice and does not claim that a successful build replaces page inspection.

The module does not change registered statistical profiles, Scientific Authority, estimators, confidence-interval methods or release readiness. A caller-supplied experimental result stays experimental. Local clinical aggregate regression and the supplied synthetic example validate report assembly within their tested scope; they do not establish clinical validity, universal layout fidelity or readiness of an unapproved method.
