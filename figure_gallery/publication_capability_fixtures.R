# Original generic fixtures. No patient data or benchmark result values.
# SYNTHETIC_DEMONSTRATION_ONLY; no estimator is run to create these curves.
tte_publication_capability_fixtures <- function() {
  nodes <- data.frame(
    id = c("start", "eligible", "excluded", "control", "treatment"),
    label = c("Starting population", "Remaining eligible", "Excluded", "Control analysis", "Treatment analysis"),
    n = c(620, 480, 140, 240, 240),
    kind = c("start", "inclusion", "exclusion", "analysis", "analysis"),
    reason = c("", "Criteria satisfied", "Incomplete baseline", "", ""))
  edges <- data.frame(from = c("start", "start", "eligible", "eligible"),
    to = c("eligible", "excluded", "control", "treatment"))
  clones <- data.frame(subject_id = rep(c("SYN_S1", "SYN_S2"), each = 2),
    clone_id = paste0("SYN_C", 1:4), strategy = rep(c("Control", "Treatment"), 2),
    followup_start = 0, followup_end = c(2, 8, 9, 3), grace_end = 3,
    display_label = c("S1 / C1 / Control", "S1 / C2 / Treatment", "S2 / C3 / Control", "S2 / C4 / Treatment"))
  events <- data.frame(clone_id = c("SYN_C1", "SYN_C1", "SYN_C2", "SYN_C2", "SYN_C3", "SYN_C4"),
    time = c(2, 2, 2, 8, 9, 3),
    event_type = c("treatment", "artificial_censor", "treatment", "outcome", "competing_event", "artificial_censor"))
  competing_clones <- clones
  competing_clones$followup_end <- c(6, 8, 9, 7)
  competing_events <- data.frame(clone_id = clones$clone_id, time = c(6, 8, 9, 7),
    event_type = c("natural_censor", "outcome", "competing_event", "natural_censor"))
  curve <- data.frame(time = rep(seq(0, 12, 3), 2),
    estimate = c(1, .97, .92, .86, .79, 1, .98, .95, .90, .85),
    strategy = rep(c("Control", "Treatment"), each = 5))
  curve$ci_lower <- pmax(0, curve$estimate - .035)
  curve$ci_upper <- pmin(1, curve$estimate + .035)
  # Supplied CIF toy values are independent of the survival example: a
  # competing-risk CIF must not be demonstrated as 1 - Kaplan-Meier.
  risk <- data.frame(time = rep(seq(0, 12, 3), 2),
    estimate = c(0, .02, .06, .10, .15, 0, .015, .04, .07, .11),
    strategy = rep(c("Control", "Treatment"), each = 5))
  risk$ci_lower <- pmax(0, risk$estimate - .025)
  risk$ci_upper <- pmin(1, risk$estimate + .025)
  risk_table <- data.frame(strategy = rep(c("Control", "Treatment"), each = 5),
    time = rep(seq(0, 12, 3), 2), n_at_risk = c(240, 225, 208, 185, 160, 240, 231, 215, 198, 178))
  subgroup <- data.frame(
    subgroup = c("Overall", "Tier", "Tier", "Tier", "Band", "Band", "Band"),
    label = c("Overall", "Eligibility tier", "Lower", "Higher", "Baseline band", "Band 1", "Band 2"),
    row_type = c("overall", "header", "category", "category", "header", "category", "category"),
    estimate = c(.04, NA, .02, .06, NA, .01, .07),
    ci_lower = c(-.01, NA, -.04, .01, NA, -.05, .02),
    ci_upper = c(.09, NA, .08, .11, NA, .07, .12),
    n = c(480, NA, 220, 260, NA, 230, 250),
    p_interaction = c(NA, .43, NA, NA, .31, NA, NA))
  ratio <- subgroup
  # Independently supplied ratio examples, not a conversion from differences.
  ratio$estimate <- c(.93, NA, .91, .97, NA, .90, 1.00)
  ratio$ci_lower <- c(.84, NA, .81, .86, NA, .80, .89)
  ratio$ci_upper <- c(1.04, NA, 1.03, 1.09, NA, 1.02, 1.13)
  result <- list(nodes = nodes, edges = edges, clones = clones, events = events,
    competing_clones = competing_clones, competing_events = competing_events,
    survival = curve, risk = risk, number_at_risk = risk_table,
    subgroup_difference = subgroup, subgroup_ratio = ratio)
  attr(result, "fixture_status") <- "SYNTHETIC_DEMONSTRATION_ONLY"
  result
}

tte_publication_capability_plots <- function(column = c("single", "double")) {
  column <- match.arg(column)
  d <- tte_publication_capability_fixtures()
  survival <- plot_survival_risk_publication(d$survival, "survival", d$number_at_risk,
    effect_annotation = "Synthetic supplied difference: 0.06 (95% CI 0.01 to 0.11)")
  incidence <- plot_survival_risk_publication(d$risk, "cumulative_incidence", d$number_at_risk,
    effect_annotation = "Synthetic supplied difference: -0.04 (95% CI -0.09 to 0.01)")
  panels <- list(incidence, survival)
  for (horizon in c(30, 60)) {
    curve <- d$survival
    risk_table <- d$number_at_risk
    curve$time <- curve$time * horizon / 12
    risk_table$time <- risk_table$time * horizon / 12
    panels[[length(panels) + 1L]] <- plot_survival_risk_publication(curve, "survival", risk_table,
      time_breaks = c(0, horizon / 2, horizon))
  }
  # Fixed display breaks are caller-supplied, not inferred from curve images.
  panels[[1]] <- plot_survival_risk_publication(d$risk, "cumulative_incidence", d$number_at_risk,
    time_breaks = c(0, 6, 12))
  panels[[2]] <- plot_survival_risk_publication(d$survival, "survival", d$number_at_risk,
    time_breaks = c(0, 6, 12))
  forest1 <- plot_subgroup_forest(d$subgroup_difference, "difference", alternating_rows = TRUE)
  other <- d$subgroup_difference
  other$estimate <- other$estimate + .015
  other$ci_lower <- other$ci_lower + .015
  other$ci_upper <- other$ci_upper + .015
  forest2 <- plot_subgroup_forest(other, "difference", alternating_rows = TRUE)
  list(
    participant_flowchart = plot_participant_flowchart(d$nodes, d$edges),
    research_ccw_timeline = plot_tte_ccw_timeline(d$clones, d$events,
      research_steps = c("Prepared cohort", "Clone and assign", "Grace period", "Assess adherence", "Censor or follow-up")),
    competing_event_timeline = plot_tte_ccw_timeline(d$competing_clones, d$competing_events),
    cumulative_incidence_risk_table = incidence,
    survival_risk_table = survival,
    subgroup_difference_forest = forest1,
    subgroup_ratio_forest = plot_subgroup_forest(d$subgroup_ratio, "ratio", alternating_rows = TRUE),
    multi_panel_outcomes = compose_outcome_panels(panels, ncol = 2),
    multi_panel_forests = compose_forest_panels(list(forest1, forest2),
      ncol = if (column == "single") 1 else 2))
}
