# Publication visualization utilities. All estimates, events, counts and
# annotations are supplied by the caller. No estimator or scientific decision
# is implemented here. Synthetic examples are SYNTHETIC_DEMONSTRATION_ONLY.

tte_publication_matrix <- function(grobs, ncol, widths = NULL, heights = NULL, gap_mm = 0) {
  if (!length(grobs) || length(ncol) != 1L || ncol < 1 || ncol != as.integer(ncol)) {
    stop("Provide nonempty grobs and a positive integer ncol")
  }
  nrow <- ceiling(length(grobs) / ncol)
  grobs <- c(grobs, rep(list(grid::nullGrob()), nrow * ncol - length(grobs)))
  if (is.null(widths)) widths <- rep(1, ncol)
  if (is.null(heights)) heights <- rep(1, nrow)
  result <- gtable::gtable_matrix("tte_publication",
    grobs = matrix(grobs, nrow = nrow, ncol = ncol, byrow = TRUE),
    widths = grid::unit(widths, "null"), heights = grid::unit(heights, "null"),
    clip = "off")
  class(result) <- c("tte_publication_figure", class(result))
  if (gap_mm > 0 && ncol > 1L) {
    for (position in rev(seq_len(ncol - 1L))) {
      result <- gtable::gtable_add_cols(result, grid::unit(gap_mm, "mm"), pos = position)
    }
  }
  result
}

tte_align_plot_grobs <- function(plots, dimension = c("widths", "heights")) {
  dimension <- match.arg(dimension)
  grobs <- lapply(plots, ggplot2::ggplotGrob)
  if (length(unique(vapply(grobs, function(g) length(g[[dimension]]), integer(1)))) != 1L) {
    stop("Panel layout structures differ; use matching native plot components")
  }
  common <- do.call(grid::unit.pmax, lapply(grobs, `[[`, dimension))
  lapply(grobs, function(g) { g[[dimension]] <- common; g })
}

tte_publication_legend <- function(plot) {
  g <- ggplot2::ggplotGrob(plot)
  indices <- grep("^guide-box", g$layout$name)
  indices <- indices[!vapply(g$grobs[indices], inherits, logical(1), "zeroGrob")]
  if (length(indices)) g$grobs[[indices[[1]]]] else grid::nullGrob()
}

tte_publication_vertical <- function(grobs, body_heights, legend = NULL) {
  result <- tte_publication_matrix(grobs, 1, heights = body_heights)
  if (!is.null(legend) && !inherits(legend, "null")) {
    result <- gtable::gtable_add_rows(result, grid::grobHeight(legend))
    result <- gtable::gtable_add_grob(result, legend, t = nrow(result), l = 1,
                                       clip = "off", name = "shared_legend")
  }
  class(result) <- unique(c("tte_publication_figure", class(result)))
  result
}

