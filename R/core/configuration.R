# Configuration readers. Scientific choices are supplied by the researcher and
# are validated but never changed in response to observed effect estimates.

tte_read_analysis_spec <- function(path, profile) {
  if (!requireNamespace("yaml", quietly = TRUE)) stop("Package 'yaml' is required")
  if (!file.exists(path)) stop("Analysis specification not found: ", path)
  spec <- yaml::read_yaml(path)
  if (!is.null(spec$analyses)) {
    if (!profile %in% names(spec$analyses)) {
      stop("Profile is absent from analysis specification: ", profile)
    }
    return(list(document = spec, analysis = spec$analyses[[profile]]))
  }
  if (is.null(spec$profile) || !identical(as.character(spec$profile), profile)) {
    stop("Single-analysis specification must declare profile: ", profile)
  }
  list(document = spec, analysis = spec)
}

tte_profile_configuration <- function(specification, profile) {
  analysis <- specification$analysis
  thresholds <- analysis$runtime_thresholds
  if (is.null(thresholds)) stop("runtime_thresholds are required for production profiles")
  required <- c(
    "positivity_lower", "positivity_upper", "max_positivity_violation_rate",
    "max_abs_smd", "min_total_ess", "min_group_n",
    "run_truncation_sensitivity", "truncation_lower", "truncation_upper"
  )
  missing <- setdiff(required, names(thresholds))
  if (length(missing)) stop("Missing runtime thresholds: ", paste(missing, collapse = ", "))
  list(
    profile = profile,
    estimand = analysis$estimand$name,
    outcome_type = analysis$outcome$type,
    mice_m = analysis$missing_data$m,
    mice_maxit = analysis$missing_data$maxit,
    seed = analysis$missing_data$seed,
    positivity_lower = thresholds$positivity_lower,
    positivity_upper = thresholds$positivity_upper,
    max_positivity_violation_rate = thresholds$max_positivity_violation_rate,
    max_abs_smd = thresholds$max_abs_smd,
    min_total_ess = thresholds$min_total_ess,
    min_group_n = thresholds$min_group_n,
    run_truncation_sensitivity = isTRUE(thresholds$run_truncation_sensitivity),
    truncation_lower = thresholds$truncation_lower,
    truncation_upper = thresholds$truncation_upper,
    variance_method = analysis$variance$method,
    analysis_population = analysis$design$analysis_population
  )
}

tte_read_variable_dictionary <- function(path) {
  if (!file.exists(path)) stop("Variable dictionary not found: ", path)
  utils::read.csv(path, check.names = FALSE, stringsAsFactors = FALSE,
                  na.strings = character())
}

tte_validate_analysis_spec <- function(path, profile, execution_mode = "SYNTHETIC_TEST") {
  spec <- read_analysis_spec(path)
  validate_analysis_spec(spec, profile, execution_mode)
}

tte_validate_variable_dictionary <- function(path, data_names = NULL) {
  dictionary <- read_variable_dictionary(path)
  validate_variable_dictionary(dictionary, data_names = data_names)
}
