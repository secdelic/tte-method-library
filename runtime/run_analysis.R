source(file.path("runtime", "load_library.R"))
tte_source_library(".")

profile <- Sys.getenv("TTE_PROFILE", "BASELINE_BINARY_RISK")
data_path <- Sys.getenv("TTE_DATA", "input/private/analysis_data.csv")
config_dir <- Sys.getenv("TTE_CONFIG_DIR", "config")
output_dir <- Sys.getenv("TTE_OUTPUT_DIR", "output")
execution_mode <- Sys.getenv("TTE_EXECUTION_MODE", "CANARY")

tte_run_analysis(
  profile = profile, data_path = data_path, config_dir = config_dir,
  output_dir = output_dir, execution_mode = execution_mode,
  project_root = "."
)
