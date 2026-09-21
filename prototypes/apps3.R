options(halftone.style = "editorial")
source("geom_halftone.R", local = TRUE)
library(patchwork); library(survival); library(MASS); library(viridis)
th <- theme_minimal(base_size = 11) + theme(panel.grid.minor = element_blank(), panel.grid.major = element_line(colour = "grey92"),
        plot.background = element_rect(fill = "white", colour = NA), plot.title = element_text(face = "bold", size = 11))
pal <- c(Male = "#B5443C", Female = "#2C6E8F")

## A. KM
fit <- survfit(Surv(time, status) ~ sex, data = lung)
s <- summary(fit, times = seq(0, 900, by = 5), extend = TRUE)
km <- data.frame(time = s$time, surv = s$surv, lo = s$lower, hi = s$upper, sex = factor(s$strata, labels = c("Male", "Female")))
km$lo[is.na(km$lo)] <- 0; km$hi[is.na(km$hi)] <- km$surv[is.na(km$hi)]
band <- do.call(rbind, lapply(split(km, km$sex), function(d) {
  g <- expand.grid(time = d$time, surv = seq(0, 1, by = 0.004)); i <- match(g$time, d$time)
  half <- pmax(d$hi[i] - d$lo[i], 1e-6) / 2; mid <- (d$hi[i] + d$lo[i]) / 2
  g$z <- pmax(0, 1 - abs(g$surv - mid) / half); g$sex <- d$sex[1]; g }))
p_km <- ggplot() +
  geom_halftone(data = band, aes(time, surv, z = z, colour = sex), pitch = 1.1, grid = "hex", levels = 3, range = c(0, 1), show.legend = FALSE) +
  geom_step(data = km, aes(time, surv, colour = sex), linewidth = 1) +
  annotate("text", x = 640, y = 0.42, label = "Female", colour = pal["Female"], fontface = "bold", hjust = 0) +
  annotate("text", x = 330, y = 0.20, label = "Male", colour = pal["Male"], fontface = "bold", hjust = 0) +
  scale_colour_manual(values = pal, guide = "none") + scale_y_continuous(labels = scales::percent) +
  labs(x = "Days since diagnosis", y = "Survival", title = "A  Kaplan-Meier, 95% CI as hex halftone (pitch 1.1 mm)") + th

## B. KDE, Floyd-Steinberg now cheap enough to use at 0.8 mm
kd <- kde2d(faithful$eruptions, faithful$waiting, n = 150, lims = c(1.3, 5.6, 40, 100))
dens <- data.frame(expand.grid(x = kd$x, y = kd$y), z = as.vector(kd$z))
p_dens <- ggplot() +
  geom_halftone(data = dens, aes(x, y, z = z, colour = z), pitch = 1.0, algorithm = "floyd_steinberg", levels = 6, dot_max = 1, show.legend = FALSE) +
  scale_colour_viridis_c(option = "mako", direction = -1, end = 0.9, begin = 0.15) +
  geom_point(data = faithful, aes(eruptions, waiting), size = 0.5, colour = "white", alpha = 0.9) +
  labs(x = "Eruption duration (min)", y = "Waiting time (min)", title = "B  2D density, Floyd-Steinberg (Rcpp), pitch 1.0 mm") + th

## C. Volcano, 45 deg, colour = height
vol <- data.frame(expand.grid(x = seq_len(ncol(volcano)), y = seq_len(nrow(volcano))), z = as.vector(t(volcano)))
p_vol <- ggplot() +
  geom_halftone(data = vol, aes(x, y, z = z, colour = z), pitch = 1.1, angle = 45, levels = 6, dot_max = 1, size_map = "radius") +
  scale_colour_gradientn(colours = c("#EADFC8", "#C79A5A", "#8D5A2B", "#4A2E1E"), name = "Elevation (m)") +
  geom_contour(data = vol, aes(x, y, z = z), colour = "white", linewidth = 1.4, bins = 8, alpha = 0.9) +
  geom_contour(data = vol, aes(x, y, z = z), colour = "#2B1D14", linewidth = 0.45, bins = 8) +
  coord_equal(expand = FALSE) + labs(title = "C  Elevation, 45\u00b0 screen, pitch 1.1 mm, radius-mapped", x = NULL, y = NULL) +
  th + theme(axis.text = element_blank(), panel.grid = element_blank()) + guides(colour = guide_colourbar(override.aes = list(size = 3)))

