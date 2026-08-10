# File-system and runtime utilities for aggregate statistical execution.

tte_write_csv <- function(x, path) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  utils::write.csv(x, path, row.names = FALSE, na = "", fileEncoding = "UTF-8")
  invisible(path)
}

tte_sha256_file <- function(path) {
  if (!requireNamespace("digest", quietly = TRUE)) stop("Package 'digest' is required")
  digest::digest(file = path, algo = "sha256", serialize = FALSE)
}

tte_ensure_output_tree <- function(root = "output") {
  paths <- file.path(root, c(
    "diagnostics", "tables", "figures", "sensitivity", "internal", "logs"
  ))
  vapply(paths, dir.create, logical(1), recursive = TRUE, showWarnings = FALSE)
  invisible(paths)
}

tte_parse_iso_time <- function(x) {
  normalized <- sub("([+-][0-9]{2}):([0-9]{2})$", "\\1\\2", x)
  as.POSIXct(normalized, format = "%Y-%m-%dT%H:%M:%S%z", tz = "UTC")
}

tte_capture_warnings <- function(expr) {
  warnings <- list()
  value <- tryCatch(
    withCallingHandlers(
      expr,
      warning = function(w) {
        message <- conditionMessage(w)
        call <- paste(deparse(conditionCall(w)), collapse = "")
        known <- identical(message, "partial match of 'coef' to 'coefficients'") &&
          identical(call, "qr$coef")
        warnings[[length(warnings) + 1L]] <<- data.frame(
          warning_class = if (known) "KNOWN_PACKAGE_INTERNAL_PARTIAL_MATCH" else "UNCLASSIFIED",
          warning_message = message,
          warning_call = call,
          count = 1L,
          severity = if (known) "INFO" else "UNCLASSIFIED",
          review_status = if (known) "AUTO_CLASSIFIED" else "NOT_REVIEWED",
          stringsAsFactors = FALSE
        )
        invokeRestart("muffleWarning")
      }
    ),
    error = function(e) structure(list(error = conditionMessage(e)), class = "tte_runtime_error")
  )
  warning_table <- if (length(warnings)) {
    raw <- do.call(rbind, warnings)
    stats::aggregate(
      count ~ warning_class + warning_message + warning_call + severity + review_status,
      data = raw, FUN = sum
    )
  } else {
    data.frame(
      warning_class = character(), warning_message = character(),
      warning_call = character(), count = integer(), severity = character(),
      review_status = character(), stringsAsFactors = FALSE
    )
  }
  list(value = value, warnings = warning_table,
       failed = inherits(value, "tte_runtime_error"))
}

tte_package_versions <- function(packages) {
  data.frame(
    package = packages,
    version = vapply(packages, function(package) {
      if (requireNamespace(package, quietly = TRUE)) {
        as.character(utils::packageVersion(package))
      } else {
        NA_character_
      }
    }, character(1)),
    stringsAsFactors = FALSE
  )
}
