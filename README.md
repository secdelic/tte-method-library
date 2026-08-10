# Target Trial Emulation Statistical Analysis Method Library

This repository is a statistical execution library for target trial emulation and related causal-inference analyses. Study design, database extraction, causal-variable definition, and manuscript writing are outside its scope.

The library executes researcher-specified target trial emulation and causal-inference analyses. Scientific study design, causal identification, database extraction and manuscript interpretation remain the responsibility of the investigators.

Version: `1.0.0`
Library status: `COMPLETE_METHOD_LIBRARY_WITH_MIXED_MODULE_READINESS`

## Scope

The software validates prepared analysis data and frozen analysis specifications, executes registered statistical profiles, and exports diagnostics, estimates, sensitivity results, publication-oriented tables and figures, and reproducibility metadata. It never modifies an analysis specification in response to observed results.

## Out of scope

The repository does not perform SQL generation, database connection or extraction, study-question definition, DAG construction, confounder selection, treatment/outcome/time-zero definition, automatic estimand selection, result-driven model selection, causal interpretation, clinical recommendations, manuscript writing, reviewer simulation, or submission decisions.

## Current module readiness

### Production validated

- `BASELINE_BINARY_RISK`
- `MI_PS_CONTINUOUS_ATE`

### Experimental or development scope

CCW, LMTP, longitudinal TTE, PATH, three-timepoint TTE and multilevel propensity-score workflows retain their existing mixed-readiness classifications and are not production-approved in this RC1.

`AVAILABLE != PRODUCTION-APPROVED`

`PRODUCTION EXECUTION IS CONTROLLED BY THE PRODUCTION REGISTRY`

See [module readiness](docs/module_readiness.md) and [known limitations](docs/known_limitations.md).

## Installation

Install R, clone the repository, open its root directory, and restore the locked environment:

```r
install.packages("renv")
renv::restore()
```

Environment restoration may require network access to package repositories. The statistical examples themselves do not download data or contact a database.

## Quick Start

From the repository root:

```text
Rscript examples/quick_start/run_quick_start.R
```

This executes `BASELINE_BINARY_RISK` using fixed-seed synthetic data and produces:

- structural and contract diagnostics;
- propensity scores, weights, balance and ESS diagnostics;
- `primary_effects.csv` and HTML;
- Table 1 without default group-comparison P values;
- PDF, SVG, TIFF and PNG figures;
- `figure_qc.csv` with human visual approval still required.

Outputs are written under `examples/quick_start/output/` and are excluded from Git.

## Input data

Formal studies supply a prepared CSV under a private project location. The runtime expects one row per analysis unit for the two RC1 production profiles, unique `subject_id` and `analysis_id`, explicit ISO-8601 time fields, a binary treatment, a profile-compatible outcome and researcher-approved baseline confounders.

The repository contains synthetic rows only. It contains no real patient data.

## Analysis specification

`analysis_spec.yml` records the researcher-frozen population, time zero, treatment strategies, outcome, estimand, missing-data settings, weighting, variance and prespecified sensitivity analysis. The runtime validates and executes these fields; it does not choose or alter them.

## Variable dictionary

`variable_dictionary.csv` records labels, roles, types, timing, valid values and approved modeling/imputation use. Variable roles must be assigned by the investigator. The library does not determine whether a variable is a confounder, mediator or collider.

## Runtime

Source the library and call the registered execution function:

```r
source("runtime/load_library.R")
tte_source_library(".")

tte_run_analysis(
  profile = "BASELINE_BINARY_RISK",
  data_path = "input/private/analysis_data.csv",
  config_dir = "config",
  output_dir = "output",
  execution_mode = "CANARY",
  project_root = "."
)
```

The output tree is fixed:

```text
output/
├─ diagnostics/
├─ tables/
├─ figures/
├─ sensitivity/
├─ internal/
└─ logs/
```

## Tables

The publication table layer supports unweighted and weighted Table 1 summaries with SMD, primary-effect tables, sensitivity tables, CSV export and optional HTML. Table 1 does not report group-comparison P values by default.

## Figures

The figure system supports vector PDF/SVG and 600-DPI TIFF/PNG output, 85-mm and 178-mm widths, minimum 7-point fonts, colorblind-aware palettes and grayscale redundancy. Machine checks do not replace study-specific human visual approval.

## Synthetic examples

- `examples/quick_start/`: baseline binary-risk production path.
- `examples/mi_ps/`: PMM plus propensity-weighted continuous-outcome ATE path.

Neither example uses a database, SQL, network-downloaded data or real patient information.

## Validation

The RC1 includes:

- canonical-to-public numerical equivalence on identical synthetic inputs;
- frozen public regression fixtures;
- independent formulas for weighted risks, RD, RR, SMD, ESS and Rubin/Barnard-Rubin pooling;
- figure and table contract tests;
- input-contract and private-governance leak gates.

See [numerical equivalence](validation/numerical_equivalence_summary.md) and [independent validation](validation/independent_validation_summary.md).

## Reproducibility

The repository records seeds, configuration files, input hashes, package versions, output contracts and frozen regression tolerances. See [reproducibility](docs/reproducibility.md).

## Citation

Use `CITATION.cff` for the stable-release metadata. The source repository is `https://github.com/secdelic/tte-method-library`. Until Zenodo archives the immutable `v1.0.0` GitHub Release, cite that fixed tag rather than the moving `main` branch. After archival, prefer the version-specific Zenodo DOI. No DOI has been assigned yet.

## License

The project implementation is distributed under the [MIT License](LICENSE). Package dependencies retain their own licenses; see [third-party notices](THIRD_PARTY_NOTICES.md).

## Data privacy

Do not commit research data, credentials or internal configuration. Root `input/private/`, runtime outputs, RDS/RData files, secrets and local caches are ignored. Public examples are fully synthetic.

## Contributing

Contributions must preserve frozen estimands, registry-controlled production scope, synthetic-only tests, privacy gates and mixed-readiness labels. Statistical changes require prespecified validation and independent review before production eligibility changes.
