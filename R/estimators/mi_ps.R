# Production implementation for the registered MI_PS_CONTINUOUS_ATE profile.

tte_run_mi_ps <- function(data, dictionary, covariates, configuration) {
  for (package in c("mice", "WeightIt", "cobalt")) {
    if (!requireNamespace(package, quietly = TRUE)) stop("Package '", package, "' is required")
  }
  imputation <- tte_run_multiple_imputation(
    data, dictionary, covariates,
    m = as.integer(configuration$mice_m),
    maxit = as.integer(configuration$mice_maxit),
    seed = as.integer(configuration$seed)
  )
  m <- as.integer(configuration$mice_m)
  formula <- stats::reformulate(covariates, response = "treatment")
  per_imputation <- vector("list", m)
  balance <- vector("list", m)
  completed <- vector("list", m)
  fits <- vector("list", m)
  for (index in seq_len(m)) {
    completed_data <- mice::complete(imputation, index)
    propensity <- WeightIt::weightit(
      formula, data = completed_data, method = "glm", estimand = "ATE"
    )
    fit <- WeightIt::lm_weightit(
      outcome ~ treatment, data = completed_data, weightit = propensity
    )
    estimate <- stats::coef(fit)[["treatment"]]
    within_variance <- stats::vcov(fit)["treatment", "treatment"]
    balance_object <- cobalt::bal.tab(
      formula, data = completed_data, weights = propensity$weights,
      binary = "std", s.d.denom = "pooled", un = TRUE, quick = FALSE
    )
    per_imputation[[index]] <- data.frame(
      imputation = index,
      estimate = estimate,
      within_variance = within_variance,
      se = sqrt(within_variance),
      total_ess = sum(propensity$weights)^2 / sum(propensity$weights^2),
      max_weight = max(propensity$weights),
      positivity_violation_rate = mean(
        propensity$ps < configuration$positivity_lower |
          propensity$ps > configuration$positivity_upper
      ),
      max_abs_smd = max(abs(balance_object$Balance$Diff.Adj), na.rm = TRUE),
      stringsAsFactors = FALSE
    )
    balance[[index]] <- data.frame(
      imputation = index,
      variable = rownames(balance_object$Balance),
      unadjusted_smd = balance_object$Balance$Diff.Un,
      adjusted_smd = balance_object$Balance$Diff.Adj,
      stringsAsFactors = FALSE
    )
    completed[[index]] <- transform(
      completed_data, imputation = index, ps = propensity$ps,
      weight = propensity$weights
    )
    fits[[index]] <- fit
  }
  per_imputation <- do.call(rbind, per_imputation)
  pooled <- tte_pool_rubin(
    per_imputation$estimate, per_imputation$within_variance,
    n = nrow(data), parameter_count = 2L
  )
  critical <- stats::qt(.975, pooled$df)
  primary <- data.frame(
    profile = "MI_PS_CONTINUOUS_ATE",
    analysis = "primary",
    estimand = "ATE",
    effect = "mean_difference",
    estimate = pooled$qbar,
    se = sqrt(pooled$t),
    conf_low = pooled$qbar - critical * sqrt(pooled$t),
    conf_high = pooled$qbar + critical * sqrt(pooled$t),
    variance_method = "weightit_m_estimation_plus_rubin",
    n_analyzed = nrow(data),
    ps_formula = paste(deparse(formula), collapse = ""),
    weight_formula = "A/e+(1-A)/(1-e)",
    release_status = "AUDIT_ONLY",
    stringsAsFactors = FALSE
  )
  complete <- stats::complete.cases(data[c("outcome", "treatment", covariates)])
  sensitivity <- data.frame()
  if (sum(complete) >= 30L) {
    complete_data <- data[complete, , drop = FALSE]
    propensity <- WeightIt::weightit(
      formula, data = complete_data, method = "glm", estimand = "ATE"
    )
    fit <- WeightIt::lm_weightit(
      outcome ~ treatment, data = complete_data, weightit = propensity
    )
    estimate <- stats::coef(fit)[["treatment"]]
    se <- sqrt(stats::vcov(fit)["treatment", "treatment"])
    sensitivity <- data.frame(
      profile = "MI_PS_CONTINUOUS_ATE",
      analysis = "prespecified_complete_case_sensitivity",
      estimand = "ATE",
      effect = "mean_difference",
      estimate = estimate,
      se = se,
      conf_low = estimate - stats::qnorm(.975) * se,
      conf_high = estimate + stats::qnorm(.975) * se,
      variance_method = "weightit_m_estimation_complete_case",
      release_status = "AUDIT_ONLY",
      stringsAsFactors = FALSE
    )
  }
  logged_events <- if (is.null(imputation$loggedEvents)) 0L else nrow(imputation$loggedEvents)
  list(
    effects = primary,
    per_imputation = per_imputation,
    balance = do.call(rbind, balance),
    weight_summary = data.frame(
      n_analyzed = nrow(data),
      imputations = m,
      median_total_ess = stats::median(per_imputation$total_ess),
      minimum_total_ess = min(per_imputation$total_ess),
      maximum_weight = max(per_imputation$max_weight),
      maximum_abs_smd = max(per_imputation$max_abs_smd),
      maximum_positivity_violation_rate = max(per_imputation$positivity_violation_rate),
      mice_logged_events = logged_events,
      ps_formula = paste(deparse(formula), collapse = ""),
      weight_formula = "A/e+(1-A)/(1-e)",
      stringsAsFactors = FALSE
    ),
    sensitivity = sensitivity,
    internal = completed,
    imputation = imputation,
    fits = fits
  )
}