plot_participant_flowchart <- function(nodes, edges, base_size = 8) {
  tte_figure_columns(nodes, c("id", "label", "n", "kind"), "Flowchart nodes")
  tte_figure_columns(edges, c("from", "to"), "Flowchart edges")
  tte_finite_numeric(nodes$n, "Participant counts")
  if (!nrow(nodes) || any(nodes$n < 0 | nodes$n != floor(nodes$n)) ||
      anyNA(nodes$id) || anyDuplicated(nodes$id)) stop("Nodes require unique IDs and nonnegative integer counts")
  if (!all(nodes$kind %in% c("start", "inclusion", "exclusion", "analysis"))) {
    stop("Node kind must be start, inclusion, exclusion or analysis")
  }
  if (any(!edges$from %in% nodes$id) || any(!edges$to %in% nodes$id) ||
      any(edges$from == edges$to) || anyDuplicated(edges)) stop("Invalid flowchart edges")
  starts <- which(nodes$kind == "start")
  if (length(starts) != 1L || !any(nodes$kind == "analysis") ||
      nodes$id[starts] %in% edges$to) stop("Provide one starting population and final analysis node(s)")
  depth <- stats::setNames(rep(NA_integer_, nrow(nodes)), nodes$id)
  depth[starts] <- 0L
  while (anyNA(depth)) {
    unresolved <- names(depth)[is.na(depth)]
    ready <- unresolved[vapply(unresolved, function(id) {
      parents <- edges$from[edges$to == id]
      length(parents) > 0L && all(!is.na(depth[parents]))
    }, logical(1))]
    if (!length(ready)) stop("Flowchart must be acyclic and connected to the starting population")
    for (id in ready) depth[id] <- max(depth[edges$from[edges$to == id]]) + 1L
  }
  layout <- nodes
  layout$y <- -unname(depth) * 1.7
  layout$x <- ave(seq_len(nrow(nodes)), depth, FUN = function(x) {
    (seq_along(x) - (length(x) + 1) / 2) * 3
  })
  reason <- if ("reason" %in% names(nodes)) as.character(nodes$reason) else rep("", nrow(nodes))
  reason[is.na(reason)] <- ""
  layout$text <- vapply(seq_len(nrow(nodes)), function(i) paste(
    c(paste(strwrap(as.character(nodes$label[i]), width = 22), collapse = "\n"),
      paste0("N = ", format(nodes$n[i], scientific = FALSE, trim = TRUE)),
      if (nzchar(reason[i])) paste(strwrap(reason[i], width = 22), collapse = "\n")),
    collapse = "\n"), character(1))
  connectors <- data.frame(
    x = layout$x[match(edges$from, nodes$id)],
    y = layout$y[match(edges$from, nodes$id)] - .55,
    xend = layout$x[match(edges$to, nodes$id)],
    yend = layout$y[match(edges$to, nodes$id)] + .55)
  p <- ggplot2::ggplot(layout) +
    ggplot2::geom_segment(data = connectors, ggplot2::aes(x = x, y = y, xend = xend, yend = yend),
      linewidth = .45 / ggplot2::.pt, colour = tte_sci_colors()$control,
      arrow = grid::arrow(length = grid::unit(2, "mm"))) +
    ggplot2::geom_rect(ggplot2::aes(xmin = x - 1.35, xmax = x + 1.35,
      ymin = y - .55, ymax = y + .55), fill = "#EEF2F5", colour = "#687780",
      linewidth = .45 / ggplot2::.pt) +
    ggplot2::geom_text(ggplot2::aes(x = x, y = y, label = text),
      size = base_size / ggplot2::.pt, colour = tte_sci_colors()$text, lineheight = .95) +
    ggplot2::coord_cartesian(xlim = range(layout$x) + c(-1.6, 1.6),
      ylim = range(layout$y) + c(-.75, .75), clip = "off") +
    tte_theme_publication(base_size) +
    ggplot2::theme(axis.line = ggplot2::element_blank(), axis.text = ggplot2::element_blank(),
      axis.ticks = ggplot2::element_blank(), axis.title = ggplot2::element_blank(),
      panel.grid = ggplot2::element_blank(), panel.grid.major.y = ggplot2::element_blank())
  attr(p, "tte_flow_nodes") <- nodes
  attr(p, "tte_flow_edges") <- edges
  p
}

tte_research_steps <- function(steps, base_size) {
  if (!is.character(steps) || !length(steps) || anyNA(steps) || any(!nzchar(steps))) {
    stop("research_steps must contain caller-supplied nonempty stage labels")
  }
  d <- data.frame(x = seq_along(steps), label = vapply(steps,
    function(s) paste(strwrap(s, width = 12), collapse = "\n"), character(1)))
  ggplot2::ggplot(d, ggplot2::aes(x = x, y = 0)) +
    ggplot2::geom_segment(data = head(d, -1), ggplot2::aes(xend = x + .55, yend = 0),
      linewidth = .45 / ggplot2::.pt, colour = tte_sci_colors()$control,
      arrow = grid::arrow(length = grid::unit(1.5, "mm"))) +
    ggplot2::geom_tile(width = .86, height = 1.4, fill = "#EEF2F5", colour = "#687780",
      linewidth = .45 / ggplot2::.pt) +
    ggplot2::geom_text(ggplot2::aes(label = label), size = base_size / ggplot2::.pt,
      colour = tte_sci_colors()$text, lineheight = .95) +
    ggplot2::coord_cartesian(ylim = c(-.9, .9), clip = "off") +
    tte_theme_publication(base_size) +
    ggplot2::theme(axis.line = ggplot2::element_blank(), axis.text = ggplot2::element_blank(),
      axis.ticks = ggplot2::element_blank(), axis.title = ggplot2::element_blank(),
      panel.grid = ggplot2::element_blank(), panel.grid.major.y = ggplot2::element_blank(),
      plot.margin = ggplot2::margin(2, 2, 2, 2))
}

