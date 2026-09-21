options(halftone.style = "journal"); source("geom_halftone.R", local = TRUE); source("theme_halftone.R", local = TRUE); source("with_halftone.R", local = TRUE); source("halftone_helpers.R", local = TRUE)
library(survival); library(maps); ink <- halftone_inks
fit <- survfit(Surv(time, status) ~ ph.ecog, data = subset(lung, ph.ecog < 3))
km <- broom_like <- do.call(rbind, lapply(seq_along(fit$strata), function(i) { s <- fit[i]; data.frame(time = c(0, s$time), surv = c(1, s$surv), lo = c(1, s$lower), hi = c(1, s$upper), g = names(fit$strata)[i]) }))
km$g <- factor(km$g, labels = c("ECOG 0", "ECOG 1", "ECOG 2")); km$lo[is.na(km$lo)] <- 0; km$hi[is.na(km$hi)] <- km$surv[is.na(km$hi)]
# step form for the ribbon: at each event time carry the previous value then jump
stepify <- function(d) { n <- nrow(d); i <- rep(seq_len(n), each = 2)[-1]; j <- c(rep(2:n, each = 2)); out <- d[i, ]; out$time <- d$time[c(1, j)][seq_len(nrow(out))]; out }
kms <- do.call(rbind, lapply(split(km, km$g), function(d) { d <- d[order(d$time), ]; n <- nrow(d)
  data.frame(time = c(d$time[1], rep(d$time[-1], each = 2)), surv = c(rep(d$surv[-n], each = 2), d$surv[n]), lo = c(rep(d$lo[-n], each = 2), d$lo[n]), hi = c(rep(d$hi[-n], each = 2), d$hi[n]), g = d$g[1]) }))
cols <- c(`ECOG 0` = ink[["blue"]], `ECOG 1` = ink[["ochre"]], `ECOG 2` = ink[["red"]])
# A: the KM is now geom_ribbon + geom_step, wrapped
A <- ggplot(kms, aes(time, group = g)) +
  with_halftone(geom_ribbon(aes(ymin = lo, ymax = hi, fill = g), stat = "identity", outline.type = "full"), pitch = 0.5, tone = "centre", levels = 6, outline = FALSE) +
  geom_step(aes(y = surv, colour = g), linewidth = 0.55) +
  scale_fill_manual(values = cols, name = NULL) + scale_colour_manual(values = cols, guide = "none") +
  scale_y_continuous(labels = scales::percent) + labs(x = "Days", y = "Overall survival", tag = "A") + theme_halftone() + theme(legend.position = c(0.8, 0.85))
# B: geom_col
d <- data.frame(g = c("BOS", "RAS", "Mixed", "Undef."), n = c(52, 21, 14, 13))
B <- ggplot(d, aes(g, n, fill = g)) + with_halftone(geom_col(width = 0.7, colour = "black", linewidth = 0.3), pitch = 0.55, tone = "flat") +
  scale_fill_manual(values = unname(ink[c("red", "ochre", "violet", "grey")]), guide = "none") + labs(x = NULL, y = "Patients (%)", tag = "B") + theme_halftone()
# C: geom_density with centre fade
C <- ggplot(iris, aes(Sepal.Length, fill = Species)) + with_halftone(geom_density(alpha = 1, colour = "black", linewidth = 0.3), pitch = 0.5, tone = "edge", levels = 5) +
  scale_fill_halftone(name = NULL) + labs(x = "Sepal length (cm)", y = "Density", tag = "C") + theme_halftone() + theme(legend.position = c(0.8, 0.85))
# D: geom_polygon map (no sf), tone by value through the fill scale, flat screen
val <- setNames(USArrests$Murder, tolower(rownames(USArrests))); st <- map_data("state"); st$murder <- val[st$region]
D <- ggplot(st, aes(long, lat, group = group, fill = murder)) + with_halftone(geom_polygon(colour = "black", linewidth = 0.2), pitch = 0.5, angle = 45, grid = "square", tone = "flat", levels = 6) +
  scale_fill_gradientn(colours = c("#E7D9B8", ink[["ochre"]], ink[["red"]], "#3A0A0A"), name = "Murder\nper 100k") + coord_map("albers", lat0 = 30, lat1 = 45) +
  labs(x = NULL, y = NULL, tag = "D") + theme_halftone(axes = "none") + theme(axis.text = element_blank(), legend.key.height = unit(5, "mm"), legend.key.width = unit(2.5, "mm"))
for (nm in c("A", "B", "C", "D")) { r <- try(ggsave_journal(paste0("wh_", nm, ".png"), get(nm), "single", height = 62, dpi = 600), silent = TRUE); cat(nm, if (inherits(r, "try-error")) conditionMessage(attr(r, "condition")) else "ok", "\n") }
