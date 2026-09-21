options(halftone.style = "journal"); source("geom_halftone.R", local = TRUE); source("theme_halftone.R", local = TRUE); source("with_halftone.R", local = TRUE); source("halftone_helpers.R", local = TRUE)
library(survival); library(mgcv); library(MASS); library(maps); library(patchwork); ink <- halftone_inks; W <- "white"; out <- list()
## 1 Fig 1 -------------------------------------------------------------------------
fit <- survfit(Surv(time, status) ~ ph.ecog, data = subset(lung, ph.ecog < 3))
km <- do.call(rbind, lapply(seq_along(fit$strata), function(i) { s <- fit[i]; data.frame(time = c(0, s$time), surv = c(1, s$surv), lo = c(1, s$lower), hi = c(1, s$upper), g = names(fit$strata)[i]) }))
km$g <- factor(km$g, labels = c("ECOG 0", "ECOG 1", "ECOG 2")); km$lo[is.na(km$lo)] <- 0; km$hi[is.na(km$hi)] <- km$surv[is.na(km$hi)]
kms <- do.call(rbind, lapply(split(km, km$g), function(d) { d <- d[order(d$time), ]; n <- nrow(d); data.frame(time = c(d$time[1], rep(d$time[-1], each = 2)), surv = c(rep(d$surv[-n], each = 2), d$surv[n]), lo = c(rep(d$lo[-n], each = 2), d$lo[n]), hi = c(rep(d$hi[-n], each = 2), d$hi[n]), g = d$g[1]) }))
cols <- c(`ECOG 0` = ink[["blue"]], `ECOG 1` = "#9C6A0F", `ECOG 2` = ink[["red"]])   # deeper amber
rk <- summary(fit, times = seq(0, 750, 250)); rt <- data.frame(time = rk$time, n = rk$n.risk, g = factor(rk$strata, labels = names(cols)))
pA <- ggplot(kms, aes(time, group = g)) + with_halftone(geom_ribbon(aes(ymin = lo, ymax = hi, fill = g), stat = "identity"), pitch = 0.5, levels = 6, dot_max = 0.78, gamma = 1.25, outline = FALSE) +
  geom_step(aes(y = surv), colour = W, linewidth = 0.9, lineend = "round") + geom_step(aes(y = surv, colour = g), linewidth = 0.55, lineend = "round") +
  scale_fill_manual(values = cols, name = NULL) + scale_colour_manual(values = cols, guide = "none") +
  scale_y_continuous(labels = scales::percent, breaks = seq(0, 1, 0.25), expand = expansion(c(0, 0.02))) + scale_x_continuous(breaks = seq(0, 750, 250), limits = c(-35, 910), expand = c(0, 0)) + coord_cartesian(clip = "off") +
  labs(x = NULL, y = "Overall survival", tag = "A") + theme_halftone() + theme(legend.position = c(0.8, 0.87), legend.key.size = unit(4, "mm"), plot.margin = margin(3, 3, 0, 3))
rtab <- ggplot(rt, aes(time, g, label = n, colour = g)) + geom_text(size = 7 / .pt, family = "Liberation Sans") + scale_colour_manual(values = cols, guide = "none") +
  scale_y_discrete(limits = rev(names(cols))) + scale_x_continuous(breaks = seq(0, 750, 250), limits = c(-35, 910), expand = c(0, 0)) + coord_cartesian(clip = "off") +
  labs(x = "Days since diagnosis", y = NULL, subtitle = "Number at risk") + theme_halftone() + theme(axis.line = element_blank(), axis.ticks = element_blank(), axis.text.y = element_text(size = 6), plot.subtitle = element_text(size = 6, margin = margin(b = 1)), plot.margin = margin(0, 3, 3, 3))
A1 <- pA / rtab + plot_layout(heights = c(10, 2.2))
m <- gam(accel ~ s(times, k = 20), data = mcycle); nd <- data.frame(times = seq(2.4, 57.6, length.out = 160)); pr <- predict(m, nd, se.fit = TRUE); nd$fit <- pr$fit; nd$lo <- pr$fit - 1.96 * pr$se.fit; nd$hi <- pr$fit + 1.96 * pr$se.fit
B1 <- ggplot(nd, aes(times)) + with_halftone(geom_ribbon(aes(ymin = lo, ymax = hi), fill = ink[["blue"]]), pitch = 0.5, levels = 5, outline = FALSE) +
  geom_line(aes(y = fit), colour = W, linewidth = 0.85) + geom_line(aes(y = fit), colour = ink[["blue"]], linewidth = 0.5) +
  geom_point(data = mcycle, aes(times, accel), shape = 21, fill = W, colour = "black", size = 0.8, stroke = 0.3) + labs(x = "Time after impact (ms)", y = "Head acceleration (g)", tag = "B") + theme_halftone()