plot_tte_ccw_timeline <- function(clones, events, base_size = 8, research_steps = NULL,
                                 time_label = "Follow-up time") {
  tte_figure_columns(clones, c("subject_id", "clone_id", "strategy", "followup_start",
    "followup_end", "grace_end"), "Clone timeline")
  tte_figure_columns(events, c("clone_id", "time", "event_type"), "Timeline events")
  if (!nrow(clones) || anyNA(clones$clone_id) || anyDuplicated(clones$clone_id)) {
    stop("Timeline requires unique clone identifiers")
  }
  for (name in c("followup_start", "followup_end", "grace_end")) tte_finite_numeric(clones[[name]], name)
  if (any(clones$followup_start > clones$followup_end) ||
      any(clones$grace_end < clones$followup_start)) stop("Invalid follow-up/grace boundaries")
  tte_finite_numeric(events$time, "Event time")
  kinds <- c("treatment", "artificial_censor", "natural_censor", "outcome", "competing_event")
  if (any(!events$clone_id %in% clones$clone_id) || any(!events$event_type %in% kinds)) {
    stop("Unknown clone or event type")
  }
  i <- match(events$clone_id, clones$clone_id)
  if (any(events$time < clones$followup_start[i] | events$time > clones$followup_end[i])) {
    stop("An event lies outside its caller-supplied clone follow-up")
  }
  lanes <- clones
  lanes$row <- rev(seq_len(nrow(clones)))
  lanes$display_label <- paste(clones$subject_id, clones$clone_id, clones$strategy, sep = " | ")
  if ("display_label" %in% names(clones)) {
    if (anyNA(clones$display_label) || any(!nzchar(clones$display_label))) stop("Display labels must be nonempty")
    lanes$display_label <- as.character(clones$display_label)
  }
  marks <- events
  marks$row <- lanes$row[i]
  if (nrow(marks)) {
    keys <- paste(marks$clone_id, sprintf("%.17g", marks$time), sep = ":")
    marks$row <- marks$row + ave(seq_len(nrow(marks)), keys, FUN = function(x) {
      if (length(x) == 1L) 0 else seq(-.14, .14, length.out = length(x))
    })
  }
  p <- ggplot2::ggplot(lanes) +
    ggplot2::geom_rect(ggplot2::aes(xmin = followup_start, xmax = pmin(grace_end, followup_end),
      ymin = row - .35, ymax = row + .35), fill = tte_sci_colors()$caution, alpha = .16) +
    ggplot2::geom_segment(ggplot2::aes(x = followup_start, xend = followup_end,
      y = row, yend = row, colour = strategy, linetype = strategy), linewidth = .7) +
    ggplot2::geom_segment(ggplot2::aes(x = grace_end, xend = grace_end,
      y = row - .35, yend = row + .35), colour = tte_sci_colors()$control,
      linetype = 2, linewidth = .4) +
    ggplot2::geom_point(ggplot2::aes(x = followup_end, y = row),
      shape = 0, size = 2, colour = tte_sci_colors()$control) +
    ggplot2::geom_point(data = marks, ggplot2::aes(x = time, y = row, shape = event_type),
      size = 2.3, colour = tte_sci_colors()$text) +
    ggplot2::scale_shape_manual(values = stats::setNames(c(17, 4, 3, 18, 8), kinds),
      breaks = kinds, labels = c("Treatment", "Artificial censor", "Natural censor", "Outcome", "Competing event")) +
    ggplot2::scale_colour_manual(values = tte_sci_group_colors(clones$strategy)) +
    ggplot2::scale_y_continuous(breaks = lanes$row, labels = lanes$display_label) +
    ggplot2::labs(x = time_label, y = NULL,
      colour = "Assigned strategy", linetype = "Assigned strategy", shape = "Event") +
    ggplot2::guides(shape = ggplot2::guide_legend(ncol = 2, order = 2),
      colour = ggplot2::guide_legend(order = 1), linetype = ggplot2::guide_legend(order = 1)) +
    tte_theme_publication(base_size) +
    ggplot2::theme(panel.grid = ggplot2::element_blank(), panel.grid.major.y = ggplot2::element_blank(),
      legend.box = "vertical", legend.spacing.y = grid::unit(1, "mm"))
  attr(p, "tte_clone_data") <- clones
  attr(p, "tte_event_data") <- events
  attr(p, "tte_grace_boundaries") <- clones$grace_end
  attr(p, "tte_method_status") <- "VISUALIZATION_ONLY"
  if (is.null(research_steps)) return(p)
  result <- tte_publication_matrix(list(ggplot2::ggplotGrob(tte_research_steps(research_steps, base_size)),
    ggplot2::ggplotGrob(p)), 1, heights = c(1, 5))
  attr(result, "tte_timeline_plot") <- p
  attr(result, "tte_research_steps") <- research_steps
  attr(result, "tte_method_status") <- "VISUALIZATION_ONLY"
  result
}

