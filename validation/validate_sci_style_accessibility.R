# Development-only review aids; these packages are not runtime dependencies.
# Run after figure_gallery/render_all_native_figures.R from repository root.
for (package in c("colorspace", "magick", "ggplot2", "rsvg")) {
  if (!requireNamespace(package, quietly = TRUE)) stop("Required review package: ", package)
}
source("R/figures/publication_figures.R")
source("figure_gallery/native_fixture_plots.R")
plots <- tte_native_fixture_plots()
asset_root <- Sys.getenv("TTE_FIGURE_ASSET_ROOT", unset = "output/sci_style_gallery")
gallery_dir <- file.path(asset_root, "figure_gallery")
comparison_dir <- file.path(asset_root, "figure_style_comparison")
manifest <- utils::read.csv(file.path(comparison_dir, "figure_style_comparison_manifest.csv"))
preview_dir <- file.path(gallery_dir, "accessibility")
dir.create(preview_dir, recursive = TRUE, showWarnings = FALSE)
source("validation/figure_accessibility_helpers.R")
transforms <- tte_accessibility_transforms()
palette <- unlist(tte_sci_colors())
palette_table <- data.frame(role = names(palette), original = unname(palette))
for (mode in names(transforms)) {
  palette_table[[mode]] <- transforms[[mode]](palette)
}
tte_render_accessibility_previews(stats::setNames(file.path(comparison_dir,
  paste0(names(plots), "_candidate.png")), names(plots)), preview_dir)
utils::write.csv(palette_table, file.path(preview_dir, "palette_simulations.csv"), row.names = FALSE)

contrast <- data.frame(surface = "figure text on white", foreground = tte_sci_colors()$text,
                       background = "#FFFFFF", minimum_ratio = 4.5)
# Exercise all documented CCW states without changing the frozen gallery fixture.
states <- data.frame(strategy = "Synthetic diagnostic", period = 0:7,
  status = c("Baseline", "Grace", "Follow-up", "Adherent", "Censored",
             "Deviation", "Inactive", "Not-at-risk"))
layers <- ggplot2::ggplot_build(plot_ccw_strategy_schematic(states))$data
contrast <- rbind(contrast, data.frame(surface = paste("CCW", states$status),
  foreground = layers[[2]]$colour, background = layers[[1]]$fill, minimum_ratio = 4.5))
contrast$ratio <- mapply(colorspace::contrast_ratio, contrast$foreground, contrast$background)
contrast$pass <- contrast$ratio >= contrast$minimum_ratio
stopifnot(all(contrast$pass))
utils::write.csv(contrast, file.path(preview_dir, "text_contrast.csv"), row.names = FALSE)

redundancy <- data.frame(figure = names(plots), encoding = c(
  "Stage labels and bar lengths", "Variable labels and bar lengths",
  "Linetype", "Linetype", "Shape", "Shape", "Row labels and CI position",
  "Row labels and CI position", "Linetype", "Linetype", "Linetype",
  "Analysis labels and CI position", "Status text within every tile",
  "Linetype and shape"), confirmed = TRUE)
for (figure in names(plots)) {
  built <- ggplot2::ggplot_build(plots[[figure]])$data
  if (redundancy$encoding[redundancy$figure == figure] %in% c("Linetype", "Linetype and shape")) {
    lines <- Filter(function(x) "linetype" %in% names(x), built)
    stopifnot(length(lines) > 0L, length(unique(lines[[1]]$linetype)) == 2L)
  }
  if (redundancy$encoding[redundancy$figure == figure] == "Shape") {
    stopifnot(length(unique(tail(built, 1)[[1]]$shape)) == 2L)
  }
}
utils::write.csv(redundancy, file.path(preview_dir, "non_color_redundancy.csv"), row.names = FALSE)
svg_preview <- file.path("output", "sci_style_validation")
dir.create(svg_preview, recursive = TRUE, showWarnings = FALSE)
for (column in c("single", "double")) {
  for (figure in names(plots)) {
    magick::image_write(magick::image_read_svg(
      file.path(gallery_dir, column, paste0(figure, ".svg")), width = 1200),
      file.path(svg_preview, paste0(figure, "_", column, "_svg.png")))
  }
}
for (name in c("palette_simulations.csv", "text_contrast.csv", "non_color_redundancy.csv")) {
  file.copy(file.path(preview_dir, name), file.path("figure_gallery/accessibility", name),
            overwrite = TRUE)
}
cat("SCI_ACCESSIBILITY_AIDS=PASS FIGURES=14 MODES=4 TEXT_CONTRAST_CHECKS=9\n")
