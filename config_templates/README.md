# Configuration templates

Copy the templates into a private analysis project and complete every researcher-defined scientific field before a canary or formal-candidate run.

- `analysis_spec.yml`: frozen design and statistical analysis specification.
- `variable_dictionary.csv`: investigator-assigned variable roles and timing.
- `input_data_contract.csv`: private input file manifest and key contract.
- `figure_config.yml`: journal-neutral publication-figure settings.

The runtime validates these objects. It does not select confounders, estimands, treatment definitions, outcomes, time zero or models.

## Project entry

`runtime/project_workspace.py init <project_id>` copies these unresolved
templates into `project/<project_id>/config/` without replacing existing files.
`project_report_config.json` is the optional, disabled Word template; it supplies
no scientific approval or study definitions. See
[project workspaces](../docs/project_workspace.md) for the actual commands and
the separate optional Word code dependency.