tte_curve_publication_grob <- function(curve, risk_table = NULL, base_size = 8,
                                       include_legend = TRUE) {
  legend <- if (include_legend) tte_publication_legend(curve) else NULL
  stripped <- curve + ggplot2::theme(legend.position = "none")
  if (is.null(risk_table)) {
    result <- tte_publication_vertical(list(ggplot2::ggplotGrob(stripped)), 1, legend)
  } else {
    grobs <- tte_align_plot_grobs(list(stripped, risk_table), "widths")
    result <- tte_publication_vertical(grobs, c(4, 1.2), legend)
  }
  attr(result, "tte_curve_plot") <- curve
  attr(result, "tte_risk_plot") <- risk_table
  attr(result, "tte_base_size") <- base_size
  result
}

plot_survival_risk_publication <- function(data, measure, number_at_risk = NULL,
    time_breaks = sort(unique(data$time)), effect_annotation = NULL, base_size = 8,
    time_label = "Follow-up time") {
  if (missing(measure) || !measure %in% c("survival", "risk", "cumulative_incidence")) {
    stop("Specify measure as survival, risk or cumulative_incidence")
  }
  tte_figure_columns(data, c("time", "estimate", "strategy"), "Publication curve")
  tte_finite_numeric(time_breaks, "Time breaks")
  if (!length(time_breaks) || anyDuplicated(time_breaks) || is.unsorted(time_breaks, strictly = TRUE)) {
    stop("Time breaks must be unique and increasing")
  }
  if (anyDuplicated(data[c("strategy", "time")])) stop("Curve contains duplicate strategy/time rows")
  curve <- if (measure == "cumulative_incidence") plot_cumulative_incidence(data, base_size) else
    plot_survival_risk(data, measure, base_size)
  if (any(time_breaks < min(data$time) | time_breaks > max(data$time))) {
    stop("Time breaks must lie within the supplied curve range")
  }
  curve <- curve + ggplot2::scale_x_continuous(breaks = time_breaks,
    limits = range(data$time), expand = ggplot2::expansion(mult = .02)) +
    ggplot2::labs(x = time_label)
  if (!is.null(effect_annotation)) {
    if (!is.character(effect_annotation) || length(effect_annotation) != 1L || is.na(effect_annotation)) {
      stop("effect_annotation must be caller-supplied text")
    }
    curve <- curve + ggplot2::labs(caption = paste(strwrap(effect_annotation, width = 52), collapse = "\n")) +
      ggplot2::theme(plot.caption = ggplot2::element_text(size = base_size,
        colour = tte_sci_colors()$text, hjust = 0))
  }
  table_plot <- NULL
  if (!is.null(number_at_risk)) {
    tte_figure_columns(number_at_risk, c("strategy", "time", "n_at_risk"), "Number-at-risk table")
    tte_finite_numeric(number_at_risk$time, "Risk-table time")
    tte_finite_numeric(number_at_risk$n_at_risk, "Number at risk")
    if (any(number_at_risk$n_at_risk < 0 | number_at_risk$n_at_risk != floor(number_at_risk$n_at_risk)) ||
        anyDuplicated(number_at_risk[c("strategy", "time")])) stop("Invalid risk-table counts or duplicate keys")
    groups <- names(tte_sci_group_colors(data$strategy))
    shown <- number_at_risk[number_at_risk$time %in% time_breaks, , drop = FALSE]
    expected <- expand.grid(strategy = groups, time = time_breaks, stringsAsFactors = FALSE)
    key <- function(d) paste(d$strategy, d$time, sep = "|")
    if (!setequal(key(shown), key(expected))) stop("Risk table must supply every strategy/time-break combination")
    shown$strategy <- factor(shown$strategy, levels = rev(groups))
    shown$hjust <- ifelse(shown$time == min(data$time), 0,
      ifelse(shown$time == max(data$time), 1, .5))
    table_plot <- ggplot2::ggplot(shown, ggplot2::aes(x = time, y = strategy, label = n_at_risk)) +
      ggplot2::geom_text(ggplot2::aes(hjust = hjust), size = base_size / ggplot2::.pt,
        colour = tte_sci_colors()$text) +
      ggplot2::scale_x_continuous(breaks = time_breaks, limits = range(data$time),
        expand = ggplot2::expansion(mult = .02)) +
      ggplot2::labs(x = time_label, y = NULL, title = "Number at risk") +
      tte_theme_publication(base_size) +
      ggplot2::theme(panel.grid = ggplot2::element_blank(), panel.grid.major.y = ggplot2::element_blank(),
        axis.line.y = ggplot2::element_blank(),
        axis.ticks.y = ggplot2::element_blank(),
        axis.text.y = ggplot2::element_text(margin = ggplot2::margin(r = 4)),
        plot.title = ggplot2::element_text(size = base_size))
  }
  result <- tte_curve_publication_grob(curve, table_plot, base_size)
  attr(result, "tte_number_at_risk") <- number_at_risk
  attr(result, "tte_time_breaks") <- time_breaks
  attr(result, "tte_effect_annotation") <- effect_annotation
  attr(result, "tte_measure") <- measure
  result
}

