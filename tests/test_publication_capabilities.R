# Structural/semantic tests use original SYNTHETIC_DEMONSTRATION_ONLY fixtures.
source("R/figures/publication_figures.R")
source("R/figures/publication_capabilities.R")
source("figure_gallery/publication_capability_fixtures.R")
expect_failure <- function(expr, pattern) {
  error <- try(eval.parent(substitute(expr)), silent = TRUE)
  stopifnot(inherits(error, "try-error"), grepl(pattern, as.character(error)))
}
d <- tte_publication_capability_fixtures()
stopifnot(attr(d, "fixture_status") == "SYNTHETIC_DEMONSTRATION_ONLY")
stopifnot(attr(d$nodes, "demonstration_type") == "GENERIC_PARTICIPANT_FLOW_DEMONSTRATION",
          d$nodes$n[d$nodes$id == "start"] == 620,
          d$nodes$n[d$nodes$id == "eligible"] == 480,
          sum(d$nodes$n[d$nodes$id %in% c("control", "treatment")]) == 480)
# Independent consistency checks for this tiny display fixture, not a CCW
# production validator or a selection of real-study censoring conventions.
check_toy_history <- function(clones, events, original) {
  stopifnot(!anyDuplicated(original$subject_id))
  for (i in seq_len(nrow(clones))) {
    clone <- clones[i, ]; source <- original[original$subject_id == clone$subject_id, ]
    marks <- events[events$clone_id == clone$clone_id, ]
    if (nrow(source) != 1L) stop("Missing original subject history")
    artificial <- marks$time[marks$event_type == "artificial_censor"]
    expected_end <- min(c(source$observed_end, artificial))
    if (clone$followup_end != expected_end) stop("Inconsistent original observation end")
    terminal <- marks[marks$event_type %in% c("natural_censor", "outcome", "competing_event"), ]
    if (clone$followup_end == source$observed_end) {
      if (nrow(terminal) != 1L || terminal$time != source$observed_end ||
          terminal$event_type != source$terminal_event) stop("Inconsistent original terminal event")
    } else if (nrow(terminal)) stop("Terminal event after artificial censor")
    treatment <- marks$time[marks$event_type == "treatment"]
    observed_treatment <- source$treatment_time[!is.na(source$treatment_time) &
      source$treatment_time <= clone$followup_end]
    if (!identical(treatment, observed_treatment)) stop("Inconsistent original treatment history")
    if (any(marks$time > clone$followup_end)) stop("Post-censor contribution")
  }
}
check_toy_history(d$clones, d$events, d$original_subjects)
check_toy_history(d$competing_clones, d$competing_events, d$original_subjects)
stopifnot(all(table(d$competing_clones$subject_id) == 2L))
bad_clones <- d$competing_clones; bad_clones$followup_end[1] <- 6
bad_history <- rbind(d$competing_events[d$competing_events$clone_id != "SYN_C1", ],
  data.frame(clone_id = "SYN_C1", time = 6, event_type = "natural_censor"))
expect_failure(check_toy_history(bad_clones, bad_history, d$original_subjects), "original observation end")
bad_history <- d$competing_events
bad_history$event_type[bad_history$clone_id == "SYN_C2" & bad_history$event_type == "outcome"] <- "natural_censor"
expect_failure(check_toy_history(d$competing_clones, bad_history, d$original_subjects), "original terminal event")
bad_history <- d$competing_events
bad_history$time[bad_history$clone_id == "SYN_C2" & bad_history$event_type == "treatment"] <- 1
expect_failure(check_toy_history(d$competing_clones, bad_history, d$original_subjects), "original treatment history")
flow <- plot_participant_flowchart(d$nodes, d$edges)
stopifnot(identical(attr(flow, "tte_flow_nodes"), d$nodes),
          identical(attr(flow, "tte_flow_edges"), d$edges))
flow_layers <- ggplot2::ggplot_build(flow)$data
stopifnot(nrow(flow_layers[[1]]) == nrow(d$edges), nrow(flow_layers[[2]]) == nrow(d$nodes),
          all(grepl("N =", flow_layers[[3]]$label)),
          any(grepl("Incomplete baseline", flow_layers[[3]]$label)))
bad_edges <- rbind(d$edges, data.frame(from = "control", to = "eligible"))
expect_failure(plot_participant_flowchart(d$nodes, bad_edges), "acyclic")

