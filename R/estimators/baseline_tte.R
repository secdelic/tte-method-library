# Production implementation for the registered BASELINE_BINARY_RISK profile.

tte_run_baseline_tte <- function(data, covariates, configuration) {
  propensity <- tte_fit_propensity_model(
    data, treatment = "treatment", covariates = covariates,
    estimand = configuration$estimand
  )
  weights <- tte_compute_weights(propensity)
  effects <- tte_effects_from_weights(
    data$outcome, data$treatment, weights, configuration$estimand, "primary"
  )
  balance <- tte_compute_balance(data, "treatment", covariates, weights)
  positivity <- tte_check_weight_positivity(
    propensity$propensity_score,
    configuration$positivity_lower,
    configuration$positivity_upper
  )
  ess <- tte_compute_ess(weights, data$treatment)
  weight_summary <- data.frame(
    n_analyzed = nrow(data),
    n_control = sum(data$treatment == 0),
    n_treated = sum(data$treatment == 1),
    event_count = sum(data$outcome),
    ps_formula = paste(deparse(propensity$formula), collapse = ""),
    weight_formula = if (configuration$estimand == "ATE") {
      "A/e+(1-A)/(1-e)"
    } else {
      "A*(1-e)+(1-A)*e"
    },
    total_ess = ess$total_ess,
    control_ess = ess$control_ess,
    treated_ess = ess$treated_ess,
    max_weight = max(weights),
    positivity_violation_rate = positivity$violation_rate,
    stringsAsFactors = FALSE
  )
  sensitivity <- data.frame()
  if (isTRUE(configuration$run_truncation_sensitivity)) {
    truncated <- tte_truncate_weights(
      weights, configuration$truncation_lower, configuration$truncation_upper
    )
    sensitivity <- tte_effects_from_weights(
      data$outcome, data$treatment, truncated, configuration$estimand,
      paste0(
        "prespecified_truncation_", configuration$truncation_lower,
        "_", configuration$truncation_upper
      )
    )
  }
  list(
    effects = effects,
    balance = balance,
    weight_summary = weight_summary,
    sensitivity = sensitivity,
    internal = transform(
      data, ps = propensity$propensity_score, weight = weights
    ),
    propensity = propensity$model
  )
}
