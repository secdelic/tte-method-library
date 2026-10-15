# Unchanged synthetic fixtures and constructor calls from the v1.0.0 native gallery.
# Fixtures match tests/test_publication_figures.R; seed is fixed at 20260809.
tte_native_fixture_plots <- function() {
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
  figure_01_cohort_flow = plot_cohort_flow(data.frame(
    stage = c("Eligible", "Assigned", "Analyzed"),
    n = c(500, 480, 470)
  )),
  figure_02_missingness = plot_missingness(data.frame(
    variable = c("age", "score"), missing_fraction = c(.02, .12)
  )),
  figure_03_propensity_score_distribution =
    plot_propensity_score_distribution(ps),
  figure_04_weight_distribution = plot_weight_distribution(weights),
  figure_05_love_plot = plot_love(data.frame(
    variable = c("age", "score"),
    smd_unweighted = c(.22, -.16),
    smd_weighted = c(.04, -.06)
  )),
  figure_06_standardized_balance = plot_standardized_balance(data.frame(
    variable = rep(c("age", "score"), 2),
    smd = c(.22, -.16, .04, -.06),
    stage = rep(c("Unweighted", "Weighted"), each = 2)
  )),
  figure_07_difference_forest = plot_forest(
    forest_difference, effect_scale = "difference"
  ),
  figure_08_ratio_forest = plot_forest(
    forest_ratio, effect_scale = "ratio"
  ),
  figure_09_survival_curve = plot_survival_risk(curve, "survival"),
  figure_10_risk_curve = plot_survival_risk(
    transform(curve, estimate = 1 - estimate,
              ci_lower = 1 - ci_upper, ci_upper = 1 - ci_lower),
    "risk"
  ),
  figure_11_cumulative_incidence = plot_cumulative_incidence(transform(
    curve, estimate = 1 - estimate,
    ci_lower = 1 - ci_upper, ci_upper = 1 - ci_lower
  )),
  figure_12_sensitivity_forest = plot_sensitivity_forest(
    transform(forest_ratio, analysis = label), effect_scale = "ratio"
  ),
  figure_13_ccw_strategy_schematic = plot_ccw_strategy_schematic(
    expand.grid(
      strategy = c("Initiate", "Do not initiate"), period = 0:3,
      stringsAsFactors = FALSE
    ) |>
      transform(status = ifelse(period == 0, "Grace", "Follow-up"))
  ),
  figure_14_lmtp_policy_plot = plot_lmtp_policy(data.frame(
    time = 0:4,
    observed = c(.2, .3, .5, .6, .7),
    policy = c(.3, .4, .6, .7, .8)
  ))
)

  plots
}
