script_arg <- grep("^--file=", commandArgs(FALSE), value = TRUE)
root <- normalizePath(
  file.path(dirname(sub("^--file=", "", script_arg[[1]])), ".."),
  winslash = "/", mustWork = TRUE
)
forbidden <- c("private_publication_rights_attestation.yml", "release_human_metadata.yml")
files <- list.files(root, recursive = TRUE, all.files = TRUE,
                    full.names = FALSE, include.dirs = FALSE)
hits <- files[basename(files) %in% forbidden]
if (length(hits)) stop("PRIVATE_GOVERNANCE_FILE_PUBLICATION_GATE failed: ",
                       paste(hits, collapse = ", "))
message("PRIVATE_GOVERNANCE_FILE_PUBLICATION_GATE=PASS")
