# Synthetic-only publication table contract and export tests.

script_arg <- grep("^--file=", commandArgs(FALSE), value = TRUE)
root <- if (length(script_arg)) {
  normalizePath(
    file.path(dirname(sub("^--file=", "", script_arg[[1]])), ".."),
    winslash = "/", mustWork = TRUE
  )
} else {
  normalizePath(".", winslash = "/", mustWork = TRUE)
}
if (!file.exists(file.path(root, "R", "tables", "publication_tables.R"))) {
  stop("Unable to locate repository root")
}

expect_error <- function(expr, pattern = NULL) {
  value <- try(eval.parent(substitute(expr)), silent = TRUE)
  if (!inherits(value, "try-error")) stop("Expected an error but none occurred")
  if (!is.null(pattern) && !grepl(pattern, as.character(value), ignore.case = TRUE)) {
    stop("Error did not match expected pattern: ", pattern, "\n", value)
  }
  invisible(TRUE)
}

source(file.path(root, "R", "tables", "publication_tables.R"))

table1_input <- data.frame(
  variable = c("Age", "Age", "Sex", "Sex"),
  level = c("", "", "Female", "Female"),
  group = c("Strategy A", "Strategy B", "Strategy A", "Strategy B"),
  unweighted_summary = c("62.0 (10.1)", "63.8 (9.7)", "120 (48.0%)", "128 (51.2%)"),
  weighted_summary = c("62.7 (9.9)", "62.9 (9.8)", "123 (49.1%)", "124 (49.6%)"),
  smd_unweighted = c(.18, .18, .064, .064),
  smd_weighted = c(.02, .02, .01, .01),
  stringsAsFactors = FALSE
)
table1 <- build_table1(table1_input)
stopifnot(
  nrow(table1) == nrow(table1_input),
  identical(names(table1), c(
    "Variable", "Level", "Group", "Unweighted", "Weighted",
    "SMD_unweighted", "SMD_weighted"
  )),
  !any(grepl("p[._ -]?value", names(table1), ignore.case = TRUE))
)
expect_error(build_table1(transform(table1_input, p_value = .7)), "P-value")

main_input <- data.frame(
  analysis = c("primary_rd", "primary_rr"),
  effect = c("risk_difference", "risk_ratio"),
  estimate = c(-.04, .82),
  se = c(.015, .07),
  conf_low = c(-.07, .70),
  conf_high = c(-.01, .96),
  p_value = c(.008, NA_real_),
  estimand = c("ATE", "ATE"),
  analysis_population = c("eligible analysis population", "eligible analysis population"),
  method = c("Prespecified weighted estimator", "Prespecified weighted estimator"),
  variance_method = c("robust", "robust"),
  release_status = c("SYNTHETIC_TEST", "SYNTHETIC_TEST"),
  stringsAsFactors = FALSE
)
main <- build_main_results_table(
  main_input, p_value_appropriate = c(TRUE, FALSE)
)
stopifnot(
  all(c(
    "estimate", "standard_error", "ci_lower", "ci_upper", "p_value",
    "estimand", "analysis_population", "method", "variance_method"
  ) %in% names(main)),
  identical(main$p_value_reporting_status,
            c("REPORTED_AS_PRESPECIFIED", "NOT_APPROPRIATE_NOT_REPORTED")),
  is.na(main$p_value[[2]]),
  main$estimate[[1]] == main_input$estimate[[1]]
)
expect_error(build_main_results_table(main_input), "explicitly prespecified")
bad_ci <- main_input
bad_ci$conf_low[[1]] <- 0
expect_error(build_main_results_table(bad_ci, c(TRUE, FALSE)),
             "outside its confidence interval")
bad_p <- main_input
bad_p$p_value[[1]] <- 1.2
expect_error(build_main_results_table(bad_p, c(TRUE, FALSE)), "between 0 and 1")

sensitivity_input <- data.frame(
  analysis = c("weight_truncation", "complete_case"),
  effect_measure = c("risk_ratio", "risk_difference"),
  effect_scale = c("ratio", "difference"),
  estimate = c(.88, -.03),
  standard_error = c(.08, .017),
  ci_lower = c(.74, -.06),
  ci_upper = c(1.04, .01),
  estimand = c("ATE", "ATE"),
  analysis_population = c("eligible analysis population", "complete cases"),
  method = c("Prespecified truncation", "Prespecified complete-case analysis"),
  variance_method = c("robust", "robust"),
  stringsAsFactors = FALSE
)
sensitivity <- build_sensitivity_table(sensitivity_input)
stopifnot(
  identical(sensitivity$null_value, c(1, 0)),
  identical(sensitivity$effect_scale, c("ratio", "difference")),
  identical(sensitivity$forest_order, 1:2),
  all(nzchar(sensitivity$forest_label))
)
bad_scale <- sensitivity_input
bad_scale$effect_scale[[1]] <- "unspecified"
expect_error(build_sensitivity_table(bad_scale), "explicitly")

tmp <- tempfile("publication_table_test_")
dir.create(tmp, recursive = TRUE)
on.exit(unlink(tmp, recursive = TRUE, force = TRUE), add = TRUE)
html_main <- main
html_main$method[[1]] <- "Synthetic <method> & check"
manifest <- export_publication_table(
  html_main, "main_results", data_classification = "SYNTHETIC_CONFIRMED",
  output_dir = tmp, publication_format = "html", title = "Synthetic results"
)
stopifnot(
  file.exists(manifest$csv), file.info(manifest$csv)$size > 0,
  file.exists(manifest$publication_file),
  file.info(manifest$publication_file)$size > 0,
  manifest$contains_patient_level_rows == FALSE,
  manifest$final_disclosure_review == "REQUIRED"
)
html <- paste(readLines(manifest$publication_file, warn = FALSE), collapse = "\n")
stopifnot(
  grepl("Synthetic &lt;method&gt; &amp; check", html, fixed = TRUE),
  !grepl("Synthetic <method> & check", html, fixed = TRUE)
)
roundtrip <- utils::read.csv(manifest$csv, check.names = FALSE,
                             stringsAsFactors = FALSE)
stopifnot(nrow(roundtrip) == nrow(main), all(names(main) %in% names(roundtrip)))

with_identifier <- main
with_identifier$subject_id <- c("SYN001", "SYN002")
expect_error(
  export_publication_table(
    with_identifier, "unsafe", "SYNTHETIC_CONFIRMED", output_dir = tmp
  ),
  "identifier"
)
expect_error(
  export_publication_table(main, "missing_classification", output_dir = tmp),
  "classification"
)
expect_error(
  export_publication_table(
    main, "../unsafe", "SYNTHETIC_CONFIRMED", output_dir = tmp
  ),
  "filesystem-safe"
)

cat("PUBLICATION_TABLE_SYNTHETIC_TEST=PASS TABLE1_ROWS=", nrow(table1),
    " MAIN_ROWS=", nrow(main), " SENSITIVITY_ROWS=", nrow(sensitivity),
    "\n", sep = "")
