# halftone_raster.R — turn an image into a field data frame for geom_halftone()
library(magick)
halftone_raster <- function(img, max_px = 160, channel = c("luminance", "red", "green", "blue"), invert = TRUE) {
  channel <- match.arg(channel)
  if (is.character(img)) img <- image_read(img)
  img <- image_resize(img, paste0(max_px, "x", max_px)); info <- image_info(img)
  a <- as.integer(image_data(img, channels = "rgb")) / 255      # h x w x 3
  z <- switch(channel, luminance = 0.2126 * a[,,1] + 0.7152 * a[,,2] + 0.0722 * a[,,3], red = a[,,1], green = a[,,2], blue = a[,,3])
  if (invert) z <- 1 - z                                          # dark = more ink
  h <- nrow(z); w <- ncol(z)
  data.frame(expand.grid(x = seq_len(w), y = rev(seq_len(h))), z = as.vector(t(z)),
             r = as.vector(t(a[,,1])), g = as.vector(t(a[,,2])), b = as.vector(t(a[,,3])))
}
