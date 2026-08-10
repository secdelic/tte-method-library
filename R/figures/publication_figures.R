# Journal-oriented figures from synthetic or aggregate statistical summaries.
# These functions format prespecified results. They do not estimate effects,
# select models, or infer scientific meaning.

tte_require_ggplot2 <- function() {
  if (!requireNamespace("ggplot2", quietly = TRUE)) {
    stop("Package 'ggplot2' is required for publication figures")
  }
  invisible(TRUE)
}

tte_figure_columns <- function(data, required, name) {
  if (!is.data.frame(data)) stop(name, " must be a data.frame")
  missing <- setdiff(required, names(data))
  if (length(missing)) {
    stop(name, " is missing columns: ", paste(missing, collapse = ", "))
  }
  invisible(TRUE)
}

tte_finite_numeric <- function(x, name, allow_na = FALSE) {
  if (!is.numeric(x)) stop(name, " must be numeric")
  invalid <- if (allow_na) !is.na(x) & !is.finite(x) else !is.finite(x)
  if (any(invalid) || (!allow_na && anyNA(x))) {
    stop(name, " contains missing or non-finite values")
  }
  invisible(TRUE)
}

tte_probability_values <- function(x, name) {
  tte_finite_numeric(x, name)
  if (any(x < 0 | x > 1)) stop(name, " must be between 0 and 1")
  invisible(TRUE)
}

tte_validate_intervals <- function(data, name) {
  for (column in c("estimate", "ci_lower", "ci_upper")) {
    tte_finite_numeric(data[[column]], paste(name, column))
  }
  invalid <- data$ci_lower > data$estimate | data$estimate > data$ci_upper
  if (any(invalid)) stop(name, " has an estimate outside its confidence interval")
  invisible(TRUE)
}

tte_theme_publication <- function(base_size = 8, base_family = "sans") {
  tte_require_ggplot2()
  if (!is.numeric(base_size) || length(base_size) != 1L ||
      !is.finite(base_size) || base_size < 7) {
    stop("base_size must be a finite value of at least 7 pt")
  }
  ggplot2::theme_bw(base_size = base_size, base_family = base_family) +
    ggplot2::theme(
      panel.grid.minor = ggplot2::element_blank(),
      legend.position = "bottom",
      plot.title.position = "plot",
      axis.title = ggplot2::element_text(size = base_size),
      axis.text = ggplot2::element_text(size = max(7, base_size - 1)),
      legend.text = ggplot2::element_text(size = max(7, base_size - 1)),
      plot.margin = ggplot2::margin(5.5, 7, 5.5, 7)
    )
}

tte_journal_palette <- function() {
  # Generic Okabe-Ito-style colors; no journal-specific branding is encoded.
  c("#0072B2", "#D55E00", "#009E73", "#CC79A7", "#000000")
}

tte_normalize_effect_scale <- function(effect_scale) {
  if (missing(effect_scale) || is.null(effect_scale) ||
      length(effect_scale) != 1L || is.na(effect_scale)) {
    stop("effect_scale must be explicitly supplied as 'difference' or 'ratio'")
  }
  effect_scale <- tolower(trimws(as.character(effect_scale)))
  aliases <- c(
    difference = "difference", additive = "difference",
    ratio = "ratio", multiplicative = "ratio"
  )
  if (!effect_scale %in% names(aliases)) {
    stop("effect_scale must be 'difference' or 'ratio'")
  }
  unname(aliases[[effect_scale]])
}

tte_null_value_for_scale <- function(effect_scale) {
  scale <- tte_normalize_effect_scale(effect_scale)
  if (scale == "ratio") 1 else 0
}

tte_resolve_null_value <- function(effect_scale, null_value = NULL) {
  scale <- tte_normalize_effect_scale(effect_scale)
  expected <- tte_null_value_for_scale(scale)
  if (!is.null(null_value)) {
    if (!is.numeric(null_value) || length(null_value) != 1L ||
        !is.finite(null_value)) {
      stop("null_value must be one finite numeric value")
    }
    if (!isTRUE(all.equal(as.numeric(null_value), expected, tolerance = 1e-12))) {
      stop("null_value conflicts with effect_scale: expected ", expected)
    }
  }
  expected
}

