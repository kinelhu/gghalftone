source("geom_halftone.R", local = TRUE); source("theme_halftone.R", local = TRUE); source("halftone_helpers.R", local = TRUE); source("halftone_raster.R", local = TRUE); source("with_halftone.R", local = TRUE)
library(patchwork); library(MASS); library(mgcv); library(maps); ink <- halftone_inks; W <- "white"
th <- theme_halftone(); halo <- function(d, m, lw = 0.5) list(geom_line(data = d, aes(x, y), colour = W, linewidth = lw + 0.35), geom_line(data = d, aes(x, y), colour = m, linewidth = lw))

## A forecast fan
fit <- arima(log(AirPassengers), order = c(0, 1, 1), seasonal = list(order = c(0, 1, 1), period = 12)); h <- 36; fc <- predict(fit, n.ahead = h); tt <- seq(1961, by = 1 / 12, length.out = h)
fan <- halftone_band(tt, exp(fc$pred), exp(fc$pred - 1.96 * fc$se), exp(fc$pred + 1.96 * fc$se), profile = "gauss", ny = 320)
hist <- data.frame(x = as.numeric(time(AirPassengers)), y = as.numeric(AirPassengers)); fcd <- data.frame(x = tt, y = exp(fc$pred))
A <- ggplot() + geom_halftone(data = fan, aes(x, y, z = z, colour = x), pitch = 0.5, grid = "hex", levels = 6, range = c(0, 1), show.legend = FALSE) +
  scale_colour_gradient(low = ink[["red"]], high = ink[["ochre"]]) + geom_line(data = hist, aes(x, y), colour = "black", linewidth = 0.4) +
  halo(fcd, "black") + geom_vline(xintercept = 1961, linewidth = 0.3, linetype = "dotted") +
  labs(x = NULL, y = "Passengers (thousands)", tag = "A") + th

## B choropleth
val <- setNames(USArrests$Murder, tolower(rownames(USArrests))); reg <- halftone_regions("state", val, res = 0.12); borders <- map_data("state")
B <- ggplot() + geom_halftone(data = reg, aes(x, y, z = z, colour = z), pitch = 0.5, angle = 45, levels = 6, dot_max = 1) +
  scale_colour_gradientn(colours = c("#E7D9B8", ink[["ochre"]], ink[["red"]], "#3A0A0A"), name = "Murder\nper 100k") +
  geom_polygon(data = borders, aes(long, lat, group = group), fill = NA, colour = W, linewidth = 0.55) +
  geom_polygon(data = borders, aes(long, lat, group = group), fill = NA, colour = "black", linewidth = 0.2) +
  coord_map("albers", lat0 = 30, lat1 = 45) + labs(x = NULL, y = NULL, tag = "B") + theme_halftone(axes = "none") + theme(axis.text = element_blank(), legend.key.height = unit(5, "mm"), legend.key.width = unit(2.5, "mm"))

## C dot-matrix bars
d4 <- data.frame(cat = c("BOS", "RAS", "Mixed", "Undefined"), n = c(52, 21, 14, 13)); bars <- halftone_bars(d4$cat, d4$n, nx = 40, ny = 200, fade = 0.3)
C <- ggplot() + geom_halftone(data = bars, aes(x, y, z = z, colour = cat), pitch = 0.6, shape = "square", levels = 5, dot_max = 0.9, range = c(0, 1), show.legend = FALSE) +
  scale_colour_manual(values = c(ink[["red"]], ink[["ochre"]], ink[["violet"]], ink[["grey"]])) +
  geom_text(data = d4, aes(seq_along(cat), n, label = paste0(n, "%")), size = 7 / .pt, family = "Liberation Sans", vjust = -0.5) +
  scale_x_continuous(breaks = 1:4, labels = d4$cat) + scale_y_continuous(expand = expansion(c(0, 0.12))) +
  labs(x = NULL, y = "Patients (%)", tag = "C") + th + theme(axis.line.x = element_blank(), axis.ticks.x = element_blank())

## D facets + groups -- loess bands per class straight from stat_smooth, through the wrapper
mp <- ggplot2::mpg[ggplot2::mpg$class %in% c("compact", "suv", "subcompact", "pickup"), ]
D <- ggplot(mp, aes(displ, hwy, colour = class, fill = class)) +
  with_halftone(geom_smooth(method = "loess", span = 1, se = TRUE, linewidth = 0, colour = NA), pitch = 0.5, levels = 4, outline = FALSE) +
  geom_smooth(method = "loess", span = 1, se = FALSE, linewidth = 0.5) + geom_point(size = 0.6) +
  scale_colour_halftone(name = NULL) + scale_fill_halftone(guide = "none") +
  facet_wrap(~ drv, labeller = labeller(drv = c(`4` = "4WD", f = "Front", r = "Rear"))) +
  labs(x = "Displacement (L)", y = "Highway mpg", tag = "D") + theme_halftone(axes = "box") + theme(legend.position = "bottom", legend.justification = "left") + guides(colour = guide_legend(override.aes = list(size = 1.5)))

