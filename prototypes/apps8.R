options(halftone.style = "editorial")
source("geom_halftone.R", local = TRUE); source("theme_halftone.R", local = TRUE); source("halftone_helpers.R", local = TRUE)
library(patchwork); library(survival); ink <- halftone_inks; paper <- halftone_paper; inkc <- halftone_ink; mono <- "Inconsolata"

## 1. one ink, three screens -- now ONE layer with aes(screen = series)
tt <- 1:40; set.seed(4)
s6 <- data.frame(t = tt, a = 10 + 4 * sin(tt / 5) + rnorm(40, 0, 0.6), b = 6 + tt / 6 + rnorm(40, 0, 0.5), c = 5 + 3 * cos(tt / 7) + rnorm(40, 0, 0.5))
cum <- with(s6, cbind(0, a, a + b, a + b + c)); nms <- c("Series A", "Series B", "Series C")
f6 <- do.call(rbind, lapply(1:3, function(k) { b <- halftone_band(tt, (cum[, k] + cum[, k + 1]) / 2, cum[, k], cum[, k + 1], profile = "flat", ny = 220, ylim = c(0, max(cum) * 1.02)); b$series <- nms[k]; b }))
p1 <- ggplot() +
  geom_halftone(data = f6, aes(x, y, z = z, screen = series), pitch = 1.0, levels = 1, dot_max = 0.62, colour = inkc, range = c(0, 1)) +
  scale_screen_discrete(name = NULL) +
  lapply(2:4, function(k) list(geom_line(data = data.frame(t = tt, y = cum[, k]), aes(t, y), colour = paper, linewidth = 1.6), geom_line(data = data.frame(t = tt, y = cum[, k]), aes(t, y), colour = inkc, linewidth = 0.5))) +
  scale_y_continuous(expand = c(0, 0)) + scale_x_continuous(expand = c(0, 0)) +
  labs(x = "TIME", y = "STACKED VALUE", title = "aes(screen = series)", subtitle = "ONE LAYER, ONE INK  ·  scale_screen_discrete() AT 0° / 30° / 60°  ·  LEGEND KEYS ROTATE") +
  theme_halftone() + theme(legend.position = "top", legend.justification = "left", legend.key.size = unit(6, "mm"))

## 2. the KM, black & white edition: strata by screen angle, colour-free
fit <- survfit(Surv(time, status) ~ ph.ecog, data = subset(lung, ph.ecog < 3))
s <- summary(fit, times = seq(0, 900, by = 4), extend = TRUE)
km <- data.frame(time = s$time, surv = s$surv, lo = s$lower, hi = s$upper, g = factor(s$strata, labels = c("ECOG 0", "ECOG 1", "ECOG 2")))
km$lo[is.na(km$lo)] <- 0; km$hi[is.na(km$hi)] <- km$surv[is.na(km$hi)]
band <- do.call(rbind, lapply(split(km, km$g), function(d) { b <- halftone_band(d$time, d$surv, d$lo, d$hi, ny = 260, ylim = c(0, 1), profile = "gauss"); b$z <- b$z * 0.5; b$g <- d$g[1]; b }))
p2 <- ggplot() +
  geom_halftone(data = band, aes(x, y, z = z, screen = g), pitch = 1.4, levels = 3, colour = inkc, range = c(0, 1), dot_max = 0.8, alpha = 0.75) +
  scale_screen_manual(values = c(0, 45, 90), name = NULL) +
  geom_step(data = km, aes(time, surv, group = g), colour = paper, linewidth = 2.6) +
  geom_step(data = km, aes(time, surv, group = g, linetype = g), colour = inkc, linewidth = 0.9) +
  scale_linetype_manual(values = c("solid", "22", "11"), name = NULL) +
  scale_y_continuous(labels = scales::percent, breaks = seq(0, 1, 0.25), expand = expansion(c(0, 0.03))) +
  scale_x_continuous(breaks = seq(0, 750, 250), limits = c(-10, 920), expand = c(0, 0)) +
  labs(x = "DAYS", y = "OVERALL SURVIVAL", title = "Kaplan–Meier, one ink", subtitle = "SCREEN ANGLE + LINE TYPE, TONE CAPPED AT 50%  ·  NO COLOUR ANYWHERE") +
  theme_halftone() + theme(legend.position = c(0.8, 0.8), legend.key.size = unit(6, "mm")) + guides(screen = "none")

gal <- (p1 | p2) + plot_annotation(theme = theme(plot.background = element_rect(fill = paper, colour = NA)))
ggsave("gallery8.png", gal, width = 13, height = 5.8, dpi = 150, bg = paper, device = ragg::agg_png); cat("ok\n")