tte_effect_scale_from_measure <- function(effect_measure) {
  measure <- tolower(trimws(as.character(effect_measure)))
  ratio <- c(
    "rr", "or", "hr", "irr", "pr", "risk_ratio", "odds_ratio",
    "hazard_ratio", "incidence_rate_ratio", "prevalence_ratio"
  )
  difference <- c(
    "rd", "md", "risk_difference", "mean_difference", "rate_difference",
    "rmst_difference", "average_treatment_effect"
  )
  out <- rep(NA_character_, length(measure))
  out[measure %in% ratio] <- "ratio"
  out[measure %in% difference] <- "difference"
  if (anyNA(out)) {
    stop("Unknown effect measure; effect scale requires manual specification: ",
         paste(unique(effect_measure[is.na(out)]), collapse = ", "))
  }
  out
}

plot_cohort_flow <- function(data, base_size = 8) {
  tte_figure_columns(data, c("stage", "n"), "Cohort-flow data")
  tte_finite_numeric(data$n, "Cohort-flow n")
  if (any(data$n < 0)) stop("Cohort-flow n cannot be negative")
  data$stage <- factor(data$stage, levels = rev(unique(data$stage)))
  ggplot2::ggplot(data, ggplot2::aes(x = stage, y = n)) +
    ggplot2::geom_col(width = 0.65, fill = "grey70", colour = "black",
                      linewidth = 0.4) +
    ggplot2::geom_text(ggplot2::aes(label = n), hjust = -0.15,
                       size = base_size * 25.4 / 72.27) +
    ggplot2::coord_flip(clip = "off") +
    ggplot2::scale_y_continuous(expand = ggplot2::expansion(mult = c(0, 0.14))) +
    ggplot2::labs(x = NULL, y = "Participants") +
    tte_theme_publication(base_size)
}

plot_missingness <- function(data, base_size = 8) {
  tte_figure_columns(data, c("variable", "missing_fraction"), "Missingness data")
  tte_probability_values(data$missing_fraction, "missing_fraction")
  ggplot2::ggplot(data, ggplot2::aes(
    x = missing_fraction, y = stats::reorder(variable, missing_fraction)
  )) +
    ggplot2::geom_col(fill = "grey55", colour = "black", linewidth = 0.3) +
    ggplot2::scale_x_continuous(labels = function(x) paste0(round(100 * x), "%"),
                               limits = c(0, 1)) +
    ggplot2::labs(x = "Missing observations", y = NULL) +
    tte_theme_publication(base_size)
}

plot_propensity_score_distribution <- function(data, base_size = 8) {
  tte_figure_columns(data, c("propensity_score", "treatment"),
                     "Propensity-score data")
  tte_probability_values(data$propensity_score, "propensity_score")
  if (length(unique(data$treatment)) < 2L) {
    stop("Propensity-score data require at least two treatment groups")
  }
  ggplot2::ggplot(data, ggplot2::aes(
    x = propensity_score, colour = factor(treatment), linetype = factor(treatment)
  )) +
    ggplot2::geom_density(linewidth = 0.7, na.rm = TRUE) +
    ggplot2::scale_colour_manual(values = tte_journal_palette()) +
    ggplot2::labs(x = "Propensity score", y = "Density",
                  colour = "Treatment", linetype = "Treatment") +
    tte_theme_publication(base_size)
}