set.seed(7); genes <- c("CD3E","CD8A","NKG7","MS4A1","CD79A","LYZ","S100A8","FCGR3A"); cl <- paste0("C", 1:6)
dp <- expand.grid(gene = genes, cluster = cl); dp$pct <- runif(nrow(dp), 0.05, 1); dp$expr <- rbeta(nrow(dp), 0.7, 1.8) * 3
for (i in seq_along(genes)) { j <- ((i - 1) %% 6) + 1; k <- which(dp$gene == genes[i] & dp$cluster == cl[j]); dp$pct[k] <- 0.9; dp$expr[k] <- 2.7 }
C1 <- ggplot(dp, aes(cluster, gene, z = expr, size = pct)) + geom_spot(pitch = 0.35, levels = 5, colour = ink[["violet"]], ring_lwd = 0.3, range = c(0, 3)) +
  scale_radius(range = c(0.9, 2.1), name = "Expressing", breaks = c(0.25, 0.5, 1), labels = scales::percent) +   # min disc large enough to carry tone
  labs(x = "Cluster", y = NULL, tag = "C") + theme_halftone(axes = "none") + theme(axis.ticks = element_blank(), axis.text.y = element_text(face = "italic"), legend.position = "bottom", legend.justification = "left", legend.key.size = unit(4.5, "mm"))
ggsave_journal("k_fig1.png", (A1 | B1 | C1) + plot_layout(widths = c(1.25, 1, 0.9)), "double", height = 78)
## 4 fan ----------------------------------------------------------------------------
fit2 <- arima(co2, order = c(0, 1, 1), seasonal = list(order = c(0, 1, 1), period = 12)); h <- 60; fc <- predict(fit2, n.ahead = h); tt <- seq(1998, by = 1 / 12, length.out = h)
bands <- do.call(rbind, lapply(c(1.96, 1.28, 0.67), function(k) data.frame(t = tt, lo = as.numeric(fc$pred - k * fc$se), hi = as.numeric(fc$pred + k * fc$se), level = factor(paste0(round(2 * pnorm(k) * 100 - 100), "%"), levels = c("95%", "80%", "50%")))))
hist <- data.frame(t = as.numeric(time(co2)), y = as.numeric(co2)); hist <- hist[hist$t >= 1990, ]
F4 <- ggplot() + with_halftone(geom_ribbon(data = bands, aes(t, ymin = lo, ymax = hi, alpha = level), fill = ink[["blue"]], stat = "identity"), pitch = 0.5, tone = "flat", tone_max = 1, levels = 1, dot_max = 0.9, outline = FALSE, overlap = "stack") +
  scale_alpha_manual(values = c(`95%` = 0.15, `80%` = 0.45, `50%` = 1), name = "Interval", breaks = c("50%", "80%", "95%")) +
  geom_line(data = hist, aes(t, y), colour = "black", linewidth = 0.4) + geom_line(data = data.frame(t = tt, y = as.numeric(fc$pred)), aes(t, y), colour = W, linewidth = 1.0) + geom_line(data = data.frame(t = tt, y = as.numeric(fc$pred)), aes(t, y), colour = "black", linewidth = 0.45, linetype = "22") +
  geom_vline(xintercept = 1998, linewidth = 0.3, linetype = "dotted") + labs(x = NULL, y = expression(CO[2]~(ppm))) + theme_halftone() + theme(legend.position = c(0.15, 0.8), legend.key.size = unit(5, "mm")) + guides(alpha = guide_legend(override.aes = list(fill = ink[["blue"]])))