compose_outcome_panels <- function(panels, ncol = 2, labels = LETTERS[seq_along(panels)],
                                   align_x = FALSE, base_size = 8) {
  tte_theme_publication(base_size)
  if (!length(panels) || length(labels) != length(panels) || anyNA(labels) || anyDuplicated(labels)) stop("Supply panels and unique labels")
  curves <- lapply(panels, function(p) {
    if (inherits(p, "ggplot")) p else attr(p, "tte_curve_plot")
  })
  if (any(vapply(curves, is.null, logical(1)))) stop("Outcome panels must be ggplots or native publication curve wrappers")
  groups <- sort(unique(unlist(lapply(curves, function(p) as.character(p$data$strategy)))))
  colors <- tte_sci_group_colors(groups)
  common_range <- if (align_x) range(unlist(lapply(curves, function(p) p$data$time))) else NULL
  bodies <- lapply(seq_along(panels), function(i) {
    p <- curves[[i]] + tte_theme_publication(base_size) +
      ggplot2::theme(plot.caption = ggplot2::element_text(size = base_size,
        colour = tte_sci_colors()$text, hjust = 0))
    if (!is.null(p$labels$caption)) {
      p <- p + ggplot2::labs(caption = paste(strwrap(gsub("\n", " ", p$labels$caption),
        width = max(24, floor(52 / ncol))), collapse = "\n"))
    }
    if (length(groups) && "strategy" %in% names(p$data)) {
      p <- p + ggplot2::scale_colour_manual(values = colors, limits = groups, drop = FALSE) +
        ggplot2::scale_fill_manual(values = colors, limits = groups, drop = FALSE) +
        ggplot2::scale_linetype_manual(values = stats::setNames(rep(c("solid", "dashed", "dotdash", "longdash", "twodash", "dotted"), length.out = length(groups)), groups),
          limits = groups, drop = FALSE)
    }
    if (align_x) {
      if (!"time" %in% names(p$data)) stop("align_x requires explicit time data in every panel")
      p <- p + ggplot2::coord_cartesian(xlim = common_range,
        ylim = p$coordinates$limits$y, expand = FALSE)
    }
    curves[[i]] <<- p
    risk_plot <- attr(panels[[i]], "tte_risk_plot")
    if (!is.null(risk_plot)) {
      risk_plot <- risk_plot + tte_theme_publication(base_size) +
        ggplot2::theme(panel.grid = ggplot2::element_blank(), panel.grid.major.y = ggplot2::element_blank(),
          axis.line.y = ggplot2::element_blank(), axis.ticks.y = ggplot2::element_blank(),
          axis.text.y = ggplot2::element_text(margin = ggplot2::margin(r = 4)),
          plot.title = ggplot2::element_text(size = base_size))
      risk_plot$layers[[1]]$aes_params$size <- base_size / ggplot2::.pt
    }
    if (align_x && !is.null(risk_plot)) {
      risk_plot <- risk_plot + ggplot2::coord_cartesian(xlim = common_range, expand = FALSE)
    }
    body <- tte_curve_publication_grob(p, risk_plot, base_size, include_legend = FALSE)
    title <- grid::textGrob(labels[i], x = grid::unit(2, "mm"), just = "left",
      gp = grid::gpar(fontsize = base_size, fontface = "bold", col = tte_sci_colors()$text))
    tagged <- gtable::gtable_add_rows(body, grid::unit(5, "mm"), pos = 0)
    gtable::gtable_add_grob(tagged, title, t = 1, l = 1, clip = "off", name = "panel_label")
  })
  result <- tte_publication_matrix(bodies, ncol, gap_mm = 4)
  result <- tte_publication_vertical(list(result), 1, tte_publication_legend(curves[[1]]))
  attr(result, "tte_outcome_panels") <- curves
  attr(result, "tte_strategy_colors") <- colors
  attr(result, "tte_shared_x_range") <- common_range
  attr(result, "tte_panel_labels") <- labels
  result
}