plot_weight_distribution <- function(data, base_size = 8) {
  tte_figure_columns(data, c("weight", "treatment"), "Weight data")
  tte_finite_numeric(data$weight, "weight")
  if (any(data$weight < 0) || all(data$weight == 0)) {
    stop("Weights must be non-negative and not all zero")
  }
  ggplot2::ggplot(data, ggplot2::aes(
    x = weight, colour = factor(treatment), linetype = factor(treatment)
  )) +
    ggplot2::geom_density(linewidth = 0.7, na.rm = TRUE) +
    ggplot2::scale_colour_manual(values = tte_journal_palette()) +
    ggplot2::labs(x = "Analysis weight", y = "Density",
                  colour = "Treatment", linetype = "Treatment") +
    tte_theme_publication(base_size)
}

plot_love <- function(data, threshold = 0.1, base_size = 8) {
  tte_figure_columns(data, c("variable", "smd_unweighted", "smd_weighted"),
                     "Love-plot data")
  tte_finite_numeric(data$smd_unweighted, "smd_unweighted", allow_na = TRUE)
  tte_finite_numeric(data$smd_weighted, "smd_weighted", allow_na = TRUE)
  if (!is.numeric(threshold) || length(threshold) != 1L ||
      !is.finite(threshold) || threshold <= 0) stop("threshold must be positive")
  long <- rbind(
    data.frame(variable = data$variable, absolute_smd = abs(data$smd_unweighted),
               stage = "Unweighted"),
    data.frame(variable = data$variable, absolute_smd = abs(data$smd_weighted),
               stage = "Weighted")
  )
  ggplot2::ggplot(long, ggplot2::aes(
    x = absolute_smd, y = stats::reorder(variable, absolute_smd),
    colour = stage, shape = stage
  )) +
    ggplot2::geom_vline(xintercept = threshold, linetype = 2, linewidth = 0.45) +
    ggplot2::geom_point(size = 2) +
    ggplot2::scale_colour_manual(values = c(
      "Unweighted" = "#D55E00", "Weighted" = "#0072B2"
    )) +
    ggplot2::labs(x = "Absolute standardized mean difference", y = NULL,
                  colour = NULL, shape = NULL) +
    tte_theme_publication(base_size)
}

plot_standardized_balance <- function(data, threshold = 0.1, base_size = 8) {
  tte_figure_columns(data, c("variable", "smd", "stage"),
                     "Standardized-balance data")
  tte_finite_numeric(data$smd, "smd", allow_na = TRUE)
  if (!is.numeric(threshold) || length(threshold) != 1L ||
      !is.finite(threshold) || threshold <= 0) stop("threshold must be positive")
  ggplot2::ggplot(data, ggplot2::aes(
    x = smd, y = stats::reorder(variable, abs(smd)), colour = stage, shape = stage
  )) +
    ggplot2::geom_vline(xintercept = c(-threshold, threshold), linetype = 2,
                        linewidth = 0.45) +
    ggplot2::geom_vline(xintercept = 0, colour = "grey55", linewidth = 0.35) +
    ggplot2::geom_point(size = 2) +
    ggplot2::scale_colour_manual(values = tte_journal_palette()) +
    ggplot2::labs(x = "Standardized mean difference", y = NULL,
                  colour = NULL, shape = NULL) +
    tte_theme_publication(base_size)
}

plot_forest <- function(data, effect_scale, null_value = NULL, base_size = 8,
                        x_label = "Estimate (95% CI)") {
  tte_figure_columns(data, c("label", "estimate", "ci_lower", "ci_upper"),
                     "Forest-plot data")
  tte_validate_intervals(data, "Forest-plot data")
  resolved_null <- tte_resolve_null_value(effect_scale, null_value)
  normalized_scale <- tte_normalize_effect_scale(effect_scale)
  data$label <- factor(data$label, levels = rev(unique(data$label)))
  p <- ggplot2::ggplot(data, ggplot2::aes(y = label, x = estimate)) +
    ggplot2::geom_vline(xintercept = resolved_null, linetype = 2,
                        linewidth = 0.45) +
    ggplot2::geom_segment(ggplot2::aes(
      x = ci_lower, xend = ci_upper, yend = label
    ), linewidth = 0.6) +
    ggplot2::geom_point(size = 2) +
    ggplot2::labs(x = x_label, y = NULL) +
    tte_theme_publication(base_size)
  attr(p, "tte_effect_scale") <- normalized_scale
  attr(p, "tte_null_value") <- resolved_null
  p
}

