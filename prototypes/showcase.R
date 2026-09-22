# showcase.R: examples that exercise corners of the API the gallery does not reach.
# Run from the project root: Rscript prototypes/showcase.R
suppressPackageStartupMessages({library(gghalftone); library(ggplot2); library(patchwork)})
out <- function(name, p, width = "single", height = 62, ...) ggsave_journal(file.path("figures/v2/showcase", paste0(name, ".png")), p, width, height = height, ...)
th <- function(base = theme_classic) base(base_size = 8) + theme_halftone()
ink <- halftone_inks

## 1 A photograph, two ways: four-colour process, and one ink by error diffusion ----------------------------------------
img <- magick::image_read("rose:")
f <- halftone_raster(img, max_px = 150)
pA <- ggplot() + geom_halftone_cmyk(f, pitch = 0.6, levels = 6) + coord_equal(expand = FALSE) +
  labs(tag = "A") + theme_void(base_size = 8) + theme_halftone() + theme(plot.tag.location = "margin")
pB <- ggplot(f, aes(x, y, z = z)) + geom_halftone(levels = 2, algorithm = "floyd_steinberg", colour = "black", pitch = 0.4) +
  coord_equal(expand = FALSE) + labs(tag = "B") + theme_void(base_size = 8) + theme_halftone() + theme(plot.tag.location = "margin")
out("photograph", pA | pB, width = "double", height = 62)

## 2 Simple features: a choropleth straight from an sf object ------------------------------------------------------------
if (requireNamespace("sf", quietly = TRUE)) {
  nc <- sf::st_read(system.file("shape/nc.shp", package = "sf"), quiet = TRUE)
  nc$rate <- nc$SID74 / nc$BIR74 * 1000
  pS <- ggplot(nc) + with_halftone(geom_sf(aes(fill = rate), colour = "black", linewidth = 0.12), angle = 45, grid = "square") +
    labs(fill = "SIDS per\n1000 births") + theme_void(base_size = 8) + theme_halftone() + theme(legend.position = "right")
  out("sf_choropleth", pS, width = "double", height = 66)
}

## 3 A wind rose: direction by angle, frequency by radius, wind speed by hatch --------------------------------------------
dirs <- c("N", "NE", "E", "SE", "S", "SW", "W", "NW")
set.seed(9)
w <- expand.grid(dir = factor(dirs, dirs), speed = factor(c("2-5", "5-8", "8+"), c("2-5", "5-8", "8+")))
w$pct <- round(c(8, 6, 5, 9, 14, 22, 19, 11) / 10 * rep(c(3.6, 2.6, 1.3), each = 8) * runif(24, 0.75, 1.25), 1)
ring <- ceiling(max(tapply(w$pct, w$dir, sum)))
pR <- ggplot(w, aes(dir, pct, screen = speed)) +
  with_halftone(geom_col(width = 0.98, fill = "black", colour = "black", linewidth = 0.15, position = position_stack(reverse = TRUE)),
                shape = "line", pitch = 0.75) +   # coarse: 24 hatched regions meet in one panel
  scale_screen_discrete(name = "Wind speed (m/s)") + coord_polar(start = -pi / 8) +
  scale_y_continuous(limits = c(0, ring), breaks = seq(5, ring, 5), expand = c(0, 0)) +
  labs(x = NULL, y = NULL) + th(theme_minimal) +
  theme(panel.grid.major = element_line(colour = "grey85", linewidth = 0.2),
        axis.text.y = element_text(size = 5.5, colour = "grey45"), axis.text.x = element_text(size = 7),
        legend.position = "bottom", legend.key.width = unit(7, "mm"), plot.margin = margin(2, 2, 2, 2))
out("wind_rose", pR, height = 84)

## 4 Ridgelines from a computed tone field -------------------------------------------------------------------------------
r <- halftone_ridges(mpg$hwy, factor(mpg$class), scale = 1.9)
pD <- ggplot()
for (i in seq_along(r$fields)) pD <- pD + geom_halftone(data = r$fields[[i]], aes(x, y, z = z), pitch = 0.4, colour = ink[["blue"]], overlap = "stack", tone_max = 0.75)
for (l in r$lines) pD <- pD + with_halo(geom_path(data = l, aes(x, y), colour = ink[["blue"]], linewidth = 0.3))
pD <- pD + scale_y_continuous(breaks = seq_along(r$levels), labels = r$levels, expand = expansion(c(0.02, 0.12))) +
  coord_cartesian(xlim = c(12, 45)) + labs(x = "Highway miles per gallon", y = NULL) +
  th() + theme(axis.line.y = element_blank(), axis.ticks.y = element_blank())
out("ridgelines", pD, height = 74)

## 5 Violins in one ink: seven groups, so hatching rather than colour ------------------------------------------------------
pV <- ggplot(mpg, aes(reorder(class, hwy), hwy, screen = class)) +
  with_halftone(geom_violin(fill = "black", colour = "black", linewidth = 0.25), shape = "line", pitch = 0.6) +
  scale_screen_discrete(guide = "none") + labs(x = NULL, y = "Highway miles per gallon") +
  th() + theme(axis.text.x = element_text(angle = 30, hjust = 1))
out("violins", pV, width = "onehalf", height = 62)

## 6 The physical pitch: one figure at three widths, cropped at the same magnification -------------------------------------
x <- seq(0, 10, length.out = 80); d <- data.frame(x, y = sin(x), lo = sin(x) - 0.45, hi = sin(x) + 0.45)
pP <- ggplot(d, aes(x)) + with_halftone(geom_ribbon(aes(ymin = lo, ymax = hi), fill = ink[["red"]])) +
  with_halo(geom_line(aes(y = y), colour = ink[["red"]], linewidth = 0.35)) + labs(x = NULL, y = NULL) + th()
widths <- c(40, 89, 183); dpi <- 600
files <- vapply(widths, function(w) { f <- tempfile(fileext = ".png"); ggsave_journal(f, pP, w, height = 60, dpi = dpi); f }, "")
if (requireNamespace("magick", quietly = TRUE)) {
  mm <- function(v) round(v / 25.4 * dpi)
  cw <- 18; ch <- 12   # crop size in mm, taken from the same place on the panel in each render
  panel <- function(f, w) {
    im <- magick::image_crop(magick::image_read(f), sprintf("%dx%d+%d+%d", mm(cw), mm(ch), mm(11), mm(8)))
    ggplot() + annotation_custom(grid::rasterGrob(as.raster(im), interpolate = FALSE)) +
      labs(title = sprintf("saved at %d mm", w)) + theme_void(base_size = 8) +
      theme(plot.title = element_text(size = 7, hjust = 0.5, margin = margin(b = 1.5)), plot.margin = margin(1, 1, 1, 1))
  }
  strip <- wrap_plots(Map(panel, files, widths), nrow = 1)
  out("pitch_invariance", strip, width = 3 * (cw + 2), height = ch + 7)
}
cat("showcase ok\n")
