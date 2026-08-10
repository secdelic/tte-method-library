local({
  project_library <- Sys.getenv("R_LIBS_USER", unset = NA_character_)
  options(
    repos = c(CRAN = "https://cloud.r-project.org"),
    stringsAsFactors = FALSE,
    warnPartialMatchArgs = TRUE,
    warnPartialMatchDollar = TRUE
  )
  renv_activate <- file.path("renv", "activate.R")
  if (file.exists(renv_activate)) {
    source(renv_activate)
  }
})
