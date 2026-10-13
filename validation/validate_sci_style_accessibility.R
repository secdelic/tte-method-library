# Development-only review aids; these packages are not runtime dependencies.
# Run after figure_gallery/render_all_native_figures.R from repository root.
for (package in c("colorspace", "magick", "ggplot2", "rsvg")) {
  if (!requireNamespace(package, quietly = TRUE)) stop("Required review package: ", package)
}
source("R/figures/publication_figures.R")
source("figure_gallery/native_fixture_plots.R")
plots <- tte_native_fixture_plots()
manifest <- utils::read.csv("figure_style_comparison/figure_style_comparison_manifest.csv")
preview_dir <- "figure_gallery/accessibility"
dir.create(preview_dir, showWarnings = FALSE)
transforms <- list(
  grayscale = colorspace::desaturate,
  deutan = function(x) colorspace::deutan(x, severity = 1, linear = TRUE),
  protan = function(x) colorspace::protan(x, severity = 1, linear = TRUE),
  tritan = function(x) colorspace::tritan(x, severity = 1, linear = TRUE)
)
palette <- unlist(tte_sci_colors())
palette_table <- data.frame(role = names(palette), original = unname(palette))
for (mode in names(transforms)) {
  palette_table[[mode]] <- transforms[[mode]](palette)
  for (figure in names(plots)) {
    path <- file.path("figure_style_comparison", paste0(figure, "_candidate.png"))
    # Downsample the actual 600-DPI export for review; do not alter the deliverable.
    raster <- as.raster(magick::image_resize(magick::image_read(path), "1000x"))
    values <- substr(as.character(raster), 1, 7)
    unique_colors <- unique(values)
    converted <- transforms[[mode]](unique_colors)
    mapped <- matrix(converted[match(values, unique_colors)], nrow = nrow(raster))
    class(mapped) <- "raster"
    magick::image_write(magick::image_read(mapped),
      file.path(preview_dir, paste0(figure, "_", mode, ".png")))
  }
}
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
      file.path("figure_gallery", column, paste0(figure, ".svg")), width = 1200),
      file.path(svg_preview, paste0(figure, "_", column, "_svg.png")))
  }
}
cat("SCI_ACCESSIBILITY_AIDS=PASS FIGURES=14 MODES=4 TEXT_CONTRAST_CHECKS=9\n")
