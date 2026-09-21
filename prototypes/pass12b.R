options(halftone.style = "journal"); source("geom_halftone.R", local = TRUE); source("theme_halftone.R", local = TRUE); source("with_halftone.R", local = TRUE); source("halftone_helpers.R", local = TRUE)
ink <- halftone_inks; W <- "white"
## H: stacked areas -- lighter screens, angle AND shape differ, thin outlines
tt6 <- 1:40; set.seed(4); s6 <- data.frame(t = tt6, a = 10 + 4 * sin(tt6 / 5) + rnorm(40, 0, 0.6), b = 6 + tt6 / 6 + rnorm(40, 0, 0.5), c = 5 + 3 * cos(tt6 / 7) + rnorm(40, 0, 0.5))
long <- data.frame(t = rep(tt6, 3), v = c(s6$a, s6$b, s6$c), series = rep(c("Series A", "Series B", "Series C"), each = 40))
H <- ggplot(long, aes(t, v, screen = series, group = series)) +
  with_halftone(geom_area(fill = "black", colour = "black", linewidth = 0.35, position = position_stack(reverse = TRUE)), pitch = 0.7, tone = "flat", tone_max = 1, levels = 1, dot_max = 0.5) +
  scale_screen_discrete(name = NULL) + scale_y_continuous(expand = c(0, 0)) + scale_x_continuous(expand = c(0, 0)) +
  labs(x = "Time", y = "Stacked value", tag = "H") + theme_halftone() + theme(legend.position = "bottom", legend.justification = "left", legend.key.size = unit(4.5, "mm"))
## A: fan chart on a series that fans -- co2, seasonal ARIMA, 5-year horizon; nested bands, ONE ink, tone increasing inward
fit <- arima(co2, order = c(0, 1, 1), seasonal = list(order = c(0, 1, 1), period = 12)); h <- 60; fc <- predict(fit, n.ahead = h); tt <- seq(1998, by = 1 / 12, length.out = h)
bands <- do.call(rbind, lapply(c(1.96, 1.28, 0.67), function(k) data.frame(t = tt, lo = as.numeric(fc$pred - k * fc$se), hi = as.numeric(fc$pred + k * fc$se),
  level = factor(paste0(round(2 * pnorm(k) * 100 - 100), "%"), levels = c("95%", "80%", "50%")))))
hist <- data.frame(t = as.numeric(time(co2)), y = as.numeric(co2)); hist <- hist[hist$t >= 1990, ]
A <- ggplot() +
  with_halftone(geom_ribbon(data = bands, aes(t, ymin = lo, ymax = hi, alpha = level), fill = ink[["blue"]], stat = "identity"), pitch = 0.5, tone = "flat", tone_max = 1, levels = 1, dot_max = 0.9, outline = FALSE, overlap = "stack") +
  scale_alpha_manual(values = c(`95%` = 0.22, `80%` = 0.5, `50%` = 1), name = "Interval", breaks = c("50%", "80%", "95%")) +
  geom_line(data = hist, aes(t, y), colour = "black", linewidth = 0.4) +
  geom_line(data = data.frame(t = tt, y = as.numeric(fc$pred)), aes(t, y), colour = W, linewidth = 1.0) + geom_line(data = data.frame(t = tt, y = as.numeric(fc$pred)), aes(t, y), colour = "black", linewidth = 0.45, linetype = "22") +
  geom_vline(xintercept = 1998, linewidth = 0.3, linetype = "dotted") +
  labs(x = NULL, y = expression(CO[2]~(ppm)), tag = "A") + theme_halftone() + theme(legend.position = c(0.15, 0.8), legend.key.size = unit(3.5, "mm")) +
  guides(alpha = guide_legend(override.aes = list(fill = ink[["blue"]])))
## G: back to the diverging colour scale, but no grey ground and lighter cell grid
set.seed(2); genes <- paste0("Gene ", 1:18); samples <- paste0("S", 1:12)
M <- outer(sin(seq(0, 3, length.out = 18)), cos(seq(0, 3, length.out = 12))) * 2 + matrix(rnorm(18 * 12, sd = 0.6), 18)
ord <- hclust(dist(M))$order; M <- M[ord, ]; genes <- genes[ord]
hm <- data.frame(expand.grid(x = seq_along(samples), y = seq_along(genes)), v = as.vector(t(M))); hm$mag <- abs(hm$v)
G <- ggplot(hm, aes(x, y)) + geom_tile(fill = NA, colour = "grey88", linewidth = 0.15) +
  geom_halftone(aes(z = mag, colour = v), pitch = 0.5, levels = 5, dot_max = 0.9, range = c(0, max(hm$mag)), overlap = "stack") +
  scale_colour_gradient2(low = ink[["blue"]], mid = "#EDE9E0", high = ink[["red"]], midpoint = 0, name = expression(log[2]~FC)) +
  scale_x_continuous(breaks = seq_along(samples), labels = samples, expand = c(0, 0.5)) + scale_y_continuous(breaks = seq_along(genes), labels = genes, expand = c(0, 0.5)) +
  coord_equal() + labs(x = NULL, y = NULL, tag = "G") + theme_halftone(axes = "none") +
  theme(axis.ticks = element_blank(), axis.text.x = element_text(angle = 45, hjust = 1), axis.text.y = element_text(size = 6), legend.key.height = unit(5, "mm"), legend.key.width = unit(2.5, "mm"))
for (nm in c("H", "A", "G")) { r <- try(ggsave_journal(paste0("p12b_", nm, ".png"), get(nm), "single", height = c(H = 62, A = 62, G = 90)[[nm]], dpi = 600), silent = TRUE); cat(nm, if (inherits(r, "try-error")) conditionMessage(attr(r, "condition")) else "ok", "\n") }
