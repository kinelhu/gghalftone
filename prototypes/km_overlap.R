options(halftone.style = "editorial")
source("geom_halftone.R", local = TRUE); source("theme_halftone.R", local = TRUE); source("halftone_helpers.R", local = TRUE)
library(patchwork); library(survival); ink <- halftone_inks; paper <- halftone_paper; inkc <- halftone_ink; mono <- "Inconsolata"
fit <- survfit(Surv(time, status) ~ ph.ecog, data = subset(lung, ph.ecog < 3))
s <- summary(fit, times = seq(0, 900, by = 5), extend = TRUE)
km <- data.frame(time = s$time, surv = s$surv, lo = s$lower, hi = s$upper, g = factor(s$strata, labels = c("ECOG 0", "ECOG 1", "ECOG 2")))
km$lo[is.na(km$lo)] <- 0; km$hi[is.na(km$hi)] <- km$surv[is.na(km$hi)]
cols <- c(`ECOG 0` = ink[["blue"]], `ECOG 1` = ink[["ochre"]], `ECOG 2` = ink[["red"]])
band <- do.call(rbind, lapply(split(km, km$g), function(d) { b <- halftone_band(d$time, d$surv, d$lo, d$hi, ny = 220, ylim = c(0, 1), profile = "flat"); b$z <- b$z * 0.3; b$g <- d$g[1]; b }))
common <- function(ttl, sub) list(
  geom_step(data = km, aes(time, surv, group = g), colour = paper, linewidth = 2.4), geom_step(data = km, aes(time, surv, colour = g), linewidth = 1.0),
  scale_colour_manual(values = cols, guide = "none"), scale_y_continuous(labels = scales::percent, breaks = seq(0, 1, 0.25), expand = expansion(c(0, 0.03))),
  scale_x_continuous(breaks = seq(0, 750, 250), limits = c(-10, 920), expand = c(0, 0)),
  labs(x = "DAYS", y = "OVERALL SURVIVAL", title = ttl, subtitle = sub), theme_halftone(base_size = 10))
mk <- function(mode, ttl, sub, blend = "mix") ggplot() + geom_halftone(data = band, aes(x, y, z = z, colour = g), pitch = 1.25, grid = "hex", levels = 1, range = c(0, 1), dot_max = 0.85, overlap = mode, blend = blend) + common(ttl, sub)
A <- mk("overprint", "overprint, blend = multiply", "PRINT-FAITHFUL: INKS MULTIPLY, OVERLAP GOES DARK", "multiply")
B <- mk("interleave", "interleave", "PHASE-SHIFTED LATTICE PER STRATUM  ·  BOTH INKS VISIBLE IN OVERLAP")
C <- mk("overprint", "overprint, blend = mix (default)", "AVERAGED INK, DARKENED  ·  OVERLAP READS AS A THIRD TONE")
# zoom on the crossing region
zoom <- function(p) p + coord_cartesian(xlim = c(380, 900), ylim = c(0, 0.5)) + labs(title = NULL, subtitle = "ZOOM 380–900 DAYS", x = NULL, y = NULL)
gal <- (A | B | C) / (zoom(A) | zoom(B) | zoom(C)) + plot_layout(heights = c(1.4, 1)) + plot_annotation(theme = theme(plot.background = element_rect(fill = paper, colour = NA)))
ggsave("km_overlap.png", gal, width = 16, height = 9, dpi = 145, bg = paper, device = ragg::agg_png); cat("ok\n")
