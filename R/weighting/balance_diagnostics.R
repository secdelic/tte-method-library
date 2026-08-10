# Covariate balance and effective-sample-size diagnostics.

tte_compute_ess <- function(weights, treatment = NULL) {
  ess <- function(x) sum(x)^2 / sum(x^2)
  out <- data.frame(total_ess = ess(weights), stringsAsFactors = FALSE)
  if (!is.null(treatment)) {
    out$control_ess <- ess(weights[treatment == 0])
    out$treated_ess <- ess(weights[treatment == 1])
  }
  out
}

tte_compute_balance <- function(data, treatment, covariates, weights) {
  if (!requireNamespace("cobalt", quietly = TRUE)) stop("Package 'cobalt' is required")
  formula <- stats::reformulate(covariates, response = treatment)
  object <- cobalt::bal.tab(
    formula, data = data, weights = weights, binary = "std",
    s.d.denom = "pooled", un = TRUE, quick = FALSE
  )
  data.frame(
    variable = rownames(object$Balance),
    unadjusted_smd = object$Balance$Diff.Un,
    adjusted_smd = object$Balance$Diff.Adj,
    stringsAsFactors = FALSE
  )
}

tte_maximum_absolute_smd <- function(balance) {
  max(abs(balance$adjusted_smd), na.rm = TRUE)
}
