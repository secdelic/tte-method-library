script_arg <- grep("^--file=", commandArgs(FALSE), value = TRUE)
root <- normalizePath(
  file.path(dirname(sub("^--file=", "", script_arg[[1]])), ".."),
  winslash = "/", mustWork = TRUE
)
source(file.path(root, "runtime", "load_library.R"))
tte_source_library(root)
config <- file.path(root, "examples", "quick_start", "config")
data <- utils::read.csv(
  file.path(root, "examples", "quick_start", "input", "private", "analysis_data.csv"),
  stringsAsFactors = FALSE, check.names = FALSE
)
checks <- validate_runtime_contract_files(
  file.path(config, "analysis_spec.yml"),
  file.path(config, "variable_dictionary.csv"),
  file.path(config, "input_data_contract.csv"),
  profile = "BASELINE_BINARY_RISK", execution_mode = "SYNTHETIC_TEST",
  data_names = names(data)
)
stopifnot(nrow(checks) > 0L, all(checks$pass))

contract <- utils::read.csv(file.path(config, "input_data_contract.csv"),
                            stringsAsFactors = FALSE, check.names = FALSE)
contract$relative_path <- "input/private/../../outside.csv"
negative <- validate_input_data_contract(contract)
stopifnot(!negative$pass[negative$check == "no_path_traversal"])
message("Runtime contract tests PASS")