plot_survival_risk <- function(data, measure = c("survival", "risk"),
                               base_size = 8) {
  measure <- match.arg(measure)
  tte_figure_columns(data, c("time", "estimate", "strategy"),
                     "Survival/risk-curve data")
  tte_finite_numeric(data$time, "time")
  tte_probability_values(data$estimate, "curve estimate")
  if (all(c("ci_lower", "ci_upper") %in% names(data))) {
    tte_probability_values(data$ci_lower, "ci_lower")
    tte_probability_values(data$ci_upper, "ci_upper")
    tte_validate_intervals(data, "Survival/risk-curve data")
  }
  p <- ggplot2::ggplot(data, ggplot2::aes(
    x = time, y = estimate, colour = strategy, linetype = strategy,
    group = strategy
  ))
  if (all(c("ci_lower", "ci_upper") %in% names(data))) {
    p <- p + ggplot2::geom_ribbon(
      ggplot2::aes(ymin = ci_lower, ymax = ci_upper, fill = strategy),
      alpha = 0.13, colour = NA, show.legend = FALSE
    )
  }
  p +
    ggplot2::geom_step(linewidth = 0.7) +
    ggplot2::scale_colour_manual(values = tte_journal_palette()) +
    ggplot2::scale_fill_manual(values = tte_journal_palette()) +
    ggplot2::coord_cartesian(ylim = c(0, 1)) +
    ggplot2::labs(x = "Follow-up time",
                  y = if (measure == "survival") "Survival probability" else "Risk",
                  colour = "Strategy", linetype = "Strategy") +
    tte_theme_publication(base_size)
}

plot_cumulative_incidence <- function(data, base_size = 8) {
  plot_survival_risk(data, measure = "risk", base_size = base_size) +
    ggplot2::labs(y = "Cumulative incidence")
}

plot_sensitivity_forest <- function(data, effect_scale, null_value = NULL,
                                    base_size = 8) {
  tte_figure_columns(data, c("analysis", "estimate", "ci_lower", "ci_upper"),
                     "Sensitivity-forest data")
  forest_data <- data.frame(
    label = data$analysis, estimate = data$estimate,
    ci_lower = data$ci_lower, ci_upper = data$ci_upper
  )
  plot_forest(
    forest_data, effect_scale = effect_scale, null_value = null_value,
    base_size = base_size, x_label = "Sensitivity estimate (95% CI)"
  )
}

plot_ccw_strategy_schematic <- function(data, base_size = 8) {
  tte_figure_columns(data, c("strategy", "period", "status"),
                     "CCW schematic data")
  tte_finite_numeric(data$period, "CCW period")
  ggplot2::ggplot(data, ggplot2::aes(x = period, y = strategy, fill = status)) +
    ggplot2::geom_tile(colour = "white", linewidth = 0.35) +
    ggplot2::scale_fill_manual(values = tte_journal_palette()) +
    ggplot2::labs(x = "Follow-up period", y = "Cloned strategy", fill = "Status") +
    tte_theme_publication(base_size)
}

plot_lmtp_policy <- function(data, base_size = 8) {
  tte_figure_columns(data, c("time", "observed", "policy"), "LMTP policy data")
  for (column in c("time", "observed", "policy")) {
    tte_finite_numeric(data[[column]], paste("LMTP", column))
  }
  long <- rbind(
    data.frame(time = data$time, value = data$observed, series = "Observed"),
    data.frame(time = data$time, value = data$policy, series = "Policy")
  )
  ggplot2::ggplot(long, ggplot2::aes(
    x = time, y = value, colour = series, linetype = series, shape = series
  )) +
    ggplot2::geom_line(linewidth = 0.7) +
    ggplot2::geom_point(size = 2) +
    ggplot2::scale_colour_manual(values = c(
      "Observed" = "#000000", "Policy" = "#0072B2"
    )) +
    ggplot2::labs(x = "Treatment time", y = "Treatment value",
                  colour = NULL, linetype = NULL, shape = NULL) +
    tte_theme_publication(base_size)
}

