options(halftone.style = "editorial")
source("geom_halftone.R", local = TRUE); source("theme_halftone.R", local = TRUE); source("halftone_helpers.R", local = TRUE)
library(patchwork); library(survival); ink <- halftone_inks; paper <- halftone_paper; inkc <- halftone_ink; mono <- "Inconsolata"
fit <- survfit(Surv(time, status) ~ ph.ecog, data = subset(lung, ph.ecog < 3))
s <- summary(fit, times = seq(0, 900, by = 4), extend = TRUE)
km <- data.frame(time = s$time, surv = s$surv, lo = s$lower, hi = s$upper, g = factor(s$strata, labels = c("ECOG 0", "ECOG 1", "ECOG 2")))
km$lo[is.na(km$lo)] <- 0; km$hi[is.na(km$hi)] <- km$surv[is.na(km$hi)]
cols <- c(`ECOG 0` = ink[["blue"]], `ECOG 1` = ink[["ochre"]], `ECOG 2` = ink[["red"]])
mkband <- function(profile, f = identity) do.call(rbind, lapply(split(km, km$g), function(d) { b <- halftone_band(d$time, d$surv, d$lo, d$hi, ny = 260, ylim = c(0, 1), profile = profile); b$z <- f(b$z); b$g <- d$g[1]; b }))
common <- function(ttl, sub) list(
  geom_step(data = km, aes(time, surv, group = g), colour = paper, linewidth = 2.6), geom_step(data = km, aes(time, surv, colour = g), linewidth = 1.0),
  annotate("label", x = c(560, 660, 250), y = c(0.64, 0.30, 0.18), label = names(cols), colour = cols, fill = paper, label.size = 0, label.padding = unit(0.12, "lines"), family = mono, fontface = "bold", size = 3.1, hjust = 0),
  scale_colour_manual(values = cols, guide = "none"), scale_y_continuous(labels = scales::percent, breaks = seq(0, 1, 0.25), expand = expansion(c(0, 0.03))),
  scale_x_continuous(breaks = seq(0, 750, 250), limits = c(-10, 920), expand = c(0, 0)),
  labs(x = "DAYS", y = "OVERALL SURVIVAL", title = ttl, subtitle = sub), theme_halftone(base_size = 10))
mk <- function(b, ttl, sub, pitch = 1.2, levels = 4, grid = "hex", angle = 0, blend = "mix") ggplot() + geom_halftone(data = b, aes(x, y, z = z, colour = g), pitch = pitch, grid = grid, angle = angle, levels = levels, range = c(0, 1), dot_max = 0.9, overlap = "overprint", blend = blend) + common(ttl, sub)
A <- mk(mkband("gauss"), "A  Gaussian + overprint", "TONE PEAKS ON THE ESTIMATE  ·  OVERLAPS BLEND  ·  1.2 MM HEX")
B <- mk(mkband("gauss"), "B  Gaussian + alternate", "OVERLAP AS A TWO-INK WEAVE, NO MUD", blend = "alternate")
C <- mk(mkband("gauss"), "C  45° square + alternate", "ROTATED SQUARE LATTICE, 1.1 MM, WOVEN OVERLAP", pitch = 1.1, angle = 45, grid = "square", blend = "alternate")
D <- mk(mkband("gauss"), "D  45° square + mix", "SAME LATTICE, BLENDED OVERLAP", pitch = 1.1, angle = 45, grid = "square")
zoom <- function(p) p + coord_cartesian(xlim = c(380, 900), ylim = c(0, 0.5)) + labs(title = NULL, subtitle = "ZOOM 380–900 DAYS", x = NULL, y = NULL)
gal <- (A | B | C | D) / (zoom(A) | zoom(B) | zoom(C) | zoom(D)) + plot_layout(heights = c(1.4, 1)) + plot_annotation(theme = theme(plot.background = element_rect(fill = paper, colour = NA)))
ggsave("km_tonal.png", gal, width = 20, height = 9, dpi = 130, bg = paper, device = ragg::agg_png); cat("ok\n")
