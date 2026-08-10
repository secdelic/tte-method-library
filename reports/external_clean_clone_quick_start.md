# External Clean-clone Quick Start Validation

`EXTERNAL_QUICK_START = PASS`

## Source isolation

- Clone source: anonymous public HTTPS Git access
- Checked-out reference: `v1.0.0-rc1`
- HEAD: `df33cb71d5fc40ea8737cc8d98771ee5465db296`
- Git alternates: absent
- Canonical repository paths used: `0`
- Original local RC1 paths used: `0`
- Private governance YAML used: `0`
- Repository worktree after validation: clean

The clone and its dependency roots were created under a separate external-validation root. Reports use placeholders instead of recording the workstation's absolute path.

## Environment restore

The validation used R `4.5.1`, a newly created `RENV_PATHS_ROOT`, and a separate `R_LIBS_USER`. No prior local renv cache was reused.

Commands equivalent to the README installation instructions were run:

```text
install.packages("renv")
renv::restore(prompt = FALSE)
```

- process exit code: `0`
- total process elapsed time: `140.8` seconds
- `renv::restore()` elapsed time: `93.7` seconds
- lockfile packages: `149`
- newly downloaded differing packages: `renv`, `Rcpp`
- remaining locked versions already satisfied by the machine-level R library: `147`
- warning: the bootstrap `renv` binary was built under R 4.5.3; the lockfile restored `renv` 1.2.2 and execution under R 4.5.1 completed successfully

This proves that no existing renv cache was required. It is not a claim of testing on a machine with no R packages installed; the successful public GitHub Actions run provides the separate clean-runner corroboration.

## README Quick Start

Command:

```text
Rscript examples/quick_start/run_quick_start.R
```

- exit code: `0`
- elapsed time: `4.4` seconds
- warnings table rows: `0`
- undocumented runtime requirement: none found

Generated outputs included contract, structure, balance, ESS and weight diagnostics; independent validation; primary effects; Table 1; sensitivity results; package versions; figure QC; PDF, SVG, PNG and TIFF figures. All inputs were fixed-seed synthetic data.
