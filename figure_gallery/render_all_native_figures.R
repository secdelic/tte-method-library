# Run from repository root. Only native constructors/exporters render figures.
# Original and candidate use identical v1.0.0 synthetic fixtures, not estimates
# selected or regenerated to improve appearance.
root <- normalizePath(".", winslash = "/", mustWork = TRUE)
figure_source <- "R/figures/publication_figures.R"
baseline_commit <- system2("git", c("rev-parse", "v1.0.0^{commit}"), stdout = TRUE)
stopifnot(length(baseline_commit) == 1L)
original_source <- system2("git", c("show", paste0("v1.0.0:", figure_source)),
                           stdout = TRUE)
original_config <- system2("git", c("show", "v1.0.0:config_templates/figure_config.yml"),
                           stdout = TRUE)
original <- new.env(parent = globalenv())
candidate <- new.env(parent = globalenv())
eval(parse(text = original_source), envir = original)
sys.source(figure_source, envir = candidate)
for (env in list(original, candidate)) {
  sys.source("figure_gallery/native_fixture_plots.R", envir = env)
}
before <- original$tte_native_fixture_plots()
after <- candidate$tte_native_fixture_plots()
stopifnot(length(before) == 14L, identical(names(before), names(after)))
config <- candidate$read_figure_config("config_templates/figure_config.yml")
baseline_config <- yaml::yaml.load(paste(original_config, collapse = "\n"))

comparison_dir <- "figure_style_comparison"
dir.create(comparison_dir, showWarnings = FALSE)
double_column <- c("figure_01_cohort_flow", "figure_02_missingness",
                   "figure_05_love_plot", "figure_06_standardized_balance",
                   "figure_07_difference_forest", "figure_08_ratio_forest",
                   "figure_12_sensitivity_forest", "figure_13_ccw_strategy_schematic")
manifest <- list()
invariance <- list()
for (figure in names(after)) {
  # Compare data and all common native layer coordinates, including densities
  # and confidence ribbons. Added CCW text is a redundant display layer only.
  stopifnot(identical(before[[figure]]$data, after[[figure]]$data))
  old_layers <- ggplot2::ggplot_build(before[[figure]])$data
  new_layers <- ggplot2::ggplot_build(after[[figure]])$data
  for (i in seq_along(old_layers)) {
    coords <- intersect(c("x", "y", "xend", "yend", "ymin", "ymax",
                          "xmin", "xmax", "density", "count", "n"),
                        names(old_layers[[i]]))
    stopifnot(isTRUE(all.equal(old_layers[[i]][coords], new_layers[[i]][coords],
                               tolerance = 0, check.attributes = FALSE)))
  }
  invariance[[figure]] <- data.frame(figure = figure, fixture_data_identical = TRUE,
                                    native_layer_coordinates_identical = TRUE)
  selected_column <- if (figure %in% double_column) "double" else "single"
  for (column in c("single", "double")) {
    export <- candidate$export_publication_figure(
      after[[figure]], figure, file.path("figure_gallery", column), config,
      column = column)
    stopifnot(isTRUE(export$qc$machine_checks_pass),
              !export$qc$publication_ready, export$qc$manual_review == "PENDING")
    if (column == selected_column) {
      file.copy(file.path("figure_gallery", column, paste0(figure, ".png")),
                file.path(comparison_dir, paste0(figure, "_candidate.png")),
                overwrite = TRUE)
    }
  }
  original$export_publication_figure(
    before[[figure]], paste0(figure, "_original"), comparison_dir, baseline_config,
    column = selected_column, vector_formats = "pdf", raster_formats = "png")
  # The before/after deliverables are PNGs; temporary original PDFs are removed.
  unlink(file.path(comparison_dir, paste0(figure, "_original.pdf")))
  manifest[[figure]] <- data.frame(
    figure = figure, baseline_commit = baseline_commit,
    fixture_source = "figure_gallery/native_fixture_plots.R", fixture_seed = 20260809,
    original_png = paste0(figure, "_original.png"),
    candidate_png = paste0(figure, "_candidate.png"),
    width_mm = if (selected_column == "double") 178 else 85,
    height_mm = config$dimensions$default_height_mm, dpi = 600,
    fixture_data_identical = TRUE, native_layer_coordinates_identical = TRUE,
    publication_ready = FALSE, manual_review = "PENDING")
}
# Comparison PNGs are review copies. Their temporary vector-export QC is not
# delivered, because those original PDFs are not part of the comparison set.
unlink(file.path(comparison_dir, "figure_qc.csv"))
utils::write.csv(do.call(rbind, manifest),
  file.path(comparison_dir, "figure_style_comparison_manifest.csv"), row.names = FALSE)
utils::write.csv(do.call(rbind, invariance),
  "figure_gallery/figure_data_invariance.csv", row.names = FALSE)
cat("SCI_NATIVE_GALLERY=PASS FIGURE_TYPES=14 WIDTHS=2 FORMATS=4 COMPARISONS=14\n")
