# gallery2.R: the gallery. Every figure uses library(gghalftone) and as few overrides as the figure allows.
# Renders to figures/v2/ at 600 dpi. Run from the project root: Rscript prototypes/gallery2.R
suppressPackageStartupMessages({library(gghalftone); library(ggplot2); library(survival); library(patchwork); library(maps); library(MASS)})
# Every figure is registered as it is rendered, so press_gallery.R can re-use these exact plots instead of keeping a
# second copy of the code. Set options(gallery.render = FALSE) to build the registry without writing any file.
FIGS <- list()
# figures/ is gitignored, so a fresh clone has no output directory and every render fails on the first ggsave
dir.create("figures/v2", showWarnings = FALSE, recursive = TRUE)
out <- function(name, p, width = "single", height = 62, ...) {
  FIGS[[name]] <<- list(p = p, width = width, height = height, args = list(...))
  if (isTRUE(getOption("gallery.render", TRUE)))
    ggsave_journal(file.path("figures/v2", paste0(name, ".png")), p, width, height = height, ...)
  invisible(NULL)
}
ink <- halftone_inks; W <- "white"
# the gallery uses stock ggplot2 themes plus the modifier: nothing in the package sets fonts or sizes
th <- function(base = theme_classic) base(base_size = 8) + theme_halftone() + theme(plot.tag = element_text(face = "bold"), plot.tag.location = "margin")

## 1 Kaplan-Meier, three strata, censor marks, risk table --------------------------------------------------------------
fit <- survfit(Surv(time, status) ~ ph.ecog, data = subset(lung, ph.ecog < 3))
relabel <- function(d) { levels(d$strata) <- paste("ECOG", levels(d$strata)); d }
s <- relabel(km_steps(fit)); cens <- relabel(km_censor(fit)); risk <- relabel(km_risk(fit, seq(0, 1000, 250)))
xs <- scale_x_continuous(breaks = seq(0, 1000, 250), limits = c(-40, 1040), expand = c(0, 0))
pA <- ggplot(s, aes(time, group = strata)) +
  with_halftone(geom_ribbon(aes(ymin = lo, ymax = hi, fill = strata))) +
  with_halo(geom_step(aes(y = surv, colour = strata), linewidth = 0.35)) +
  geom_point(data = cens, aes(time, surv, colour = strata), shape = "|", size = 1.6, stroke = 0.4) +
  scale_y_continuous(labels = scales::percent, breaks = seq(0, 1, 0.25), expand = expansion(c(0, 0.02))) + xs + coord_cartesian(clip = "off") +
  guides(colour = "none") + labs(x = NULL, y = "Overall survival", fill = NULL, tag = "A") + th() +
  theme(legend.position = "inside", legend.position.inside = c(0.82, 0.86), plot.margin = margin(3, 3, 0, 3))
rtab <- ggplot(risk, aes(time, strata, label = n.risk, colour = strata)) + geom_text(size = 7 / .pt, family = "") +
  scale_y_discrete(limits = rev(levels(risk$strata))) + xs + coord_cartesian(clip = "off") + guides(colour = "none") +
  labs(x = "Days since diagnosis", y = NULL, subtitle = "Number at risk") + th() +
  theme(axis.line = element_blank(), axis.ticks = element_blank(), axis.text.y = element_text(size = 6), plot.subtitle = element_text(size = 6, margin = margin(b = 1)), plot.margin = margin(0, 3, 3, 3))
out("km", pA / rtab + plot_layout(heights = c(10, 2.4)), height = 78)

## 2 The same KM in one ink: line screens + linetypes --------------------------------------------------------------------
pK <- ggplot(s, aes(time, group = strata, screen = strata)) +
  with_halftone(geom_ribbon(aes(ymin = lo, ymax = hi), fill = "black"), shape = "line", pitch = 0.7) +   # hatched intervals are hairline by default; coarse because three hatches overlap
  with_halo(geom_step(aes(y = surv, linetype = strata), linewidth = 0.5), width = 0.2) +   # the line needs its own channel through the mesh
  geom_point(data = cens, aes(time, surv), shape = "|", size = 1.6, stroke = 0.4) +
  scale_screen_manual(values = c(45, 135, 0), name = NULL) + scale_linetype_manual(values = c("solid", "62", "22"), name = NULL) +   # long dashes: a short dash disappears into the hatch
  scale_y_continuous(labels = scales::percent, breaks = seq(0, 1, 0.25), expand = expansion(c(0, 0.02))) + xs + coord_cartesian(clip = "off") +
  labs(x = "Days since diagnosis", y = "Overall survival") + th() + theme(legend.position = "inside", legend.position.inside = c(0.82, 0.84), legend.key.size = unit(5, "mm"))
