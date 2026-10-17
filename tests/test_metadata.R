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

# Keep the 30 historical/RC cases above. The archival-ready fixtures have no
# allocated DOI or date and do not represent an already published archive.
ready_message <- "If you use this software, please cite version 1.2.0 using the metadata in this file."
ready_description <- paste(
  "Version 1.2.0 of the Target Trial Emulation Statistical Analysis Method Library",
  "provides publication visualization with fourteen native figure variants and six publication APIs.",
  "Production-validated estimation remains limited to BASELINE_BINARY_RISK and MI_PS_CONTINUOUS_ATE",
  "(ATE); CCW visualization does not establish CCW statistical production validation."
)
make_ready_case <- function() {
  p <- make_case(TRUE)
  cat("Release-Status: RELEASE_READY_FOR_ARCHIVAL\n", file = file.path(p, "DESCRIPTION"), append = TRUE)
  edit_cff(p, function(x) { x$message <- ready_message; x })
  edit_zenodo(p, function(x) { x$description <- ready_description; x })
  dir.create(file.path(p, "docs", "releases"), recursive = TRUE)
  writeLines(c("# Visualization v1.2.0", "", ready_description),
             file.path(p, "docs", "releases", "visualization-v1.2.0.md"))
  p
}
expect_ready_fail <- function(label, mutate, error) {
  p <- make_ready_case()
  mutate(p)
  result <- tryCatch(validate_metadata(p), error = function(e) e)
  stopifnot(inherits(result, "error"), grepl(error, conditionMessage(result), fixed = TRUE))
  passed <<- passed + 1L
  message("METADATA_CASE=PASS; rejected ", label, "; ", conditionMessage(result))
}
expect_pass("v1.2.0 ready for archival, no allocated date or DOI", make_ready_case(), "RELEASE_READY_FOR_ARCHIVAL")
expect_fail("RC fields relabeled archival-ready", function(p) {
  cat("Release-Status: RELEASE_READY_FOR_ARCHIVAL\n", file = file.path(p, "DESCRIPTION"), append = TRUE)
}, "archival-ready metadata contains RC wording")
expect_ready_fail("ready CFF still Unreleased", function(p) edit_cff(p, function(x) { x$message <- "Unreleased v1.2.0 Release Candidate;"; x }), "RC wording")
expect_ready_fail("ready Zenodo still Unreleased", function(p) edit_zenodo(p, function(x) { x$description <- paste("Unreleased", x$description); x }), "RC wording")
expect_ready_fail("ready CFF abstract still RC", function(p) edit_cff(p, function(x) { x$abstract <- "Release Candidate"; x }), "RC wording")
expect_ready_fail("ready DESCRIPTION still RC", function(p) edit_description(p, "Description", "Unreleased Release Candidate"), "RC wording")
expect_ready_fail("ready old CFF DOI", function(p) edit_cff(p, function(x) { x$doi <- "10.5281/zenodo.21879884"; x }), "candidate CFF")
expect_ready_fail("ready old Zenodo DOI", function(p) edit_zenodo(p, function(x) { x$doi <- "10.5281/zenodo.21879884"; x }), "candidate Zenodo")
expect_ready_fail("unallocated DOI in CFF", function(p) edit_cff(p, function(x) { x$doi <- "10.5281/zenodo.999999999"; x }), "candidate CFF")
expect_ready_fail("unallocated DOI in Zenodo", function(p) edit_zenodo(p, function(x) { x$doi <- "10.5281/zenodo.999999999"; x }), "candidate Zenodo")
expect_ready_fail("ready old CFF date", function(p) edit_cff(p, function(x) { x$`date-released` <- "2026-08-11"; x }), "candidate CFF")
expect_ready_fail("ready old Zenodo date", function(p) edit_zenodo(p, function(x) { x$publication_date <- "2026-08-11"; x }), "candidate Zenodo")
expect_ready_fail("ready DESCRIPTION date", function(p) cat("Date: 2026-08-11\n", file = file.path(p, "DESCRIPTION"), append = TRUE), "DESCRIPTION release date")
expect_ready_fail("ready inconsistent software version", function(p) edit_zenodo(p, function(x) { x$version <- "1.0.0"; x }), "software versions disagree")
expect_ready_fail("ready missing author", function(p) edit_cff(p, function(x) { x$authors <- NULL; x }), "missing authors")
expect_ready_fail("ready changed license", function(p) edit_zenodo(p, function(x) { x$license <- "SYN_TEST"; x }), "MIT license identity")
expect_ready_fail("ready changed repository", function(p) edit_cff(p, function(x) { x$`repository-code` <- "SYN_TEST"; x }), "CFF repository identity")
expect_ready_fail("ready false archive state", function(p) edit_description(p, "Release-Status", "ARCHIVED"), "unsupported release status")
expect_ready_fail("ready submitted flag", function(p) edit_zenodo(p, function(x) { x$submitted <- TRUE; x }), "candidate Zenodo")
expect_ready_fail("ready missing state marker", function(p) edit_description(p, "Release-Status", NULL), "explicitly unreleased")
expect_ready_fail("ready misleading citation message", function(p) edit_cff(p, function(x) { x$message <- "Cite v1.0.0 DOI for v1.2.0"; x }), "archival-ready citation message")
expect_ready_fail("ready unsupported production claim", function(p) edit_zenodo(p, function(x) { x$description <- paste(x$description, "CCW estimator is production validated."); x }), "archival-ready software description")
expect_ready_fail("ready missing release notes", function(p) unlink(file.path(p, "docs", "releases", "visualization-v1.2.0.md")), "release notes required")
expect_ready_fail("ready mismatched release notes", function(p) writeLines(c("# Visualization v1.2.0", "", "SYN_TEST mismatch"), file.path(p, "docs", "releases", "visualization-v1.2.0.md")), "release notes must match")
expect_ready_fail("ready RC release notes", function(p) cat("Unreleased Release Candidate\n", file = file.path(p, "docs", "releases", "visualization-v1.2.0.md"), append = TRUE), "release notes must match")
message("METADATA_CONTRACT_TESTS=PASS; cases=", passed)
