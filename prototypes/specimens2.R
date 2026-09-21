options(halftone.style = "journal"); source("geom_halftone.R", local = TRUE); source("theme_halftone.R", local = TRUE); source("with_halftone.R", local = TRUE); source("halftone_helpers.R", local = TRUE)
library(patchwork); library(maps); library(MASS); ink <- halftone_inks; W <- "white"
tilth <- function(p, title, code) p + labs(title = title, subtitle = code) + theme(plot.title = element_text(size = 8, face = "bold", margin = margin(b = 0)),
  plot.subtitle = element_text(size = 5.5, family = "Liberation Mono", colour = "#555555", margin = margin(b = 3)))
sheet <- function(tiles, title, sub, file, h = 105) {
  s <- wrap_plots(tiles, ncol = 4) + plot_annotation(title = title, subtitle = sub, theme = theme_halftone() + theme(plot.title = element_text(size = 12, face = "bold"), plot.subtitle = element_text(size = 7, colour = "#555555")))
  ggsave_journal(file, s, "double", height = h, dpi = 500) }

## SHEET B — bars: categorical screens ------------------------------------------------------------------
d <- data.frame(g = factor(c("BOS", "RAS", "Mixed", "Undef."), c("BOS", "RAS", "Mixed", "Undef.")), n = c(52, 21, 14, 13))
bb <- function(layer, ...) ggplot(d, aes(g, n, ...)) + layer + scale_y_continuous(expand = expansion(c(0, 0.08))) + labs(x = NULL, y = NULL) + theme_halftone()
B <- list(
  tilth(bb(with_halftone(geom_col(width = 0.7, fill = ink[["blue"]], colour = "black", linewidth = 0.3), pitch = 0.5, tone = "flat")), "1  Flat dot fill, one ink", 'tone = "flat"'),
  tilth(bb(with_halftone(geom_col(aes(fill = g), width = 0.7, colour = "black", linewidth = 0.3), pitch = 0.5, tone = "flat")) + scale_fill_halftone(guide = "none"), "2  Flat, ink per bar", "aes(fill = g)"),
  tilth(bb(with_halftone(geom_col(aes(fill = g), width = 0.7, colour = "black", linewidth = 0.3), pitch = 0.5, tone = "centre", profile = "radial")) + scale_fill_halftone(guide = "none"), "3  Radial fade", 'tone = "centre", profile = "radial"'),
  tilth(bb(with_halftone(geom_col(aes(fill = g), width = 0.7, colour = "black", linewidth = 0.3), pitch = 0.5, tone = "edge", profile = "radial")) + scale_fill_halftone(guide = "none"), "4  Edge (vignette)", 'tone = "edge", profile = "radial"'),
  tilth(bb(with_halftone(geom_col(width = 0.7, fill = "black", colour = "black", linewidth = 0.3), pitch = 0.6, shape = "line"), screen = g) + scale_screen_manual(values = c(45, 135, 0, 90), guide = "none"), "5  Hatch angle per bar", "aes(screen = g), shape = \"line\""),
  tilth(bb(with_halftone(geom_col(width = 0.7, fill = "black", colour = "black", linewidth = 0.3), pitch = 0.6, tone = "flat"), screen = g) + scale_screen_discrete(guide = "none"), "6  Dot screen recipe", "aes(screen = g), scale_screen_discrete()"),
  tilth(bb(with_halftone(geom_col(width = 0.7, fill = "black", colour = "black", linewidth = 0.3), pitch = 0.5, tone = "flat", levels = 1, algorithm = "blue_noise", tone_max = 0.4)), "7  Blue-noise fill", 'algorithm = "blue_noise"'),
  tilth(bb(with_halftone(geom_col(width = 0.7, fill = "black", colour = NA), pitch = 1.0, tone = "flat", tone_max = 0.7, shape = "square", outline = FALSE)), "8  Coarse square dots, no outline", 'pitch = 1, shape = "square"')
)
sheet(B, "One bar chart, eight screens", "Categorical fills: colour, angle, shape and tone are independent channels", "specimen_bars.png", 95)

