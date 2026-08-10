root <- normalizePath(".", winslash = "/", mustWork = TRUE)
if (!requireNamespace("yaml", quietly = TRUE)) stop("Package 'yaml' is required")
cff <- yaml::read_yaml(file.path(root, "CITATION.cff"))
required <- c("cff-version", "message", "title", "type", "authors", "version", "license", "keywords")
missing <- setdiff(required, names(cff))
if (length(missing)) stop("CITATION.cff missing: ", paste(missing, collapse = ", "))
stopifnot(
  identical(as.character(cff$`cff-version`), "1.2.0"),
  identical(cff$type, "software"),
  identical(cff$version, "1.0.0-rc1"),
  identical(cff$license, "MIT"),
  length(cff$authors) >= 1L
)
author <- cff$authors[[1]]
stopifnot(
  nzchar(author$`given-names`), nzchar(author$`family-names`),
  grepl("^https://orcid[.]org/[0-9]{4}-[0-9]{4}-[0-9]{4}-[0-9]{3}[0-9X]$", author$orcid)
)
if (!requireNamespace("jsonlite", quietly = TRUE)) stop("Package 'jsonlite' is required")
zenodo <- jsonlite::fromJSON(file.path(root, ".zenodo.json"))
stopifnot(zenodo$version == "1.0.0-rc1", zenodo$license == "MIT",
          zenodo$upload_type == "software")
description <- read.dcf(file.path(root, "DESCRIPTION"))
stopifnot(description[1, "Version"] == "1.0.0-rc1")
stopifnot(trimws(readLines(file.path(root, "VERSION"), n = 1L)) == "1.0.0-rc1")
stopifnot(grepl("MIT License", readLines(file.path(root, "LICENSE"), n = 1L), fixed = TRUE))
message("PUBLIC_METADATA_VALIDATION=PASS; remote URL/date/DOI pending")
