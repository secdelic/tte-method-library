# Publication-oriented aggregate adapters. These functions do not alter or
# recompute the registered estimands.

tte_standardize_effects <- function(effects, profile, analysis_population,
                                    release_status) {
  if (!nrow(effects)) return(effects)
  effects$standard_error <- effects$se
  effects$ci_lower <- effects$conf_low
  effects$ci_upper <- effects$conf_high
  effects$p_value <- NA_real_
  effects$p_value_reporting_status <- "NOT_GENERATED_BY_FORMATTING_LAYER"
  effects$effect_measure <- effects$effect
  effects$analysis_population <- analysis_population
  effects$method <- if (profile == "BASELINE_BINARY_RISK") {
    "Propensity-score weighting with fixed-weight influence-curve inference"
  } else {
    "Within-imputation WeightIt M-estimation with Rubin pooling"
  }
  effects$release_status <- release_status
  effects
}

tte_weighted_sd <- function(x, weights) {
  mean_x <- stats::weighted.mean(x, weights)
  sqrt(sum(weights * (x - mean_x)^2) / sum(weights))
}

tte_build_table1_summary <- function(data, covariates, weights, balance) {
  rows <- list()
  for (variable in covariates) {
    balance_row <- balance[balance$variable == variable, , drop = FALSE]
    for (group in c(0, 1)) {
      index <- data$treatment == group
      x <- as.numeric(data[[variable]])
      rows[[length(rows) + 1L]] <- data.frame(
        variable = variable,
        level = "",
        group = as.character(group),
        unweighted_summary = sprintf("%.3f (%.3f)", mean(x[index]), stats::sd(x[index])),
        weighted_summary = sprintf(
          "%.3f (%.3f)",
          stats::weighted.mean(x[index], weights[index]),
          tte_weighted_sd(x[index], weights[index])
        ),
        smd_unweighted = balance_row$unadjusted_smd[[1]],
        smd_weighted = balance_row$adjusted_smd[[1]],
        stringsAsFactors = FALSE
      )
    }
  }
  do.call(rbind, rows)
}

tte_write_publication_outputs <- function(result, profile, analysis_population,
                                          data, covariates, output_dir,
                                          figure_config, release_status) {
  effects <- tte_standardize_effects(
    result$effects, profile, analysis_population, release_status
  )
  main <- build_main_results_table(effects, p_value_appropriate = FALSE)
  export_publication_table(
    main, "primary_effects", "SYNTHETIC_CONFIRMED",
    output_dir = file.path(output_dir, "tables"), publication_format = "html",
    title = "Primary effects"
  )
  weights <- if (profile == "BASELINE_BINARY_RISK") {
    result$internal$weight
  } else {
    result$internal[[1]]$weight
  }
  table1_input <- tte_build_table1_summary(data, covariates, weights, result$balance)
  table1 <- build_table1(table1_input)
  export_publication_table(
    table1, "table1", "SYNTHETIC_CONFIRMED",
    output_dir = file.path(output_dir, "tables"), publication_format = "html",
    title = "Baseline characteristics"
  )
  qcs <- list()
  balance_for_plot <- data.frame(
    variable = result$balance$variable,
    smd_unweighted = result$balance$unadjusted_smd,
    smd_weighted = result$balance$adjusted_smd
  )
  if ("imputation" %in% names(result$balance)) {
    balance_for_plot <- stats::aggregate(
      cbind(smd_unweighted, smd_weighted) ~ variable,
      data = balance_for_plot, FUN = stats::median, na.rm = TRUE
    )
  }
  qcs[[length(qcs) + 1L]] <- export_publication_figure(
    plot_love(balance_for_plot), "covariate_balance",
    output_dir = file.path(output_dir, "figures"), config = figure_config,
    column = "single"
  )$qc
  additive <- effects[effects$effect %in% c("RD", "mean_difference"), , drop = FALSE]
  if (nrow(additive)) {
    qcs[[length(qcs) + 1L]] <- export_publication_figure(
      plot_forest(
        data.frame(
          label = paste(additive$analysis, additive$effect),
          estimate = additive$estimate,
          ci_lower = additive$ci_lower,
          ci_upper = additive$ci_upper
        ),
        effect_scale = "difference"
      ),
      "primary_effect_difference", file.path(output_dir, "figures"),
      figure_config, column = "single"
    )$qc
  }
  ratio <- effects[effects$effect %in% c("RR", "OR", "HR"), , drop = FALSE]
  if (nrow(ratio)) {
    qcs[[length(qcs) + 1L]] <- export_publication_figure(
      plot_forest(
        data.frame(
          label = paste(ratio$analysis, ratio$effect),
          estimate = ratio$estimate,
          ci_lower = ratio$ci_lower,
          ci_upper = ratio$ci_upper
        ),
        effect_scale = "ratio"
      ),
      "primary_effect_ratio", file.path(output_dir, "figures"),
      figure_config, column = "single"
    )$qc
  }
  qc <- do.call(rbind, qcs)
  tte_write_figure_qc(qc, file.path(output_dir, "figures", "figure_qc.csv"))
  invisible(list(effects = effects, table1 = table1, qc = qc))
}