## SHEET D — overlapping densities: overlap policy -------------------------------------------------------
dd <- function(layer, ...) ggplot(iris, aes(Sepal.Length, ...)) + layer + labs(x = NULL, y = NULL) + theme_halftone() + theme(legend.position = "none")
D <- list(
  tilth(dd(with_halftone(geom_density(colour = "black", linewidth = 0.3), pitch = 0.5), fill = Species) + scale_fill_halftone(), "1  Default: woven overprint", 'overlap = "overprint" (default)'),
  tilth(dd(with_halftone(geom_density(colour = "black", linewidth = 0.3), pitch = 0.5, overlap = "stack"), fill = Species) + scale_fill_halftone(), "2  Stack (last wins)", 'overlap = "stack"'),
  tilth(dd(with_halftone(geom_density(colour = "black", linewidth = 0.3), pitch = 0.5, tone = "flat", tone_max = 0.35), fill = Species) + scale_fill_halftone(), "3  Flat, woven", 'tone = "flat"'),
  tilth(dd(with_halftone(geom_density(colour = "black", linewidth = 0.3), pitch = 0.5, tone = "edge"), fill = Species) + scale_fill_halftone(), "4  Edge-weighted", 'tone = "edge"'),
  tilth(dd(with_halftone(geom_density(fill = "black", colour = "black", linewidth = 0.3), pitch = 0.6, shape = "line"), screen = Species) + scale_screen_manual(values = c(0, 60, 120)), "5  One ink, hatch angles", "aes(screen), shape = \"line\""),
  tilth(dd(with_halftone(geom_density(colour = "black", linewidth = 0.3), pitch = 0.6, shape = "line"), fill = Species, screen = Species) + scale_fill_halftone() + scale_screen_manual(values = c(0, 60, 120)), "6  Colour + angle", "aes(fill, screen)"),
  tilth(dd(with_halftone(geom_density(colour = "black", linewidth = 0.3), pitch = 0.6, tone = "flat", tone_max = 0.5), fill = Species, screen = Species) + scale_fill_halftone() + scale_screen_discrete(), "7  Colour + dot recipe", "aes(fill, screen), dots"),
  tilth(dd(with_halftone(geom_density(colour = "black", linewidth = 0.3), pitch = 0.45, levels = 1, algorithm = "blue_noise"), fill = Species) + scale_fill_halftone(), "8  Blue noise, woven", 'algorithm = "blue_noise"')
)
sheet(D, "Three overlapping densities, eight policies", "How the same overlap is shown: weave, stack, hatch — and what each hides", "specimen_densities.png", 95)

