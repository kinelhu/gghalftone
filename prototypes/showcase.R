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
# gamma above 1 pulls the tone down: the rose is a dark subject and at gamma 1 the one-ink screen filled in
pB <- ggplot(f, aes(x, y, z = z)) + geom_halftone(levels = 2, algorithm = "floyd_steinberg", colour = "black", pitch = 0.4, gamma = 1.7) +
  coord_equal(expand = FALSE) + labs(tag = "B") + theme_void(base_size = 8) + theme_halftone() + theme(plot.tag.location = "margin")
out("photograph", pA | pB, width = "double", height = 62)

## 2 Simple features: a choropleth straight from an sf object ------------------------------------------------------------
if (requireNamespace("sf", quietly = TRUE)) {
  nc <- sf::st_read(system.file("shape/nc.shp", package = "sf"), quiet = TRUE)
  nc$rate <- nc$SID74 / nc$BIR74 * 1000
  # the rate is skewed: 69 of 100 counties fall below a quarter of the maximum, so a linear ramp leaves the map flat
  pS <- ggplot(nc) + with_halftone(geom_sf(aes(fill = rate), colour = "black", linewidth = 0.12), angle = 45, grid = "square") +
    scale_fill_gradientn(colours = halftone_ramp, transform = "sqrt", breaks = c(0, 1, 2.5, 5, 9)) +
    labs(fill = "SIDS per\n1000 births") + theme_void(base_size = 8) + theme_halftone() + theme(legend.position = "right")
  out("sf_choropleth", pS, width = "double", height = 66)
}

