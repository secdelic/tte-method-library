# Publication-table contracts operating on aggregate or synthetic summaries.
# Formatting never selects covariates, models, estimands, or scientific claims.

tte_assert_columns <- function(x, required, object_name = deparse(substitute(x))) {
  if (!is.data.frame(x)) stop(object_name, " must be a data.frame")
  missing <- setdiff(required, names(x))
  if (length(missing)) {
    stop(object_name, " is missing columns: ", paste(missing, collapse = ", "))
  }
  invisible(TRUE)
}

tte_copy_result_alias <- function(x, target, aliases) {
  if (!target %in% names(x)) {
    hit <- aliases[aliases %in% names(x)]
    if (length(hit)) x[[target]] <- x[[hit[[1]]]]
  }
  x
}

tte_normalize_result_columns <- function(x) {
  aliases <- list(
    standard_error = c("se", "std_error"),
    ci_lower = c("conf_low", "lower", "conf.low", "2.5 %"),
    ci_upper = c("conf_high", "upper", "conf.high", "97.5 %"),
    effect_measure = c("effect", "contrast"),
    analysis = c("analysis_id", "sensitivity_id")
  )
  for (target in names(aliases)) {
    x <- tte_copy_result_alias(x, target, aliases[[target]])
  }
  x
}

tte_validate_result_intervals <- function(x, object_name) {
  for (column in c("estimate", "standard_error", "ci_lower", "ci_upper")) {
    if (!is.numeric(x[[column]]) || anyNA(x[[column]]) ||
        any(!is.finite(x[[column]]))) {
      stop(object_name, " column ", column,
           " must contain finite numeric values")
    }
  }
  if (any(x$standard_error < 0)) stop(object_name, " has a negative standard error")
  if (any(x$ci_lower > x$estimate | x$estimate > x$ci_upper)) {
    stop(object_name, " has an estimate outside its confidence interval")
  }
  invisible(TRUE)
}

tte_nonempty_character <- function(x, name) {
  if (anyNA(x) || any(!nzchar(trimws(as.character(x))))) {
    stop(name, " must be non-empty")
  }
  invisible(TRUE)
}

tte_table_effect_scale <- function(x) {
  x <- tolower(trimws(as.character(x)))
  aliases <- c(
    difference = "difference", additive = "difference",
    ratio = "ratio", multiplicative = "ratio"
  )
  invalid <- !x %in% names(aliases)
  if (any(invalid)) {
    stop("effect_scale must be explicitly 'difference' or 'ratio'")
  }
  unname(aliases[x])
}

tte_table_null_value <- function(effect_scale) {
  ifelse(tte_table_effect_scale(effect_scale) == "ratio", 1, 0)
}

build_table1 <- function(summary_data) {
  required <- c(
    "variable", "level", "group", "unweighted_summary",
    "weighted_summary", "smd_unweighted", "smd_weighted"
  )
  tte_assert_columns(summary_data, required, "Table 1 aggregate summary")
  forbidden <- grep("(^p$|p[._ -]?value)", names(summary_data),
                    ignore.case = TRUE, value = TRUE)
  if (length(forbidden)) {
    stop("Table 1 does not accept default group-comparison P-value columns: ",
         paste(forbidden, collapse = ", "))
  }
  tte_nonempty_character(summary_data$variable, "Table 1 variable")
  tte_nonempty_character(summary_data$group, "Table 1 group")
  for (column in c("smd_unweighted", "smd_weighted")) {
    if (!is.numeric(summary_data[[column]]) ||
        any(!is.na(summary_data[[column]]) & !is.finite(summary_data[[column]]))) {
      stop("Table 1 ", column, " must be numeric or NA")
    }
  }
  out <- summary_data[, required, drop = FALSE]
  names(out) <- c(
    "Variable", "Level", "Group", "Unweighted", "Weighted",
    "SMD_unweighted", "SMD_weighted"
  )
  out
}

build_main_results_table <- function(results, p_value_appropriate) {
  if (missing(p_value_appropriate)) {
    stop("p_value_appropriate must be explicitly prespecified")
  }
  results <- tte_normalize_result_columns(results)
  required <- c(
    "analysis", "effect_measure", "estimate", "standard_error",
    "ci_lower", "ci_upper", "estimand", "analysis_population", "method",
    "variance_method"
  )
  tte_assert_columns(results, required, "Main results")
  tte_validate_result_intervals(results, "Main results")
  for (column in c(
    "analysis", "effect_measure", "estimand", "analysis_population",
    "method", "variance_method"
  )) {
    tte_nonempty_character(results[[column]], paste("Main results", column))
  }
  if (length(p_value_appropriate) == 1L) {
    p_value_appropriate <- rep(isTRUE(p_value_appropriate), nrow(results))
  }
  if (!is.logical(p_value_appropriate) ||
      length(p_value_appropriate) != nrow(results) || anyNA(p_value_appropriate)) {
    stop("p_value_appropriate must be one logical value or one per result row")
  }
  if (!"p_value" %in% names(results)) results$p_value <- NA_real_
  if (!is.numeric(results$p_value)) stop("p_value must be numeric")
  reported <- results$p_value[p_value_appropriate]
  if (anyNA(reported) || any(!is.finite(reported)) ||
      any(reported < 0 | reported > 1)) {
    stop("Prespecified reportable P values must be finite and between 0 and 1")
  }
  results$p_value[!p_value_appropriate] <- NA_real_
  results$p_value_reporting_status <- ifelse(
    p_value_appropriate, "REPORTED_AS_PRESPECIFIED",
    "NOT_APPROPRIATE_NOT_REPORTED"
  )
  output_columns <- c(
    "analysis", "effect_measure", "estimate", "standard_error",
    "ci_lower", "ci_upper", "p_value", "p_value_reporting_status",
    "estimand", "analysis_population", "method", "variance_method"
  )
  optional <- intersect(c("release_status", "profile"), names(results))
  results[, c(output_columns, optional), drop = FALSE]
}

