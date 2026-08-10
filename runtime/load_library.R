tte_source_library <- function(project_root = ".") {
  files <- sort(list.files(
    file.path(project_root, "R"), pattern = "[.]R$",
    recursive = TRUE, full.names = TRUE
  ))
  for (file in files) source(file, local = .GlobalEnv)
  invisible(files)
}
