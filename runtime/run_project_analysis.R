# Path adapter only. The original statistical function and its API are unchanged.
args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 7L) stop("Expected repository, project, profile, data, config, output and execution mode")
repository <- normalizePath(args[[1]], winslash = "/", mustWork = TRUE)
project <- normalizePath(args[[2]], winslash = "/", mustWork = TRUE)
source(file.path(repository, "runtime", "load_library.R"))
tte_source_library(repository)

# In the legacy API project_root locates only the Registry; data/config/output
# paths are independent. Bind the project root while resolving that one read
# against the authoritative library Registry. The override is scoped to this
# invocation's function environment, never to the original function or Registry.
reader <- tte_read_production_registry
scope <- new.env(parent = environment(tte_run_analysis))
scope$tte_read_production_registry <- function(path) {
  reader(file.path(repository, "runtime", "production_registry.csv"))
}
runner <- tte_run_analysis
environment(runner) <- scope
runner(
  profile = args[[3]], data_path = args[[4]], config_dir = args[[5]],
  output_dir = args[[6]], execution_mode = args[[7]], project_root = project
)
