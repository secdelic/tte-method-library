# Original synthetic fixtures; benchmark data/figures are not used.
# SYNTHETIC_DEMONSTRATION_ONLY. Run from repository root.
source("R/figures/publication_figures.R")
source("R/figures/publication_capabilities.R")
source("figure_gallery/publication_capability_fixtures.R")
config <- read_figure_config("config_templates/figure_config.yml")
gallery <- "output/publication_capability/figure_gallery"
manifest <- list()
for (column in c("single", "double")) {
  plots <- tte_publication_capability_plots(column)
  for (name in names(plots)) {
    height <- if (name == "multi_panel_outcomes") 190 else if (name == "multi_panel_forests" && column == "single") 190 else
      if (name == "research_ccw_timeline") 150 else 110
    export <- export_publication_figure(plots[[name]], name, file.path(gallery, column),
      config, column = column, height_mm = height)
    stopifnot(export$qc$machine_checks_pass, !export$qc$publication_ready,
              export$qc$manual_review == "PENDING")
    manifest[[length(manifest) + 1L]] <- data.frame(figure = name, column = column,
      width_mm = if (column == "single") 85 else 178, height_mm = height,
      dpi = 600, fixture_status = "SYNTHETIC_DEMONSTRATION_ONLY",
      publication_ready = FALSE, manual_review = "PENDING")
  }
}
manifest <- do.call(rbind, manifest)
utils::write.csv(manifest, "output/publication_capability/manifest.csv", row.names = FALSE)
utils::write.csv(manifest, "reports/publication_capability_gallery_manifest.csv", row.names = FALSE)
selected <- file.path("figure_gallery", "publication_capability", "png")
dir.create(selected, recursive = TRUE, showWarnings = FALSE)
for (name in unique(manifest$figure)) {
  column <- if (name %in% c("research_ccw_timeline", "competing_event_timeline",
    "multi_panel_outcomes", "multi_panel_forests")) "double" else "single"
  if (!file.copy(file.path(gallery, column, paste0(name, ".png")),
    file.path(selected, paste0(name, ".png")), overwrite = TRUE)) stop("Gallery copy failed: ", name)
}
cat("PUBLICATION_CAPABILITY_GALLERY=PASS CASES=9 WIDTHS=2 FORMATS=4 FILES=72\n")
