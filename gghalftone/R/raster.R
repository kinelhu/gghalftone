# halftone_raster.R — turn an image into a field data frame for geom_halftone()

#' Image to field
#'
#' Reads an image (path or `magick` image) and returns a field data frame (`x`, `y`, `z` and `r`, `g`, `b`) for
#' [geom_halftone()] or [geom_halftone_cmyk()]. Dark pixels get high tone when `invert = TRUE`. Needs the magick
#' package.
#' @param img A file path or a `magick-image`.
#' @param max_px Longest side of the resampled image in cells.
#' @param channel Which channel becomes `z`.
#' @param invert Map dark to high tone.
#' @return A data frame.
#' @export
halftone_raster <- function(img, max_px = 160, channel = c("luminance", "red", "green", "blue"), invert = TRUE) {
  channel <- match.arg(channel); if (!requireNamespace("magick", quietly = TRUE)) stop("halftone_raster() needs the magick package")
  if (is.character(img)) img <- magick::image_read(img)
  img <- magick::image_resize(img, paste0(max_px, "x", max_px)); info <- magick::image_info(img)
  a <- as.integer(magick::image_data(img, channels = "rgb")) / 255      # h x w x 3
  z <- switch(channel, luminance = 0.2126 * a[,,1] + 0.7152 * a[,,2] + 0.0722 * a[,,3], red = a[,,1], green = a[,,2], blue = a[,,3])
  if (invert) z <- 1 - z                                          # dark = more ink
  h <- nrow(z); w <- ncol(z)
  data.frame(expand.grid(x = seq_len(w), y = rev(seq_len(h))), z = as.vector(t(z)),
             r = as.vector(t(a[,,1])), g = as.vector(t(a[,,2])), b = as.vector(t(a[,,3])))
}
