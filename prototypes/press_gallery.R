# press_gallery.R: every gallery figure as prepared and as printed, side by side.
# It sources gallery2.R with rendering off, so the plots are the gallery's own and there is no second copy of the
# figure code here. Renders to figures/v2/press/. Run from the project root: Rscript prototypes/press_gallery.R
suppressPackageStartupMessages({library(gghalftone); library(ggplot2); library(patchwork)})
options(gallery.render = FALSE)
source("prototypes/gallery2.R")

dir.create("figures/v2/press", showWarnings = FALSE, recursive = TRUE)

# One house press for the whole sheet, so it shows what a single impression does to different figure types rather
# than a setting tuned per figure. Every layer gets its own plate offset and mottle, counted up from the base seed.
PRESS <- list(gain = 0.26, slur = 0.06, slur_angle = 90, fillet = 0.06, mottle = 0.13, mottle_scale = 8,
              registration = 0.05, seed = 41)

# Only the top-level annotation of a patchwork survives, so each half is sealed with wrap_elements() before the join.
half <- function(x, title) {
  ttl <- theme(plot.title = element_text(size = 8, face = "bold", hjust = 0))
  wrap_elements(if (inherits(x, "patchwork")) x + plot_annotation(title = title, theme = ttl) else x + labs(title = title) + ttl)
}
pair <- function(name, fig) {
  w <- if (is.character(fig$width)) halftone_widths[[fig$width]] else fig$width
  out <- half(fig$p, "as prepared") | half(do.call(with_press, c(list(fig$p), PRESS)), "with_press()")
  ggsave_journal(file.path("figures/v2/press", paste0(name, ".png")), out, width = 2 * w, height = fig$height + 6)
}
for (nm in names(FIGS)) { cat(nm, "")
  tryCatch(pair(nm, FIGS[[nm]]), error = function(e) cat("[FAILED:", conditionMessage(e), "] ")) }
cat("\npress gallery ok\n")
