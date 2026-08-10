script_arg <- grep("^--file=", commandArgs(FALSE), value = TRUE)
root <- if (length(script_arg)) {
  normalizePath(file.path(dirname(sub("^--file=", "", script_arg[[1]])), ".."),
                winslash = "/", mustWork = TRUE)
} else normalizePath(".", winslash = "/", mustWork = TRUE)
source(file.path(root, "runtime", "load_library.R"))
tte_source_library(root)
tolerance <- 1e-8

read_data <- function(path) utils::read.csv(
  path, stringsAsFactors = FALSE, check.names = FALSE,
  colClasses = c(subject_id = "character", analysis_id = "character")
)
maximum_difference <- function(x, y) {
  if (length(x) != length(y)) return(Inf)
  max(abs(as.numeric(x) - as.numeric(y)), na.rm = TRUE)
}
assert_close <- function(name, x, y) {
  difference <- maximum_difference(x, y)
  if (!is.finite(difference) || difference > tolerance) {
    stop(name, " exceeded frozen tolerance: ", difference)
  }
  data.frame(quantity = name, maximum_absolute_difference = difference,
             tolerance = tolerance, status = "PASS", stringsAsFactors = FALSE)
}

dictionary <- tte_read_variable_dictionary(file.path(
  root, "examples", "quick_start", "config", "variable_dictionary.csv"
))
baseline_data <- read_data(file.path(
  root, "examples", "quick_start", "input", "private", "analysis_data.csv"
))
baseline_spec <- tte_read_analysis_spec(file.path(
  root, "examples", "quick_start", "config", "analysis_spec.yml"
), "BASELINE_BINARY_RISK")
baseline_capture <- tte_capture_warnings(tte_run_baseline_tte(
  baseline_data, c("x", "z"),
  tte_profile_configuration(baseline_spec, "BASELINE_BINARY_RISK")
))
if (baseline_capture$failed || any(baseline_capture$warnings$severity != "INFO")) {
  stop("Baseline regression produced a blocking warning or error")
}
baseline <- baseline_capture$value
expected_weights <- utils::read.csv(file.path(
  root, "validation", "fixtures", "baseline_ps_weights.csv"
))
expected_effects <- utils::read.csv(file.path(
  root, "validation", "fixtures", "baseline_effects.csv"
))
expected_balance <- utils::read.csv(file.path(
  root, "validation", "fixtures", "baseline_balance.csv"
))
rows <- list(
  assert_close("baseline_propensity_scores", baseline$internal$ps, expected_weights$ps),
  assert_close("baseline_weights", baseline$internal$weight, expected_weights$weight),
  assert_close("baseline_effect_estimates", baseline$effects$estimate, expected_effects$estimate),
  assert_close("baseline_standard_errors", baseline$effects$se, expected_effects$se),
  assert_close("baseline_confidence_limits",
               c(baseline$effects$conf_low, baseline$effects$conf_high),
               c(expected_effects$conf_low, expected_effects$conf_high)),
  assert_close("baseline_balance",
               c(baseline$balance$unadjusted_smd, baseline$balance$adjusted_smd),
               c(expected_balance$unadjusted_smd, expected_balance$adjusted_smd))
)
independent_baseline <- tte_independent_validate_baseline(
  baseline_data, c("x", "z"), baseline
)
if (any(independent_baseline$status != "PASS")) stop("Independent baseline validation failed")

mi_data <- read_data(file.path(
  root, "examples", "mi_ps", "input", "private", "analysis_data.csv"
))
mi_spec <- tte_read_analysis_spec(file.path(
  root, "examples", "mi_ps", "config", "analysis_spec.yml"
), "MI_PS_CONTINUOUS_ATE")
mi_capture <- tte_capture_warnings(tte_run_mi_ps(
  mi_data, dictionary, c("x", "z"),
  tte_profile_configuration(mi_spec, "MI_PS_CONTINUOUS_ATE")
))
if (mi_capture$failed || any(mi_capture$warnings$severity != "INFO")) {
  stop("MI regression produced a blocking warning or error")
}
mi <- mi_capture$value
expected_internal <- utils::read.csv(file.path(
  root, "validation", "fixtures", "mi_completed_weights.csv"
))
observed_internal <- do.call(rbind, lapply(seq_along(mi$internal), function(i) {
  x <- mi$internal[[i]]
  data.frame(imputation = i, row_index = seq_len(nrow(x)), x = x$x, z = x$z,
             ps = x$ps, weight = x$weight)
}))
expected_per <- utils::read.csv(file.path(
  root, "validation", "fixtures", "mi_per_imputation.csv"
))
expected_mi_effects <- utils::read.csv(file.path(
  root, "validation", "fixtures", "mi_effects.csv"
))
rows <- c(rows, list(
  assert_close("mi_completed_x", observed_internal$x, expected_internal$x),
  assert_close("mi_propensity_scores", observed_internal$ps, expected_internal$ps),
  assert_close("mi_weights", observed_internal$weight, expected_internal$weight),
  assert_close("mi_within_estimates", mi$per_imputation$estimate, expected_per$estimate),
  assert_close("mi_within_variances", mi$per_imputation$within_variance,
               expected_per$within_variance),
  assert_close("mi_pooled_estimate", mi$effects$estimate, expected_mi_effects$estimate),
  assert_close("mi_pooled_se", mi$effects$se, expected_mi_effects$se),
  assert_close("mi_pooled_ci", c(mi$effects$conf_low, mi$effects$conf_high),
               c(expected_mi_effects$conf_low, expected_mi_effects$conf_high))
))
independent_mi <- tte_independent_validate_mi(mi, nrow(mi_data))
if (any(independent_mi$status != "PASS")) stop("Independent MI validation failed")

result <- do.call(rbind, rows)
tte_write_csv(result, file.path(root, "validation", "public_regression_results.csv"))
message("PUBLIC_NUMERICAL_REGRESSION=PASS; checks=", nrow(result))