plot_subgroup_forest <- function(data, effect_scale, base_size = 8,
    digits = 2, alternating_rows = FALSE, x_limits = NULL) {
  tte_figure_columns(data, c("subgroup", "label", "row_type", "estimate", "ci_lower", "ci_upper"), "Subgroup forest")
  scale <- tte_normalize_effect_scale(effect_scale)
  if (!nrow(data) || any(!data$row_type %in% c("overall", "header", "category"))) stop("Invalid subgroup row structure")
  is_effect <- data$row_type != "header"
  tte_validate_intervals(data[is_effect, , drop = FALSE], "Subgroup effects")
  if (!all(is.na(data$estimate[!is_effect]) & is.na(data$ci_lower[!is_effect]) & is.na(data$ci_upper[!is_effect]))) {
    stop("Subgroup header rows must not carry effect estimates")
  }
  current <- NULL
  for (i in seq_len(nrow(data))) {
    if (data$row_type[i] == "header") current <- as.character(data$subgroup[i])
    if (data$row_type[i] == "category" && (is.null(current) || as.character(data$subgroup[i]) != current)) {
      stop("Every category must follow its matching subgroup header")
    }
  }
  if ("n" %in% names(data)) {
    tte_finite_numeric(data$n, "Subgroup N", allow_na = TRUE)
    if (any(data$n < 0 | data$n != floor(data$n), na.rm = TRUE)) stop("Subgroup N must be a nonnegative integer")
  }
  if ("p_interaction" %in% names(data)) {
    tte_finite_numeric(data$p_interaction, "Interaction P", allow_na = TRUE)
    if (any(data$p_interaction < 0 | data$p_interaction > 1, na.rm = TRUE)) stop("Interaction P must be in [0,1]")
    if (any(!is.na(data$p_interaction) & data$row_type != "header")) {
      stop("Interaction P values belong on explicit subgroup header rows")
    }
  }
  d <- data
  d$row <- rev(seq_len(nrow(data)))
  d$fontface <- ifelse(d$row_type == "category", "plain", "bold")
  d$display_label <- vapply(as.character(d$label), function(x) paste(strwrap(x, width = 24), collapse = "\n"), character(1))
  d$formatted <- ""
  d$formatted[is_effect] <- sprintf(paste0("%.", digits, "f (%.", digits, "f, %.", digits, "f)"),
    d$estimate[is_effect], d$ci_lower[is_effect], d$ci_upper[is_effect])
  d$display_effect <- ""
  d$display_effect[is_effect] <- sprintf(paste0("%.", digits, "f\n(%.", digits, "f, %.", digits, "f)"),
    d$estimate[is_effect], d$ci_lower[is_effect], d$ci_upper[is_effect])
  null <- tte_null_value_for_scale(scale)
  if (is.null(x_limits)) x_limits <- range(c(d$ci_lower[is_effect], d$ci_upper[is_effect], null))
  if (length(x_limits) != 2L || any(!is.finite(x_limits)) || x_limits[1] >= x_limits[2] ||
      any(d$ci_lower[is_effect] < x_limits[1] | d$ci_upper[is_effect] > x_limits[2])) {
    stop("x_limits must include every confidence interval")
  }
  common_y <- ggplot2::scale_y_continuous(limits = c(.5, nrow(d) + 1.7), expand = c(0, 0))
  text_theme <- tte_theme_publication(base_size) +
    ggplot2::theme(axis.line = ggplot2::element_blank(), axis.text = ggplot2::element_blank(),
      axis.title = ggplot2::element_blank(), axis.ticks = ggplot2::element_blank(),
      panel.grid = ggplot2::element_blank(), panel.grid.major.y = ggplot2::element_blank(),
      plot.margin = ggplot2::margin(1, 1, 1, 1))
  shading <- d[d$row %% 2 == 0, , drop = FALSE]
  shade_layer <- function() ggplot2::geom_rect(data = shading,
    ggplot2::aes(ymin = row - .5, ymax = row + .5), xmin = -Inf, xmax = Inf,
    fill = "#F3F5F6", colour = NA, inherit.aes = FALSE)
  left <- ggplot2::ggplot(d, ggplot2::aes(y = row))
  center <- ggplot2::ggplot(d[is_effect, , drop = FALSE], ggplot2::aes(y = row))
  right <- ggplot2::ggplot(d, ggplot2::aes(y = row))
  if (alternating_rows) {
    left <- left + shade_layer(); center <- center + shade_layer(); right <- right + shade_layer()
  }
  left <- left + ggplot2::geom_text(ggplot2::aes(x = ifelse(row_type == "category", .06, 0),
    label = display_label, fontface = fontface), hjust = 0,
    size = base_size / ggplot2::.pt, colour = tte_sci_colors()$text) +
    ggplot2::annotate("text", x = 0, y = nrow(d) + 1, label = "Subgroup", hjust = 0,
      fontface = "bold", size = base_size / ggplot2::.pt, colour = tte_sci_colors()$text) +
    ggplot2::scale_x_continuous(limits = c(0, 1), expand = c(0, 0)) + common_y + text_theme
  center <- center + ggplot2::geom_vline(xintercept = null, colour = tte_sci_colors()$neutral,
    linetype = 2, linewidth = .4) +
    ggplot2::geom_segment(ggplot2::aes(x = ci_lower, xend = ci_upper, yend = row),
      linewidth = .55, colour = tte_sci_colors()$treatment) +
    ggplot2::geom_point(ggplot2::aes(x = estimate), size = 2.2, colour = tte_sci_colors()$treatment) +
    common_y + ggplot2::coord_cartesian(xlim = x_limits) +
    ggplot2::labs(y = NULL, x = if (scale == "ratio") "Ratio (95% CI)" else "Difference (95% CI)") +
    tte_theme_publication(base_size) +
    ggplot2::theme(axis.text.y = ggplot2::element_blank(), axis.ticks.y = ggplot2::element_blank(),
      panel.grid = ggplot2::element_blank(), panel.grid.major.y = ggplot2::element_blank(),
      plot.margin = ggplot2::margin(1, 1, 1, 1))
  right <- right + ggplot2::geom_text(ggplot2::aes(x = 0, label = display_effect,
    fontface = fontface), hjust = 0, size = base_size / ggplot2::.pt,
    colour = tte_sci_colors()$text, lineheight = .95) +
    ggplot2::annotate("text", x = 0, y = nrow(d) + 1, label = "Estimate\n(95% CI)",
      hjust = 0, fontface = "bold", size = base_size / ggplot2::.pt, colour = tte_sci_colors()$text)
  if ("n" %in% names(d)) {
    right <- right + ggplot2::geom_text(ggplot2::aes(x = 1, label = ifelse(is.na(n), "", n)),
      hjust = 1, size = base_size / ggplot2::.pt, colour = tte_sci_colors()$text) +
      ggplot2::annotate("text", x = 1, y = nrow(d) + 1, label = "N", hjust = 1,
        fontface = "bold", size = base_size / ggplot2::.pt, colour = tte_sci_colors()$text)
  }
  if ("p_interaction" %in% names(d)) {
    interaction <- d[!is.na(d$p_interaction), , drop = FALSE]
    right <- right + ggplot2::geom_text(data = interaction,
      ggplot2::aes(x = 0, label = paste0("P int. = ", format(p_interaction, digits = 3))),
      hjust = 0, size = base_size / ggplot2::.pt, colour = tte_sci_colors()$text)
  }
  right <- right + ggplot2::scale_x_continuous(limits = c(0, 1), expand = c(0, 0)) + common_y + text_theme
  components <- list(left = left, center = center, right = right)
  result <- tte_publication_matrix(tte_align_plot_grobs(components, "heights"), 3,
    widths = c(.31, .32, .37))
  attr(result, "tte_subgroup_data") <- data
  attr(result, "tte_row_structure") <- data[c("subgroup", "label", "row_type")]
  attr(result, "tte_formatted_effects") <- d$formatted
  attr(result, "tte_effect_scale") <- scale
  attr(result, "tte_null_value") <- null
  attr(result, "tte_forest_components") <- components
  attr(result, "tte_forest_arguments") <- list(data = data, effect_scale = effect_scale,
    base_size = base_size, digits = digits, alternating_rows = alternating_rows, x_limits = x_limits)
  result
}

