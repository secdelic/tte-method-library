# Shared development-only conversion of actual exported PNGs. The originals
# remain unchanged. Review previews are downsampled, not publication outputs.
tte_accessibility_transforms <- function() list(
  grayscale = colorspace::desaturate,
  deutan = function(x) colorspace::deutan(x, severity = 1, linear = TRUE),
  protan = function(x) colorspace::protan(x, severity = 1, linear = TRUE),
  tritan = function(x) colorspace::tritan(x, severity = 1, linear = TRUE)
)

tte_render_accessibility_previews <- function(paths, output_dir) {
  if (is.null(names(paths)) || any(!file.exists(paths))) stop("Supply named existing PNG paths")
  dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
  transforms <- tte_accessibility_transforms()
  for (figure in names(paths)) {
    raster <- as.raster(magick::image_resize(magick::image_read(paths[[figure]]), "1000x"))
    values <- substr(as.character(raster), 1, 7)
    unique_colors <- unique(values)
    for (mode in names(transforms)) {
      converted <- transforms[[mode]](unique_colors)
      mapped <- matrix(converted[match(values, unique_colors)], nrow = nrow(raster))
      class(mapped) <- "raster"
      magick::image_write(magick::image_read(mapped),
        file.path(output_dir, paste0(figure, "_", mode, ".png")))
    }
  }
  invisible(output_dir)
}