read_figure_config <- function(path = "config/figure_config.yml") {
  if (!requireNamespace("yaml", quietly = TRUE)) {
    stop("Package 'yaml' is required to read figure_config.yml")
  }
  yaml::read_yaml(path)
}

validate_figure_config <- function(config) {
  required <- list(
    single_width = config$dimensions$single_column_width_mm,
    double_width = config$dimensions$double_column_width_mm,
    default_height = config$dimensions$default_height_mm,
    base_font = config$typography$base_font_pt,
    minimum_font = config$typography$minimum_font_pt,
    line_width = config$geometry$line_width_pt,
    point_size = config$geometry$point_size_pt,
    dpi = config$export$raster_dpi,
    vector_formats = config$export$vector_formats,
    raster_formats = config$export$raster_formats,
    background = config$export$background
  )
  unresolved <- names(required)[vapply(required, is.null, logical(1))]
  if (length(unresolved)) {
    stop("Figure configuration is missing: ", paste(unresolved, collapse = ", "))
  }
  vector_formats <- tolower(unlist(config$export$vector_formats, use.names = FALSE))
  raster_formats <- tolower(unlist(config$export$raster_formats, use.names = FALSE))
  checks <- data.frame(
    check = c(
      "single_column_width", "double_column_width", "positive_height",
      "minimum_font", "base_font", "positive_geometry", "raster_dpi",
      "vector_output", "raster_output", "grayscale_configuration",
      "no_decorative_3d", "no_decorative_gradients", "no_ai_decoration",
      "human_visual_approval_required"
    ),
    pass = c(
      isTRUE(config$dimensions$single_column_width_mm == 85),
      config$dimensions$double_column_width_mm >= 175 &&
        config$dimensions$double_column_width_mm <= 180,
      is.finite(config$dimensions$default_height_mm) &&
        config$dimensions$default_height_mm > 0,
      config$typography$minimum_font_pt >= 7,
      config$typography$base_font_pt >= config$typography$minimum_font_pt,
      config$geometry$line_width_pt > 0 && config$geometry$point_size_pt > 0,
      config$export$raster_dpi >= 600,
      length(vector_formats) > 0L &&
        all(vector_formats %in% c("pdf", "svg")),
      length(raster_formats) > 0L &&
        all(raster_formats %in% c("tif", "tiff", "png")),
      isTRUE(config$palette$grayscale_compatible) &&
        isTRUE(config$palette$use_shape_and_linetype_redundancy),
      identical(config$style$three_dimensional_effects, FALSE),
      identical(config$style$decorative_gradients, FALSE),
      identical(config$style$ai_style_decoration, FALSE),
      isTRUE(config$quality_control$require_human_visual_approval)
    ),
    stringsAsFactors = FALSE
  )
  if (any(!checks$pass)) {
    stop("Figure configuration failed: ",
         paste(checks$check[!checks$pass], collapse = ", "))
  }
  checks
}

tte_safe_output_stem <- function(x, object = "figure") {
  if (length(x) != 1L || is.na(x) || !grepl("^[A-Za-z0-9][A-Za-z0-9._-]*$", x)) {
    stop(object, " must be a filesystem-safe stem")
  }
  x
}

tte_bind_rows_fill <- function(x, y) {
  columns <- union(names(x), names(y))
  for (column in setdiff(columns, names(x))) x[[column]] <- NA
  for (column in setdiff(columns, names(y))) y[[column]] <- NA
  rbind(x[, columns, drop = FALSE], y[, columns, drop = FALSE])
}

