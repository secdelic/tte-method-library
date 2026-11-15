# Restore the existing lockfile; do not select or upgrade statistical methods.
main <- function() {
  args <- commandArgs(trailingOnly = TRUE)
  if (length(args) != 2L || !grepl("^[0-9]+[.][0-9]+[.][0-9]+$", args[[2]])) {
    stop("Expected repository root and locked renv version")
  }
  repository <- normalizePath(args[[1]], winslash = "/", mustWork = TRUE)
  setwd(repository)
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
    url <- sprintf("https://cran.r-project.org/src/contrib/Archive/renv/renv_%s.tar.gz", version)
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
}
main()
