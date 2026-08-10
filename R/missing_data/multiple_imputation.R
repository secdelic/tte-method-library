# Audited predictive mean matching and Rubin/Barnard-Rubin pooling.

tte_run_multiple_imputation <- function(data, dictionary, covariates, m, maxit, seed) {
  if (!requireNamespace("mice", quietly = TRUE)) stop("Package 'mice' is required")
  if (m < 2L || maxit < 1L) stop("Multiple imputation requires m >= 2 and maxit >= 1")
  variables <- unique(c("outcome", "treatment", covariates))
  imputation_data <- data[variables]
  method <- setNames(rep("", length(variables)), variables)
  variable_col <- if ("variable_name" %in% names(dictionary)) "variable_name" else "variable"
  for (variable in covariates) {
    if (anyNA(imputation_data[[variable]])) {
      row <- dictionary[dictionary[[variable_col]] == variable, , drop = FALSE]
      if (nrow(row) != 1L || toupper(row$impute) != "TRUE" || row$mice_method != "pmm") {
        stop("Missing covariate lacks audited PMM configuration: ", variable)
      }
      method[[variable]] <- "pmm"
    }
  }
  predictor <- matrix(
    1L, nrow = length(variables), ncol = length(variables),
    dimnames = list(variables, variables)
  )
  diag(predictor) <- 0L
  predictor[method == "", ] <- 0L
  set.seed(as.integer(seed))
  mice::mice(
    imputation_data, m = as.integer(m), maxit = as.integer(maxit),
    method = method, predictorMatrix = predictor, printFlag = FALSE,
    seed = as.integer(seed)
  )
}

tte_pool_rubin <- function(estimates, within_variances, n, parameter_count = 2L) {
  mice::pool.scalar(
    Q = estimates, U = within_variances,
    n = n, k = parameter_count
  )
}
