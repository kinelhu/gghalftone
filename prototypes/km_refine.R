source("geom_halftone.R", local = TRUE); source("theme_halftone.R", local = TRUE); source("halftone_helpers.R", local = TRUE)
library(patchwork); library(survival); ink <- halftone_inks
fit <- survfit(Surv(time, status) ~ ph.ecog, data = subset(lung, ph.ecog < 3))
s <- summary(fit, times = seq(0, 900, by = 3), extend = TRUE)
km <- data.frame(time = s$time, surv = s$surv, lo = s$lower, hi = s$upper, g = factor(s$strata, labels = c("ECOG 0", "ECOG 1", "ECOG 2")))
km$lo[is.na(km$lo)] <- 0; km$hi[is.na(km$hi)] <- km$surv[is.na(km$hi)]
cols <- c(`ECOG 0` = ink[["blue"]], `ECOG 1` = ink[["ochre"]], `ECOG 2` = ink[["red"]])
band <- do.call(rbind, lapply(split(km, km$g), function(d) { b <- halftone_band(d$time, d$surv, d$lo, d$hi, ny = 320, ylim = c(0, 1), profile = "gauss"); b$g <- d$g[1]; b }))
mk <- function(pitch, levels, halo, lw = 0.55, tag, sub) {
  p <- ggplot() + geom_halftone(data = band, aes(x, y, z = z, colour = g), pitch = pitch, grid = "hex", levels = levels, range = c(0, 1), dot_max = 0.92, show.legend = FALSE)
  if (halo > 0) p <- p + geom_step(data = km, aes(time, surv, group = g), colour = "white", linewidth = lw + 2 * halo / .pt * 2.845, lineend = "round")
  p + geom_step(data = km, aes(time, surv, colour = g), linewidth = lw, lineend = "round") +
    scale_colour_manual(values = cols, guide = "none") +
    scale_y_continuous(labels = scales::percent, breaks = seq(0, 1, 0.25), expand = expansion(c(0, 0.02))) +
    scale_x_continuous(breaks = seq(0, 750, 250), limits = c(-5, 910), expand = c(0, 0)) +
    labs(x = "Days", y = "Overall survival", tag = tag, subtitle = sub) + theme_halftone() + theme(plot.subtitle = element_text(size = 6))
}
A <- mk(0.9, 4, 0.30, tag = "A", sub = "0.9 mm, 4 levels, 0.3 mm halo (current)")
B <- mk(0.9, 4, 0.00, tag = "B", sub = "0.9 mm, 4 levels, no halo")
C <- mk(0.55, 6, 0.08, tag = "C", sub = "0.55 mm, 6 levels, hairline halo")
D <- mk(0.45, 8, 0.00, tag = "D", sub = "0.45 mm, 8 levels, no halo")
fig <- (A | B | C | D)
ggsave_journal("km_refine.png", fig, "double", height = 50, dpi = 600)
cat("ok\n")