tte_write_figure_qc <- function(qc, path) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  utils::write.csv(qc, path, row.names = FALSE, na = "", fileEncoding = "UTF-8")
  invisible(path)
}

export_publication_figure <- function(
    plot, figure, output_dir = "output/figures", config,
    column = c("single", "double"), height_mm = NULL,
    vector_formats = NULL, raster_formats = NULL) {
  tte_require_ggplot2()
  if (!inherits(plot, "ggplot")) stop("plot must be a ggplot object")
  figure <- tte_safe_output_stem(figure)
  column <- match.arg(column)
  config_checks <- validate_figure_config(config)
  width_mm <- if (column == "single") {
    config$dimensions$single_column_width_mm
  } else {
    config$dimensions$double_column_width_mm
  }
  if (is.null(height_mm)) height_mm <- config$dimensions$default_height_mm
  if (!is.numeric(height_mm) || length(height_mm) != 1L ||
      !is.finite(height_mm) || height_mm <= 0) stop("height_mm must be positive")
  if (is.null(vector_formats)) vector_formats <- config$export$vector_formats
  if (is.null(raster_formats)) raster_formats <- config$export$raster_formats
  vector_formats <- unique(tolower(unlist(vector_formats, use.names = FALSE)))
  raster_formats <- unique(tolower(unlist(raster_formats, use.names = FALSE)))
  if (!length(vector_formats) || !all(vector_formats %in% c("pdf", "svg"))) {
    stop("At least one supported vector format (pdf or svg) is required")
  }
  if (!length(raster_formats) ||
      !all(raster_formats %in% c("tif", "tiff", "png"))) {
    stop("At least one supported raster format (tiff or png) is required")
  }
  formats <- unique(c(vector_formats, raster_formats))
  dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
  written <- character()
  for (format in formats) {
    path <- file.path(output_dir, paste0(figure, ".", format))
    args <- list(
      filename = path, plot = plot, width = width_mm, height = height_mm,
      units = "mm", bg = config$export$background, limitsize = FALSE
    )
    if (format == "svg") args$device <- grDevices::svg
    if (format %in% raster_formats) args$dpi <- config$export$raster_dpi
    if (format %in% c("tif", "tiff")) args$compression <- "lzw"
    do.call(ggplot2::ggsave, args)
    written <- c(written, path)
  }
  exists <- file.exists(written)
  nonempty <- exists & !is.na(file.info(written)$size) & file.info(written)$size > 0
  vector_ok <- all(nonempty[formats %in% vector_formats])
  raster_ok <- all(nonempty[formats %in% raster_formats])
  machine_checks_pass <- all(config_checks$pass) && width_mm > 0 &&
    height_mm > 0 && config$typography$minimum_font_pt >= 7 &&
    config$export$raster_dpi >= 600 && vector_ok && raster_ok
  qc <- data.frame(
    figure = figure,
    width_mm = width_mm,
    height_mm = height_mm,
    dpi = config$export$raster_dpi,
    minimum_font_pt = config$typography$minimum_font_pt,
    vector_output = vector_ok,
    clipping = "PENDING_MANUAL_REVIEW",
    overlap = "PENDING_MANUAL_REVIEW",
    grayscale_pass = "PENDING_MANUAL_REVIEW",
    publication_ready = FALSE,
    manual_review = "PENDING",
    machine_checks_pass = machine_checks_pass,
    raster_output = raster_ok,
    output_files = paste(basename(written), collapse = "|"),
    manual_reviewer = "",
    manual_reviewed_at = "",
    manual_notes = "",
    stringsAsFactors = FALSE
  )
  qc_path <- file.path(output_dir, "figure_qc.csv")
  if (file.exists(qc_path)) {
    previous <- utils::read.csv(
      qc_path, check.names = FALSE, stringsAsFactors = FALSE,
      na.strings = character()
    )
    if ("figure" %in% names(previous)) {
      previous <- previous[previous$figure != figure, , drop = FALSE]
    }
    qc <- tte_bind_rows_fill(previous, qc)
  }
  tte_write_figure_qc(qc, qc_path)
  invisible(list(files = written, qc = qc[qc$figure == figure, , drop = FALSE],
                 qc_path = qc_path))
}