timeline <- plot_tte_ccw_timeline(d$clones, d$events)
layers <- ggplot2::ggplot_build(timeline)$data
stopifnot(identical(as.numeric(layers[[5]]$x), d$events$time),
          identical(as.numeric(layers[[3]]$x), d$clones$grace_end),
          length(unique(layers[[2]]$linetype)) == 2L,
          layers[[5]]$y[1] != layers[[5]]$y[2],
          attr(timeline, "tte_method_status") == "VISUALIZATION_ONLY")
bad_events <- d$events; bad_events$time[1] <- 40
expect_failure(plot_tte_ccw_timeline(d$clones, bad_events), "outside")
competing_layers <- ggplot2::ggplot_build(plot_tte_ccw_timeline(d$competing_clones, d$competing_events))$data
competing <- competing_layers[[5]]
stopifnot(setequal(unique(competing$shape), c(17, 4, 3, 18, 8)),
          identical(as.numeric(competing$x), d$competing_events$time),
          nrow(competing_layers[[4]]) == 0L)
# Regression: terminal symbols must not be overprinted by endpoint squares.
# An end with no supplied terminal event must still receive its square.
no_terminal <- d$competing_events[d$competing_events$clone_id != "SYN_C5", ]
unmarked <- ggplot2::ggplot_build(plot_tte_ccw_timeline(d$competing_clones, no_terminal))$data[[4]]
stopifnot(nrow(unmarked) == 1L, unmarked$x == 6)

publication <- plot_survival_risk_publication(d$survival, "survival", d$number_at_risk,
  effect_annotation = "Synthetic annotation supplied by caller")
stopifnot(identical(attr(publication, "tte_number_at_risk"), d$number_at_risk),
          identical(attr(publication, "tte_curve_plot")$data$estimate, d$survival$estimate))
risk_text <- ggplot2::ggplot_build(attr(publication, "tte_risk_plot"))$data[[1]]
stopifnot(setequal(risk_text$label, d$number_at_risk$n_at_risk),
          nrow(risk_text) == nrow(d$number_at_risk),
          all(risk_text$hjust[risk_text$x == min(d$survival$time)] == 0),
          all(risk_text$hjust[risk_text$x == max(d$survival$time)] == 1))
expect_failure(plot_survival_risk_publication(d$survival, "survival", d$number_at_risk[-1, ]), "every strategy")
expect_failure(plot_survival_risk_publication(d$survival), "Specify measure")
stopifnot(identical(attr(attr(publication, "tte_number_at_risk"), "risk_count_metadata"), d$risk_count_metadata),
          d$risk_count_metadata$unit == "original_subject", !d$risk_count_metadata$weighted,
          d$risk_count_metadata$timepoint == "immediately_before_t")
mass <- d$number_at_risk; mass$n_at_risk[1] <- 240.4
expect_failure(plot_survival_risk_publication(d$survival, "survival", mass), "Invalid risk-table counts")
for (curve in list(d$survival, d$risk)) {
  stopifnot(all(curve$estimate >= 0 & curve$estimate <= 1),
    all(curve$ci_lower >= 0 & curve$ci_upper <= 1),
    all(curve$ci_lower <= curve$estimate & curve$estimate <= curve$ci_upper))
}
for (strategy in unique(d$survival$strategy)) {
  s <- d$survival[d$survival$strategy == strategy, ]
  cif <- d$risk[d$risk$strategy == strategy, ]
  stopifnot(s$estimate[1] == 1, cif$estimate[1] == 0,
    all(diff(s$estimate) <= 0), all(diff(cif$estimate) >= 0),
    !isTRUE(all.equal(cif$estimate, 1 - s$estimate)))
}
for (i in seq_len(nrow(d$effect_annotations))) {
  e <- d$effect_annotations[i, ]
  curve <- if (e$measure == "survival") d$survival else d$risk
  at_horizon <- curve[curve$time == e$horizon, ]
  contrast <- at_horizon$estimate[at_horizon$strategy == "Treatment"] -
    at_horizon$estimate[at_horizon$strategy == "Control"]
  stopifnot(isTRUE(all.equal(contrast, e$estimate)), e$effect_scale == "difference",
    e$contrast == "Treatment - Control", e$confidence_level == .95,
    e$ci_lower <= e$estimate, e$ci_upper >= e$estimate)
}

difference <- plot_subgroup_forest(d$subgroup_difference, "difference")
ratio <- plot_subgroup_forest(d$subgroup_ratio, "ratio")
stopifnot(attr(difference, "tte_null_value") == 0, attr(ratio, "tte_null_value") == 1,
          identical(attr(difference, "tte_subgroup_data"), d$subgroup_difference),
          attr(difference, "tte_formatted_effects")[1] == "0.04 (-0.01, 0.09)")
