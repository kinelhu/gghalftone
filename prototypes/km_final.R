options(halftone.style = "editorial")
source("geom_halftone.R", local = TRUE); source("theme_halftone.R", local = TRUE); source("halftone_helpers.R", local = TRUE)
library(patchwork); library(survival); ink <- halftone_inks; paper <- halftone_paper; inkc <- halftone_ink; mono <- "Inconsolata"
fit <- survfit(Surv(time, status) ~ ph.ecog, data = subset(lung, ph.ecog < 3))
s <- summary(fit, times = seq(0, 900, by = 5), extend = TRUE)
km <- data.frame(time = s$time, surv = s$surv, lo = s$lower, hi = s$upper, g = factor(s$strata, labels = c("ECOG 0", "ECOG 1", "ECOG 2")))
km$lo[is.na(km$lo)] <- 0; km$hi[is.na(km$hi)] <- km$surv[is.na(km$hi)]
cols <- c(`ECOG 0` = ink[["blue"]], `ECOG 1` = ink[["ochre"]], `ECOG 2` = ink[["red"]])
mkband <- function(profile, tone = 1) do.call(rbind, lapply(split(km, km$g), function(d) { b <- halftone_band(d$time, d$surv, d$lo, d$hi, ny = 220, ylim = c(0, 1), profile = profile); b$z <- b$z * tone; b$g <- d$g[1]; b }))
risk <- summary(fit, times = seq(0, 750, by = 250))
rt <- data.frame(time = risk$time, n = risk$n.risk, g = factor(risk$strata, labels = names(cols)))
common <- function(ttl, sub) list(
  geom_step(data = km, aes(time, surv, group = g), colour = paper, linewidth = 2.4),
  geom_step(data = km, aes(time, surv, colour = g), linewidth = 1.0),
  annotate("label", x = c(560, 640, 250), y = c(0.62, 0.36, 0.20), label = names(cols), colour = cols, fill = paper, label.size = 0, family = mono, fontface = "bold", size = 3.2, hjust = 0),
  scale_colour_manual(values = cols, guide = "none"),
  scale_y_continuous(labels = scales::percent, breaks = seq(0, 1, 0.25), expand = expansion(c(0, 0.03))),
  scale_x_continuous(breaks = seq(0, 750, 250), limits = c(-10, 920), expand = c(0, 0)),
  labs(x = NULL, y = "OVERALL SURVIVAL", title = ttl, subtitle = sub),
  theme_halftone(base_size = 10), theme(plot.margin = margin(12, 14, 2, 12)))
risk_tab <- ggplot(rt, aes(time, g, label = n, colour = g)) + geom_text(family = mono, size = 2.8) +
  scale_colour_manual(values = cols, guide = "none") + scale_y_discrete(limits = rev(names(cols))) +
  scale_x_continuous(breaks = seq(0, 750, 250), limits = c(-10, 920), expand = c(0, 0)) +
  labs(x = "DAYS SINCE DIAGNOSIS", y = NULL, subtitle = "NUMBER AT RISK") +
  theme_halftone(base_size = 10) + theme(axis.line = element_blank(), axis.ticks = element_blank(), axis.text.y = element_text(size = rel(0.75)),
        plot.subtitle = element_text(size = rel(0.7), margin = margin(b = 2)), plot.margin = margin(0, 14, 10, 12))
A <- ggplot() + geom_halftone(data = mkband("flat", 0.28), aes(x, y, z = z, colour = g), pitch = 1.25, grid = "hex", levels = 1, range = c(0, 1), dot_max = 0.85) +
  common("A  Flat screen", "UNIFORM 28% TONE INSIDE THE 95% CI  ·  1.25 MM HEX")
b5 <- mkband("tent"); b5$z <- ((1 - b5$z) * (b5$z > 0))^1.6
B <- ggplot() + geom_halftone(data = b5, aes(x, y, z = z, colour = g), pitch = 1.25, grid = "hex", levels = 3, range = c(0, 1), dot_max = 0.85) +
  common("B  Edge-weighted", "INK CONCENTRATED AT THE CI LIMITS, OPEN AROUND THE ESTIMATE")
A <- A / risk_tab + plot_layout(heights = c(10, 2)); B <- B / risk_tab + plot_layout(heights = c(10, 2))

## seismic, rebuilt: column layout with the tone legend below, no inset, no fixed-aspect fight
q <- quakes[sample(nrow(quakes), 220), ]
S <- ggplot(q, aes(long, lat, z = depth, size = mag)) +
  geom_spot(pitch = 0.5, levels = 5, colour = ink[["red"]], ring_lwd = 0.35, alpha = 0.85) +
  scale_radius(range = c(1, 3.6), name = "MAGNITUDE", breaks = c(4, 5, 6)) +
  coord_fixed(ratio = 1.05) + scale_x_continuous(breaks = seq(165, 185, 5)) +
  labs(x = "LONGITUDE", y = "LATITUDE", title = "Seismic events", subtitle = "FIJI REGION  ·  RADIUS = MAGNITUDE, TONE = DEPTH") +
  theme_halftone(base_size = 10, axes = "box") + theme(legend.position = "right", legend.justification = "top")
S <- S / halftone_tone_legend("DEPTH (KM)", c("40", "680"), colour = ink[["red"]]) + plot_layout(heights = c(10, 1.4))

gal <- (A | B | S) + plot_layout(widths = c(1.2, 1.2, 1)) + plot_annotation(theme = theme(plot.background = element_rect(fill = paper, colour = NA)))
ggsave("km_final.png", gal, width = 17, height = 6.5, dpi = 150, bg = paper, device = ragg::agg_png); cat("ok\n")
