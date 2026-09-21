options(halftone.style = "editorial")
source("geom_halftone.R", local = TRUE); source("theme_halftone.R", local = TRUE); source("halftone_raster.R", local = TRUE)
library(patchwork); library(survival); library(MASS); library(viridis)
ink <- halftone_inks

## A. KM
fit <- survfit(Surv(time, status) ~ sex, data = lung)
s <- summary(fit, times = seq(0, 900, by = 5), extend = TRUE)
km <- data.frame(time = s$time, surv = s$surv, lo = s$lower, hi = s$upper, sex = factor(s$strata, labels = c("Male", "Female")))
km$lo[is.na(km$lo)] <- 0; km$hi[is.na(km$hi)] <- km$surv[is.na(km$hi)]
band <- do.call(rbind, lapply(split(km, km$sex), function(d) {
  g <- expand.grid(time = d$time, surv = seq(0, 1, by = 0.004)); i <- match(g$time, d$time)
  half <- pmax(d$hi[i] - d$lo[i], 1e-6) / 2; mid <- (d$hi[i] + d$lo[i]) / 2
  g$z <- pmax(0, 1 - abs(g$surv - mid) / half); g$sex <- d$sex[1]; g }))
pal <- c(Male = ink[["red"]], Female = ink[["blue"]])
p_km <- ggplot() +
  geom_halftone(data = band, aes(time, surv, z = z, colour = sex), pitch = 1.1, grid = "hex", levels = 3, range = c(0, 1), show.legend = FALSE) +
  geom_step(data = km, aes(time, surv, colour = sex), linewidth = 0.9) +
  annotate("text", x = 640, y = 0.44, label = "Female", colour = pal["Female"], family = "Inconsolata", fontface = "bold", hjust = 0) +
  annotate("text", x = 330, y = 0.20, label = "Male", colour = pal["Male"], family = "Inconsolata", fontface = "bold", hjust = 0) +
  scale_colour_manual(values = pal, guide = "none") +
  scale_y_continuous(labels = scales::percent, breaks = seq(0, 1, 0.25), expand = expansion(c(0.02, 0.05))) +
  scale_x_continuous(expand = expansion(c(0.01, 0.03))) +
  labs(x = "DAYS SINCE DIAGNOSIS", y = "SURVIVAL", title = "Kaplan–Meier", subtitle = "95% CI RENDERED AS HEX HALFTONE  ·  NCCTG LUNG") +
  theme_halftone()

## B. KDE
kd <- kde2d(faithful$eruptions, faithful$waiting, n = 150, lims = c(1.3, 5.6, 40, 100))
dens <- data.frame(expand.grid(x = kd$x, y = kd$y), z = as.vector(kd$z))
p_dens <- ggplot() +
  geom_halftone(data = dens, aes(x, y, z = z, colour = z), pitch = 1.0, algorithm = "floyd_steinberg", levels = 6, dot_max = 1, show.legend = FALSE) +
  scale_colour_gradientn(colours = c(ink[["ochre"]], ink[["red"]], "#3A0A0A")) +
  geom_point(data = faithful, aes(eruptions, waiting), size = 0.5, colour = halftone_paper) +
  labs(x = "ERUPTION DURATION (MIN)", y = "WAITING TIME (MIN)", title = "Old Faithful", subtitle = "2D KERNEL DENSITY  ·  FLOYD–STEINBERG, 1.0 MM") +
  theme_halftone(axes = "box")

## C. Volcano
vol <- data.frame(expand.grid(x = seq_len(ncol(volcano)), y = seq_len(nrow(volcano))), z = as.vector(t(volcano)))
p_vol <- ggplot() +
  geom_halftone(data = vol, aes(x, y, z = z, colour = z), pitch = 1.1, angle = 45, levels = 6, dot_max = 1, size_map = "radius") +
  scale_colour_gradientn(colours = c("#E7D9B8", ink[["ochre"]], "#7A4A1E", "#2B1D14"), name = "ELEVATION (M)") +
  geom_contour(data = vol, aes(x, y, z = z), colour = halftone_paper, linewidth = 1.4, bins = 8) +
  geom_contour(data = vol, aes(x, y, z = z), colour = halftone_ink, linewidth = 0.45, bins = 8) +
  coord_equal(expand = FALSE) + labs(title = "Maunga Whau", subtitle = "45° SCREEN, 1.1 MM  ·  OUTLINED CONTOURS", x = NULL, y = NULL) +
  theme_halftone(axes = "box") + theme(axis.text = element_blank(), axis.ticks = element_blank(), legend.position = "right", legend.justification = "top") +
  guides(colour = guide_colourbar(barwidth = 0.6, barheight = 8))

## D. Raster mode: ImageMagick's built-in test image through the same geom
img <- halftone_raster("logo:", max_px = 140)
p_img <- ggplot(img, aes(x, y, z = z)) +
  geom_halftone(pitch = 0.85, angle = 45, levels = 8, dot_max = 1.05, colour = halftone_ink) +
  coord_equal(expand = FALSE) + labs(title = "Raster mode", subtitle = "halftone_raster('logo:')  ·  45°, 0.85 MM, 8 LEVELS", x = NULL, y = NULL) +
  theme_halftone(axes = "box") + theme(axis.text = element_blank(), axis.ticks = element_blank())

ggsave("apps4.png", (p_km | p_dens) / (p_vol | p_img) + plot_annotation(theme = theme(plot.background = element_rect(fill = halftone_paper, colour = NA))), width = 12.5, height = 11, dpi = 170, bg = halftone_paper, device = ragg::agg_png)
cat("apps ok\n")

## dark variant quick check
p_dark <- p_km + theme_halftone(paper = "#141210", ink = "#EDE6D6") +
  scale_colour_manual(values = c(Male = "#E07A5F", Female = "#81B29A"), guide = "none")
ggsave("dark.png", p_dark, width = 6.5, height = 5, dpi = 170, bg = "#141210", device = ragg::agg_png)
cat("dark ok\n")
