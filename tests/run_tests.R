root <- normalizePath(".", winslash = "/", mustWork = TRUE)
files <- sort(list.files(file.path(root, "tests"), pattern = "^test_.*[.]R$", full.names = TRUE))
if (!length(files)) stop("No tests found")
rscript <- file.path(R.home("bin"), "Rscript")
for (file in files) {
  status <- system2(rscript, shQuote(file))
  if (!identical(status, 0L)) stop("Test failed: ", basename(file))
}
message("PUBLIC_TEST_SUITE=PASS; tests=", length(files))
