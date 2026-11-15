# Project workspaces

**所有后续新项目统一使用`project/<project_id>/`，不再手动指定互相独立的任意输出根目录。**

The new project entry anchors every study to the actual Git checkout containing
the entry script. Python 3.11 or later and the existing R environment are needed.
The statistical path uses only the Python standard library; Word is optional.
Shell working directories do not determine project or result locations.
R starts in the library checkout to load its installed locked environment,
then enters the project before executing the analysis.

## Initialize and execute a study

From the repository root:

```text
python runtime/project_workspace.py init SEPSIS_AKI
```

Use a researcher-chosen, non-identifying research code of 1–64 ASCII letters,
digits, underscores or hyphens, starting with a letter or digit. Do not include
patient identity. This restricted syntax cannot establish that a code contains
no identity; the researcher must choose an appropriate code. Reserved device
names, case conflicts, traversal, absolute paths, links and Windows junctions
are rejected.

Initialization creates directories and copies unresolved templates only. It
reuses an existing exact-case project and never replaces its files. No study
definitions, scientific approval or clinical rows are generated. No historical
JM1021 directory is moved or imported.

Place the prepared private CSV at
`project/SEPSIS_AKI/input/private/analysis_data.csv`. Supply researcher-confirmed
`analysis_spec.yml`, `variable_dictionary.csv`, `input_data_contract.csv` and
`figure_config.yml` in `project/SEPSIS_AKI/config/`. Replace the unresolved
templates; do not treat them as an approved protocol. The input contract must
declare the selected project input and its hash, when supplied, must match.

Select an actually approved profile and the appropriate execution mode:

```text
python runtime/project_workspace.py run SEPSIS_AKI --profile BASELINE_BINARY_RISK --execution-mode CANARY --run-id run_001
```

The profile here is an example, not a recommendation for this study. The
repository Registry still controls permission. CCW is not authorized by a
project configuration. `CANARY` and `FORMAL_CANDIDATE` retain the existing
scientific-freeze checks; successful execution grants no scientific approval.
Use `SYNTHETIC_TEST` only for synthetic inputs. A diagnostic gate can fail even
when model execution completes; its actual Boolean is recorded and returned.

Omit `--run-id` to get a UTC timestamp plus random identifier. Reusing an
existing ID, including a case variant, is rejected. `--data` accepts only paths
under this project's `input/`; both slash conventions work. Configuration is
always taken from this project's `config/`. `--rscript` optionally names the
installed Rscript executable. There is no arbitrary output-root option.

```text
project/SEPSIS_AKI/
  input/private/analysis_data.csv
  config/
  runs/
    index.json
    run_001/
      output/{diagnostics,tables,figures,sensitivity,internal,logs}/
      report/
      internal/
        config/
        run.json
        runtime.log
```

Each run takes a private configuration snapshot before calling the original
`tte_run_analysis` function. It records project/run identity, mode, repository
commit, actual R/adapter code hashes, input/configuration/Registry hashes, output hashes, timestamps and the
diagnostic gate. Inputs and project configurations are checked for changes
during execution. Raw patient data are not duplicated into snapshots. Keep the
matching private input version separately if exact reruns are required.

Read results and figures in the selected run's `output/`. `runs/index.json`
locates runs and their report versions. Failed runs retain their directory,
snapshot and failure status; do not reuse the ID. Statistical errors go to that
run's private `internal/runtime.log`, not to shared output or console data dumps.
These logs may contain sensitive runtime context and remain private.

A project lock prevents concurrent mutation of the same index or report. Other
projects can execute independently. An interrupted process may leave
`runs/.workspace.lock`; verify that no process is active and inspect the run
before removing that empty lock directory. No lock is automatically stolen.

## Word from a completed run

Word stays disabled for statistical runs and for a `report` call without
`--enable`, even if a project config enables the standalone adapter. Reporting
does not call R, refit a model or produce new estimates. Only the DOCX is the
user report; snapshots and validation state remain in `internal/`.