## SHEET M — choropleth: lattice under projection -----------------------------------------------------------
val <- setNames(USArrests$Murder, tolower(rownames(USArrests))); st <- map_data("state"); st$murder <- val[st$region]
mm <- function(layer, ...) ggplot(st, aes(long, lat, group = group, ...)) + layer + coord_map("albers", lat0 = 30, lat1 = 45) + labs(x = NULL, y = NULL) + theme_halftone(axes = "none") + theme(axis.text = element_blank(), legend.position = "none")
pal <- scale_fill_gradientn(colours = c("#E7D9B8", ink[["ochre"]], ink[["red"]], "#3A0A0A"))
M <- list(
  tilth(mm(with_halftone(geom_polygon(colour = "black", linewidth = 0.2), pitch = 0.5, angle = 45, grid = "square", tone = "flat", tone_max = 0.6), fill = murder) + pal, "1  45° square (default map)", 'angle = 45, grid = "square"'),
  tilth(mm(with_halftone(geom_polygon(colour = "black", linewidth = 0.2), pitch = 0.5, grid = "hex", tone = "flat", tone_max = 0.6), fill = murder) + pal, "2  Hex", 'grid = "hex"'),
  tilth(mm(with_halftone(geom_polygon(colour = "black", linewidth = 0.2), pitch = 0.9, angle = 45, grid = "square", tone = "flat", tone_max = 0.7), fill = murder) + pal, "3  Coarse", "pitch = 0.9"),
  tilth(mm(with_halftone(geom_polygon(colour = "black", linewidth = 0.2), pitch = 0.5, tone = "flat", tone_max = 0.6, levels = 1, algorithm = "blue_noise"), fill = murder) + pal, "4  Blue noise", 'algorithm = "blue_noise"'),
  tilth(mm(with_halftone(geom_polygon(colour = "black", linewidth = 0.2), pitch = 0.5, tone = "centre", profile = "radial"), fill = murder) + pal, "5  Radial fade per state", 'tone = "centre", profile = "radial"'),
  tilth(mm(with_halftone(geom_polygon(colour = "black", linewidth = 0.2), pitch = 0.5, tone = "edge", profile = "radial"), fill = murder) + pal, "6  Edge vignette per state", 'tone = "edge", profile = "radial"'),
  tilth(mm(with_halftone(geom_polygon(colour = "black", linewidth = 0.2), pitch = 0.55, shape = "line", angle = 45, tone = "flat", tone_max = 0.6), fill = murder) + pal, "7  Line screen", 'shape = "line"'),
  tilth(mm(with_halftone(geom_polygon(aes(alpha = murder), fill = "black", colour = "black", linewidth = 0.2), pitch = 0.55, shape = "line", angle = 45, tone = "flat", tone_max = 1), ) + scale_alpha(range = c(0.15, 1)), "8  One ink, alpha → weight", "fill = black, aes(alpha = murder)")
)
sheet(M, "One choropleth, eight screens", "Lattice geometry survives the Albers projection because dots are placed in panel space, not data space", "specimen_map.png", 85)

## SHEET F — continuous field: algorithm × levels -------------------------------------------------------------
kd <- kde2d(faithful$eruptions, faithful$waiting, n = 150, lims = c(1.3, 5.6, 40, 100)); dens <- data.frame(expand.grid(x = kd$x, y = kd$y), z = as.vector(kd$z))
ff <- function(...) ggplot(dens, aes(x, y, z = z)) + geom_halftone(colour = "black", ...) + labs(x = NULL, y = NULL) + theme_halftone(axes = "box")
F <- list(
  tilth(ff(pitch = 0.5, levels = 1, algorithm = "bayer"), "1  Bayer, binary", 'levels = 1'),
  tilth(ff(pitch = 0.5, levels = 4, algorithm = "bayer"), "2  Bayer, 4 levels", "levels = 4"),
  tilth(ff(pitch = 0.5, levels = 8, algorithm = "bayer", bayer_n = 8), "3  Bayer 8×8, 8 levels", "bayer_n = 8, levels = 8"),
  tilth(ff(pitch = 0.5, levels = 1, algorithm = "blue_noise"), "4  Blue noise, binary", 'algorithm = "blue_noise"'),
  tilth(ff(pitch = 0.5, levels = 1, algorithm = "floyd_steinberg"), "5  Floyd–Steinberg, binary", 'algorithm = "floyd_steinberg"'),
  tilth(ff(pitch = 0.5, levels = 6, algorithm = "bayer", gamma = 0.5), "6  Gamma 0.5 (lift shadows)", "gamma = 0.5"),
  tilth(ff(pitch = 0.5, levels = 6, algorithm = "bayer", gamma = 2), "7  Gamma 2 (crush)", "gamma = 2"),
  tilth(ff(pitch = 0.45, shape = "line", angle = 30, gamma = 1.3), "8  Line screen", 'shape = "line", angle = 30')
)
sheet(F, "One density surface, eight renderings", "Dither algorithm, tone levels and gamma on the same field", "specimen_field.png", 95)
cat("ok\n")
