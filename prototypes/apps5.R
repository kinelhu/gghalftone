options(halftone.style = "editorial")
source("geom_halftone.R", local = TRUE); source("theme_halftone.R", local = TRUE); source("halftone_helpers.R", local = TRUE)
library(patchwork); library(MASS); library(mgcv); library(maps)
ink <- halftone_inks; paper <- halftone_paper; inkc <- halftone_ink
mono <- "Inconsolata"

## 1. GAM on mcycle: tent band, estimate line, raw points
m <- gam(accel ~ s(times, k = 20), data = mcycle)
nd <- data.frame(times = seq(2.4, 57.6, length.out = 200)); pr <- predict(m, nd, se.fit = TRUE)
nd$fit <- pr$fit; nd$lo <- pr$fit - 1.96 * pr$se.fit; nd$hi <- pr$fit + 1.96 * pr$se.fit
bd <- halftone_band(nd$times, nd$fit, nd$lo, nd$hi, profile = "tent")
p1 <- ggplot() +
  geom_halftone(data = bd, aes(x, y, z = z), pitch = 1.0, grid = "hex", levels = 4, colour = ink[["blue"]], range = c(0, 1)) +
  geom_line(data = nd, aes(times, fit), colour = paper, linewidth = 2.2) +
  geom_line(data = nd, aes(times, fit), colour = ink[["blue"]], linewidth = 0.9) +
  geom_point(data = mcycle, aes(times, accel), shape = 21, fill = paper, colour = inkc, size = 1.4, stroke = 0.4) +
  labs(x = "TIME AFTER IMPACT (MS)", y = "HEAD ACCELERATION (G)", title = "Smooth with uncertainty", subtitle = "GAM, 95% CI AS TENT-PROFILE HALFTONE  ·  MCYCLE") +
  theme_halftone()

## 2. Forecast fan: ARIMA on log AirPassengers, gaussian profile across the 95% band, colour = time
fit <- arima(log(AirPassengers), order = c(0, 1, 1), seasonal = list(order = c(0, 1, 1), period = 12))
h <- 36; fc <- predict(fit, n.ahead = h); tt <- seq(1961, by = 1 / 12, length.out = h)
fan <- halftone_band(tt, exp(fc$pred), exp(fc$pred - 1.96 * fc$se), exp(fc$pred + 1.96 * fc$se), profile = "gauss", ny = 300)
hist <- data.frame(t = as.numeric(time(AirPassengers)), y = as.numeric(AirPassengers))
p2 <- ggplot() +
  geom_halftone(data = fan, aes(x, y, z = z, colour = x), pitch = 0.8, angle = 45, levels = 6, dot_max = 1, range = c(0, 1), show.legend = FALSE) +
  scale_colour_gradient(low = ink[["red"]], high = ink[["ochre"]]) +
  geom_line(data = hist, aes(t, y), colour = inkc, linewidth = 0.6) +
  geom_line(data = data.frame(t = tt, y = exp(fc$pred)), aes(t, y), colour = paper, linewidth = 2) +
  geom_line(data = data.frame(t = tt, y = exp(fc$pred)), aes(t, y), colour = inkc, linewidth = 0.7, linetype = "22") +
  geom_vline(xintercept = 1961, colour = inkc, linewidth = 0.3, linetype = "dotted") +
  labs(x = NULL, y = "PASSENGERS (THOUSANDS)", title = "Forecast fan", subtitle = "SEASONAL ARIMA, 3-YEAR HORIZON  ·  GAUSSIAN PROFILE, 45°") +
  theme_halftone()

## 3. Choropleth without sf: USArrests murder rate, 45 deg screen, dots sized by value; state borders on top
val <- setNames(USArrests$Murder, tolower(rownames(USArrests)))
reg <- halftone_regions("state", val, res = 0.18)
borders <- map_data("state")
p3 <- ggplot() +
  geom_halftone(data = reg, aes(x, y, z = z, colour = z), pitch = 1.0, angle = 45, levels = 6, dot_max = 1) +
  scale_colour_gradientn(colours = c("#E7D9B8", ink[["ochre"]], ink[["red"]], "#3A0A0A"), name = "PER 100K") +
  geom_polygon(data = borders, aes(long, lat, group = group), fill = NA, colour = paper, linewidth = 1.1) +
  geom_polygon(data = borders, aes(long, lat, group = group), fill = NA, colour = inkc, linewidth = 0.3) +
  coord_map("albers", lat0 = 30, lat1 = 45) +
  labs(title = "Choropleth", subtitle = "USARRESTS 1973  ·  RASTERISED VIA maps::map.where(), NO sf", x = NULL, y = NULL) +
  theme_halftone(axes = "none") + theme(axis.text = element_blank(), legend.position = "right", legend.justification = "top") +
  guides(colour = guide_colourbar(barwidth = 0.6, barheight = 7))