ggsave_journal("k_fan.png", F4, "single", height = 62)
## 5 choropleth ----------------------------------------------------------------------
val <- setNames(USArrests$Murder, tolower(rownames(USArrests))); st <- map_data("state"); st$murder <- val[st$region]
C5 <- ggplot(st, aes(long, lat, group = group, fill = murder)) + with_halftone(geom_polygon(colour = "black", linewidth = 0.2), pitch = 0.5, angle = 45, grid = "square", tone = "flat", tone_max = 0.6, levels = 6) +
  scale_fill_gradientn(colours = c("#E7D9B8", ink[["ochre"]], ink[["red"]], "#3A0A0A"), name = "Per 100k") + coord_map("albers", lat0 = 30, lat1 = 45) + labs(x = NULL, y = NULL) + theme_halftone(axes = "none") + theme(axis.text = element_blank())
ggsave_journal("k_map.png", C5, "single", height = 58)
## 8 heatmap: two inks, no grid ------------------------------------------------------
set.seed(2); genes2 <- paste0("Gene ", 1:18); samples <- paste0("S", 1:12)
M <- outer(sin(seq(0, 3, length.out = 18)), cos(seq(0, 3, length.out = 12))) * 2 + matrix(rnorm(18 * 12, sd = 0.6), 18); ord <- hclust(dist(M))$order; M <- M[ord, ]; genes2 <- genes2[ord]
hm <- data.frame(expand.grid(x = seq_along(samples), y = seq_along(genes2)), v = as.vector(t(M))); hm$mag <- abs(hm$v); hm$sign <- factor(ifelse(hm$v >= 0, "Up", "Down"), c("Up", "Down"))
H8 <- ggplot(hm, aes(x, y)) + geom_halftone(aes(z = mag, colour = sign), pitch = 0.5, levels = 5, dot_max = 0.9, range = c(0, max(hm$mag)), overlap = "stack") +
  scale_colour_manual(values = c(Up = ink[["red"]], Down = ink[["blue"]]), name = NULL) +
  scale_x_continuous(breaks = seq_along(samples), labels = samples, expand = c(0, 0.5)) + scale_y_continuous(breaks = seq_along(genes2), labels = genes2, expand = c(0, 0.5)) + coord_equal() +
  labs(x = NULL, y = NULL, caption = expression(Dot~area == "|"*log[2]~FC*"|")) + theme_halftone(axes = "none") + theme(axis.ticks = element_blank(), axis.text.x = element_text(angle = 45, hjust = 1), axis.text.y = element_text(size = 6), legend.position = "bottom", legend.justification = "left")
ggsave_journal("k_heat.png", H8, "single", height = 90)
## 9 screens (lighter base) ------------------------------------------------------------
tt6 <- 1:40; set.seed(4); s6 <- data.frame(t = tt6, a = 10 + 4 * sin(tt6 / 5) + rnorm(40, 0, 0.6), b = 6 + tt6 / 6 + rnorm(40, 0, 0.5), c = 5 + 3 * cos(tt6 / 7) + rnorm(40, 0, 0.5))
long <- data.frame(t = rep(tt6, 3), v = c(s6$a, s6$b, s6$c), series = rep(c("Series A", "Series B", "Series C"), each = 40))
S9 <- ggplot(long, aes(t, v, screen = series, group = series)) + with_halftone(geom_area(fill = "black", colour = "black", linewidth = 0.35, position = position_stack(reverse = TRUE)), pitch = 0.7, tone = "flat", tone_max = 1, levels = 1, dot_max = 0.45) +
  scale_screen_discrete(name = NULL) + scale_y_continuous(expand = c(0, 0)) + scale_x_continuous(expand = c(0, 0)) + labs(x = "Time", y = "Stacked value") + theme_halftone() + theme(legend.position = "bottom", legend.justification = "left", legend.key.size = unit(4.5, "mm"))
ggsave_journal("k_screens.png", S9, "single", height = 62)
## 10 elevation dots / 11 engraving ---------------------------------------------------
vol <- data.frame(expand.grid(x = seq_len(ncol(volcano)), y = seq_len(nrow(volcano))), z = as.vector(t(volcano)))
E10 <- ggplot(vol, aes(x, y, z = z)) + geom_halftone(aes(colour = z), pitch = 0.5, angle = 45, levels = 8, dot_max = 1.05, gamma = 0.6) +
  scale_colour_gradientn(colours = c("#E7D9B8", ink[["ochre"]], "#7A4A1E", "#2B1D14"), name = "Elevation (m)") + geom_contour(colour = W, linewidth = 0.6, bins = 8) + geom_contour(colour = "black", linewidth = 0.25, bins = 8) +
  coord_equal(expand = FALSE) + labs(x = NULL, y = NULL) + theme_halftone(axes = "box") + theme(axis.text = element_blank(), axis.ticks = element_blank())
