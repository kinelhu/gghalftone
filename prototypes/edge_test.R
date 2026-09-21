options(halftone.style = "journal"); source("geom_halftone.R", local = TRUE); source("theme_halftone.R", local = TRUE); source("with_halftone.R", local = TRUE); source("halftone_helpers.R", local = TRUE)
library(survival); library(patchwork); library(maps); ink <- halftone_inks; W <- "white"
tt <- function(p, t) p + labs(title = t, x = NULL, y = NULL) + theme(plot.title = element_text(size = 8, face = "bold"), legend.position = "none")
fit <- survfit(Surv(time, status) ~ ph.ecog, data = subset(lung, ph.ecog < 3))
km <- do.call(rbind, lapply(seq_along(fit$strata), function(i) { s <- fit[i]; data.frame(time = c(0, s$time), surv = c(1, s$surv), lo = c(1, s$lower), hi = c(1, s$upper), g = names(fit$strata)[i]) }))
km$lo[is.na(km$lo)] <- 0; km$hi[is.na(km$hi)] <- km$surv[is.na(km$hi)]
kms <- do.call(rbind, lapply(split(km, km$g), function(d) { d <- d[order(d$time), ]; n <- nrow(d); data.frame(time = c(d$time[1], rep(d$time[-1], each = 2)), surv = c(rep(d$surv[-n], each = 2), d$surv[n]), lo = c(rep(d$lo[-n], each = 2), d$lo[n]), hi = c(rep(d$hi[-n], each = 2), d$hi[n]), g = d$g[1]) }))
P1 <- tt(ggplot(kms, aes(time, group = g)) + with_halftone(geom_ribbon(aes(ymin = lo, ymax = hi, fill = g)), pitch = 0.5, tone = "edge", outline = FALSE) + geom_step(aes(y = surv, colour = g), linewidth = 0.5) + scale_fill_halftone() + scale_colour_halftone() + theme_halftone(), "KM — edge")
val <- setNames(USArrests$Murder, tolower(rownames(USArrests))); st <- map_data("state"); st$murder <- val[st$region]
P2 <- tt(ggplot(st, aes(long, lat, group = group, fill = murder)) + with_halftone(geom_polygon(colour = "black", linewidth = 0.2), pitch = 0.5, tone = "edge", profile = "radial") + scale_fill_gradientn(colours = c("#E7D9B8", ink[["ochre"]], ink[["red"]], "#3A0A0A")) + coord_map("albers", lat0 = 30, lat1 = 45) + theme_halftone(axes = "none") + theme(axis.text = element_blank()), "Choropleth — edge")
d <- data.frame(g = factor(c("BOS", "RAS", "Mixed", "Undef."), c("BOS", "RAS", "Mixed", "Undef.")), n = c(52, 21, 14, 13))
P3 <- tt(ggplot(d, aes(g, n, fill = g)) + with_halftone(geom_col(width = 0.7, colour = "black", linewidth = 0.3), pitch = 0.5, tone = "edge", profile = "radial") + scale_fill_halftone() + scale_y_continuous(expand = expansion(c(0, 0.08))) + theme_halftone(), "Bars — edge")
aq <- airquality; aq$Month <- factor(month.abb[aq$Month], levels = month.abb[5:9])
P4 <- tt(ggplot(aq, aes(Temp, fill = Month)) + with_halftone(geom_density(colour = "black", linewidth = 0.3, alpha = 1), pitch = 0.5, tone = "edge") + scale_fill_halftone() + theme_halftone(), "5 densities — edge")
tt6 <- 1:40; set.seed(4); s6 <- data.frame(t = tt6, a = 10 + 4 * sin(tt6 / 5) + rnorm(40, 0, 0.6), b = 6 + tt6 / 6 + rnorm(40, 0, 0.5), c = 5 + 3 * cos(tt6 / 7) + rnorm(40, 0, 0.5))
long <- data.frame(t = rep(tt6, 3), v = c(s6$a, s6$b, s6$c), series = rep(c("A", "B", "C"), each = 40))
P5 <- tt(ggplot(long, aes(t, v, fill = series, group = series)) + with_halftone(geom_area(colour = "black", linewidth = 0.3, position = position_stack(reverse = TRUE)), pitch = 0.5, tone = "edge") + scale_fill_halftone() + scale_y_continuous(expand = c(0, 0)) + scale_x_continuous(expand = c(0, 0)) + theme_halftone(), "Stacked areas — edge")
P6 <- tt(ggplot(kms, aes(time, group = g)) + with_halftone(geom_ribbon(aes(ymin = lo, ymax = hi, fill = g)), pitch = 0.5, outline = FALSE) + geom_step(aes(y = surv, colour = g), linewidth = 0.5) + scale_fill_halftone() + scale_colour_halftone() + theme_halftone(), "KM — gaussian (reference)")
ggsave_journal("edge_test.png", (P1 | P2 | P3) / (P4 | P5 | P6), "double", height = 100, dpi = 500); cat("ok\n")
