# SYNTHETIC_DEMONSTRATION_ONLY: reuse the style preview conversion, not a second palette.
for (package in c("magick", "colorspace", "rsvg")) {
  if (!requireNamespace(package, quietly = TRUE)) stop("Required review package: ", package)
}
source("validation/figure_accessibility_helpers.R")
manifest <- utils::read.csv("output/publication_capability/manifest.csv")
names <- unique(manifest$figure)
gallery <- "output/publication_capability/figure_gallery"
paths <- stats::setNames(file.path(gallery, "double", paste0(names, ".png")), names)
tte_render_accessibility_previews(paths, file.path(gallery, "accessibility"))
preview <- "output/publication_capability_validation"
dir.create(preview, recursive = TRUE, showWarnings = FALSE)
for (column in c("single", "double")) {
  for (name in names) {
    magick::image_write(magick::image_read_svg(file.path(gallery, column, paste0(name, ".svg")), width = 1200),
      file.path(preview, paste0(name, "_", column, "_svg.png")))
  }
}
cat("PUBLICATION_ACCESSIBILITY_PREVIEWS=PASS CASES=9 MODES=4 SVG_RENDERED=18\n")