out("km_bw", pK)

## 3 Smooth with CI ---------------------------------------------------------------------------------------------------------
m <- mgcv::gam(accel ~ s(times, k = 20), data = mcycle); nd <- data.frame(times = seq(2.4, 57.6, length.out = 160)); pr <- predict(m, nd, se.fit = TRUE)
nd$fit <- pr$fit; nd$lo <- pr$fit - 1.96 * pr$se.fit; nd$hi <- pr$fit + 1.96 * pr$se.fit
pB <- ggplot(nd, aes(times)) + with_halftone(geom_ribbon(aes(ymin = lo, ymax = hi), fill = ink[["blue"]])) + with_halo(geom_line(aes(y = fit), colour = ink[["blue"]], linewidth = 0.35)) +
  geom_point(data = mcycle, aes(times, accel), shape = 21, fill = W, colour = "black", size = 0.8, stroke = 0.3) +
  labs(x = "Time after impact (ms)", y = "Head acceleration (g)") + th()
out("smooth", pB)

## 4 Densities, colour (vignette) and one ink (line screens) --------------------------------------------------------------
pD <- ggplot(iris, aes(Sepal.Length, fill = Species, group = Species)) + with_halftone(geom_density(linewidth = 0.25)) +
  labs(x = "Sepal length (cm)", y = "Density", fill = NULL) + th() + theme(legend.position = "inside", legend.position.inside = c(0.82, 0.85))
out("densities", pD)
pD2 <- ggplot(iris, aes(Sepal.Length, screen = Species, group = Species)) + with_halftone(geom_density(fill = "black", linewidth = 0.25), shape = "line") + scale_screen_discrete(name = NULL) +
  labs(x = "Sepal length (cm)", y = "Density") + th() + theme(legend.position = "inside", legend.position.inside = c(0.82, 0.85), legend.key.size = unit(5, "mm"))
out("densities_bw", pD2)

## 5 Bars: hatched (one ink) and dot-screened (colour) -------------------------------------------------------------------
d <- data.frame(g = factor(c("BOS", "RAS", "Mixed", "Undef."), c("BOS", "RAS", "Mixed", "Undef.")), n = c(52, 21, 14, 13))
pB1 <- ggplot(d, aes(g, n, screen = g)) + with_halftone(geom_col(width = 0.7, fill = "black", colour = "black", linewidth = 0.25), shape = "line") + scale_screen_discrete(guide = "none") +
  scale_y_continuous(expand = expansion(c(0, 0.08))) + labs(x = NULL, y = "Patients (%)") + th()
pB2 <- ggplot(d, aes(g, n, fill = g)) + with_halftone(geom_col(width = 0.7)) + guides(fill = "none") +
  scale_y_continuous(expand = expansion(c(0, 0.08))) + labs(x = NULL, y = "Patients (%)") + th()
out("bars", (pB1 + labs(tag = "A")) | (pB2 + labs(tag = "B")), width = "double", height = 60)

## 6 Stacked area, colour: each ink gets its own screen (angle x shape), as in print ---------------------------------------------------------------------------------------------------
tt <- 1:40; set.seed(4); s6 <- data.frame(t = tt, a = 10 + 4 * sin(tt / 5) + rnorm(40, 0, 0.6), b = 6 + tt / 6 + rnorm(40, 0, 0.5), c = 5 + 3 * cos(tt / 7) + rnorm(40, 0, 0.5))
long <- data.frame(t = rep(tt, 3), v = c(s6$a, s6$b, s6$c), series = rep(c("Series A", "Series B", "Series C"), each = 40))
# screens are assigned automatically to the fills (colour is redundant); the legend keys show both
pS <- ggplot(long, aes(t, v, fill = series)) + with_halftone(geom_area(colour = "black", linewidth = 0.25)) + scale_y_continuous(expand = c(0, 0)) + scale_x_continuous(expand = c(0, 0)) +
  labs(x = "Time", y = "Stacked value", fill = NULL) + th() + theme(legend.position = "bottom", legend.justification = "left")
out("area", pS)

