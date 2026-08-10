# Build an aggregate analysis release. Private inputs, unit-level internal
# objects, writing artifacts and reviewer artifacts are never copied.

tte_build_analysis_release <- function(
    config_dir, output_dir, destination, project_root = ".") {
  if (file.exists(destination) || dir.exists(destination)) {
    stop("Release destination already exists: ", destination)
  }
  required_output <- c("diagnostics", "tables", "figures", "sensitivity")
  missing <- required_output[!dir.exists(file.path(output_dir, required_output))]
  if (length(missing)) stop("Analysis output is incomplete: ", paste(missing, collapse = ", "))
  dir.create(destination, recursive = TRUE, showWarnings = FALSE)
  for (directory in c(
    "config_snapshot", "diagnostics", "tables", "figures", "sensitivity", "metadata"
  )) dir.create(file.path(destination, directory), recursive = TRUE)

  config_files <- c(
    "analysis_spec.yml", "variable_dictionary.csv", "input_data_contract.csv",
    "figure_config.yml"
  )
  for (file in config_files) {
    source <- file.path(config_dir, file)
    if (!file.exists(source)) stop("Missing release configuration: ", file)
    file.copy(source, file.path(destination, "config_snapshot", file), overwrite = FALSE)
  }
  for (directory in required_output) {
    files <- list.files(file.path(output_dir, directory), full.names = TRUE,
                        recursive = TRUE, all.files = FALSE)
    files <- files[file.info(files)$isdir %in% FALSE]
    for (source in files) {
      relative <- substring(
        normalizePath(source, winslash = "/"),
        nchar(normalizePath(file.path(output_dir, directory), winslash = "/")) + 2L
      )
      target <- file.path(destination, directory, relative)
      dir.create(dirname(target), recursive = TRUE, showWarnings = FALSE)
      file.copy(source, target, overwrite = FALSE)
    }
  }
  file.copy(file.path(project_root, "VERSION"),
            file.path(destination, "metadata", "VERSION"), overwrite = FALSE)
  writeLines(capture.output(utils::sessionInfo()),
             file.path(destination, "metadata", "session_info.txt"))
  files <- list.files(destination, recursive = TRUE, full.names = TRUE)
  files <- files[file.info(files)$isdir %in% FALSE]
  relative <- substring(
    normalizePath(files, winslash = "/"),
    nchar(normalizePath(destination, winslash = "/")) + 2L
  )
  manifest <- data.frame(
    path = relative,
    size_bytes = file.info(files)$size,
    sha256 = vapply(files, tte_sha256_file, character(1)),
    stringsAsFactors = FALSE
  )
  tte_write_csv(manifest, file.path(destination, "result_manifest.csv"))
  forbidden <- c("internal", "input/private", "manuscript", "reviewer")
  final_files <- list.files(destination, recursive = TRUE, full.names = FALSE)
  if (any(vapply(forbidden, function(pattern) {
    any(grepl(pattern, tolower(final_files), fixed = TRUE))
  }, logical(1)))) stop("Forbidden asset entered aggregate analysis release")
  invisible(manifest)
}