compose_forest_panels <- function(panels, ncol = 2, labels = LETTERS[seq_along(panels)],
                                  independent_x_scales = FALSE, base_size = 8) {
  tte_theme_publication(base_size)
  if (!length(panels) || length(labels) != length(panels) || anyNA(labels) || anyDuplicated(labels)) stop("Supply forest panels and unique labels")
  structures <- lapply(panels, attr, "tte_row_structure")
  if (any(vapply(structures, is.null, logical(1))) ||
      !all(vapply(structures, identical, logical(1), structures[[1]]))) stop("Forest panels must have identical subgroup row structures")
  scales <- vapply(panels, function(p) attr(p, "tte_effect_scale"), character(1))
  if (!independent_x_scales && length(unique(scales)) != 1L) stop("Different effect scales require explicit independent_x_scales=TRUE")
  common_x <- if (!independent_x_scales) range(unlist(lapply(panels,
    function(p) attr(p, "tte_forest_arguments")$x_limits))) else NULL
  rebuilt <- lapply(seq_along(panels), function(i) {
    args <- attr(panels[[i]], "tte_forest_arguments")
    if (!independent_x_scales) args$x_limits <- common_x
    args$base_size <- base_size
    p <- do.call(plot_subgroup_forest, args)
    title <- grid::textGrob(labels[i], x = grid::unit(2, "mm"), just = "left",
      gp = grid::gpar(fontsize = base_size, fontface = "bold", col = tte_sci_colors()$text))
    p <- gtable::gtable_add_rows(p, grid::unit(5, "mm"), pos = 0)
    gtable::gtable_add_grob(p, title, t = 1, l = 1, r = ncol(p), clip = "off", name = "panel_label")
  })
  result <- tte_publication_matrix(rebuilt, ncol, gap_mm = 4)
  attr(result, "tte_forest_panels") <- panels
  attr(result, "tte_row_structure") <- structures[[1]]
  attr(result, "tte_shared_x_range") <- common_x
  attr(result, "tte_independent_x_scales") <- independent_x_scales
  attr(result, "tte_panel_labels") <- labels
  result
}
