# theme.R: the theme modifier and the export helpers.
# theme_halftone() is an incomplete theme. Add it on top of any complete theme. It sets only what a halftone needs:
# a paper ground with no gridlines under the screen, legend keys large enough to show a screen, and the ink palettes.

#' Theme modifier and export helpers
#'
#' `theme_halftone()` is an incomplete theme to add on top of your own theme, for example
#' `theme_classic() + theme_halftone()`. It changes only what a halftone needs and leaves fonts, sizes and axes to the
#' theme it is added to:
#'
#' * paper ground: plot and panel backgrounds in `paper`, no gridlines, no panel border fill;
#' * legend keys large enough to show a screen (6 by 4 mm), no key background;
#' * on ggplot2 4.0 and later, [halftone_inks] (or [halftone_process]) as the default discrete palette and
#'   [halftone_ramp] as the default continuous palette. `halftone_inks` holds six inks and `halftone_ramp` four stops; past six groups, map
#'   [scale_screen_discrete()] instead of colour, or pass `palette = "none"` and set your own.
#'
#' `ggsave_journal()` saves at a journal column width in mm. The file extension selects the format: PNG or TIFF at
#' 600 dpi through ragg, or vector PDF through `cairo_pdf()`. Most journals prefer vector files for line art, and in a
#' vector file every dot is a path at physical size. `halftone_proof()` renders a plot at final size and a magnified
#' crop of one region (by default the panel centre at 4x) and returns the two file paths.
#' @param paper Background colour of the plot and panel. Use [halftone_paper] for cream stock.
#' @param palette Default discrete palette on ggplot2 4.0 and later: `"inks"` ([halftone_inks]), `"process"`
#'   ([halftone_process], press colours of one or two plates) or `"none"` to leave the palettes alone.
#' @param filename,plot,dpi,... Passed to [ggplot2::ggsave()].
#' @param width `"single"` (89 mm), `"onehalf"` (120 mm), `"double"` (183 mm) or a width in mm.
#' @param height Height in mm.
#' @param format `"png"`, `"tiff"` or `"pdf"`; `NULL` takes it from the extension of `filename`.
#' @param bg Device background. Set it to the paper colour when the plot has a fixed aspect ratio, because the
#'   device shows beside the panel.
#' @param dir,centre,size,zoom For `halftone_proof()`: output directory, the crop centre as a fraction of width and height,
#'   the crop size in mm, and the magnification.
#' @return A ggplot2 theme; `ggsave_journal()` is called for its side effect.
#' @references
#' Nature Portfolio. Formatting guide: figures. <https://www.nature.com/nature/for-authors/formatting-guide>
#' Elsevier. Artwork and media instructions. <https://www.elsevier.com/about/policies-and-standards/author/artwork-and-media-instructions>
#' @examples
#' ggplot2::ggplot(mtcars, ggplot2::aes(wt, mpg)) + ggplot2::geom_point() + ggplot2::theme_classic() + theme_halftone()
#' @export
theme_halftone <- function(paper = "white", palette = c("inks", "process", "none")) {
  palette <- match.arg(palette)
  t <- theme(plot.background = element_rect(fill = paper, colour = NA), panel.background = element_rect(fill = paper, colour = NA),
             panel.grid = element_blank(), panel.grid.major = element_blank(), panel.grid.minor = element_blank(),
             legend.key = element_blank(), legend.key.width = unit(6, "mm"), legend.key.height = unit(4, "mm"))
  if (palette != "none" && utils::packageVersion("ggplot2") >= "4.0.0") {
    inks <- unname(if (palette == "process") halftone_process else halftone_inks)
    t <- t + theme(palette.colour.discrete = inks, palette.fill.discrete = inks, palette.colour.continuous = halftone_ramp, palette.fill.continuous = halftone_ramp)
  }
  t
}

#' @rdname theme_halftone
#' @export
ggsave_journal <- function(filename, plot, width = c("double", "single", "onehalf"), height = 100, dpi = 600, format = NULL, bg = "white", ...) {
  w <- if (is.character(width)) halftone_widths[[match.arg(width)]] else width
  format <- match.arg(format %||% tolower(tools::file_ext(filename)), c("png", "tiff", "tif", "pdf"))
  dev <- switch(format, png = ragg::agg_png, tiff = , tif = agg_tiff_lzw, pdf = grDevices::cairo_pdf)
  ggsave(filename, plot, width = w, height = height, units = "mm", dpi = dpi, device = dev, bg = bg, ...)
}
# ggsave() reads a device's formals to decide what to pass (res, units, bg), so the wrapper must declare them
agg_tiff_lzw <- function(filename, width, height, units = "in", res = 300, bg = "white", ...) ragg::agg_tiff(filename, width, height, units = units, res = res, background = bg, compression = "lzw", ...)
#' @rdname theme_halftone
#' @export
halftone_proof <- function(plot, width = "single", height = 62, dir = tempdir(), centre = c(0.5, 0.5), size = 20, zoom = 4, dpi = 600, bg = "white") {
  full <- file.path(dir, "proof_full.png"); ggsave_journal(full, plot, width, height = height, dpi = dpi, bg = bg)
  if (!requireNamespace("magick", quietly = TRUE)) { message("halftone_proof(): install magick for the magnified crop"); return(c(full = full)) }
  im <- magick::image_read(full); info <- magick::image_info(im); px <- size / 25.4 * dpi
  x0 <- max(0, round(centre[1] * info$width - px / 2)); y0 <- max(0, round((1 - centre[2]) * info$height - px / 2))
  crop <- magick::image_resize(magick::image_crop(im, sprintf("%dx%d+%d+%d", round(px), round(px), x0, y0)), sprintf("%d%%", round(100 * zoom)), filter = "Point")
  zf <- file.path(dir, "proof_zoom.png"); magick::image_write(crop, zf)
  c(full = full, zoom = zf)
}
