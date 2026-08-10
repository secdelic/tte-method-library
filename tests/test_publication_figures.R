# Synthetic-only publication figure smoke and contract tests.

script_arg <- grep("^--file=", commandArgs(FALSE), value = TRUE)
root <- if (length(script_arg)) {
  normalizePath(
    file.path(dirname(sub("^--file=", "", script_arg[[1]])), ".."),
    winslash = "/", mustWork = TRUE
  )
} else {
  normalizePath(".", winslash = "/", mustWork = TRUE)
}
if (!file.exists(file.path(root, "R", "figures", "publication_figures.R"))) {
  stop("Unable to locate repository root")
}

expect_error <- function(expr, pattern = NULL) {
  value <- try(eval.parent(substitute(expr)), silent = TRUE)
  if (!inherits(value, "try-error")) stop("Expected an error but none occurred")
  if (!is.null(pattern) && !grepl(pattern, as.character(value), ignore.case = TRUE)) {
    stop("Error did not match expected pattern: ", pattern, "\n", value)
  }
  invisible(TRUE)
}

png_dimensions <- function(path) {
  con <- file(path, open = "rb")
  on.exit(close(con), add = TRUE)
  header <- readBin(con, what = "raw", n = 24L)
  signature <- c(137L, 80L, 78L, 71L, 13L, 10L, 26L, 10L)
  if (length(header) != 24L ||
      !identical(as.integer(header[seq_len(8L)]), signature)) {
    stop("Invalid PNG signature")
  }
  big_endian_uint32 <- function(x) {
    sum(as.numeric(as.integer(x)) * 256^(3:0))
  }
  c(
    width = big_endian_uint32(header[17:20]),
    height = big_endian_uint32(header[21:24])
  )
}

source(file.path(root, "R", "figures", "publication_figures.R"))
stopifnot(requireNamespace("ggplot2", quietly = TRUE))
stopifnot(requireNamespace("yaml", quietly = TRUE))

config <- read_figure_config(file.path(root, "config_templates", "figure_config.yml"))
checks <- validate_figure_config(config)
stopifnot(nrow(checks) >= 10L, all(checks$pass))

bad_dpi <- config
bad_dpi$export$raster_dpi <- 300
expect_error(validate_figure_config(bad_dpi), "raster_dpi")
bad_gray <- config
bad_gray$palette$grayscale_compatible <- FALSE
expect_error(validate_figure_config(bad_gray), "grayscale")

stopifnot(
  identical(tte_null_value_for_scale("difference"), 0),
  identical(tte_null_value_for_scale("ratio"), 1),
  identical(tte_effect_scale_from_measure(c("RD", "RR")),
            c("difference", "ratio"))
)
expect_error(tte_resolve_null_value("ratio", 0), "conflicts")
expect_error(tte_effect_scale_from_measure("scientifically_unspecified"),
             "manual specification")

forest_difference <- data.frame(
  label = c("Primary", "Sensitivity"),
  estimate = c(-0.04, -0.03),
  ci_lower = c(-0.07, -0.06),
  ci_upper = c(-0.01, 0.00),
  stringsAsFactors = FALSE
)
forest_ratio <- data.frame(
  label = c("Primary", "Sensitivity"),
  estimate = c(0.82, 0.88),
  ci_lower = c(0.70, 0.74),
  ci_upper = c(0.96, 1.04),
  stringsAsFactors = FALSE
)
difference_plot <- plot_forest(forest_difference, effect_scale = "difference")
ratio_plot <- plot_forest(forest_ratio, effect_scale = "ratio")
stopifnot(
  identical(attr(difference_plot, "tte_null_value"), 0),
  identical(attr(ratio_plot, "tte_null_value"), 1),
  identical(attr(difference_plot, "tte_effect_scale"), "difference"),
  identical(attr(ratio_plot, "tte_effect_scale"), "ratio")
)
expect_error(plot_forest(forest_ratio), "effect_scale")
expect_error(plot_forest(forest_ratio, effect_scale = "ratio", null_value = 0),
             "conflicts")