record_figure_manual_review <- function(
    qc_path, figure, clipping, overlap, grayscale_pass,
    decision = c("APPROVED", "REJECTED"), reviewer, reviewed_at,
    notes = "") {
  # This is an explicit human-recording interface. No timestamp, reviewer, or
  # approval is generated by code.
  decision <- match.arg(decision)
  figure <- tte_safe_output_stem(figure)
  if (!file.exists(qc_path)) stop("figure_qc.csv does not exist")
  if (length(reviewer) != 1L || is.na(reviewer) ||
      length(reviewed_at) != 1L || is.na(reviewed_at) ||
      !nzchar(trimws(reviewer)) || !nzchar(trimws(reviewed_at))) {
    stop("Explicit human reviewer and reviewed_at are required")
  }
  if (!grepl("^[0-9]{4}-[0-9]{2}-[0-9]{2}($|T)", reviewed_at)) {
    stop("reviewed_at must begin with an ISO 8601 date")
  }
  checks <- toupper(c(clipping, overlap, grayscale_pass))
  if (!all(checks %in% c("PASS", "FAIL"))) {
    stop("clipping, overlap, and grayscale_pass must be PASS or FAIL")
  }
  qc <- utils::read.csv(
    qc_path, check.names = FALSE, stringsAsFactors = FALSE,
    na.strings = character()
  )
  hit <- which(qc$figure == figure)
  if (length(hit) != 1L) stop("Figure must have exactly one QC row: ", figure)
  machine_pass <- isTRUE(as.logical(qc$machine_checks_pass[hit]))
  visual_pass <- all(checks == "PASS")
  if (decision == "APPROVED" && (!machine_pass || !visual_pass)) {
    stop("Publication approval requires all machine and human visual checks")
  }
  qc$clipping[hit] <- checks[[1]]
  qc$overlap[hit] <- checks[[2]]
  qc$grayscale_pass[hit] <- checks[[3]]
  qc$manual_review[hit] <- decision
  qc$manual_reviewer[hit] <- reviewer
  qc$manual_reviewed_at[hit] <- reviewed_at
  qc$manual_notes[hit] <- notes
  qc$publication_ready[hit] <- decision == "APPROVED" &&
    machine_pass && visual_pass
  tte_write_figure_qc(qc, qc_path)
  invisible(qc[hit, , drop = FALSE])
}

assert_publication_figures_ready <- function(qc_path, figures = NULL) {
  if (!file.exists(qc_path)) stop("figure_qc.csv does not exist")
  qc <- utils::read.csv(
    qc_path, check.names = FALSE, stringsAsFactors = FALSE,
    na.strings = character()
  )
  required <- c(
    "figure", "machine_checks_pass", "clipping", "overlap",
    "grayscale_pass", "publication_ready", "manual_review",
    "manual_reviewer", "manual_reviewed_at"
  )
  tte_figure_columns(qc, required, "Figure QC")
  if (!is.null(figures)) {
    missing <- setdiff(figures, qc$figure)
    if (length(missing)) stop("Missing figure QC rows: ", paste(missing, collapse = ", "))
    qc <- qc[qc$figure %in% figures, , drop = FALSE]
  }
  ready <- as.logical(qc$machine_checks_pass) &
    qc$clipping == "PASS" & qc$overlap == "PASS" &
    qc$grayscale_pass == "PASS" & as.logical(qc$publication_ready) &
    qc$manual_review == "APPROVED" & nzchar(qc$manual_reviewer) &
    nzchar(qc$manual_reviewed_at)
  ready[is.na(ready)] <- FALSE
  if (!nrow(qc) || any(!ready)) {
    stop("One or more figures lack completed machine and human approval")
  }
  invisible(qc)
}
