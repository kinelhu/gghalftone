source("geom_halftone.R", local = TRUE); source("theme_halftone.R", local = TRUE); source("halftone_helpers.R", local = TRUE)
library(patchwork); library(survival); library(mgcv); ink <- halftone_inks
# Figure 1, double column (183 mm): A KM with risk table | B smooth ± CI | C dot plot
fit <- survfit(Surv(time, status) ~ ph.ecog, data = subset(lung, ph.ecog < 3))
s <- summary(fit, times = seq(0, 900, by = 4), extend = TRUE)
km <- data.frame(time = s$time, surv = s$surv, lo = s$lower, hi = s$upper, g = factor(s$strata, labels = c("ECOG 0", "ECOG 1", "ECOG 2")))
km$lo[is.na(km$lo)] <- 0; km$hi[is.na(km$hi)] <- km$surv[is.na(km$hi)]
cols <- c(`ECOG 0` = ink[["blue"]], `ECOG 1` = ink[["ochre"]], `ECOG 2` = ink[["red"]])
band <- do.call(rbind, lapply(split(km, km$g), function(d) { b <- halftone_band(d$time, d$surv, d$lo, d$hi, ny = 240, ylim = c(0, 1), profile = "gauss"); b$g <- d$g[1]; b }))
rk <- summary(fit, times = seq(0, 750, 250)); rt <- data.frame(time = rk$time, n = rk$n.risk, g = factor(rk$strata, labels = names(cols)))
pA <- ggplot() +
  geom_halftone(data = band, aes(x, y, z = z, colour = g), pitch = 0.55, grid = "hex", levels = 6, range = c(0, 1), dot_max = 0.92) +
  geom_step(data = km, aes(time, surv, group = g), colour = "white", linewidth = 0.9, lineend = "round") + geom_step(data = km, aes(time, surv, colour = g), linewidth = 0.55, lineend = "round") +
  scale_colour_manual(values = cols, name = NULL) +
  scale_y_continuous(labels = scales::percent, breaks = seq(0, 1, 0.25), expand = expansion(c(0, 0.02))) +
  scale_x_continuous(breaks = seq(0, 750, 250), limits = c(-5, 910), expand = c(0, 0)) + coord_cartesian(clip = "off") +
  labs(x = NULL, y = "Overall survival", tag = "A") + theme_halftone() + theme(legend.position = c(0.8, 0.87), legend.key.size = unit(3, "mm"), plot.margin = margin(3, 3, 0, 3))
rtab <- ggplot(rt, aes(time, g, label = n, colour = g)) + geom_text(size = 7 / .pt, family = "Liberation Sans") + scale_colour_manual(values = cols, guide = "none") +
  scale_y_discrete(limits = rev(names(cols))) + scale_x_continuous(breaks = seq(0, 750, 250), limits = c(-5, 910), expand = c(0, 0)) + coord_cartesian(clip = "off") +
  labs(x = "Days since diagnosis", y = NULL, subtitle = "Number at risk") + theme_halftone() +
  theme(axis.line = element_blank(), axis.ticks = element_blank(), axis.text.y = element_text(size = 6), plot.subtitle = element_text(size = 6, margin = margin(b = 1)), plot.margin = margin(0, 3, 3, 3))
A <- pA / rtab + plot_layout(heights = c(10, 2.2))

m <- gam(accel ~ s(times, k = 20), data = MASS::mcycle); nd <- data.frame(times = seq(2.4, 57.6, length.out = 160)); pr <- predict(m, nd, se.fit = TRUE)
bd <- halftone_band(nd$times, pr$fit, pr$fit - 1.96 * pr$se.fit, pr$fit + 1.96 * pr$se.fit)
B <- ggplot() + geom_halftone(data = bd, aes(x, y, z = z), pitch = 0.5, grid = "hex", levels = 5, colour = ink[["blue"]], range = c(0, 1)) +
  geom_line(data = nd, aes(times, pr$fit), colour = "white", linewidth = 0.85) + geom_line(data = nd, aes(times, pr$fit), colour = ink[["blue"]], linewidth = 0.5) +
  geom_point(data = MASS::mcycle, aes(times, accel), shape = 21, fill = "white", colour = "black", size = 0.8, stroke = 0.3) +
  labs(x = "Time after impact (ms)", y = "Head acceleration (g)", tag = "B") + theme_halftone()

set.seed(7); genes <- c("CD3E","CD8A","NKG7","MS4A1","CD79A","LYZ","S100A8","FCGR3A"); cl <- paste0("C", 1:6)
dp <- expand.grid(gene = genes, cluster = cl); dp$pct <- runif(nrow(dp), 0.05, 1); dp$expr <- rbeta(nrow(dp), 0.7, 1.8) * 3
for (i in seq_along(genes)) { j <- ((i - 1) %% 6) + 1; k <- which(dp$gene == genes[i] & dp$cluster == cl[j]); dp$pct[k] <- 0.9; dp$expr[k] <- 2.7 }
C <- ggplot(dp, aes(cluster, gene, z = expr, size = pct)) + geom_spot(pitch = 0.35, levels = 5, colour = ink[["violet"]], ring_lwd = 0.3, range = c(0, 3)) +
  scale_radius(range = c(0.5, 1.9), name = "Expressing", breaks = c(0.25, 0.5, 1), labels = scales::percent) +
  labs(x = "Cluster", y = NULL, tag = "C") + theme_halftone(axes = "none") + theme(axis.ticks = element_blank(), axis.text.y = element_text(face = "italic"), legend.position = "bottom", legend.justification = "left", legend.key.size = unit(3.5, "mm"))

fig <- (A | B | C) + plot_layout(widths = c(1.25, 1, 0.9))
ggsave_journal("fig1_double.png", fig, "double", height = 78, dpi = 600)
ggsave_journal("fig1_single.png", A, "single", height = 75, dpi = 600)
cat("ok\n")
