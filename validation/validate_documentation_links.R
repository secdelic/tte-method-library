root <- normalizePath(".", winslash = "/", mustWork = TRUE)
tracked <- system2("git", "ls-files", stdout = TRUE)
if (!length(tracked)) stop("No Git-tracked files were found for documentation validation")
tracked <- tracked[grepl("[.]md$", tracked, ignore.case = TRUE)]
files <- file.path(root, tracked)
files <- files[file.exists(files)]
missing <- character()
for (file in files) {
  lines <- readLines(file, warn = FALSE, encoding = "UTF-8")
  matches <- gregexpr("\\[[^]]+\\]\\(([^)#]+)(#[^)]+)?\\)", lines, perl = TRUE)
  for (i in seq_along(lines)) {
    if (matches[[i]][1] == -1L) next
    links <- regmatches(lines[i], matches[i])[[1]]
    targets <- sub("^.*\\(([^)#]+).*$", "\\1", links)
    targets <- targets[!grepl("^[a-z]+://|^mailto:", targets, ignore.case = TRUE)]
    for (target in targets) {
      candidate <- file.path(dirname(file), target)
      if (!file.exists(candidate)) missing <- c(missing, paste0(basename(file), ":", target))
    }
  }
}
if (length(missing)) stop("Broken documentation links: ", paste(unique(missing), collapse = " | "))
message("DOCUMENTATION_LINKS=PASS")
