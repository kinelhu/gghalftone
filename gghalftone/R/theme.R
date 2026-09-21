# theme_halftone.R — two styles on one skeleton
#   "journal"   (default): sans, absolute point sizes at final figure size, bold panel tags, sentence case.
#                          Sized for 89 mm (single) / 183 mm (double) column figures at 7-8 pt, per Nature/Elsevier/Wiley guidance.
#   "editorial": the print/display look (Garamond titles, mono upper-case labels) used in the galleries.
# Shared rationale: no gridlines (halftone is texture; nothing else should be), paper ground, hard axis rules, outward ticks.


# first installed family from a preference list (via systemfonts, which ragg uses); fallback = device generic family
halftone_font <- function(prefer, fallback = "") {
  if (!requireNamespace("systemfonts", quietly = TRUE)) return(prefer[1])
  hit <- prefer[prefer %in% unique(systemfonts::system_fonts()$family)]
  if (length(hit)) hit[1] else fallback
}

#' Halftone theme and journal export
#'
#' `theme_halftone()` is a print theme on one skeleton with two registers. `"journal"` (default): sans, absolute
#' point sizes for 89 or 183 mm figures (ticks 7 pt, axis titles 8 pt, tags 8 pt bold, legend 7 pt grey), white
#' paper, no gridlines, 0.7 pt axis rules, outward ticks. `"editorial"`: cream paper, a serif for titles, a monospace
#' for labels. Font families are resolved from what is installed (journal: Liberation Sans, Helvetica, Arial;
#' editorial: EB Garamond, Garamond, Georgia, Times; mono: Inconsolata, Menlo, Courier New). Helvetica precedes
#' Arial because the pdf device knows it as a base family. On ggplot2 >= 4.0 the theme
#' also makes [halftone_inks] the default discrete palette and [halftone_ramp] the default continuous one.
#'
#' `ggsave_journal()` saves at a journal column width in mm: PNG (proofs) or TIFF at 600 dpi through ragg, or a vector
#' PDF through `cairo_pdf()`, which most journals prefer for line art and which this package suits, every dot being a
#' geometric object at physical size. The format follows the file extension. `halftone_proof()` renders a plot at true
#' size and a magnified crop of one region (default the panel centre, 4x), which is how every default in this package
#' was judged; it returns the two file paths.
#' @param style `"journal"` or `"editorial"`; the default follows `options(halftone.style = )`.
#' @param base_size Base font size in pt (7 journal, 11 editorial).
#' @param base_family,mono_family Font families; `NULL` resolves the first installed family from the lists above.
#' @param paper,ink Paper and ink colours.
#' @param axes `"left-bottom"` (two axis rules), `"box"` (panel border) or `"none"`.
#' @param palette Default discrete palette on ggplot2 >= 4.0: `"inks"` ([halftone_inks], muted, for screen and RGB
#'   workflows) or `"process"` ([halftone_process], one or two press plates at 100 %, for CMYK print).
#' @param filename,plot,dpi,... Passed to [ggplot2::ggsave()].
#' @param width `"single"` (89 mm), `"onehalf"` (120 mm), `"double"` (183 mm) or a width in mm.
#' @param height Height in mm.
#' @param format `"png"`, `"tiff"` or `"pdf"`; `NULL` takes it from the extension of `filename`.
#' @param dir,centre,size,zoom For `halftone_proof()`: output directory, the crop centre as a fraction of width and height,
#'   the crop size in mm, and the magnification.
#' @return A ggplot2 theme; `ggsave_journal()` is called for its side effect.
#' @examples
#' ggplot2::ggplot(mtcars, ggplot2::aes(wt, mpg)) + ggplot2::geom_point() + theme_halftone()
#' @export
theme_halftone <- function(style = getOption("halftone.style", c("journal", "editorial")), base_size = NULL, base_family = NULL, mono_family = NULL,
                           paper = if (style[1] == "journal") "white" else halftone_paper, ink = halftone_ink,
                           axes = c("left-bottom", "box", "none"), palette = c("inks", "process")) {
  style <- match.arg(style); axes <- match.arg(axes); palette <- match.arg(palette); rule <- if (style == "journal") 0.25 else 0.3
  inks <- if (palette == "process") halftone_process else halftone_inks
  if (style == "journal") {
    base_size <- base_size %||% 7; base_family <- base_family %||% halftone_font(c("Liberation Sans", "Helvetica", "Arial"), "sans")
    lab_family <- base_family
    sizes <- list(axis_text = 7, axis_title = 8, title = 9, subtitle = 7, caption = 6, legend_title = 7, legend_text = 7, strip = 8, tag = 8); legend_ink <- "#444444"
    case <- identity
  } else {
    legend_ink <- ink; base_size <- base_size %||% 11; base_family <- base_family %||% halftone_font(c("EB Garamond", "Garamond", "Georgia", "Times"), "serif")
    mono_family <- mono_family %||% halftone_font(c("Inconsolata", "Menlo", "Courier New"), "mono")
    lab_family <- mono_family
    sizes <- list(axis_text = base_size * 0.85, axis_title = base_size * 0.8, title = base_size * 1.6, subtitle = base_size * 0.85,
                  caption = base_size * 0.7, legend_title = base_size * 0.8, legend_text = base_size * 0.75, strip = base_size * 0.85, tag = base_size * 1.1)
  }
  t <- theme_minimal(base_size = base_size, base_family = base_family) %+replace% theme(
    text              = element_text(colour = ink, family = base_family, size = base_size),
    plot.background   = element_rect(fill = paper, colour = NA), panel.background = element_rect(fill = paper, colour = NA),
    panel.grid        = element_blank(),
    axis.line         = element_line(colour = ink, linewidth = rule, lineend = "square"),   # 0.25 mm = 0.7 pt: journals want 0.5-1 pt
    axis.ticks        = element_line(colour = ink, linewidth = rule), axis.ticks.length = unit(1.2, "mm"),
    axis.text         = element_text(family = lab_family, colour = ink, size = sizes$axis_text),
    axis.text.x       = element_text(margin = margin(t = 1.5)), axis.text.y = element_text(margin = margin(r = 1.5), hjust = 1),
    axis.title        = element_text(family = lab_family, colour = ink, size = sizes$axis_title),
    axis.title.x      = element_text(hjust = if (style == "journal") 0.5 else 1, margin = margin(t = 3)),
    axis.title.y      = element_text(hjust = if (style == "journal") 0.5 else 1, angle = 90, margin = margin(r = 3)),
    plot.title        = element_text(family = base_family, colour = ink, size = sizes$title, face = if (style == "journal") "bold" else "plain", hjust = 0, margin = margin(b = 1.5)),
    plot.subtitle     = element_text(family = lab_family, colour = ink, size = sizes$subtitle, hjust = 0, margin = margin(b = 5)),
    plot.caption      = element_text(family = lab_family, colour = "#666666", size = sizes$caption, hjust = 0, margin = margin(t = 4)),
    plot.tag          = element_text(family = base_family, colour = ink, size = sizes$tag, face = "bold"),
    plot.title.position = "plot", plot.caption.position = "plot", plot.tag.position = c(0, 1),
    legend.background = element_blank(), legend.key = element_blank(),
    legend.title      = element_text(family = lab_family, size = sizes$legend_title, face = "plain", colour = if (style == "journal") legend_ink else ink),
    legend.text       = element_text(family = lab_family, size = sizes$legend_text, colour = if (style == "journal") legend_ink else ink),
    legend.key.size   = unit(4, "mm"), legend.key.width = unit(2.5, "mm"), legend.key.height = unit(3.6, "mm"),   # colourbar = 2.5 x 18 mm
    legend.position = "right", legend.justification = "top", legend.margin = margin(0, 0, 0, 2), legend.spacing.y = unit(1, "mm"),
    strip.text        = element_text(family = lab_family, hjust = 0, size = sizes$strip, face = if (style == "journal") "bold" else "plain", margin = margin(b = 2)),
    plot.margin       = margin(3, 3, 3, 3),
    complete = TRUE)
  if (axes == "box")  t <- t + theme(panel.border = element_rect(fill = NA, colour = ink, linewidth = rule), axis.line = element_blank())
  if (axes == "none") t <- t + theme(axis.line = element_blank(), axis.ticks = element_blank())
  # ggplot2 >= 4.0: the ink palette is the default for mapped colour/fill, the sepia ramp for continuous scales
  if (utils::packageVersion("ggplot2") >= "4.0.0") t <- t + theme(palette.colour.discrete = unname(inks), palette.fill.discrete = unname(inks),
                                                                  palette.colour.continuous = halftone_ramp, palette.fill.continuous = halftone_ramp)
  t
}