ggsave_journal("k_elev.png", E10, "single", height = 75)
E11 <- ggplot(vol, aes(x, y, z = z)) + geom_halftone(pitch = 0.45, angle = 30, shape = "line", colour = "black", gamma = 1.4, dot_max = 1) + geom_contour(colour = W, linewidth = 0.5, bins = 8) + geom_contour(colour = "black", linewidth = 0.2, bins = 8) +
  coord_equal(expand = FALSE) + labs(x = NULL, y = NULL) + theme_halftone(axes = "box") + theme(axis.text = element_blank(), axis.ticks = element_blank())
ggsave_journal("k_engr.png", E11, "single", height = 75)
## 12 KM one ink (0.7 mm, no subtitle) ------------------------------------------------
K12 <- ggplot(kms, aes(time, group = g)) + with_halftone(geom_ribbon(aes(ymin = lo, ymax = hi, screen = g), fill = "black", stat = "identity"), pitch = 0.7, shape = "line", dot_max = 0.55, outline = TRUE) +
  scale_screen_manual(values = c(0, 60, 120), guide = "none") + geom_step(aes(y = surv), colour = W, linewidth = 1.0) + geom_step(aes(y = surv, linetype = g), colour = "black", linewidth = 0.6) +
  scale_linetype_manual(values = c("solid", "22", "11"), name = NULL) + scale_y_continuous(labels = scales::percent) + scale_x_continuous(limits = c(-5, 1030), expand = c(0, 0)) +
  labs(x = "Days", y = "Overall survival") + theme_halftone() + theme(legend.position = c(0.82, 0.82), legend.key.size = unit(5, "mm"))
ggsave_journal("k_kmbw.png", K12, "single", height = 62)
## 13 densities, line screens, one ink ---------------------------------------------------
D13 <- ggplot(iris, aes(Sepal.Length, screen = Species, group = Species)) + with_halftone(geom_density(fill = "black", colour = "black", linewidth = 0.3), pitch = 0.6, shape = "line", dot_max = 0.55) +
  scale_screen_manual(values = c(0, 60, 120), name = NULL) + labs(x = "Sepal length (cm)", y = "Density") + theme_halftone() + theme(legend.position = c(0.8, 0.85), legend.key.size = unit(5, "mm"))
ggsave_journal("k_dens.png", D13, "single", height = 62)
## 14 blue noise + one contour ----------------------------------------------------------
kd <- kde2d(faithful$eruptions, faithful$waiting, n = 150, lims = c(1.3, 5.6, 40, 100)); dens <- data.frame(expand.grid(x = kd$x, y = kd$y), z = as.vector(kd$z))
N14 <- ggplot(dens, aes(x, y, z = z)) + geom_halftone(pitch = 0.45, levels = 1, algorithm = "blue_noise", colour = "black", dot_max = 0.9) + geom_contour(colour = W, linewidth = 0.9, bins = 3) + geom_contour(colour = "black", linewidth = 0.35, bins = 3) +
  labs(x = "Eruption (min)", y = "Waiting (min)") + theme_halftone(axes = "box")
ggsave_journal("k_noise.png", N14, "single", height = 62)
## 15 hatched bars, matched weights ----------------------------------------------------
d <- data.frame(g = factor(c("BOS", "RAS", "Mixed", "Undef."), c("BOS", "RAS", "Mixed", "Undef.")), n = c(52, 21, 14, 13))
B15 <- ggplot(d, aes(g, n, screen = g)) + with_halftone(geom_col(width = 0.7, fill = "black", colour = "black", linewidth = 0.3), pitch = 0.6, shape = "line", dot_max = 0.5) +
  scale_screen_manual(values = c(45, 135, 0, 90), guide = "none") + scale_y_continuous(expand = expansion(c(0, 0.08))) + labs(x = NULL, y = "Patients (%)") + theme_halftone()
ggsave_journal("k_bars.png", B15, "single", height = 60)
cat("all ok\n")
