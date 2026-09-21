options(halftone.style = "journal"); source("geom_halftone.R", local = TRUE); source("theme_halftone.R", local = TRUE); source("halftone_helpers.R", local = TRUE)
library(survival); ink <- halftone_inks
## A engraving: volcano with line screen following elevation
vol <- data.frame(expand.grid(x = seq_len(ncol(volcano)), y = seq_len(nrow(volcano))), z = as.vector(t(volcano)))
A <- ggplot(vol, aes(x, y, z = z)) + geom_halftone(pitch = 0.45, angle = 30, shape = "line", colour = "black", gamma = 1.4, dot_max = 1) +
  geom_contour(aes(x, y, z = z), colour = "white", linewidth = 0.5, bins = 8) + geom_contour(aes(x, y, z = z), colour = "black", linewidth = 0.2, bins = 8) +
  coord_equal(expand = FALSE) + labs(x = NULL, y = NULL, tag = "A") + theme_halftone(axes = "box") + theme(axis.text = element_blank(), axis.ticks = element_blank())
## B crosshatch KM: strata by hatch angle, one ink
fit <- survfit(Surv(time, status) ~ ph.ecog, data = subset(lung, ph.ecog < 3)); s <- summary(fit, times = seq(0, 900, by = 3), extend = TRUE)
km <- data.frame(time = s$time, surv = s$surv, lo = s$lower, hi = s$upper, g = factor(s$strata, labels = c("ECOG 0", "ECOG 1", "ECOG 2")))
km$lo[is.na(km$lo)] <- 0; km$hi[is.na(km$hi)] <- km$surv[is.na(km$hi)]
band <- do.call(rbind, lapply(split(km, km$g), function(d) { b <- halftone_band(d$time, d$surv, d$lo, d$hi, ny = 300, ylim = c(0, 1), profile = "flat"); b$z <- b$z * 0.35; b$g <- d$g[1]; b }))
B <- ggplot() + geom_halftone(data = band, aes(x, y, z = z, screen = g), pitch = 0.6, shape = "line", colour = "black", range = c(0, 1), dot_max = 0.6) +
  scale_screen_manual(values = c(0, 60, 120), name = NULL) +
  geom_step(data = km, aes(time, surv, group = g), colour = "white", linewidth = 1.2) + geom_step(data = km, aes(time, surv, group = g, linetype = g), colour = "black", linewidth = 0.6) +
  scale_linetype_manual(values = c("solid", "22", "11"), name = NULL) +
  scale_y_continuous(labels = scales::percent) + scale_x_continuous(breaks = seq(0, 750, 250), limits = c(-5, 910), expand = c(0, 0)) +
  labs(x = "Days", y = "Overall survival", tag = "B") + theme_halftone() + theme(legend.position = c(0.82, 0.82), legend.key.size = unit(5, "mm")) + guides(screen = "none")
## C hatched bars (classic)
d <- data.frame(g = c("BOS", "RAS", "Mixed", "Undef."), n = c(52, 21, 14, 13)); bars <- halftone_bars(d$g, d$n, nx = 40, ny = 200, fade = 1)
C <- ggplot() + geom_halftone(data = bars, aes(x, y, z = z, screen = cat), pitch = 0.6, shape = "line", colour = "black", range = c(0, 1), dot_max = 0.45) +
  scale_screen_manual(values = c(45, 135, 0, 90), guide = "none") + annotate("rect", xmin = 1:4 - 0.4, xmax = 1:4 + 0.4, ymin = 0, ymax = d$n, fill = NA, colour = "black", linewidth = 0.3) +
  scale_x_continuous(breaks = 1:4, labels = d$g) + scale_y_continuous(expand = expansion(c(0, 0.08))) + labs(x = NULL, y = "Patients (%)", tag = "C") + theme_halftone()
for (nm in c("A", "B", "C")) { r <- try(ggsave_journal(paste0("ln_", nm, ".png"), get(nm), "single", height = c(A = 75, B = 62, C = 60)[[nm]], dpi = 600), silent = TRUE); cat(nm, if (inherits(r, "try-error")) conditionMessage(attr(r, "condition")) else "ok", "\n") }