# save at a journal column width; height in mm; dpi 600 for line/halftone art per most author guidelines
#' @rdname theme_halftone
#' @export
ggsave_journal <- function(filename, plot, width = c("double", "single", "onehalf"), height = 100, dpi = 600, format = NULL, ...) {
  w <- if (is.character(width)) halftone_widths[[match.arg(width)]] else width
  format <- match.arg(format %||% tolower(tools::file_ext(filename)), c("png", "tiff", "tif", "pdf"))
  dev <- switch(format, png = ragg::agg_png, tiff = , tif = agg_tiff_lzw, pdf = grDevices::cairo_pdf)
  ggsave(filename, plot, width = w, height = height, units = "mm", dpi = dpi, device = dev, bg = "white", ...)
}
# ggsave() reads a device's formals to decide what to pass (res, units, bg), so the wrapper must declare them
agg_tiff_lzw <- function(filename, width, height, units = "in", res = 300, bg = "white", ...) ragg::agg_tiff(filename, width, height, units = units, res = res, background = bg, compression = "lzw", ...)
#' @rdname theme_halftone
#' @export
halftone_proof <- function(plot, width = "single", height = 62, dir = tempdir(), centre = c(0.5, 0.5), size = 20, zoom = 4, dpi = 600) {
  full <- file.path(dir, "proof_full.png"); ggsave_journal(full, plot, width, height = height, dpi = dpi)
  if (!requireNamespace("magick", quietly = TRUE)) { message("halftone_proof(): install magick for the magnified crop"); return(c(full = full)) }
  im <- magick::image_read(full); info <- magick::image_info(im); px <- size / 25.4 * dpi
  x0 <- max(0, round(centre[1] * info$width - px / 2)); y0 <- max(0, round((1 - centre[2]) * info$height - px / 2))
  crop <- magick::image_resize(magick::image_crop(im, sprintf("%dx%d+%d+%d", round(px), round(px), x0, y0)), sprintf("%d%%", round(100 * zoom)), filter = "Point")
  zf <- file.path(dir, "proof_zoom.png"); magick::image_write(crop, zf)
  c(full = full, zoom = zf)
}
