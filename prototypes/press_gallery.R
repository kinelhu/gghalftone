# press_gallery.R: every gallery figure as prepared and as printed, side by side.
# It sources gallery2.R with rendering off, so the plots are the gallery's own and there is no second copy of the
# figure code here. Renders to figures/v2/press/. Run from the project root: Rscript prototypes/press_gallery.R
suppressPackageStartupMessages({library(gghalftone); library(ggplot2); library(patchwork)})
options(gallery.render = FALSE)
source("prototypes/gallery2.R")

dir.create("figures/v2/press", showWarnings = FALSE, recursive = TRUE)

# One house press for the whole sheet, so it shows what a single impression does to different figure types rather
# than a setting tuned per figure. Every layer gets its own plate offset and mottle, counted up from the base seed.
#
# Three panels. Dot gain moves ink and nothing else, so on its own it is close to what you would get by
# reaching for dot_max or gamma on the plain figure: on a flat field it is exactly that, and across a tone range it
# differs only in curve shape, compressing the shadows by at most 8 coverage points at a matched mean. Putting gain
# in its own panel leaves the third panel showing what no setting on the plain figure reproduces: mottle, the smear
# of slur, ink bridges, and one plate landing off another.
GAIN  <- list(gain = 0.26)
PRESS <- list(gain = 0.26, slur = 0.06, slur_angle = 90, fillet = 0.06, mottle = 0.13, mottle_scale = 8,
              registration = 0.05, seed = 41)

# Only the top-level annotation of a patchwork survives, so each panel is sealed with wrap_elements() before the join.
panel <- function(x, title) {
  ttl <- theme(plot.title = element_text(size = 8, face = "bold", hjust = 0))
  wrap_elements(if (inherits(x, "patchwork")) x + plot_annotation(title = title, theme = ttl) else x + labs(title = title) + ttl)
}
pair <- function(name, fig) {
  w <- if (is.character(fig$width)) halftone_widths[[fig$width]] else fig$width
  out <- panel(fig$p, "as prepared") |
         panel(do.call(with_press, c(list(fig$p), GAIN)),  "dot gain only") |
         panel(do.call(with_press, c(list(fig$p), PRESS)), "the whole press")
  ggsave_journal(file.path("figures/v2/press", paste0(name, ".png")), out, width = 3 * w, height = fig$height + 6, dpi = 300)
}
for (nm in names(FIGS)) { cat(nm, "")
  tryCatch(pair(nm, FIGS[[nm]]), error = function(e) cat("[FAILED:", conditionMessage(e), "] ")) }
cat("\npress gallery ok\n")

## The control: how much of the press is simply more ink -------------------------------------------------------------
# Raise dot_max on the plain screen until it lays down exactly as much ink as the pressed one, and compare. Whatever
# is left is what no setting on the plain figure reproduces.
suppressPackageStartupMessages(library(grid))
flat <- function(file, press = NULL, dm = 0.9, pitch = 1.2) {
  g <- expand.grid(x = seq(0, 40, 0.5), y = seq(0, 40, 0.5)); g$z <- 0.6
  lay <- geom_halftone(pitch = pitch, colour = "black", range = c(0, 1), tone_max = 1, dot_max = dm)
  if (!is.null(press)) lay <- do.call(with_press, c(list(lay), press))
  p <- ggplot(g, aes(x, y, z = z)) + lay + coord_equal(expand = FALSE) + theme_void() +
    theme(plot.margin = margin(0, 0, 0, 0), panel.background = element_rect(fill = "white", colour = NA))
  ragg::agg_png(file, 1000, 1000, res = 300, background = "white"); print(p); invisible(dev.off())
  mean(png::readPNG(file)[, , 1] < 0.5)
}
tmp <- file.path(tempdir(), c("A.png", "B.png", "C.png"))
tb <- flat(tmp[2], PRESS)
dm <- stats::uniroot(function(d) flat(tempfile(fileext = ".png"), NULL, d) - tb, c(0.9, 1.7), tol = 2e-3)$root
ta <- flat(tmp[1], NULL, 0.9); tc <- flat(tmp[3], NULL, dm)
cat(sprintf("control: plain %.4f, pressed %.4f, plain at dot_max %.2f %.4f\n", ta, tb, dm, tc))
ims <- lapply(tmp, function(f) png::readPNG(f)[150:700, 150:700, , drop = FALSE])
lab <- c("as prepared", "the whole press", sprintf("plain, ink weight raised to\nmatch the pressed panel (dot_max %.2f)", dm))
ragg::agg_png("figures/v2/press/control.png", 1980, 800, res = 150, background = "white")
pushViewport(viewport(layout = grid.layout(2, 3, heights = unit(c(2.8, 1), c("lines", "null")))))
for (j in 1:3) {
  pushViewport(viewport(layout.pos.row = 1, layout.pos.col = j))
  grid.text(lab[j], gp = gpar(fontsize = 11, col = "grey20", lineheight = 1.3)); popViewport()
  pushViewport(viewport(layout.pos.row = 2, layout.pos.col = j, width = 0.96, height = 0.95))
  grid.raster(ims[[j]], interpolate = FALSE); grid.rect(gp = gpar(col = "grey80", fill = NA, lwd = 0.8)); popViewport()
}
invisible(dev.off())
cat("control sheet ok\n")
