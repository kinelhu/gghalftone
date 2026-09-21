source("stat_halftone.R", local = TRUE)
library(patchwork); library(survival); library(MASS); library(viridis)
th <- theme_minimal(base_size = 11) + theme(panel.grid.minor = element_blank(), panel.grid.major = element_line(colour = "grey92"),
        plot.background = element_rect(fill = "white", colour = NA), plot.title = element_text(face = "bold", size = 11))

## A. KM — hex grid, colour = stratum, tone = closeness to estimate, no legend clutter
fit <- survfit(Surv(time, status) ~ sex, data = lung)
s <- summary(fit, times = seq(0, 900, by = 5), extend = TRUE)
km <- data.frame(time = s$time, surv = s$surv, lo = s$lower, hi = s$upper, sex = factor(s$strata, labels = c("Male", "Female")))
km$lo[is.na(km$lo)] <- 0; km$hi[is.na(km$hi)] <- km$surv[is.na(km$hi)]
band <- do.call(rbind, lapply(split(km, km$sex), function(d) {
  g <- expand.grid(time = d$time, surv = seq(0, 1, by = 0.004)); i <- match(g$time, d$time)
  half <- pmax(d$hi[i] - d$lo[i], 1e-6) / 2; mid <- (d$hi[i] + d$lo[i]) / 2
  g$z <- pmax(0, 1 - abs(g$surv - mid) / half); g$sex <- d$sex[1]; g }))
pal <- c(Male = "#B5443C", Female = "#2C6E8F")
p_km <- ggplot() +
  stat_halftone(data = band, aes(time, surv, z = z, colour = sex, size = after_stat(dot)),
                n = 120, levels = 3, grid = "hex", aspect = 1.4, range = c(0, 1), shape = 16, alpha = 0.9, show.legend = FALSE) +
  scale_size_halftone(max = 1.1) +
  geom_step(data = km, aes(time, surv, colour = sex), linewidth = 1) +
  annotate("text", x = 640, y = 0.42, label = "Female", colour = pal["Female"], fontface = "bold", hjust = 0) +
  annotate("text", x = 330, y = 0.20, label = "Male", colour = pal["Male"], fontface = "bold", hjust = 0) +
  scale_colour_manual(values = pal, guide = "none") + scale_y_continuous(labels = scales::percent) +
  labs(x = "Days since diagnosis", y = "Survival", title = "A  Kaplan-Meier, 95% CI as hex halftone") + th

## B. KDE — 45deg screen, colour = density via viridis (mako), replaces filled contours
kd <- kde2d(faithful$eruptions, faithful$waiting, n = 150, lims = c(1.3, 5.6, 40, 100))
dens <- data.frame(expand.grid(x = kd$x, y = kd$y), z = as.vector(kd$z))
p_dens <- ggplot() +
  stat_halftone(data = dens, aes(x, y, z = z, size = after_stat(dot), colour = after_stat(z)),
                n = 95, levels = 6, angle = 45, aspect = 1.4, shape = 16) +
  scale_size_halftone(max = 1.4) +
  scale_colour_viridis_c(option = "mako", direction = -1, end = 0.9, begin = 0.15, name = "Density", labels = NULL) +
  geom_point(data = faithful, aes(eruptions, waiting), size = 0.5, colour = "white", alpha = 0.9) +
  labs(x = "Eruption duration (min)", y = "Waiting time (min)", title = "B  2D density, 45\u00b0 screen, colour + size = density") +
  th + theme(legend.position = "none")

