# Independent formula checks. These functions do not call the estimator
# implementation that they assess.

tte_independent_weighted_effects <- function(outcome, treatment, weights) {
  n <- length(outcome)
  denominator_1 <- mean(weights * (treatment == 1))
  denominator_0 <- mean(weights * (treatment == 0))
  risk_1 <- mean(weights * (treatment == 1) * outcome) / denominator_1
  risk_0 <- mean(weights * (treatment == 0) * outcome) / denominator_0
  influence_1 <- weights * (treatment == 1) * (outcome - risk_1) / denominator_1
  influence_0 <- weights * (treatment == 0) * (outcome - risk_0) / denominator_0
  estimates <- c(risk_1, risk_0, risk_1 - risk_0, risk_1 / risk_0)
  standard_errors <- c(
    stats::sd(influence_1) / sqrt(n),
    stats::sd(influence_0) / sqrt(n),
    stats::sd(influence_1 - influence_0) / sqrt(n),
    (risk_1 / risk_0) * stats::sd(influence_1 / risk_1 - influence_0 / risk_0) /
      sqrt(n)
  )
  lower <- c(
    estimates[1:3] - stats::qnorm(.975) * standard_errors[1:3],
    exp(log(estimates[4]) - stats::qnorm(.975) * standard_errors[4] / estimates[4])
  )
  upper <- c(
    estimates[1:3] + stats::qnorm(.975) * standard_errors[1:3],
    exp(log(estimates[4]) + stats::qnorm(.975) * standard_errors[4] / estimates[4])
  )
  data.frame(
    effect = c("risk_treated", "risk_control", "RD", "RR"),
    estimate = estimates, se = standard_errors,
    conf_low = lower, conf_high = upper,
    stringsAsFactors = FALSE
  )
}

tte_independent_smd <- function(x, treatment, weights) {
  mean_1 <- stats::weighted.mean(x[treatment == 1], weights[treatment == 1])
  mean_0 <- stats::weighted.mean(x[treatment == 0], weights[treatment == 0])
  if (all(x %in% c(0, 1))) {
    p1 <- mean(x[treatment == 1])
    p0 <- mean(x[treatment == 0])
    denominator <- sqrt((p1 * (1 - p1) + p0 * (1 - p0)) / 2)
  } else {
    s1 <- stats::sd(x[treatment == 1])
    s0 <- stats::sd(x[treatment == 0])
    denominator <- sqrt((s1^2 + s0^2) / 2)
  }
  if (!is.finite(denominator) || denominator == 0) return(NA_real_)
  (mean_1 - mean_0) / denominator
}

tte_independent_rubin_pool <- function(estimates, within_variances, complete_df) {
  m <- length(estimates)
  estimate <- mean(estimates)
  within <- mean(within_variances)
  between <- stats::var(estimates)
  total <- within + (1 + 1 / m) * between
  relative_increase <- if (within > 0) ((1 + 1 / m) * between) / within else Inf
  lambda <- if (total > 0) ((1 + 1 / m) * between) / total else 0
  old_df <- if (is.finite(relative_increase) && relative_increase > 0) {
    (m - 1) * (1 + 1 / relative_increase)^2
  } else {
    Inf
  }
  observed_df <- ((complete_df + 1) / (complete_df + 3)) * complete_df * (1 - lambda)
  df <- if (is.infinite(old_df)) observed_df else
    (old_df * observed_df) / (old_df + observed_df)
  critical <- stats::qt(.975, df)
  data.frame(
    estimate = estimate, se = sqrt(total), df = df,
    conf_low = estimate - critical * sqrt(total),
    conf_high = estimate + critical * sqrt(total),
    stringsAsFactors = FALSE
  )
}

tte_independent_validate_baseline <- function(data, covariates, result,
                                              tolerance = 1e-7) {
  formula <- stats::reformulate(covariates, response = "treatment")
  model <- stats::glm(formula, data = data, family = stats::binomial())
  ps <- stats::predict(model, type = "response")
  weights <- if (unique(result$effects$estimand) == "ATE") {
    data$treatment / ps + (1 - data$treatment) / (1 - ps)
  } else {
    data$treatment * (1 - ps) + (1 - data$treatment) * ps
  }
  independent <- tte_independent_weighted_effects(data$outcome, data$treatment, weights)
  primary <- result$effects[match(independent$effect, result$effects$effect), ]
  comparisons <- data.frame(
    quantity = c("estimate", "se", "ci_lower", "ci_upper", "ESS", "maximum_absolute_SMD"),
    primary = c(
      max(abs(primary$estimate - independent$estimate)),
      max(abs(primary$se - independent$se)),
      max(abs(primary$conf_low - independent$conf_low)),
      max(abs(primary$conf_high - independent$conf_high)),
      result$weight_summary$total_ess,
      max(abs(result$balance$adjusted_smd), na.rm = TRUE)
    ),
    independent = c(
      0, 0, 0, 0,
      sum(weights)^2 / sum(weights^2),
      max(abs(vapply(covariates, function(variable) {
        tte_independent_smd(as.numeric(data[[variable]]), data$treatment, weights)
      }, numeric(1))), na.rm = TRUE)
    ),
    tolerance = tolerance,
    stringsAsFactors = FALSE
  )
  comparisons$absolute_difference <- abs(comparisons$primary - comparisons$independent)
  comparisons$status <- ifelse(comparisons$absolute_difference <= tolerance, "PASS", "FAIL")
  comparisons
}

tte_independent_validate_mi <- function(result, n, tolerance = 1e-7) {
  independent <- tte_independent_rubin_pool(
    result$per_imputation$estimate,
    result$per_imputation$within_variance,
    complete_df = n - 2L
  )
  primary <- result$effects[1, ]
  comparisons <- data.frame(
    quantity = c("pooled_ATE", "pooled_SE", "pooled_df", "ci_lower", "ci_upper"),
    primary = c(
      primary$estimate, primary$se,
      mice::pool.scalar(
        result$per_imputation$estimate, result$per_imputation$within_variance,
        n = n, k = 2
      )$df,
      primary$conf_low, primary$conf_high
    ),
    independent = c(
      independent$estimate, independent$se, independent$df,
      independent$conf_low, independent$conf_high
    ),
    tolerance = tolerance,
    stringsAsFactors = FALSE
  )
  comparisons$absolute_difference <- abs(comparisons$primary - comparisons$independent)
  comparisons$status <- ifelse(comparisons$absolute_difference <= tolerance, "PASS", "FAIL")
  comparisons
}