## 3 A wind rose: direction by angle, frequency by radius, wind speed by tone --------------------------------------------
dirs <- c("N", "NE", "E", "SE", "S", "SW", "W", "NW")
set.seed(9)
w <- expand.grid(dir = factor(dirs, dirs), speed = factor(c("2-5", "5-8", "8+"), c("2-5", "5-8", "8+")))
w$pct <- round(c(8, 6, 5, 9, 14, 22, 19, 11) / 10 * rep(c(3.6, 2.6, 1.3), each = 8) * runif(24, 0.75, 1.25), 1)
ring <- ceiling(max(tapply(w$pct, w$dir, sum)))
pR <- ggplot(w, aes(dir, pct, screen = speed)) +
  # Wind speed is ordered, so it gets tone, not hatch angle. Angle separates nominal groups; a reader cannot rank
  # three angles, and in a wedge this small cannot tell them apart at all. The third field of a screen spec scales
  # the ink weight, so the three classes sit on one lattice and darken outward.
  # width 0.85 leaves a gap between petals. At 0.98 they abut and the rose reads as a stack of discs.
  with_halftone(geom_col(width = 0.85, fill = "black", colour = "black", linewidth = 0.15, position = position_stack(reverse = TRUE)),
                pitch = 0.55) +
  scale_screen_manual(values = c("15|circle|0.45", "15|circle|0.72", "15|circle|1"), name = "Wind speed (m/s)") +
  coord_polar(start = -pi / 8) +
  scale_y_continuous(limits = c(0, ring), breaks = seq(5, ring, 5), expand = c(0, 0)) +
  labs(x = NULL, y = NULL) + th(theme_minimal) +
  # rings are the radial axis, so they are hairline ink like every other rule in the set, not grey furniture
  theme(panel.grid.major.y = element_line(colour = "black", linewidth = 0.12),
        axis.text.y = element_text(size = 5.5), axis.text.x = element_text(size = 7),
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

## 6 Press artefacts: the same plate, then what a press does to it ----------------------------------------
if (requireNamespace("magick", quietly = TRUE)) {
  fr <- halftone_raster(magick::image_read("rose:"), max_px = 140)
  plate <- function(...) { args <- list(...)
    lay <- geom_halftone_cmyk(fr, pitch = 0.7, levels = 6)
    if (length(args)) lay <- Map(function(l, s) do.call(with_press, c(list(l, seed = s), args)), lay, seq_along(lay))
    ggplot() + lay + coord_equal(expand = FALSE) + theme_void(base_size = 8) + theme_halftone() +
      theme(plot.tag = element_text(face = "bold", size = 9), plot.tag.location = "margin") }
  pP1 <- plate() + labs(tag = "A")
  pP2 <- plate(gain = 0.25, fillet = 0.04, mottle = 0.10) + labs(tag = "B")
  pP3 <- plate(gain = 0.35, fillet = 0.05, mottle = 0.18, slur = 0.12, registration = 0.14) + labs(tag = "C")
  out("press", pP1 | pP2 | pP3, width = "double", height = 62)
}

## 7 The physical pitch: the same plate at three output widths ------------------------------------------------------
# A vertical tone ramp, so tone depends on y alone and every crop comes from the same place on the panel. Anything
# that differs between crops is the screen, not the data. The lower row ties the pitch to the output width, which is
# what a screen measured in figure units would do, and is the thing this package avoids. The sheet is assembled in
# grid rather than patchwork so that every crop is drawn at one magnification and the row labels have room.
g7 <- expand.grid(x = seq(0, 10, 0.2), y = seq(0, 10, 0.2)); g7$z <- g7$y / 10
ramp7 <- function(pitch) ggplot(g7, aes(x, y, z = z)) +
  geom_halftone(pitch = pitch, colour = ink[["red"]], range = c(0, 1)) +
  coord_cartesian(expand = FALSE) + theme_void() + theme(plot.margin = margin(0, 0, 0, 0))
widths7 <- c(40, 89, 183)
if (requireNamespace("magick", quietly = TRUE)) {
  dpi7 <- 600; mm7 <- function(v) round(v / 25.4 * dpi7)
  shot7 <- function(w, scaled) { f <- tempfile(fileext = ".png")
    ggsave_journal(f, ramp7(if (scaled) 0.35 * w / 89 else 0.35), w, height = 50, dpi = dpi7)
    im <- magick::image_crop(magick::image_read(f), sprintf("%dx%d+%d+%d", mm7(16), mm7(26), mm7(4), mm7(4)))
    unlink(f); as.raster(im) }
  cells7 <- list(lapply(widths7, shot7, scaled = FALSE), lapply(widths7, shot7, scaled = TRUE))
  rows7 <- c("pitch 0.35 mm at every size,\nas the package draws it", "pitch tied to the figure width,\nfor comparison")
  # explicit millimetres for every row and column: a "lines" unit resolves against the device font and left the
  # lower row hanging off the sheet
  ragg::agg_png("figures/v2/showcase/pitch_invariance.png", mm7(142), mm7(72), res = dpi7, background = "white")
  grid::pushViewport(grid::viewport(layout = grid::grid.layout(5, 4,
    heights = grid::unit(c(9, 26, 6, 26, 5), "mm"),
    widths  = grid::unit(c(46, 32, 32, 32), "mm"))))
  for (j in seq_along(widths7)) { grid::pushViewport(grid::viewport(layout.pos.row = 1, layout.pos.col = j + 1))
    grid::grid.text(sprintf("saved %d mm wide", widths7[j]), y = grid::unit(3, "mm"), just = "bottom",
                    gp = grid::gpar(fontsize = 8, col = "grey20")); grid::popViewport() }
  for (i in 1:2) {
    r <- c(2, 4)[i]
    grid::pushViewport(grid::viewport(layout.pos.row = r, layout.pos.col = 1))
    grid::grid.text(rows7[i], x = grid::unit(1, "npc") - grid::unit(4, "mm"), just = "right",
                    gp = grid::gpar(fontsize = 8, col = "grey20", lineheight = 1.5)); grid::popViewport()
    for (j in seq_along(widths7)) {
      grid::pushViewport(grid::viewport(layout.pos.row = r, layout.pos.col = j + 1,
                                        width = grid::unit(16, "mm"), height = grid::unit(26, "mm")))
      grid::grid.raster(cells7[[i]][[j]], interpolate = FALSE); grid::popViewport()
    }
  }
  invisible(dev.off())
}

cat("showcase ok\n")