## 7 Choropleth (default sepia ramp) --------------------------------------------------------------------------------------------
val <- setNames(USArrests$Murder, tolower(rownames(USArrests))); st <- map_data("state"); st$murder <- val[st$region]
pM <- ggplot(st, aes(long, lat, group = group, fill = murder)) + with_halftone(geom_polygon(colour = "black", linewidth = 0.2), angle = 45, grid = "square") +
  coord_map("albers", lat0 = 30, lat1 = 45) + labs(x = NULL, y = NULL, fill = "Murders\nper 100k") + th(theme_minimal) + theme(axis.ticks = element_blank(), axis.line = element_blank()) + theme(axis.text = element_blank())
out("map", pM, height = 58)

## 8 Elevation: colour dots, and engraving (line screen) with illuminated contours -----------------------------------------------------------------------
vol <- data.frame(expand.grid(x = seq_len(ncol(volcano)), y = seq_len(nrow(volcano))), z = as.vector(t(volcano)))
# gamma 1.5 rather than 0.6: below 1 it lifts the whole field toward the top of the register, so the plain printed as
# dark as the flanks and the dots barely changed size. Colour was carrying the elevation on its own and the screen
# was a tint. Above 1 the plain recedes and the dot does the work it is there to do. dot_max 1.0 buys the summit the
# ink to read as a summit. Hex rather than square at 45: on a continuous field the square lattice reads through as a
# criss-cross, which is the one thing a relief map should not have.
pE <- ggplot(vol, aes(x, y, z = z)) + geom_halftone(aes(colour = z), angle = 15, grid = "hex", gamma = 1.5, dot_max = 1.0) + with_halo(geom_contour(colour = "black", linewidth = 0.25, bins = 8)) +
  coord_equal(expand = FALSE) + labs(x = NULL, y = NULL, colour = "Elevation (m)") + th(theme_bw) + theme(axis.text = element_blank(), axis.ticks = element_blank())
pE2 <- ggplot(vol, aes(x, y, z = z)) + geom_halftone(shape = "line", colour = "black", angle = 30, gamma = 1.4) + with_relief(geom_contour(bins = 10)) +   # Tanaka: lit NW in paper, shaded SE in ink
  coord_equal(expand = FALSE) + labs(x = NULL, y = NULL) + th(theme_bw) + theme(axis.text = element_blank(), axis.ticks = element_blank())
out("elevation", (pE + labs(tag = "A")) | (pE2 + labs(tag = "B")), width = "double", height = 80)

## 9 Blue-noise stipple of a 2-D density, one contour -----------------------------------------------------------------------------
kd <- kde2d(faithful$eruptions, faithful$waiting, n = 150, lims = c(1.3, 5.6, 40, 100)); dens <- data.frame(expand.grid(x = kd$x, y = kd$y), z = as.vector(kd$z))
pN <- ggplot(dens, aes(x, y, z = z)) + geom_halftone(levels = 1, algorithm = "blue_noise", colour = "black") + with_halo(geom_contour(colour = "black", linewidth = 0.35, bins = 3)) +
  labs(x = "Eruption (min)", y = "Waiting (min)") + th(theme_bw)
out("stipple", pN)

## 10 Dot plot (geom_spot) ---------------------------------------------------------------------------------------------------------
set.seed(7); genes <- c("CD3E","CD8A","NKG7","MS4A1","CD79A","LYZ","S100A8","FCGR3A"); cl <- paste0("C", 1:6)
dp <- expand.grid(gene = genes, cluster = cl); dp$pct <- runif(nrow(dp), 0.05, 1); dp$expr <- rbeta(nrow(dp), 0.7, 1.8) * 3
for (i in seq_along(genes)) { j <- ((i - 1) %% 6) + 1; k <- which(dp$gene == genes[i] & dp$cluster == cl[j]); dp$pct[k] <- 0.9; dp$expr[k] <- 2.7 }
pP <- ggplot(dp, aes(cluster, gene, tone = expr, size = pct)) + geom_spot(colour = ink[["violet"]]) +
  scale_radius(range = c(1, 2.2), name = "Expressing", breaks = c(0.25, 0.5, 1), labels = scales::percent) + scale_tone(name = "Mean expression", breaks = c(0.5, 1.5, 2.5)) +
  labs(x = "Cluster", y = NULL) + th(theme_minimal) + theme(axis.ticks = element_blank(), axis.line = element_blank()) + theme(axis.ticks = element_blank(), axis.text.y = element_text(face = "italic"), legend.position = "bottom", legend.justification = "left", legend.key.size = unit(5.5, "mm"), legend.box = "vertical", legend.box.just = "left")
out("dotplot", pP, height = 70)
cat("gallery2 ok\n")
