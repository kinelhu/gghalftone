options(halftone.style = "journal"); source("geom_halftone.R", local = TRUE); source("theme_halftone.R", local = TRUE); source("with_halftone.R", local = TRUE); source("halftone_helpers.R", local = TRUE)
library(survival); library(MASS); ink <- halftone_inks
fit <- survfit(Surv(time, status) ~ ph.ecog, data = subset(lung, ph.ecog < 3))
km <- do.call(rbind, lapply(seq_along(fit$strata), function(i) { s <- fit[i]; data.frame(time = c(0, s$time), surv = c(1, s$surv), lo = c(1, s$lower), hi = c(1, s$upper), g = names(fit$strata)[i]) }))
km$g <- factor(km$g, labels = c("ECOG 0", "ECOG 1", "ECOG 2")); km$lo[is.na(km$lo)] <- 0; km$hi[is.na(km$hi)] <- km$surv[is.na(km$hi)]
kms <- do.call(rbind, lapply(split(km, km$g), function(d) { d <- d[order(d$time), ]; n <- nrow(d)
  data.frame(time = c(d$time[1], rep(d$time[-1], each = 2)), surv = c(rep(d$surv[-n], each = 2), d$surv[n]), lo = c(rep(d$lo[-n], each = 2), d$lo[n]), hi = c(rep(d$hi[-n], each = 2), d$hi[n]), g = d$g[1]) }))
## A: crosshatch KM through the wrapper -- ribbon + step, one ink, angles from aes(screen)
A <- ggplot(kms, aes(time, group = g)) +
  with_halftone(geom_ribbon(aes(ymin = lo, ymax = hi, screen = g), fill = "black", stat = "identity"), pitch = 0.55, tone = "centre", shape = "line", dot_max = 0.42, gamma = 1.4, outline = FALSE) +
  scale_screen_manual(values = c(0, 60, 120), guide = "none") +
  geom_step(aes(y = surv), colour = "white", linewidth = 1.2) + geom_step(aes(y = surv, linetype = g), colour = "black", linewidth = 0.6) +
  scale_linetype_manual(values = c("solid", "22", "11"), name = NULL) + scale_y_continuous(labels = scales::percent) +
  labs(x = "Days", y = "Overall survival", tag = "A") + theme_halftone() + theme(legend.position = c(0.82, 0.82), legend.key.size = unit(5, "mm"))
## B: line screen through the wrapper on densities, per-species angle, colour too
B <- ggplot(iris, aes(Sepal.Length, fill = Species, screen = Species)) + with_halftone(geom_density(colour = "black", linewidth = 0.3), pitch = 0.5, tone = "centre", shape = "line", dot_max = 0.55, gamma = 1.2) +
  scale_fill_halftone(name = NULL) + scale_screen_manual(values = c(0, 60, 120), guide = "none") + labs(x = "Sepal length (cm)", y = "Density", tag = "B") + theme_halftone() + theme(legend.position = c(0.8, 0.85))
## C/D/E: dither algorithm comparison on a smooth KDE field
kd <- kde2d(faithful$eruptions, faithful$waiting, n = 150, lims = c(1.3, 5.6, 40, 100)); dens <- data.frame(expand.grid(x = kd$x, y = kd$y), z = as.vector(kd$z))
mk <- function(alg, tag, lab) ggplot(dens, aes(x, y, z = z)) + geom_halftone(pitch = 0.45, levels = 1, algorithm = alg, colour = "black", dot_max = 0.9) +
  labs(x = "Eruption (min)", y = "Waiting (min)", tag = tag, subtitle = lab) + theme_halftone(axes = "box") + theme(plot.subtitle = element_text(size = 6))
C <- mk("bayer", "C", "Bayer 4×4, binary"); D <- mk("floyd_steinberg", "D", "Floyd–Steinberg, binary"); E <- mk("blue_noise", "E", "Blue noise 32×32, binary")
for (nm in c("A", "B", "C", "D", "E")) { r <- try(ggsave_journal(paste0("l11_", nm, ".png"), get(nm), "single", height = 62, dpi = 600), silent = TRUE); cat(nm, if (inherits(r, "try-error")) conditionMessage(attr(r, "condition")) else "ok", "\n") }