## 4. Dot-matrix bars: vertical fade inside bars, square dots, per-bar ink
d4 <- data.frame(cat = c("Bronchiolitis", "Pneumonia", "Rejection", "Infection", "Other"), n = c(41, 33, 26, 18, 9))
bars <- halftone_bars(d4$cat, d4$n, nx = 30, ny = 160, fade = 0.3)
p4 <- ggplot() +
  geom_halftone(data = bars, aes(x, y, z = z, colour = cat), pitch = 1.15, shape = "square", levels = 4, dot_max = 0.9, range = c(0, 1), show.legend = FALSE) +
  scale_colour_halftone() +
  geom_text(data = d4, aes(seq_along(cat), n, label = n), family = mono, vjust = -0.6, size = 3.2, colour = inkc) +
  scale_x_continuous(breaks = seq_along(d4$cat), labels = d4$cat) + scale_y_continuous(expand = expansion(c(0, 0.12))) +
  labs(x = NULL, y = "PATIENTS", title = "Dot-matrix bars", subtitle = "SQUARE DOTS, 1.15 MM  ·  VERTICAL FADE INSIDE EACH BAR") +
  theme_halftone() + theme(axis.line.x = element_blank(), axis.ticks.x = element_blank())

## 5. Facets + groups: loess bands per class within drv
mp <- ggplot2::mpg[ggplot2::mpg$class %in% c("compact", "suv", "subcompact", "pickup"), ]
bands5 <- do.call(rbind, lapply(split(mp, list(mp$drv, mp$class), drop = TRUE), function(d) {
  if (nrow(d) < 8) return(NULL)
  lo <- loess(hwy ~ displ, d, span = 1); xs <- seq(min(d$displ), max(d$displ), length.out = 60)
  pr <- predict(lo, data.frame(displ = xs), se = TRUE)
  b <- halftone_band(xs, pr$fit, pr$fit - 1.96 * pr$se.fit, pr$fit + 1.96 * pr$se.fit, ny = 150, profile = "tent")
  b$drv <- d$drv[1]; b$class <- d$class[1]; b }))
p5 <- ggplot() +
  geom_halftone(data = bands5, aes(x, y, z = z, colour = class), pitch = 0.85, grid = "hex", levels = 3, range = c(0, 1)) +
  geom_point(data = mp, aes(displ, hwy, colour = class), size = 0.9) +
  scale_colour_halftone(name = NULL) + facet_wrap(~ drv, labeller = labeller(drv = c(`4` = "4WD", f = "FRONT", r = "REAR"))) +
  labs(x = "DISPLACEMENT (L)", y = "HIGHWAY MPG", title = "Facets and groups", subtitle = "LOESS BANDS PER CLASS  ·  ONE geom_halftone() CALL") +
  theme_halftone(axes = "box") + guides(colour = guide_legend(override.aes = list(size = 2.5)))

## 6. Screen angle as the series encoding (print-era B&W trick): stacked areas, one ink, three angles
tt6 <- 1:40; set.seed(4)
s6 <- data.frame(t = tt6, a = 10 + 4 * sin(tt6 / 5) + rnorm(40, 0, 0.6), b = 6 + tt6 / 6 + rnorm(40, 0, 0.5), c = 5 + 3 * cos(tt6 / 7) + rnorm(40, 0, 0.5))
cum <- with(s6, cbind(0, a, a + b, a + b + c)); nms <- c("SERIES A", "SERIES B", "SERIES C")
fields6 <- lapply(1:3, function(k) halftone_band(tt6, (cum[, k] + cum[, k + 1]) / 2, cum[, k], cum[, k + 1], profile = "flat", ny = 220, ylim = c(0, max(cum) * 1.02)))
p6 <- ggplot()
for (k in 1:3) p6 <- p6 + geom_halftone(data = fields6[[k]], aes(x, y, z = z), pitch = 1.0, angle = c(0, 45, 90 + 22.5)[k], levels = 1, dot_max = c(0.7, 0.75, 0.55)[k], colour = inkc, range = c(0, 1), shape = c("circle", "circle", "square")[k])
for (k in 2:4) p6 <- p6 + geom_line(data = data.frame(t = tt6, y = cum[, k]), aes(t, y), colour = paper, linewidth = 1.6) + geom_line(data = data.frame(t = tt6, y = cum[, k]), aes(t, y), colour = inkc, linewidth = 0.5)
p6 <- p6 + annotate("label", x = c(6, 6, 6), y = c(5, 13, 22), label = nms, family = mono, size = 2.8, fill = paper, label.size = 0, colour = inkc) +
  scale_y_continuous(expand = c(0, 0)) + scale_x_continuous(expand = c(0, 0)) +
  labs(x = "TIME", y = "STACKED VALUE", title = "One ink, three screens", subtitle = "SERIES ENCODED BY SCREEN ANGLE AND DOT SHAPE  ·  SURVIVES PHOTOCOPYING") +
  theme_halftone()

gal <- (p1 | p2) / (p3 | p4) / (p5 | p6) + plot_annotation(theme = theme(plot.background = element_rect(fill = paper, colour = NA)))
ggsave("gallery5.png", gal, width = 13, height = 16, dpi = 150, bg = paper, device = ragg::agg_png)
cat("gallery ok\n")