build_sensitivity_table <- function(results) {
  results <- tte_normalize_result_columns(results)
  required <- c(
    "analysis", "effect_measure", "effect_scale", "estimate",
    "standard_error", "ci_lower", "ci_upper", "estimand",
    "analysis_population", "method", "variance_method"
  )
  tte_assert_columns(results, required, "Sensitivity results")
  tte_validate_result_intervals(results, "Sensitivity results")
  results$effect_scale <- tte_table_effect_scale(results$effect_scale)
  results$null_value <- tte_table_null_value(results$effect_scale)
  for (column in c(
    "analysis", "effect_measure", "estimand", "analysis_population",
    "method", "variance_method"
  )) {
    tte_nonempty_character(results[[column]], paste("Sensitivity results", column))
  }
  if (!"sensitivity_id" %in% names(results)) {
    results$sensitivity_id <- as.character(results$analysis)
  }
  if (!"sensitivity_category" %in% names(results)) {
    results$sensitivity_category <- "sensitivity"
  }
  if (!"forest_label" %in% names(results)) {
    results$forest_label <- as.character(results$analysis)
  }
  if (!"forest_order" %in% names(results)) {
    results$forest_order <- seq_len(nrow(results))
  }
  output_columns <- c(
    "sensitivity_id", "sensitivity_category", "analysis", "effect_measure",
    "effect_scale", "null_value", "estimate", "standard_error",
    "ci_lower", "ci_upper", "estimand", "analysis_population", "method",
    "variance_method", "forest_label", "forest_order"
  )
  optional <- intersect(c("release_status", "profile"), names(results))
  results[, c(output_columns, optional), drop = FALSE]
}

tte_html_escape <- function(x) {
  x <- as.character(x)
  x[is.na(x)] <- ""
  x <- gsub("&", "&amp;", x, fixed = TRUE)
  x <- gsub("<", "&lt;", x, fixed = TRUE)
  x <- gsub(">", "&gt;", x, fixed = TRUE)
  x <- gsub('"', "&quot;", x, fixed = TRUE)
  x
}

tte_safe_table_stem <- function(x) {
  if (length(x) != 1L || is.na(x) ||
      !grepl("^[A-Za-z0-9][A-Za-z0-9._-]*$", x)) {
    stop("Table basename must be a filesystem-safe stem")
  }
  x
}

tte_assert_aggregate_export <- function(x, data_classification) {
  allowed <- c(
    "AGGREGATE_ONLY_CONFIRMED", "SYNTHETIC_CONFIRMED",
    "TEMPLATE_ONLY_CONFIRMED"
  )
  if (missing(data_classification) || length(data_classification) != 1L ||
      is.na(data_classification) || !data_classification %in% allowed) {
    stop("An explicit aggregate, synthetic, or template classification is required")
  }
  identifiers <- c(
    "subject_id", "patient_id", "analysis_id", "person_id", "stay_id",
    "hadm_id", "clone_id", "record_id"
  )
  hit <- intersect(tolower(names(x)), identifiers)
  if (length(hit)) {
    stop("Publication table contains patient-level-capable identifier columns: ",
         paste(hit, collapse = ", "))
  }
  invisible(TRUE)
}

write_publication_html_table <- function(x, path, title = "Statistical results") {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  header <- paste0("<th>", tte_html_escape(names(x)), "</th>", collapse = "")
  rows <- vapply(seq_len(nrow(x)), function(i) {
    values <- vapply(x, function(column) as.character(column[[i]]), character(1))
    paste0(
      "<tr>",
      paste0("<td>", tte_html_escape(values), "</td>", collapse = ""),
      "</tr>"
    )
  }, character(1))
  html <- c(
    "<!doctype html>", "<html><head><meta charset=\"utf-8\">",
    paste0("<title>", tte_html_escape(title), "</title>"),
    paste0(
      "<style>body{font-family:Arial,sans-serif;margin:24px}",
      "table{border-collapse:collapse;font-size:10pt}",
      "th,td{border:1px solid #555;padding:5px 8px;text-align:left}",
      "th{background:#eee}</style>"
    ),
    "</head><body>", paste0("<h1>", tte_html_escape(title), "</h1>"),
    paste0("<table><thead><tr>", header, "</tr></thead><tbody>"),
    rows, "</tbody></table></body></html>"
  )
  writeLines(html, path, useBytes = TRUE)
  invisible(path)
}

export_publication_table <- function(
    x, basename, data_classification, output_dir = "output/tables",
    publication_format = c("none", "html"), title = "Statistical results") {
  tte_assert_aggregate_export(x, data_classification)
  basename <- tte_safe_table_stem(basename)
  publication_format <- match.arg(publication_format)
  dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
  csv_path <- file.path(output_dir, paste0(basename, ".csv"))
  utils::write.csv(x, csv_path, row.names = FALSE, na = "",
                   fileEncoding = "UTF-8")
  html_path <- NA_character_
  if (publication_format == "html") {
    html_path <- file.path(output_dir, paste0(basename, ".html"))
    write_publication_html_table(x, html_path, title)
  }
  data.frame(
    table = basename,
    csv = csv_path,
    publication_format = publication_format,
    publication_file = html_path,
    data_classification = data_classification,
    contains_patient_level_rows = FALSE,
    final_disclosure_review = "REQUIRED",
    stringsAsFactors = FALSE
  )
}