## D. NEW: heatmap-style — gene-expression-like matrix (simulated), halftone tiles with diverging colour
set.seed(2); genes <- paste0("G", 1:24); samples <- paste0("S", 1:16)
M <- outer(sin(seq(0, 3, length.out = 24)), cos(seq(0, 3, length.out = 16))) * 2 + matrix(rnorm(24 * 16, sd = 0.6), 24)
hm <- data.frame(expand.grid(x = seq_along(samples), y = seq_along(genes)), v = as.vector(t(M)))
hm$mag <- abs(hm$v)
p_hm <- ggplot(hm, aes(x, y)) +
  geom_tile(fill = NA, colour = "grey88", linewidth = 0.25) +
  geom_halftone(aes(z = mag, colour = v), pitch = 1.0, levels = 4, dot_max = 1, range = c(0, max(hm$mag))) +
  scale_colour_gradient2(low = "#2C6E8F", mid = "grey85", high = "#B5443C", midpoint = 0, name = "log2 FC") +
  scale_x_continuous(breaks = seq_along(samples), labels = samples, expand = c(0, 0.5)) +
  scale_y_continuous(breaks = seq_along(genes), labels = genes, expand = c(0, 0.5)) +
  coord_equal() + labs(x = NULL, y = NULL, title = "D  Expression heatmap: hue = sign, dot area = |log2 FC|") +
  th + theme(panel.grid = element_blank(), axis.text.x = element_text(angle = 45, hjust = 1), axis.text.y = element_text(size = 7))

ggsave("apps3.png", (p_km | p_dens) / (p_vol | p_hm), width = 12.5, height = 11, dpi = 170)
cat("apps ok\n")

## E. size-invariance test: same plot at 60 mm and 180 mm wide -> dot pitch stays 1 mm
inv <- ggplot(vol, aes(x, y, z = z)) + geom_halftone(pitch = 1, angle = 45, levels = 6, colour = "#3B3B3B") + coord_equal(expand = FALSE) + theme_void()
ggsave("inv_small.png", inv, width = 60, height = 45, units = "mm", dpi = 300)
ggsave("inv_large.png", inv, width = 180, height = 135, units = "mm", dpi = 100)
cat("inv ok\n")

## Cover v4
gx <- 40; gy <- 30; gr <- 17; ring <- 2.5
field <- expand.grid(x = seq(0, 100, by = 0.5), y = seq(0, 60, by = 0.5))
field$d <- with(field, sqrt((x - gx)^2 + (y - gy)^2))
field$z <- with(field, pmin(1, (y / 45)^1.3) * pmin(1, pmax(0, (d - gr) / ring)))
circ <- data.frame(t = seq(0, 2 * pi, length.out = 400)); circ$x <- gx + gr * cos(circ$t); circ$y <- gy + gr * sin(circ$t)
curve <- data.frame(x = seq(5, 95, length.out = 300)); curve$y <- 2 + 55 / (1 + exp(-(curve$x - 78) / 3))
cover <- ggplot() +
  geom_halftone(data = field, aes(x, y, z = z, colour = z), pitch = 1.6, grid = "hex", levels = 5, show.legend = FALSE) +
  scale_colour_gradientn(colours = c("#D9A441", "#B5443C", "#7A1E1E")) +
  geom_polygon(data = circ, aes(x, y), fill = "#FBFAF5", colour = "black", linewidth = 0.8) +
  geom_line(data = curve, aes(x, y), colour = "#FBFAF5", linewidth = 3.5, lineend = "round") +
  geom_line(data = curve, aes(x, y), colour = "black", linewidth = 1, linetype = "22") +
  coord_equal(expand = FALSE) + theme_void() + theme(plot.background = element_rect(fill = "#FBFAF5", colour = NA))
ggsave("cover_v4.png", cover, width = 8, height = 4.8, dpi = 200)
cat("cover ok\n")
