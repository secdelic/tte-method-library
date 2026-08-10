root <- normalizePath(".", winslash = "/", mustWork = TRUE)
files <- list.files(root, pattern = "[.]md$", recursive = TRUE, full.names = TRUE)
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
