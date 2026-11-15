# Restore the existing lockfile; do not select or upgrade statistical methods.
main <- function() {
  args <- commandArgs(trailingOnly = TRUE)
  if (length(args) != 2L || !grepl("^[0-9]+[.][0-9]+[.][0-9]+$", args[[2]])) {
    stop("Expected repository root and locked renv version")
  }
  repository <- normalizePath(args[[1]], winslash = "/", mustWork = TRUE)
  setwd(repository)
  options(timeout = max(300L, getOption("timeout", 60L)))
  bootstrap <- file.path(repository, ".renv-bootstrap")
  dir.create(bootstrap, showWarnings = FALSE)
  .libPaths(c(bootstrap, .libPaths()))
  version <- args[[2]]
  available <- requireNamespace("renv", quietly = TRUE)
  if (available && as.character(utils::packageVersion("renv")) != version) {
    unloadNamespace("renv")
    available <- FALSE
  }
  if (!available) {
    url <- sprintf("https://cloud.r-project.org/src/contrib/Archive/renv/renv_%s.tar.gz", version)
    utils::install.packages(url, repos = NULL, type = "source", lib = bootstrap)
  }
  if (!requireNamespace("renv", quietly = TRUE) ||
      as.character(utils::packageVersion("renv")) != version) {
    stop("Locked renv bootstrap is unavailable")
  }
  # activate() may append machine-generated startup/ignore lines. The committed
  # profile already conditionally sources renv; retain its exact source bytes.
  protected <- c(".Rprofile", ".gitignore")
  original <- lapply(protected, function(path) readBin(path, "raw", n = file.info(path)$size))
  on.exit(for (i in seq_along(protected)) writeBin(original[[i]], protected[[i]]), add = TRUE)
  options(repos = c(CRAN = "https://cloud.r-project.org"))
  Sys.setenv(RENV_CONFIG_CONSENT = "TRUE", RENV_CONFIG_PAK_ENABLED = "FALSE")
  options(renv.config.pak.enabled = FALSE)
  renv::activate(project = repository)
  renv::load(project = repository)
  library <- renv::paths$library(project = repository)
  if (!startsWith(normalizePath(library, winslash = "/", mustWork = FALSE), paste0(repository, "/"))) {
    stop("The restored R library must be inside this checkout")
  }
  dir.create(library, recursive = TRUE, showWarnings = FALSE)
  .libPaths(c(library, .libPaths()))
  renv::restore(project = repository, library = library,
                lockfile = file.path(repository, "renv.lock"), prompt = FALSE, strict = TRUE)
  # Dependency-graph repair can select a newer CRAN release even when the old
  # lock declares a version. Restore the declared versions without updating any
  # other dependency, then let the separate checker reject missing/conflicting
  # packages. Never rewrite the frozen lockfile to accept an installer choice.
  lock <- jsonlite::read_json(file.path(repository, "renv.lock"))
  exact <- character()
  for (name in names(lock$Packages)) {
    record <- lock$Packages[[name]]
    path <- find.package(name, lib.loc = library, quiet = TRUE)
    if (!length(path)) next
    actual <- read.dcf(file.path(path, "DESCRIPTION"))[1, "Version"]
    if (package_version(actual) != package_version(record$Version)) {
      if (!identical(record$Source, "Repository") || !identical(record$Repository, "CRAN")) {
        stop("A non-CRAN package differs from its locked source: ", name)
      }
      exact <- c(exact, paste0(name, "@", record$Version))
    }
  }
  if (length(exact)) {
    message("RESTORE_DECLARED_VERSIONS=", paste(exact, collapse = ","))
    renv::install(exact, library = library, dependencies = FALSE, prompt = FALSE)
  }
}
main()