This integration branch includes the unchanged optional Word module from
[Draft PR #7](https://github.com/secdelic/tte-method-library/pull/7), alongside
the project entry from PR #8. The original PRs remain separate and unmerged.
No additional checkout or `--reporting-library` argument is needed here:

```text
python -m pip install -r reporting/requirements.txt -c reporting/constraints.txt
```

The Windows setup script can install these optional dependencies into `.venv/`.
See [cross-PC migration](CROSS_PC_MIGRATION.md) for a full clean-checkout example.

Edit this project's `config/report_config.json`, replacing every placeholder
with confirmed prose. Declare `AGGREGATE_ONLY_CONFIRMED`, or
`SYNTHETIC_CONFIRMED` for synthetic material. Use the PR's existing block schema
and Methods—Results—Next Steps template. Unlike the standalone adapter, asset
paths here are **relative to the selected run**, for example
`output/tables/primary_effects.csv` and `output/figures/covariate_balance.png`.
Only unchanged, hashed outputs in this run's `tables/`, `sensitivity/` and
`figures/` are accepted. Tables with patient-capable identifier columns are also
rejected by the existing adapter. Classification and identifier guards are not
proof of de-identification; review the actual content.

```text
python runtime/project_workspace.py report SEPSIS_AKI --run-id run_001 --enable
```

The report is `project/SEPSIS_AKI/runs/run_001/report/analysis_report.docx`.
Project and run identity are added to the supplied title. Existing tables stay
editable and declared existing images are embedded. No figure block means no
figure. The report configuration must accurately state study definitions,
uncertainty and any unresolved diagnostic findings; no causal interpretation is
inferred by the assembler. Inspect the actual diagnostic gate before adoption.
Render and visually inspect every page before using a report externally.

To correct reviewed content, preserve the previous Word and request a new
version in the same run:

```text
python runtime/project_workspace.py report SEPSIS_AKI --run-id run_001 --enable --report-version analysis_report_v2
```

Repeating identical report inputs reuses the unchanged file. Changed inputs,
modified statistical assets or subsequent author edits are protected from
overwrite. Report configurations are frozen per version with source bindings;
there is no automatic semantic merge of author revisions. An optional author
reference must live under this project's `config/` and retains the standalone
adapter's hash and `wording_reviewed` requirements. External/cross-project
assets, even from another run, are deliberately unsupported by this entry.
Use the unchanged standalone adapter for a separately authorized independent
aggregate source. `--reporting-library` remains available for a deliberately
selected alternate code checkout; normal migration uses this checkout's module.

## Runnable synthetic demonstration and tests

This demonstration copies only the existing public synthetic fixtures. It
binds the new project's input-manifest hash to the copied bytes (Git may check
out CSVs with LF or CRLF), leaving the source fixtures and values unchanged. It
creates `SYNTHETIC_BINARY` and `SYNTHETIC_CONTINUOUS`, executes both approved
profiles, and gives the binary project two runs. It refuses pre-existing demo
projects instead of replacing files. Word remains off by default:

```text
python examples/project_workspace/run_synthetic_projects.py
```

In a fresh checkout with the optional dependencies installed, run the combined
example, which embeds a saved binary diagnostic figure and leaves the
continuous report without a figure:

```text
python examples/project_workspace/run_synthetic_projects.py --enable-word
```

Both examples and all generated inputs/results/reports stay under `project/`
and are ignored by Git. They are workflow tests, not clinical validation.
Use an absolute path to the entry script when invoking it from another shell
directory. The explicit external **code** dependency path is resolved from the
shell; it does not change any project/input/output path.

```text
python -m unittest discover -s tests -p test_project_workspace.py -v
```

For real R integration tests, set `TTE_RUN_WORKSPACE_INTEGRATION=1`; for Word
joint tests also set `TTE_REPORTING_LIBRARY` to this checkout's absolute root.
CI sets both, uses the in-checkout Word module and retains the R
suite, Quick Start, frozen numerical regression and privacy scan. Tests use
temporary Git repositories and existing synthetic fixtures only.

## Legacy compatibility and privacy

The original R signature and calls, legacy Quick Start, standalone Word entry,
fixtures, Registry and estimators are unchanged. The R path adapter scopes only
the Registry read to this library while binding `project_root` to the study.
It does not trust a project-local Registry. Existing API calls remain
compatibility calls with their original path semantics; they are not forced
into `project/` and cannot acquire the new boundary protections automatically.

`/project/` excludes the whole workspace, including private inputs, configs,
results, images, DOCX, logs and snapshots. Do not force-add it. Check
`git check-ignore project/SEPSIS_AKI/config/analysis_spec.yml` before committing
anything unusual. Nothing automatically uploads reports or clinical data.
