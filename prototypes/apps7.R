options(halftone.style = "editorial")
source("geom_halftone.R", local = TRUE); source("theme_halftone.R", local = TRUE); source("halftone_helpers.R", local = TRUE); source("halftone_raster.R", local = TRUE)
library(patchwork); library(survival); library(mgcv); library(MASS)
ink <- halftone_inks; paper <- halftone_paper; inkc <- halftone_ink; mono <- "Inconsolata"

## 1. Dot plot revisited: size aes = radius via scale_radius -> real legend; tone legend inset
set.seed(7); genes <- c("CD3E","CD8A","NKG7","MS4A1","CD79A","LYZ","S100A8","FCGR3A","PPBP","HBB"); cl <- paste0("C", 1:8)
dp <- expand.grid(gene = genes, cluster = cl); dp$pct <- runif(nrow(dp), 0.05, 1); dp$expr <- rbeta(nrow(dp), 0.7, 1.8) * 3
for (i in seq_along(genes)) { j <- ((i - 1) %% 8) + 1; k <- which(dp$gene == genes[i] & dp$cluster == cl[j]); dp$pct[k] <- 0.9; dp$expr[k] <- 2.6 + runif(1, 0, 0.4) }
p1 <- ggplot(dp, aes(cluster, gene, z = expr, size = pct)) +
  geom_spot(pitch = 0.5, levels = 6, colour = ink[["violet"]], ring_lwd = 0.4, range = c(0, 3)) +
  scale_radius(range = c(0.8, 3), name = "% EXPRESSING", breaks = c(0.25, 0.5, 1), labels = scales::percent) +
  labs(x = "CLUSTER", y = NULL, title = "Marker dot plot", subtitle = "scale_radius() DRIVES DISC SIZE  ·  TONE LEGEND INSET") +
  theme_halftone(axes = "none") + theme(axis.ticks = element_blank(), axis.text.y = element_text(face = "italic", family = "EB Garamond", size = rel(1)), legend.position = "right", legend.justification = "top")
p1 <- p1 + inset_element(halftone_tone_legend("MEAN EXPR", c("0", "3"), colour = ink[["violet"]]), left = 0.78, bottom = 0.0, right = 1.0, top = 0.22, align_to = "full")

## 2. Legend keys: geom_halftone bands now have swatch keys (no more override.aes tricks)
fit <- survfit(Surv(time, status) ~ ph.ecog, data = subset(lung, ph.ecog < 3))
s <- summary(fit, times = seq(0, 900, by = 6), extend = TRUE)
km <- data.frame(time = s$time, surv = s$surv, lo = s$lower, hi = s$upper, ecog = factor(s$strata, labels = c("ECOG 0", "ECOG 1", "ECOG 2")))
km$lo[is.na(km$lo)] <- 0; km$hi[is.na(km$hi)] <- km$surv[is.na(km$hi)]
band <- do.call(rbind, lapply(split(km, km$ecog), function(d) { b <- halftone_band(d$time, d$surv, d$lo, d$hi, ny = 200, ylim = c(0, 1)); b$ecog <- d$ecog[1]; b }))
p2 <- ggplot() +
  geom_halftone(data = band, aes(x, y, z = z, colour = ecog), pitch = 1.0, grid = "hex", levels = 3, range = c(0, 1)) +
  geom_step(data = km, aes(time, surv, colour = ecog), linewidth = 0.8) +
  scale_colour_manual(values = c(ink[["blue"]], ink[["ochre"]], ink[["red"]]), name = NULL) +
  scale_y_continuous(labels = scales::percent) +
  labs(x = "DAYS", y = "SURVIVAL", title = "Three strata, swatch keys", subtitle = "draw_key_halftone() IN THE LEGEND  ·  NCCTG LUNG BY ECOG") +
  theme_halftone() + theme(legend.position = c(0.82, 0.8), legend.key.size = unit(5, "mm"))

## 3. Dot gain: same field, gain 0 vs 0.35 -- the "wet ink" look
vol <- data.frame(expand.grid(x = seq_len(ncol(volcano)), y = seq_len(nrow(volcano))), z = as.vector(t(volcano)))
mk <- function(gain, ttl) ggplot(vol, aes(x, y, z = z)) + geom_halftone(pitch = 1.3, angle = 45, levels = 6, colour = inkc, gain = gain, dot_max = 0.9) +
  coord_equal(expand = FALSE) + labs(title = ttl, x = NULL, y = NULL) + theme_halftone(axes = "box") + theme(axis.text = element_blank(), axis.ticks = element_blank(), plot.title = element_text(size = rel(1.1)))
p3a <- mk(0, "Dot gain = 0") + labs(subtitle = "REFERENCE"); p3b <- mk(0.35, "Dot gain = 0.35") + labs(subtitle = "INK SPREADS WITH TONE")

## 4. Spots with mapped radius + tone on a map: quakes (Fiji), radius = magnitude, tone = depth
q <- quakes[sample(nrow(quakes), 220), ]
p4 <- ggplot(q, aes(long, lat, z = depth, size = mag)) +
  geom_spot(pitch = 0.45, levels = 5, colour = ink[["red"]], ring_lwd = 0.35, alpha = 0.9) +
  scale_radius(range = c(0.9, 3.4), name = "MAGNITUDE", breaks = c(4, 5, 6)) +
  coord_quickmap() + labs(x = NULL, y = NULL, title = "Seismic events", subtitle = "FIJI 1964–  ·  RADIUS = MAGNITUDE, TONE = DEPTH") +
  theme_halftone(axes = "box") + theme(legend.position = "right", legend.justification = "top")
p4 <- p4 + inset_element(halftone_tone_legend("DEPTH (KM)", c("40", "680"), colour = ink[["red"]]), left = 0.78, bottom = 0, right = 1, top = 0.22, align_to = "full")

gal <- ((p1 | p2) / (p3a | p3b | p4 + plot_layout(widths = c(1, 1, 2)))) + plot_annotation(theme = theme(plot.background = element_rect(fill = paper, colour = NA)))
ggsave("gallery7.png", gal, width = 13, height = 11, dpi = 150, bg = paper, device = ragg::agg_png)
cat("gallery ok\n")
