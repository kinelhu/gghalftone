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

#' @export
theme_halftone <- function(style = getOption("halftone.style", c("journal", "editorial")), base_size = NULL, base_family = NULL, mono_family = NULL,
                           paper = if (style[1] == "journal") "white" else halftone_paper, ink = halftone_ink,
                           axes = c("left-bottom", "box", "none")) {
  style <- match.arg(style); axes <- match.arg(axes)
  if (style == "journal") {
    base_size <- base_size %||% 7; base_family <- base_family %||% halftone_font(c("Liberation Sans", "Arial", "Helvetica"), "sans")
    lab_family <- base_family
    sizes <- list(axis_text = 7, axis_title = 8, title = 9, subtitle = 7, caption = 6, legend_title = 7, legend_text = 7, strip = 8, tag = 10); legend_ink <- "#444444"
    case <- identity
  } else {
    legend_ink <- ink; base_size <- base_size %||% 11; base_family <- base_family %||% halftone_font(c("EB Garamond", "Garamond", "Georgia"), "serif")
    mono_family <- mono_family %||% halftone_font(c("Inconsolata", "Menlo", "Courier New"), "mono")
    lab_family <- mono_family
    sizes <- list(axis_text = base_size * 0.85, axis_title = base_size * 0.8, title = base_size * 1.6, subtitle = base_size * 0.85,
                  caption = base_size * 0.7, legend_title = base_size * 0.8, legend_text = base_size * 0.75, strip = base_size * 0.85, tag = base_size * 1.1)
  }
  t <- theme_minimal(base_size = base_size, base_family = base_family) %+replace% theme(
    text              = element_text(colour = ink, family = base_family, size = base_size),
    plot.background   = element_rect(fill = paper, colour = NA), panel.background = element_rect(fill = paper, colour = NA),
    panel.grid        = element_blank(),
    axis.line         = element_line(colour = ink, linewidth = 0.4, lineend = "square"),
    axis.ticks        = element_line(colour = ink, linewidth = 0.4), axis.ticks.length = unit(1.2, "mm"),
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
  if (axes == "box")  t <- t + theme(panel.border = element_rect(fill = NA, colour = ink, linewidth = 0.4), axis.line = element_blank())
  if (axes == "none") t <- t + theme(axis.line = element_blank(), axis.ticks = element_blank())
  # ggplot2 >= 4.0: the ink palette is the default for mapped colour/fill, the sepia ramp for continuous scales
  if (utils::packageVersion("ggplot2") >= "4.0.0") t <- t + theme(palette.colour.discrete = unname(halftone_inks), palette.fill.discrete = unname(halftone_inks),
                                                                  palette.colour.continuous = halftone_ramp, palette.fill.continuous = halftone_ramp)
  t
}

# save at a journal column width; height in mm; dpi 600 for line/halftone art per most author guidelines
#' @export
ggsave_journal <- function(filename, plot, width = c("double", "single", "onehalf"), height = 100, dpi = 600, ...) {
  w <- if (is.character(width)) halftone_widths[[match.arg(width)]] else width
  ggsave(filename, plot, width = w, height = height, units = "mm", dpi = dpi, device = ragg::agg_png, bg = "white", ...)
}
