project_root <- normalizePath(".", winslash = "/", mustWork = TRUE)
if (!file.exists(file.path(project_root, "runtime", "load_library.R"))) {
  stop("Run this script from the repository root")
}
source(file.path(project_root, "runtime", "load_library.R"))
tte_source_library(project_root)

example_root <- file.path(project_root, "examples", "quick_start")
result <- tte_run_analysis(
  profile = "BASELINE_BINARY_RISK",
  data_path = file.path(example_root, "input", "private", "analysis_data.csv"),
  config_dir = file.path(example_root, "config"),
  output_dir = file.path(example_root, "output"),
  execution_mode = "SYNTHETIC_TEST",
  project_root = project_root
)

if (!isTRUE(result$gate$diagnostic_gate_pass)) {
  stop("Synthetic Quick Start diagnostic gate failed: ", result$gate$stopping_reasons)
}
message("Synthetic production Quick Start PASS")