## C. Correlation — signed value drives a diverging colour, |r| drives dot size (stat does the tiling)
cm <- cor(mtcars); v <- colnames(cm)
cd <- data.frame(expand.grid(x = seq_along(v), y = seq_along(v)), r = as.vector(cm))
cd$absr <- abs(cd$r)
cd$sign <- factor(ifelse(cd$r >= 0, "positive", "negative"), levels = c("negative", "positive"))
p_cor <- ggplot(cd, aes(x, y)) +
  geom_tile(fill = NA, colour = "grey88", linewidth = 0.3) +
  stat_halftone(aes(z = absr, colour = sign, size = after_stat(dot), alpha = after_stat(dot)),
                n = 11 * 5, levels = 4, range = c(0, 1), shape = 16, bayer_n = 2) +
  scale_colour_manual(values = c(negative = "#2C6E8F", positive = "#B5443C"), name = "Sign of r") +
  scale_alpha(range = c(0.35, 1), guide = "none") + scale_size_halftone(max = 2.1) +
  scale_x_continuous(breaks = seq_along(v), labels = v, expand = c(0, 0.5)) + scale_y_continuous(breaks = seq_along(v), labels = v, expand = c(0, 0.5)) +
  coord_equal() + labs(x = NULL, y = NULL, title = "C  Correlation matrix: hue = sign, size = |r|") +
  th + theme(panel.grid = element_blank(), axis.text.x = element_text(angle = 45, hjust = 1), legend.position = "bottom") +
  guides(colour = guide_legend(override.aes = list(size = 3)))

## D. Volcano — colour = elevation, 45deg screen, contour lines with white extrusion
vol <- data.frame(expand.grid(x = seq_len(ncol(volcano)), y = seq_len(nrow(volcano))), z = as.vector(t(volcano)))
p_vol <- ggplot() +
  stat_halftone(data = vol, aes(x, y, z = z, size = after_stat(dot), colour = after_stat(z)),
                n = 90, levels = 6, angle = 45, aspect = 61 / 87 * 1.05, shape = 16) +
  scale_size_halftone(max = 1.35, min = 0.15) +
  scale_colour_gradientn(colours = c("#EADFC8", "#C79A5A", "#8D5A2B", "#4A2E1E"), name = "Elevation (m)",
                         labels = function(b) round(min(volcano) + b * diff(range(volcano)))) +
  geom_contour(data = vol, aes(x, y, z = z), colour = "white", linewidth = 1.4, bins = 8, alpha = 0.9) +
  geom_contour(data = vol, aes(x, y, z = z), colour = "#2B1D14", linewidth = 0.45, bins = 8) +
  coord_equal(expand = FALSE) + labs(title = "D  Elevation halftone, colour = height, outlined contours", x = NULL, y = NULL) +
  th + theme(axis.text = element_blank(), panel.grid = element_blank(), legend.position = "right")

ggsave("apps2.png", (p_km | p_dens) / (p_cor | p_vol), width = 12.5, height = 10.5, dpi = 170)
cat("apps ok\n")

## Cover v3 — two-tone gradient (red -> amber), hex grid, halo hugging the globe
gx <- 40; gy <- 30; gr <- 17; ring <- 2.5
field <- expand.grid(x = seq(0, 100, by = 0.5), y = seq(0, 60, by = 0.5))
field$d <- with(field, sqrt((x - gx)^2 + (y - gy)^2))
field$z <- with(field, pmin(1, (y / 45)^1.3) * pmin(1, pmax(0, (d - gr) / ring)))
circ <- data.frame(t = seq(0, 2 * pi, length.out = 400)); circ$x <- gx + gr * cos(circ$t); circ$y <- gy + gr * sin(circ$t)
curve <- data.frame(x = seq(5, 95, length.out = 300)); curve$y <- 2 + 55 / (1 + exp(-(curve$x - 78) / 3))
cover <- ggplot() +
  stat_halftone(data = field, aes(x, y, z = z, size = after_stat(dot), colour = after_stat(z)),
                n = 120, levels = 5, grid = "hex", aspect = 100 / 60, shape = 16) +
  scale_size_halftone(max = 1.55, min = 0.12) +
  scale_colour_gradientn(colours = c("#D9A441", "#B5443C", "#7A1E1E"), guide = "none") +
  geom_polygon(data = circ, aes(x, y), fill = "#FBFAF5", colour = "black", linewidth = 0.8) +
  geom_line(data = curve, aes(x, y), colour = "#FBFAF5", linewidth = 3.5, lineend = "round") +
  geom_line(data = curve, aes(x, y), colour = "black", linewidth = 1, linetype = "22") +
  coord_equal(expand = FALSE) + theme_void() + theme(plot.background = element_rect(fill = "#FBFAF5", colour = NA))
ggsave("cover_v3.png", cover, width = 8, height = 4.8, dpi = 200)
cat("cover ok\n")
