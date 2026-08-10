# Fixed-weight influence-function estimators for treatment-specific risks, risk
# difference, and risk ratio. The supplied weights are treated as fixed.

tte_estimate_weighted_risk <- function(outcome, treatment, weights) {
  n <- length(outcome)
  den_treated <- mean(weights * (treatment == 1))
  den_control <- mean(weights * (treatment == 0))
  treated_risk <- mean(weights * (treatment == 1) * outcome) / den_treated
  control_risk <- mean(weights * (treatment == 0) * outcome) / den_control
  if (!is.finite(control_risk) || control_risk <= 0) {
    stop("Reference risk must be positive for the risk ratio")
  }
  treated_if <- weights * (treatment == 1) * (outcome - treated_risk) / den_treated
  control_if <- weights * (treatment == 0) * (outcome - control_risk) / den_control
  list(
    n = n,
    treated_risk = treated_risk,
    control_risk = control_risk,
    treated_influence = treated_if,
    control_influence = control_if
  )
}

tte_estimate_risk_difference <- function(risk) {
  influence <- risk$treated_influence - risk$control_influence
  estimate <- risk$treated_risk - risk$control_risk
  se <- stats::sd(influence) / sqrt(risk$n)
  c(estimate = estimate, se = se,
    ci_lower = estimate - stats::qnorm(.975) * se,
    ci_upper = estimate + stats::qnorm(.975) * se)
}

tte_estimate_risk_ratio <- function(risk) {
  estimate <- risk$treated_risk / risk$control_risk
  log_influence <- risk$treated_influence / risk$treated_risk -
    risk$control_influence / risk$control_risk
  se <- estimate * stats::sd(log_influence) / sqrt(risk$n)
  log_se <- se / estimate
  c(estimate = estimate, se = se,
    ci_lower = exp(log(estimate) - stats::qnorm(.975) * log_se),
    ci_upper = exp(log(estimate) + stats::qnorm(.975) * log_se))
}

tte_effects_from_weights <- function(outcome, treatment, weights, estimand,
                                     analysis = "primary") {
  risk <- tte_estimate_weighted_risk(outcome, treatment, weights)
  rd <- tte_estimate_risk_difference(risk)
  rr <- tte_estimate_risk_ratio(risk)
  estimates <- c(risk$treated_risk, risk$control_risk, rd[["estimate"]], rr[["estimate"]])
  influence_se <- c(
    stats::sd(risk$treated_influence) / sqrt(risk$n),
    stats::sd(risk$control_influence) / sqrt(risk$n),
    rd[["se"]], rr[["se"]]
  )
  ci_lower <- c(
    estimates[1:2] - stats::qnorm(.975) * influence_se[1:2],
    rd[["ci_lower"]], rr[["ci_lower"]]
  )
  ci_upper <- c(
    estimates[1:2] + stats::qnorm(.975) * influence_se[1:2],
    rd[["ci_upper"]], rr[["ci_upper"]]
  )
  data.frame(
    profile = "BASELINE_BINARY_RISK",
    analysis = analysis,
    estimand = estimand,
    effect = c("risk_treated", "risk_control", "RD", "RR"),
    estimate = estimates,
    se = influence_se,
    conf_low = ci_lower,
    conf_high = ci_upper,
    variance_method = "fixed_weight_influence_curve",
    release_status = "AUDIT_ONLY",
    stringsAsFactors = FALSE
  )
}