components <- attr(difference, "tte_forest_components")
left <- ggplot2::ggplot_build(components$left)$data[[1]]
stopifnot(all(left$x[d$subgroup_difference$row_type == "category"] > 0),
          all(left$fontface[d$subgroup_difference$row_type == "header"] == "bold"))
right_layers <- ggplot2::ggplot_build(components$right)$data
interaction_labels <- unlist(lapply(right_layers, function(x) x$label[grepl("^P int", x$label)]))
stopifnot(setequal(interaction_labels, c("P int. = 0.43", "P int. = 0.31")))
wrong <- d$subgroup_difference; wrong$subgroup[3] <- "Different"
expect_failure(plot_subgroup_forest(wrong, "difference"), "matching subgroup")
expect_failure(compose_forest_panels(list(difference, ratio)), "explicit independent")
independent <- compose_forest_panels(list(difference, ratio), independent_x_scales = TRUE)
stopifnot(attr(independent, "tte_independent_x_scales"))
assembly <- compose_forest_panels(list(difference, difference))
stopifnot(identical(attr(assembly, "tte_row_structure"), attr(difference, "tte_row_structure")),
          identical(attr(assembly, "tte_shared_x_range"), attr(difference, "tte_forest_arguments")$x_limits))

outcomes <- compose_outcome_panels(list(publication,
  plot_survival_risk_publication(d$risk, "cumulative_incidence", d$number_at_risk)), align_x = TRUE)
stopifnot(identical(attr(outcomes, "tte_shared_x_range"), range(d$survival$time)),
          identical(attr(outcomes, "tte_panel_labels"), c("A", "B")))
panels <- attr(outcomes, "tte_outcome_panels")
stopifnot(identical(panels[[1]]$scales$get_scales("colour")$palette(2),
                    panels[[2]]$scales$get_scales("colour")$palette(2)))
# Match plotting rectangles across curve/table columns and forest text/CI rows.
aligned_curve <- tte_align_plot_grobs(list(attr(publication, "tte_curve_plot"),
  attr(publication, "tte_risk_plot")), "widths")
stopifnot(identical(aligned_curve[[1]]$widths, aligned_curve[[2]]$widths))
aligned_forest <- tte_align_plot_grobs(components, "heights")
stopifnot(identical(aligned_forest[[1]]$heights, aligned_forest[[2]]$heights),
          identical(aligned_forest[[2]]$heights, aligned_forest[[3]]$heights))
expect_failure(compose_outcome_panels(list(publication, publication), labels = c("A", "A")), "unique labels")
objects <- tte_publication_capability_plots("single")
stopifnot(length(objects) == 9L)
stopifnot(grepl("Not a CCW clone flow", objects$participant_flowchart$labels$caption),
  grepl("survival difference at t=12", attr(objects$survival_risk_table, "tte_effect_annotation")),
  grepl("CIF difference at t=12", attr(objects$cumulative_incidence_risk_table, "tte_effect_annotation")))
demo_panels <- attr(objects$multi_panel_outcomes, "tte_outcome_panels")
stopifnot(identical(vapply(demo_panels, function(p) max(p$data$time), numeric(1)), c(12, 12, 30, 60)),
  identical(demo_panels[[3]]$data$estimate, d$survival$estimate),
  identical(demo_panels[[4]]$data$estimate, d$survival$estimate),
  all(vapply(demo_panels, function(p) p$labels$x == "Toy time units", logical(1))))
cat("PUBLICATION_SEMANTIC_ASSERTIONS=PASS FLOW=GENERIC SUBJECT_HISTORY=COHERENT COUNTS=EXPLICIT ANNOTATIONS=CONSISTENT\n")
config <- read_figure_config("config_templates/figure_config.yml")
temporary <- tempfile("tte_capability_export_")
exported <- export_publication_figure(publication, "synthetic_composite", temporary, config)
stopifnot(length(exported$files) == 4L, all(file.info(exported$files)$size > 0),
          exported$qc$machine_checks_pass, !exported$qc$publication_ready,
          exported$qc$manual_review == "PENDING")
cat("PUBLICATION_CAPABILITY_TEST=PASS CASES=9 RISK_COUNTS=CALLER_SUPPLIED NULL_VALUES=0_AND_1\n")
