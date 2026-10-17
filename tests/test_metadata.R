source(file.path("validation", "validate_metadata.R"))
# These five fixtures are verbatim Git blobs from the immutable v1.0.0 tag,
# commit 998e3c0a83656eae5e3ee8dae909e2edcd2625ec, not reconstructed metadata.
fixture <- file.path("tests", "fixtures", "metadata", "v1.0.0")
files <- c("VERSION", "DESCRIPTION", "CITATION.cff", ".zenodo.json", "LICENSE")
make_case <- function(candidate = FALSE, doi = FALSE) {
  path <- tempfile("metadata_contract_")
  dir.create(path)
  stopifnot(all(file.copy(file.path(fixture, files), path)))
  if (candidate) {
    writeLines("1.2.0", file.path(path, "VERSION"))
    d <- readLines(file.path(path, "DESCRIPTION"))
    writeLines(sub("^Version: 1.0.0$", "Version: 1.2.0", d), file.path(path, "DESCRIPTION"))
    edit_cff(path, function(x) {
      x$version <- "1.2.0"; x$`date-released` <- NULL
      x$message <- "Unreleased v1.2.0 Release Candidate; no release date or version DOI is assigned."
      x
    })
    edit_zenodo(path, function(x) {
      x$version <- "1.2.0"; x$publication_date <- NULL
      x$description <- paste("Unreleased v1.2.0 Release Candidate.", x$description)
      x
    })
  } else if (doi) {
    edit_cff(path, function(x) { x$doi <- "10.5281/zenodo.21879884"; x })
  }
  path
}
edit_cff <- function(path, edit) {
  file <- file.path(path, "CITATION.cff")
  yaml::write_yaml(edit(yaml::read_yaml(file)), file)
}
edit_zenodo <- function(path, edit) {
  file <- file.path(path, ".zenodo.json")
  jsonlite::write_json(edit(jsonlite::fromJSON(file, simplifyVector = FALSE)), file,
                       auto_unbox = TRUE, pretty = TRUE)
}
edit_description <- function(path, field, value) {
  file <- file.path(path, "DESCRIPTION")
  lines <- readLines(file)
  lines <- if (is.null(value)) lines[!startsWith(lines, paste0(field, ":"))] else
    sub(paste0("^", field, ":.*$"), paste0(field, ": ", value), lines)
  writeLines(lines, file)
}
passed <- 0L
expect_pass <- function(label, path, state) {
  stopifnot(identical(validate_metadata(path), state))
  passed <<- passed + 1L
  message("METADATA_CASE=PASS; ", label)
}
expect_fail <- function(label, mutate, error, candidate = TRUE, doi = FALSE) {
  path <- make_case(candidate, doi)
  mutate(path)
  result <- tryCatch(validate_metadata(path), error = function(e) e)
  stopifnot(inherits(result, "error"), grepl(error, conditionMessage(result), fixed = TRUE))
  passed <<- passed + 1L
  message("METADATA_CASE=PASS; rejected ", label, "; ", conditionMessage(result))
}
expect_pass("original v1.0.0 tag", make_case(), "HISTORICAL_V1_0_0")
expect_pass("v1.0.0 with assigned DOI", make_case(doi = TRUE), "HISTORICAL_V1_0_0")
expect_pass("unreleased v1.2.0", make_case(TRUE), "UNRELEASED_V1_2_0_CANDIDATE")
expect_fail("VERSION / DESCRIPTION mismatch", function(p) edit_description(p, "Version", "1.0.0"), "software versions disagree")
expect_fail("CFF / Zenodo mismatch", function(p) edit_zenodo(p, function(x) { x$version <- "1.0.0"; x }), "software versions disagree")
expect_fail("CFF software version mismatch", function(p) edit_cff(p, function(x) { x$version <- "1.0.0"; x }), "software versions disagree")
expect_fail("CFF format mistaken for software version", function(p) edit_cff(p, function(x) { x$`cff-version` <- "1.0.0"; x }), "CFF format version")
expect_fail("old DOI in candidate CFF", function(p) edit_cff(p, function(x) { x$doi <- "10.5281/zenodo.21879884"; x }), "candidate CFF")
expect_fail("old DOI in candidate Zenodo", function(p) edit_zenodo(p, function(x) { x$doi <- "10.5281/zenodo.21879884"; x }), "candidate Zenodo")
expect_fail("invented candidate DOI", function(p) edit_cff(p, function(x) { x$doi <- "not-assigned"; x }), "candidate CFF")
expect_fail("old CFF release date", function(p) edit_cff(p, function(x) { x$`date-released` <- "2026-08-11"; x }), "candidate CFF")
expect_fail("old Zenodo publication date", function(p) edit_zenodo(p, function(x) { x$publication_date <- "2026-08-11"; x }), "candidate Zenodo")
expect_fail("missing CFF author", function(p) edit_cff(p, function(x) { x$authors <- NULL; x }), "CITATION.cff missing authors")
expect_fail("missing Zenodo creator", function(p) edit_zenodo(p, function(x) { x$creators <- NULL; x }), ".zenodo.json missing creators")
expect_fail("changed author", function(p) edit_cff(p, function(x) { x$authors[[1]]$`given-names` <- "SYN_TEST"; x }), "author identity")
expect_fail("changed ORCID", function(p) edit_zenodo(p, function(x) { x$creators[[1]]$orcid <- "SYN_TEST"; x }), "ORCID identity")
expect_fail("missing CFF license", function(p) edit_cff(p, function(x) { x$license <- NULL; x }), "CITATION.cff missing license")
expect_fail("missing DESCRIPTION license", function(p) edit_description(p, "License", NULL), "DESCRIPTION missing License")
expect_fail("changed Zenodo license", function(p) edit_zenodo(p, function(x) { x$license <- "SYN_TEST"; x }), "MIT license identity")
expect_fail("missing CFF repository", function(p) edit_cff(p, function(x) { x$`repository-code` <- NULL; x }), "CITATION.cff missing repository-code")
expect_fail("missing Zenodo repository", function(p) edit_zenodo(p, function(x) { x$related_identifiers <- list(); x }), "one Zenodo repository")
expect_fail("changed repository", function(p) edit_cff(p, function(x) { x$`repository-code` <- "SYN_TEST"; x }), "CFF repository identity")
expect_fail("changed title", function(p) edit_zenodo(p, function(x) { x$title <- "SYN_TEST"; x }), "software title")
expect_fail("changed historical date", function(p) edit_cff(p, function(x) { x$`date-released` <- "2026-08-12"; x }), "historical release date", FALSE, TRUE)
expect_fail("changed historical DOI", function(p) edit_cff(p, function(x) { x$doi <- "not-assigned"; x }), "historical version DOI", FALSE, TRUE)
expect_fail("changed original tag snapshot", function(p) cat("\n", file = file.path(p, "LICENSE"), append = TRUE), "original v1.0.0 tag snapshot changed", FALSE)
expect_fail("candidate marked published", function(p) edit_zenodo(p, function(x) { x$state <- "done"; x }), "candidate Zenodo")
expect_fail("candidate marked archived", function(p) edit_zenodo(p, function(x) { x$submitted <- TRUE; x }), "candidate Zenodo")
expect_fail("candidate publication claim", function(p) edit_cff(p, function(x) { x$message <- "Published v1.2.0 Release"; x }), "explicitly unreleased")
expect_fail("unsupported software version", function(p) writeLines("9.9.9", file.path(p, "VERSION")), "unsupported software version")
message("METADATA_CONTRACT_TESTS=PASS; cases=", passed)