set.seed(20260809)
ps <- data.frame(
  propensity_score = c(stats::rbeta(100, 2, 4), stats::rbeta(100, 4, 2)),
  treatment = rep(0:1, each = 100)
)
weights <- data.frame(
  weight = c(stats::rgamma(100, 4, 4), stats::rgamma(100, 5, 4)),
  treatment = rep(0:1, each = 100)
)
curve <- data.frame(
  time = rep(0:4, 2),
  estimate = c(1.00, .96, .91, .86, .80, 1.00, .94, .87, .78, .69),
  ci_lower = c(.99, .93, .87, .81, .74, .99, .91, .82, .72, .62),
  ci_upper = c(1.00, .99, .95, .91, .86, 1.00, .97, .92, .84, .76),
  strategy = rep(c("Strategy A", "Strategy B"), each = 5),
  stringsAsFactors = FALSE
)
plots <- list(
  cohort = plot_cohort_flow(data.frame(
    stage = c("Eligible", "Assigned", "Analyzed"), n = c(500, 480, 470)
  )),
  missingness = plot_missingness(data.frame(
    variable = c("age", "score"), missing_fraction = c(.02, .12)
  )),
  ps = plot_propensity_score_distribution(ps),
  weights = plot_weight_distribution(weights),
  love = plot_love(data.frame(
    variable = c("age", "score"), smd_unweighted = c(.22, -.16),
    smd_weighted = c(.04, -.06)
  )),
  balance = plot_standardized_balance(data.frame(
    variable = rep(c("age", "score"), 2),
    smd = c(.22, -.16, .04, -.06),
    stage = rep(c("Unweighted", "Weighted"), each = 2)
  )),
  difference_forest = difference_plot,
  ratio_forest = ratio_plot,
  survival = plot_survival_risk(curve, "survival"),
  risk = plot_survival_risk(transform(curve, estimate = 1 - estimate,
                                      ci_lower = 1 - ci_upper,
                                      ci_upper = 1 - ci_lower), "risk"),
  cumulative_incidence = plot_cumulative_incidence(transform(
    curve, estimate = 1 - estimate, ci_lower = 1 - ci_upper,
    ci_upper = 1 - ci_lower
  )),
  sensitivity = plot_sensitivity_forest(
    transform(forest_ratio, analysis = label), effect_scale = "ratio"
  ),
  ccw = plot_ccw_strategy_schematic(expand.grid(
    strategy = c("Initiate", "Do not initiate"), period = 0:3,
    stringsAsFactors = FALSE
  ) |> transform(status = ifelse(period == 0, "Grace", "Follow-up"))),
  lmtp = plot_lmtp_policy(data.frame(
    time = 0:4, observed = c(.2, .3, .5, .6, .7),
    policy = c(.3, .4, .6, .7, .8)
  ))
)
stopifnot(length(plots) == 14L, all(vapply(plots, inherits, logical(1), "ggplot")))

tmp <- tempfile("publication_figure_test_")
dir.create(tmp, recursive = TRUE)
on.exit(unlink(tmp, recursive = TRUE, force = TRUE), add = TRUE)
exported <- export_publication_figure(
  ratio_plot, "synthetic_ratio_forest", output_dir = tmp, config = config,
  column = "single", height_mm = 80,
  vector_formats = c("pdf", "svg"), raster_formats = c("tiff", "png")
)
stopifnot(
  length(exported$files) == 4L,
  all(file.exists(exported$files)),
  all(file.info(exported$files)$size > 0),
  isTRUE(exported$qc$machine_checks_pass),
  isTRUE(exported$qc$vector_output),
  isTRUE(exported$qc$raster_output),
  !isTRUE(exported$qc$publication_ready),
  exported$qc$manual_review == "PENDING",
  all(c(
    "figure", "width_mm", "height_mm", "dpi", "minimum_font_pt",
    "vector_output", "clipping", "overlap", "grayscale_pass",
    "publication_ready", "manual_review"
  ) %in% names(exported$qc))
)

png_path <- exported$files[grepl("[.]png$", exported$files)]
dims <- png_dimensions(png_path)
expected_width <- round(85 / 25.4 * 600)
expected_height <- round(80 / 25.4 * 600)
stopifnot(
  abs(dims[["width"]] - expected_width) <= 1,
  abs(dims[["height"]] - expected_height) <= 1
)

expect_error(
  assert_publication_figures_ready(exported$qc_path, "synthetic_ratio_forest"),
  "human approval"
)
expect_error(
  record_figure_manual_review(
    exported$qc_path, "synthetic_ratio_forest", clipping = "PASS",
    overlap = "PASS", grayscale_pass = "PASS", decision = "APPROVED",
    reviewer = "", reviewed_at = "2026-08-09"
  ),
  "reviewer"
)
expect_error(
  record_figure_manual_review(
    exported$qc_path, "synthetic_ratio_forest", clipping = "PASS",
    overlap = "PASS", grayscale_pass = "FAIL", decision = "APPROVED",
    reviewer = "SYNTHETIC_TEST_REVIEWER", reviewed_at = "2026-08-09"
  ),
  "requires all"
)
reviewed <- record_figure_manual_review(
  exported$qc_path, "synthetic_ratio_forest", clipping = "PASS",
  overlap = "PASS", grayscale_pass = "PASS", decision = "APPROVED",
  reviewer = "SYNTHETIC_TEST_REVIEWER", reviewed_at = "2026-08-09",
  notes = "Synthetic gate exercise only"
)
stopifnot(isTRUE(reviewed$publication_ready))
assert_publication_figures_ready(exported$qc_path, "synthetic_ratio_forest")

# Regenerating a figure must invalidate the prior human approval.
regenerated <- export_publication_figure(
  ratio_plot, "synthetic_ratio_forest", output_dir = tmp, config = config,
  column = "single", height_mm = 80,
  vector_formats = "pdf", raster_formats = "png"
)
stopifnot(!isTRUE(regenerated$qc$publication_ready),
          regenerated$qc$manual_review == "PENDING")
expect_error(
  assert_publication_figures_ready(regenerated$qc_path, "synthetic_ratio_forest"),
  "human approval"
)

cat("PUBLICATION_FIGURE_SYNTHETIC_TEST=PASS FIGURE_TYPES=",
    length(plots), " EXPORTED_FORMATS=4\n", sep = "")
