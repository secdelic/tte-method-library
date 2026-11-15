if (!requireNamespace("renv", quietly = TRUE)) stop("Restore the project R environment first")
library <- renv::paths$library(project = normalizePath(".", winslash = "/"))
.libPaths(c(library, .libPaths()))
if (!requireNamespace("jsonlite", quietly = TRUE)) stop("Restore the locked R dependencies first")
lock <- jsonlite::read_json("renv.lock", simplifyVector = FALSE)
if (as.character(getRversion()) != lock$R$Version) stop("R version differs from renv.lock")
issues <- character()
for (name in names(lock$Packages)) {
  expected <- lock$Packages[[name]]$Version
  path <- find.package(name, lib.loc = library, quiet = TRUE)
  if (!length(path)) {
    # renv uses R's own base/recommended packages when their locked versions
    # match. Do not accept arbitrary packages from a user's global library.
    standard <- find.package(name, lib.loc = R.home("library"), quiet = TRUE)
    if (length(standard)) {
      description <- read.dcf(file.path(standard, "DESCRIPTION"))
      if ("Priority" %in% colnames(description) && description[1, "Priority"] %in% c("base", "recommended")) {
        path <- standard
      }
    }
  }
  if (!length(path)) {
    issues <- c(issues, paste(name, "missing from project library"))
    next
  }
  actual <- read.dcf(file.path(path, "DESCRIPTION"))[1, "Version"]
  if (package_version(actual) != package_version(expected)) {
    issues <- c(issues, paste(name, "version differs from lock"))
  }
}
if (length(issues)) stop(paste(issues, collapse = "; "))
message("R_LOCKED_ENVIRONMENT=PASS; packages=", length(lock$Packages))
