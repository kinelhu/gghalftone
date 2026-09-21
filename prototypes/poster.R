options(halftone.style = "editorial")
source("geom_halftone.R", local = TRUE); source("theme_halftone.R", local = TRUE); source("halftone_helpers.R", local = TRUE)
library(patchwork); library(survival); library(mgcv); library(grid)
ink <- halftone_inks; paper <- halftone_paper; inkc <- halftone_ink; mono <- "Inconsolata"; serif <- "EB Garamond"

## hero: KM by ECOG, big, hex halftone, direct labels, no legend
fit <- survfit(Surv(time, status) ~ ph.ecog, data = subset(lung, ph.ecog < 3))
s <- summary(fit, times = seq(0, 900, by = 5), extend = TRUE)
km <- data.frame(time = s$time, surv = s$surv, lo = s$lower, hi = s$upper, g = factor(s$strata, labels = c("ECOG 0", "ECOG 1", "ECOG 2")))
km$lo[is.na(km$lo)] <- 0; km$hi[is.na(km$hi)] <- km$surv[is.na(km$hi)]
band <- do.call(rbind, lapply(split(km, km$g), function(d) { b <- halftone_band(d$time, d$surv, d$lo, d$hi, ny = 260, ylim = c(0, 1)); b$g <- d$g[1]; b }))
cols <- c(`ECOG 0` = ink[["blue"]], `ECOG 1` = ink[["ochre"]], `ECOG 2` = ink[["red"]])
hero <- ggplot() +
  geom_halftone(data = band, aes(x, y, z = z, colour = g), pitch = 1.2, grid = "hex", levels = 3, range = c(0, 1), show.legend = FALSE) +
  geom_step(data = km, aes(time, surv, colour = g), linewidth = 1.1) +
  annotate("label", x = c(560, 620, 250), y = c(0.62, 0.36, 0.20), label = names(cols), colour = cols, fill = paper, label.size = 0, label.padding = unit(0.15, "lines"), family = mono, fontface = "bold", size = 3.6, hjust = 0) +
  scale_colour_manual(values = cols, guide = "none") +
  scale_y_continuous(labels = scales::percent, expand = expansion(c(0.01, 0.04))) + scale_x_continuous(expand = expansion(c(0.01, 0.02))) +
  labs(x = "DAYS SINCE DIAGNOSIS", y = "OVERALL SURVIVAL", title = NULL) +
  theme_halftone(base_size = 12)

## small multiples
m <- gam(accel ~ s(times, k = 20), data = MASS::mcycle); nd <- data.frame(times = seq(2.4, 57.6, length.out = 160)); pr <- predict(m, nd, se.fit = TRUE)
bd <- halftone_band(nd$times, pr$fit, pr$fit - 1.96 * pr$se.fit, pr$fit + 1.96 * pr$se.fit)
sm1 <- ggplot() + geom_halftone(data = bd, aes(x, y, z = z), pitch = 0.9, grid = "hex", levels = 3, colour = ink[["blue"]], range = c(0, 1)) +
  geom_line(data = nd, aes(times, pr$fit), colour = paper, linewidth = 1.6) + geom_line(data = nd, aes(times, pr$fit), colour = ink[["blue"]], linewidth = 0.7) +
  labs(x = "MS", y = "G", subtitle = "B  SMOOTH ± 95% CI") + theme_halftone(base_size = 9)

d4 <- data.frame(cat = c("BOS", "RAS", "Mixed", "Undef."), n = c(52, 21, 14, 13)); bars <- halftone_bars(d4$cat, d4$n, nx = 24, ny = 120, fade = 0.3)
sm2 <- ggplot() + geom_halftone(data = bars, aes(x, y, z = z, colour = cat), pitch = 1.0, shape = "square", levels = 4, dot_max = 0.9, range = c(0, 1), show.legend = FALSE) +
  scale_colour_manual(values = c(ink[["red"]], ink[["ochre"]], ink[["violet"]], ink[["grey"]])) +
  scale_x_continuous(breaks = 1:4, labels = d4$cat) + scale_y_continuous(expand = expansion(c(0, 0.1))) +
  labs(x = NULL, y = "%", subtitle = "C  CLAD PHENOTYPES") + theme_halftone(base_size = 9) + theme(axis.line.x = element_blank(), axis.ticks.x = element_blank())

set.seed(3); sp <- data.frame(x = rnorm(40), y = rnorm(40)); sp$z <- with(sp, exp(-(x^2 + y^2) / 2) + runif(40, 0, 0.2)); sp$r <- runif(40, 0.4, 1)
sm3 <- ggplot(sp, aes(x, y, z = z, size = r)) + geom_spot(pitch = 0.45, levels = 5, colour = ink[["green"]], ring_lwd = 0.3, show.legend = FALSE) +
  scale_radius(range = c(0.8, 2.4)) + labs(x = "PC1", y = "PC2", subtitle = "D  SPOTS: SIZE = N, TONE = SCORE") + theme_halftone(base_size = 9, axes = "box")

## text blocks as grobs
title_g <- textGrob("Halftone graphics for the\nprinted page", x = 0, hjust = 0, y = 0.98, vjust = 1, gp = gpar(fontfamily = serif, fontsize = 30, lineheight = 0.95, col = inkc))
byline  <- textGrob("A. AUTHOR, B. AUTHOR, C. AUTHOR  ·  LUNG TRANSPLANT PROGRAMME  ·  2026", x = 0, hjust = 0, y = 0.98, vjust = 1, gp = gpar(fontfamily = mono, fontsize = 9, col = inkc))
body <- paste(strwrap(paste("Continuous uncertainty is usually drawn as a translucent ribbon, which fails in greyscale and turns to mud where",
  "strata overlap. Rendering the confidence region as a halftone screen (A) keeps the estimate crisp, lets bands interleave",
  "rather than blend, and survives photocopying. Dot pitch is physical (1.2 mm) so the figure re-flows correctly at any print size.",
  "The same geometry gives smooth bands (B), tonal bar fills (C) and per-point tone discs (D)."), 46), collapse = "\n")
body_g <- textGrob(body, x = 0, hjust = 0, y = 1, vjust = 1, gp = gpar(fontfamily = serif, fontsize = 11, lineheight = 1.15, col = inkc))
rule <- linesGrob(x = c(0, 1), y = c(0.5, 0.5), gp = gpar(col = inkc, lwd = 1.2))
capA <- textGrob("A  OVERALL SURVIVAL BY PERFORMANCE STATUS, 95% CI AS HEX HALFTONE  ·  NCCTG LUNG, N = 226", x = 0, hjust = 0, gp = gpar(fontfamily = mono, fontsize = 8, col = inkc))

layout <- c(
  area(1, 1, 5, 6),   # title
  area(6, 1, 6, 13),  # rule
  area(7, 1, 21, 13), # hero
  area(22, 1, 22, 13),# caption
  area(1, 8, 3, 13),  # byline
  area(24, 1, 36, 4), # body
  area(24, 5, 36, 7), area(24, 8, 36, 10), area(24, 11, 36, 13))
page <- wrap_elements(title_g) + wrap_elements(rule) + hero + wrap_elements(capA) + wrap_elements(byline) + wrap_elements(body_g) + sm1 + sm2 + sm3 +
  plot_layout(design = layout) & theme(plot.background = element_rect(fill = paper, colour = NA))
ggsave("poster.png", page, width = 297, height = 250, units = "mm", dpi = 130, bg = paper, device = ragg::agg_png)
cat("poster ok\n")
