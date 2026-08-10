root <- normalizePath(".", winslash = "/", mustWork = TRUE)
required <- c(
  "README.md", "LICENSE", "CITATION.cff", ".zenodo.json", "VERSION",
  "DESCRIPTION", "renv.lock", "runtime/production_registry.csv",
  "examples/quick_start/run_quick_start.R",
  "validation/numerical_equivalence_summary.md",
  "validation/independent_validation_summary.md"
)
missing <- required[!file.exists(file.path(root, required))]
if (length(missing)) stop("Release dry run missing files: ", paste(missing, collapse = ", "))
files <- system2("git", "ls-files", stdout = TRUE)
if (!length(files)) stop("No Git-tracked files were found for release validation")
files <- gsub("\\\\", "/", files)
files <- files[file.exists(file.path(root, files))]
stopifnot(
  !any(basename(files) %in% c(
    "private_publication_rights_attestation.yml", "release_human_metadata.yml"
  )),
  !any(grepl("[.](rds|rdata|rda)$", files, ignore.case = TRUE)),
  !any(file.info(file.path(root, files))$size > 50 * 1024^2)
)
source(file.path(root, "runtime", "load_library.R"))
tte_source_library(root)
analysis_output <- file.path(root, "examples", "quick_start", "output")
if (!dir.exists(analysis_output)) stop("Run the synthetic Quick Start before release dry run")
release_target <- tempfile("tte_aggregate_release_")
manifest <- tte_build_analysis_release(
  config_dir = file.path(root, "examples", "quick_start", "config"),
  output_dir = analysis_output,
  destination = release_target,
  project_root = root
)
stopifnot(nrow(manifest) > 0L)
message("PUBLIC_RELEASE_DRY_RUN=PASS; repository_files=", length(files),
        "; aggregate_payload_files=", nrow(manifest))