## E ridgelines
aq <- airquality; aq$Month <- factor(month.abb[aq$Month], levels = rev(month.abb[5:9])); rg <- halftone_ridges(aq$Temp, aq$Month, scale = 1.8)
E <- ggplot(); rc <- c(ink[["blue"]], ink[["green"]], ink[["ochre"]], ink[["red"]], ink[["violet"]])
for (i in seq_along(rg$fields)) E <- E + geom_halftone(data = rg$fields[[i]], aes(x, y, z = z), pitch = 0.5, grid = "hex", levels = 5, range = c(0, 1), colour = rc[i]) +
  geom_line(data = rg$lines[[i]], aes(x, y), colour = W, linewidth = 0.8) + geom_line(data = rg$lines[[i]], aes(x, y), colour = "black", linewidth = 0.35) +
  annotate("segment", x = min(rg$lines[[i]]$x), xend = max(rg$lines[[i]]$x), y = i, yend = i, linewidth = 0.25)
E <- E + scale_y_continuous(breaks = seq_along(rg$levels), labels = rg$levels, expand = expansion(c(0.02, 0.08))) + labs(x = "Daily max temperature (°F)", y = NULL, tag = "E") + th + theme(axis.line.y = element_blank(), axis.ticks.y = element_blank())

## F elevation
vol <- data.frame(expand.grid(x = seq_len(ncol(volcano)), y = seq_len(nrow(volcano))), z = as.vector(t(volcano)))
F <- ggplot() + geom_halftone(data = vol, aes(x, y, z = z, colour = z), pitch = 0.5, angle = 45, levels = 8, dot_max = 1.05, gamma = 0.6) +
  scale_colour_gradientn(colours = c("#E7D9B8", ink[["ochre"]], "#7A4A1E", "#2B1D14"), name = "Elevation\n(m)") +
  geom_contour(data = vol, aes(x, y, z = z), colour = W, linewidth = 0.6, bins = 8) + geom_contour(data = vol, aes(x, y, z = z), colour = "black", linewidth = 0.25, bins = 8) +
  coord_equal(expand = FALSE) + labs(x = NULL, y = NULL, tag = "F") + theme_halftone(axes = "box") + theme(axis.text = element_blank(), axis.ticks = element_blank(), legend.key.height = unit(5, "mm"), legend.key.width = unit(2.5, "mm"))

## G expression heatmap
set.seed(2); genes <- paste0("Gene ", 1:18); samples <- paste0("S", 1:12)
M <- outer(sin(seq(0, 3, length.out = 18)), cos(seq(0, 3, length.out = 12))) * 2 + matrix(rnorm(18 * 12, sd = 0.6), 18)
hm <- data.frame(expand.grid(x = seq_along(samples), y = seq_along(genes)), v = as.vector(t(M))); hm$mag <- abs(hm$v)
G <- ggplot(hm, aes(x, y)) + geom_tile(fill = NA, colour = "grey85", linewidth = 0.15) +
  geom_halftone(aes(z = mag, colour = v), pitch = 0.45, levels = 5, dot_max = 1, range = c(0, max(hm$mag))) +
  scale_colour_gradient2(low = ink[["blue"]], mid = "grey80", high = ink[["red"]], midpoint = 0, name = "log2 FC") +
  scale_x_continuous(breaks = seq_along(samples), labels = samples, expand = c(0, 0.5)) + scale_y_continuous(breaks = seq_along(genes), labels = genes, expand = c(0, 0.5)) +
  coord_equal() + labs(x = NULL, y = NULL, tag = "G") + theme_halftone(axes = "none") + theme(axis.ticks = element_blank(), axis.text.x = element_text(angle = 45, hjust = 1), axis.text.y = element_text(size = 6), legend.key.height = unit(5, "mm"), legend.key.width = unit(2.5, "mm"))

## H screens (one ink)
tt6 <- 1:40; set.seed(4); s6 <- data.frame(t = tt6, a = 10 + 4 * sin(tt6 / 5) + rnorm(40, 0, 0.6), b = 6 + tt6 / 6 + rnorm(40, 0, 0.5), c = 5 + 3 * cos(tt6 / 7) + rnorm(40, 0, 0.5))
cum <- with(s6, cbind(0, a, a + b, a + b + c)); nms <- c("Series A", "Series B", "Series C")
f6 <- do.call(rbind, lapply(1:3, function(k) { b <- halftone_band(tt6, (cum[, k] + cum[, k + 1]) / 2, cum[, k], cum[, k + 1], profile = "flat", ny = 220, ylim = c(0, max(cum) * 1.02)); b$series <- nms[k]; b }))
H <- ggplot() + geom_halftone(data = f6, aes(x, y, z = z, screen = series), pitch = 0.6, levels = 1, dot_max = 0.6, colour = "black", range = c(0, 1)) + scale_screen_discrete(name = NULL) +
  lapply(2:4, function(k) list(geom_line(data = data.frame(x = tt6, y = cum[, k]), aes(x, y), colour = W, linewidth = 0.8), geom_line(data = data.frame(x = tt6, y = cum[, k]), aes(x, y), colour = "black", linewidth = 0.35))) +
  scale_y_continuous(expand = c(0, 0)) + scale_x_continuous(expand = c(0, 0)) + labs(x = "Time", y = "Stacked value", tag = "H") + th + theme(legend.position = "bottom", legend.justification = "left", legend.key.size = unit(4, "mm"))

hts <- c(A = 60, B = 60, C = 60, D = 62, E = 60, F = 75, G = 90, H = 62)
for (nm in names(hts)) { p <- get(nm); r <- try(ggsave_journal(paste0("j_", nm, ".png"), p, "single", height = hts[[nm]], dpi = 600), silent = TRUE)
  cat(nm, if (inherits(r, "try-error")) paste("ERROR", conditionMessage(attr(r, "condition"))) else "ok", "\n") }
