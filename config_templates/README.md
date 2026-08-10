# Configuration templates

Copy the templates into a private analysis project and complete every researcher-defined scientific field before a canary or formal-candidate run.

- `analysis_spec.yml`: frozen design and statistical analysis specification.
- `variable_dictionary.csv`: investigator-assigned variable roles and timing.
- `input_data_contract.csv`: private input file manifest and key contract.
- `figure_config.yml`: journal-neutral publication-figure settings.

The runtime validates these objects. It does not select confounders, estimands, treatment definitions, outcomes, time zero or models.
