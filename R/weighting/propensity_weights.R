# Propensity-score estimation and registered weighting rules.

tte_fit_propensity_model <- function(data, treatment, covariates,
                                     estimand = "ATE") {
  if (!requireNamespace("WeightIt", quietly = TRUE)) stop("Package 'WeightIt' is required")
  if (!estimand %in% c("ATE", "ATO")) stop("Only ATE and ATO weights are available here")
  formula <- stats::reformulate(covariates, response = treatment)
  fit <- WeightIt::weightit(formula, data = data, method = "glm", estimand = estimand)
  if (any(!is.finite(fit$weights)) || any(fit$weights <= 0)) {
    stop("Propensity weighting produced nonpositive or nonfinite weights")
  }
  list(formula = formula, model = fit, propensity_score = fit$ps,
       weights = fit$weights, estimand = estimand)
}

tte_compute_weights <- function(propensity_fit) {
  weights <- propensity_fit$weights
  if (!is.numeric(weights) || anyNA(weights) || any(!is.finite(weights)) ||
      any(weights <= 0)) stop("Invalid analysis weights")
  weights
}

tte_check_weight_positivity <- function(propensity_score, lower, upper) {
  if (!is.numeric(propensity_score) || anyNA(propensity_score) ||
      any(!is.finite(propensity_score))) stop("Invalid propensity scores")
  if (!is.numeric(lower) || !is.numeric(upper) || lower <= 0 || upper >= 1 ||
      lower >= upper) stop("Positivity bounds must satisfy 0 < lower < upper < 1")
  data.frame(
    lower = lower,
    upper = upper,
    violation_rate = mean(propensity_score < lower | propensity_score > upper),
    minimum_propensity_score = min(propensity_score),
    maximum_propensity_score = max(propensity_score),
    stringsAsFactors = FALSE
  )
}

tte_truncate_weights <- function(weights, lower_probability, upper_probability) {
  cuts <- stats::quantile(
    weights, c(lower_probability, upper_probability), type = 3, names = FALSE
  )
  pmin(pmax(weights, cuts[1]), cuts[2])
}
