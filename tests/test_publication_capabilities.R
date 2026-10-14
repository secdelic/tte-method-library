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
competing <- ggplot2::ggplot_build(plot_tte_ccw_timeline(d$competing_clones, d$competing_events))$data[[5]]
stopifnot(setequal(unique(competing$shape), c(3, 18, 8)))

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

difference <- plot_subgroup_forest(d$subgroup_difference, "difference")
ratio <- plot_subgroup_forest(d$subgroup_ratio, "ratio")
stopifnot(attr(difference, "tte_null_value") == 0, attr(ratio, "tte_null_value") == 1,
          identical(attr(difference, "tte_subgroup_data"), d$subgroup_difference),
          attr(difference, "tte_formatted_effects")[1] == "0.04 (-0.01, 0.09)")
components <- attr(difference, "tte_forest_components")
left <- ggplot2::ggplot_build(components$left)$data[[1]]
stopifnot(all(left$x[d$subgroup_difference$row_type == "category"] > 0),
          all(left$fontface[d$subgroup_difference$row_type == "header"] == "bold"))
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
config <- read_figure_config("config_templates/figure_config.yml")
temporary <- tempfile("tte_capability_export_")
exported <- export_publication_figure(publication, "synthetic_composite", temporary, config)
stopifnot(length(exported$files) == 4L, all(file.info(exported$files)$size > 0),
          exported$qc$machine_checks_pass, !exported$qc$publication_ready,
          exported$qc$manual_review == "PENDING")
cat("PUBLICATION_CAPABILITY_TEST=PASS CASES=9 RISK_COUNTS=CALLER_SUPPLIED NULL_VALUES=0_AND_1\n")
