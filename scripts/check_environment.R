if (!requireNamespace("jsonlite", quietly = TRUE)) stop("Restore the locked R dependencies first")
lock <- jsonlite::read_json("renv.lock", simplifyVector = FALSE)
if (as.character(getRversion()) != lock$R$Version) stop("R version differs from renv.lock")
issues <- character()
for (name in names(lock$Packages)) {
  expected <- lock$Packages[[name]]$Version
  if (!requireNamespace(name, quietly = TRUE)) {
    issues <- c(issues, paste(name, "missing"))
  } else if (as.character(utils::packageVersion(name)) != expected) {
    issues <- c(issues, paste(name, "version differs from lock"))
  }
}
if (length(issues)) stop(paste(issues, collapse = "; "))
message("R_LOCKED_ENVIRONMENT=PASS; packages=", length(lock$Packages))
