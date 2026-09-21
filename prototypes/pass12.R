options(halftone.style = "journal"); source("geom_halftone.R", local = TRUE); source("theme_halftone.R", local = TRUE); source("with_halftone.R", local = TRUE); source("halftone_helpers.R", local = TRUE)
ink <- halftone_inks; W <- "white"
## H: stacked areas, one ink, screens -- now via the wrapper, clipped
tt6 <- 1:40; set.seed(4); s6 <- data.frame(t = tt6, a = 10 + 4 * sin(tt6 / 5) + rnorm(40, 0, 0.6), b = 6 + tt6 / 6 + rnorm(40, 0, 0.5), c = 5 + 3 * cos(tt6 / 7) + rnorm(40, 0, 0.5))
long <- data.frame(t = rep(tt6, 3), v = c(s6$a, s6$b, s6$c), series = rep(c("Series A", "Series B", "Series C"), each = 40))
H <- ggplot(long, aes(t, v, screen = series, group = series)) +
  with_halftone(geom_area(fill = "black", colour = "black", linewidth = 0.35, position = position_stack(reverse = TRUE)), pitch = 0.6, tone = "flat", tone_max = 1, levels = 1, dot_max = 0.62) +
  scale_screen_discrete(name = NULL) + scale_y_continuous(expand = c(0, 0)) + scale_x_continuous(expand = c(0, 0)) +
  labs(x = "Time", y = "Stacked value", tag = "H") + theme_halftone() + theme(legend.position = "bottom", legend.justification = "left", legend.key.size = unit(4, "mm"))
## A: forecast fan, redesigned -- log scale, 1957 onward, nested 50/80/95 % bands, one ink family, hairline median
fit <- arima(log(AirPassengers), order = c(0, 1, 1), seasonal = list(order = c(0, 1, 1), period = 12)); h <- 36; fc <- predict(fit, n.ahead = h); tt <- seq(1961, by = 1 / 12, length.out = h)
bands <- do.call(rbind, lapply(c(1.96, 1.28, 0.67), function(k) data.frame(t = tt, lo = as.numeric(exp(fc$pred - k * fc$se)), hi = as.numeric(exp(fc$pred + k * fc$se)), level = factor(paste0(round(2 * pnorm(k) * 100 - 100), "%"), levels = c("95%", "80%", "50%")))))
hist <- data.frame(t = as.numeric(time(AirPassengers)), y = as.numeric(AirPassengers)); hist <- hist[hist$t >= 1957, ]
A <- ggplot() +
  with_halftone(geom_ribbon(data = bands, aes(t, ymin = lo, ymax = hi, fill = level, group = level), stat = "identity"), pitch = 0.45, tone = "flat", levels = 1, tone_max = 0.55, dot_max = 0.9, outline = FALSE, overlap = "stack") +
  scale_fill_manual(values = c(`95%` = "#D9C9B0", `80%` = ink[["ochre"]], `50%` = ink[["red"]]), name = "Interval", breaks = c("50%", "80%", "95%")) +
  geom_line(data = hist, aes(t, y), colour = "black", linewidth = 0.45) +
  geom_line(data = data.frame(t = tt, y = as.numeric(exp(fc$pred))), aes(t, y), colour = W, linewidth = 1.0) + geom_line(data = data.frame(t = tt, y = as.numeric(exp(fc$pred))), aes(t, y), colour = "black", linewidth = 0.45, linetype = "22") +
  geom_vline(xintercept = 1961, linewidth = 0.3, linetype = "dotted") + scale_y_log10(breaks = c(300, 400, 600, 800, 1200)) +
  labs(x = NULL, y = "Passengers (thousands, log)", tag = "A") + theme_halftone() + theme(legend.position = c(0.2, 0.8), legend.key.size = unit(3.5, "mm"))
## G: heatmap, redesigned -- hue = sign, dot area = |log2FC|, no grey, rows clustered
set.seed(2); genes <- paste0("Gene ", 1:18); samples <- paste0("S", 1:12)
M <- outer(sin(seq(0, 3, length.out = 18)), cos(seq(0, 3, length.out = 12))) * 2 + matrix(rnorm(18 * 12, sd = 0.6), 18)
ord <- hclust(dist(M))$order; M <- M[ord, ]; genes <- genes[ord]
hm <- data.frame(expand.grid(x = seq_along(samples), y = seq_along(genes)), v = as.vector(t(M))); hm$mag <- abs(hm$v); hm$sign <- factor(ifelse(hm$v >= 0, "Up", "Down"), levels = c("Up", "Down"))
G <- ggplot(hm, aes(x, y)) + geom_tile(fill = NA, colour = "grey90", linewidth = 0.15) +
  geom_halftone(aes(z = mag, colour = sign), pitch = 0.5, levels = 5, dot_max = 1, range = c(0, max(hm$mag)), overlap = "stack") +
  scale_colour_manual(values = c(Up = ink[["red"]], Down = ink[["blue"]]), name = NULL) +
  scale_x_continuous(breaks = seq_along(samples), labels = samples, expand = c(0, 0.5)) + scale_y_continuous(breaks = seq_along(genes), labels = genes, expand = c(0, 0.5)) +
  coord_equal() + labs(x = NULL, y = NULL, tag = "G", caption = "Dot area = |log2 fold change|") + theme_halftone(axes = "none") +
  theme(axis.ticks = element_blank(), axis.text.x = element_text(angle = 45, hjust = 1), axis.text.y = element_text(size = 6), legend.position = "bottom", legend.justification = "left")
for (nm in c("H", "A", "G")) { r <- try(ggsave_journal(paste0("p12_", nm, ".png"), get(nm), "single", height = c(H = 62, A = 62, G = 90)[[nm]], dpi = 600), silent = TRUE); cat(nm, if (inherits(r, "try-error")) conditionMessage(attr(r, "condition")) else "ok", "\n") }
