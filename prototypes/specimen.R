options(halftone.style = "journal"); source("geom_halftone.R", local = TRUE); source("theme_halftone.R", local = TRUE); source("with_halftone.R", local = TRUE); source("halftone_helpers.R", local = TRUE)
library(mgcv); library(MASS); library(patchwork); ink <- halftone_inks; W <- "white"
m <- gam(accel ~ s(times, k = 20), data = mcycle); nd <- data.frame(times = seq(2.4, 57.6, length.out = 200)); pr <- predict(m, nd, se.fit = TRUE)
nd$fit <- pr$fit; nd$lo <- pr$fit - 1.96 * pr$se.fit; nd$hi <- pr$fit + 1.96 * pr$se.fit
base <- function(band, title, code, colour = ink[["blue"]], pts = TRUE, halo = TRUE) {
  p <- ggplot(nd, aes(times)) + band
  if (halo) p <- p + geom_line(aes(y = fit), colour = W, linewidth = 0.85)
  p <- p + geom_line(aes(y = fit), colour = colour, linewidth = 0.5)
  if (pts) p <- p + geom_point(data = mcycle, aes(times, accel), shape = 21, fill = W, colour = "black", size = 0.7, stroke = 0.3)
  p + labs(x = NULL, y = NULL, title = title, subtitle = code) + theme_halftone() +
    theme(plot.title = element_text(size = 8, face = "bold", margin = margin(b = 0)), plot.subtitle = element_text(size = 5.5, family = "Liberation Mono", colour = "#555555", margin = margin(b = 3)), axis.text = element_text(size = 6))
}
rib <- function(...) with_halftone(geom_ribbon(aes(ymin = lo, ymax = hi), fill = ink[["blue"]]), outline = FALSE, ...)
tiles <- list(
  base(rib(pitch = 0.5), "1  Default", "with_halftone(geom_ribbon())"),
  base(rib(pitch = 0.5, grid = "square", angle = 45), "2  Square lattice, 45°", 'grid = "square", angle = 45'),
  base(rib(pitch = 0.9, levels = 4), "3  Coarse pitch", "pitch = 0.9, levels = 4"),
  base(rib(pitch = 0.5, tone = "flat"), "4  Flat screen", 'tone = "flat"'),
  base(rib(pitch = 0.5, tone = "edge"), "5  Edge-weighted", 'tone = "edge"'),
  base(rib(pitch = 0.5, tone = "tent"), "6  Tent (linear)", 'tone = "tent"'),
  base(rib(pitch = 0.45, levels = 1, algorithm = "blue_noise"), "7  Blue-noise stipple", 'levels = 1, algorithm = "blue_noise"'),
  base(rib(pitch = 0.5, shape = "square", angle = 45), "8  Square dots", 'shape = "square", angle = 45'),
  base(rib(pitch = 0.5, shape = "diamond"), "9  Diamond dots", 'shape = "diamond"'),
  base(rib(pitch = 0.6, shape = "line", angle = 45), "10  Line screen", 'shape = "line", angle = 45'),
  base(rib(pitch = 0.6, shape = "line", angle = 0, dot_max = 0.5), "11  Horizontal hatch", 'shape = "line", angle = 0'),
  base(with_halftone(geom_ribbon(aes(ymin = lo, ymax = hi), fill = "black"), outline = FALSE, pitch = 0.5, gain = 0.4), "12  Black ink, dot gain", 'fill = "black", gain = 0.4', colour = "black")
)
sheet <- wrap_plots(tiles, ncol = 4) + plot_annotation(title = "One smooth, twelve screens", subtitle = "GAM fit ± 95% CI (mcycle) · every tile is the same geom_ribbon() inside with_halftone() with the arguments shown",
  theme = theme_halftone() + theme(plot.title = element_text(size = 12, face = "bold"), plot.subtitle = element_text(size = 7, colour = "#555555")))
ggsave_journal("specimen.png", sheet, "double", height = 150, dpi = 500); cat("ok\n")
