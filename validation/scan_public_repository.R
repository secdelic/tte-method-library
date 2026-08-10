root <- normalizePath(".", winslash = "/", mustWork = TRUE)
relative <- system2("git", "ls-files", stdout = TRUE)
if (!length(relative)) stop("No Git-tracked files were found for public-repository scanning")
relative <- gsub("\\\\", "/", relative)
all_files <- file.path(root, relative)
keep <- file.exists(all_files) & !dir.exists(all_files)
all_files <- all_files[keep]
relative <- relative[keep]

private_names <- c("private_publication_rights_attestation.yml", "release_human_metadata.yml")
private_hits <- relative[basename(relative) %in% private_names]

binary_extensions <- "[.](rds|rdata|rda|sqlite|db|parquet|feather)$"
binary_hits <- relative[grepl(binary_extensions, relative, ignore.case = TRUE)]

text_extensions <- "[.](R|Rmd|qmd|md|csv|yml|yaml|json|py|txt|cff|gitignore)$"
text_files <- all_files[grepl(text_extensions, relative, ignore.case = TRUE)]
text_relative <- relative[grepl(text_extensions, relative, ignore.case = TRUE)]
read_text <- function(path) paste(readLines(path, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
content <- vapply(text_files, read_text, character(1))
content_scan <- text_relative != "validation/scan_public_repository.R"

identifier_patterns <- c(
  "BaiduNetdiskDownload", "目标试验模拟课程", "培训班", "老师", "教师",
  "\\blesson[ _-]?[0-9]+\\b", "\\bchapter[ _-]?[0-9]+\\b",
  "modified from course", "teacher code", "Codex", "ChatGPT"
)
identifier_hits <- unique(unlist(lapply(identifier_patterns, function(pattern) {
  text_relative[content_scan & grepl(pattern, content, ignore.case = TRUE, perl = TRUE)]
})))

absolute_patterns <- c(
  "(?m)(^|[\"'[:space:](])[A-Za-z]:[/\\\\]",
  "/Users/[^/]+/", "/home/[^/]+/"
)
absolute_hits <- unique(unlist(lapply(absolute_patterns, function(pattern) {
  text_relative[content_scan & grepl(pattern, content, perl = TRUE)]
})))

secret_patterns <- c(
  "gh[pousr]_[A-Za-z0-9_]{20,}", "sk-[A-Za-z0-9_-]{20,}",
  "-----BEGIN [A-Z ]*PRIVATE KEY-----", "postgres(ql)?://[^[:space:]]+:[^[:space:]@]+@",
  "(?i)(api[_-]?key|access[_-]?token|password)\\s*[:=]\\s*['\"][^'\"]{8,}"
)
secret_hits <- unique(unlist(lapply(secret_patterns, function(pattern) {
  text_relative[content_scan & grepl(pattern, content, perl = TRUE)]
})))

patient_hits <- character()
csv_files <- all_files[grepl("[.]csv$", relative, ignore.case = TRUE)]
for (path in csv_files) {
  table <- try(utils::read.csv(path, stringsAsFactors = FALSE, check.names = FALSE), silent = TRUE)
  if (inherits(table, "try-error")) next
  id_columns <- intersect(tolower(names(table)), c(
    "patient_id", "hadm_id", "stay_id", "subject_id", "person_id"
  ))
  for (column in id_columns) {
    values <- as.character(table[[which(tolower(names(table)) == column)[1]]])
    values <- values[nzchar(values)]
    if (length(values) && !all(grepl("^SYN", values))) {
      patient_hits <- c(patient_hits, substring(normalizePath(path, winslash = "/"), nchar(root) + 2L))
    }
  }
}
patient_hits <- unique(patient_hits)

results <- data.frame(
  gate = c(
    "private_governance_files", "binary_patient_capable_assets",
    "nonessential_source_identifiers", "private_absolute_paths",
    "secrets_or_credentials", "non_synthetic_patient_identifiers"
  ),
  count = c(
    length(private_hits), length(binary_hits), length(identifier_hits),
    length(absolute_hits), length(secret_hits), length(patient_hits)
  ),
  evidence = c(
    paste(private_hits, collapse = "|"), paste(binary_hits, collapse = "|"),
    paste(identifier_hits, collapse = "|"), paste(absolute_hits, collapse = "|"),
    paste(secret_hits, collapse = "|"), paste(patient_hits, collapse = "|")
  ),
  stringsAsFactors = FALSE
)
dir.create(file.path(root, "reports"), showWarnings = FALSE)
utils::write.csv(results, file.path(root, "reports", "final_rc1_scan.csv"),
                 row.names = FALSE, na = "")
if (any(results$count != 0L)) {
  print(results[results$count != 0L, ], row.names = FALSE)
  stop("Public repository scan failed")
}
message("PUBLIC_REPOSITORY_SCAN=PASS")
