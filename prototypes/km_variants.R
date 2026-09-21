options(halftone.style = "editorial")
source("geom_halftone.R", local = TRUE); source("theme_halftone.R", local = TRUE); source("halftone_helpers.R", local = TRUE)
library(patchwork); library(survival); ink <- halftone_inks; paper <- halftone_paper; inkc <- halftone_ink; mono <- "Inconsolata"
fit <- survfit(Surv(time, status) ~ ph.ecog, data = subset(lung, ph.ecog < 3))
s <- summary(fit, times = seq(0, 900, by = 5), extend = TRUE)
km <- data.frame(time = s$time, surv = s$surv, lo = s$lower, hi = s$upper, g = factor(s$strata, labels = c("ECOG 0", "ECOG 1", "ECOG 2")))
km$lo[is.na(km$lo)] <- 0; km$hi[is.na(km$hi)] <- km$surv[is.na(km$hi)]
cols <- c(`ECOG 0` = ink[["blue"]], `ECOG 1` = ink[["ochre"]], `ECOG 2` = ink[["red"]])
mkband <- function(profile, tone = 1) do.call(rbind, lapply(split(km, km$g), function(d) { b <- halftone_band(d$time, d$surv, d$lo, d$hi, ny = 220, ylim = c(0, 1), profile = profile); b$z <- b$z * tone; b$g <- d$g[1]; b }))
base <- function(ttl, sub) list(scale_colour_manual(values = cols, guide = "none"), scale_y_continuous(labels = scales::percent),
  labs(x = "DAYS", y = "SURVIVAL", title = ttl, subtitle = sub), theme_halftone(base_size = 10))
steps <- function(lw = 0.9, halo = TRUE) list(if (halo) geom_step(data = km, aes(time, surv, group = g), colour = paper, linewidth = lw + 1.4),
                                            geom_step(data = km, aes(time, surv, colour = g), linewidth = lw))
edges <- function() list(geom_step(data = km, aes(time, lo, colour = g), linewidth = 0.3, linetype = "11"), geom_step(data = km, aes(time, hi, colour = g), linewidth = 0.3, linetype = "11"))

# 1. current: tent profile, hex 1.0 mm
v1 <- ggplot() + geom_halftone(data = mkband("tent"), aes(x, y, z = z, colour = g), pitch = 1.0, grid = "hex", levels = 3, range = c(0, 1)) + steps(halo = FALSE) + base("1  Tent profile (current)", "DENSE CORE FADING TO EDGES  ·  1.0 MM HEX")
# 2. flat light screen + dotted edges + haloed estimate
v2 <- ggplot() + geom_halftone(data = mkband("flat", 0.3), aes(x, y, z = z, colour = g), pitch = 1.1, grid = "hex", levels = 1, range = c(0, 1), dot_max = 0.8) + edges() + steps() + base("2  Flat 30% screen", "UNIFORM LIGHT TONE  ·  DOTTED CI EDGES  ·  HALOED ESTIMATE")
# 3. coarse 45° screen, flat, no edges
v3 <- ggplot() + geom_halftone(data = mkband("flat", 0.45), aes(x, y, z = z, colour = g), pitch = 1.6, angle = 45, levels = 1, range = c(0, 1), dot_max = 0.85) + steps() + base("3  Coarse 45° screen", "1.6 MM PITCH READS AS A DELIBERATE SCREEN, NOT NOISE")
# 4. single ink, screen angle per stratum, colour only on the step line
b4 <- mkband("flat", 0.5); v4 <- ggplot()
for (k in 1:3) v4 <- v4 + geom_halftone(data = b4[b4$g == levels(km$g)[k], ], aes(x, y, z = z), pitch = 1.2, angle = c(0, 45, 90)[k], shape = c("circle", "circle", "square")[k], levels = 1, range = c(0, 1), dot_max = c(0.7, 0.75, 0.55)[k], colour = inkc, alpha = 0.55)
v4 <- v4 + steps() + base("4  One ink, three screens", "ANGLE/SHAPE PER STRATUM  ·  COLOUR ONLY ON ESTIMATES")
# 5. edge-weighted: density highest at CI edges, hollow around estimate (the inverse of 1)
b5 <- mkband("tent"); b5$z <- (1 - b5$z) * (b5$z > 0)
v5 <- ggplot() + geom_halftone(data = b5, aes(x, y, z = z, colour = g), pitch = 1.0, grid = "hex", levels = 3, range = c(0, 1)) + steps() + base("5  Edge-weighted", "DOTS DENSE AT THE CI LIMITS, OPEN AROUND THE ESTIMATE")
# 6. two strata only, gauss profile, generous pitch -- the best-case
km2 <- km[km$g != "ECOG 1", ]; b6 <- mkband("gauss"); b6 <- b6[b6$g != "ECOG 1", ]
v6 <- ggplot() + geom_halftone(data = b6, aes(x, y, z = z, colour = g), pitch = 1.3, grid = "hex", levels = 4, range = c(0, 1)) +
  geom_step(data = km2, aes(time, surv, group = g), colour = paper, linewidth = 2.2) + geom_step(data = km2, aes(time, surv, colour = g), linewidth = 0.9) +
  base("6  Two strata, gaussian, 1.3 mm", "IS THE PROBLEM THE PROFILE OR THE NUMBER OF STRATA?")
gal <- (v1 | v2 | v3) / (v4 | v5 | v6) + plot_annotation(theme = theme(plot.background = element_rect(fill = paper, colour = NA)))
ggsave("km_variants.png", gal, width = 16, height = 9, dpi = 140, bg = paper, device = ragg::agg_png); cat("ok\n")
