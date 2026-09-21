options(halftone.style = "journal"); source("geom_halftone.R", local = TRUE); source("theme_halftone.R", local = TRUE); source("halftone_helpers.R", local = TRUE)
library(patchwork)
mk <- function(n, tag, ...) {
  set.seed(1); tt <- 1:40; vals <- sapply(seq_len(n), function(k) 4 + 2 * sin(tt / (3 + k)) + rnorm(40, 0, 0.3)); cum <- cbind(0, t(apply(vals, 1, cumsum)))
  f <- do.call(rbind, lapply(seq_len(n), function(k) { b <- halftone_band(tt, (cum[, k] + cum[, k + 1]) / 2, cum[, k], cum[, k + 1], profile = "flat", ny = 60 * n, ylim = c(0, max(cum) * 1.02)); b$series <- paste("S", k); b }))
  p <- ggplot() + geom_halftone(data = f, aes(x, y, z = z, screen = series), pitch = 0.6, levels = 1, dot_max = 0.6, colour = "black", range = c(0, 1), ...) +
    lapply(2:(n + 1), function(k) list(geom_line(data = data.frame(x = tt, y = cum[, k]), aes(x, y), colour = "white", linewidth = 0.8), geom_line(data = data.frame(x = tt, y = cum[, k]), aes(x, y), colour = "black", linewidth = 0.35))) +
    scale_y_continuous(expand = c(0, 0)) + scale_x_continuous(expand = c(0, 0)) + labs(x = "Time", y = NULL, tag = tag, subtitle = paste(n, "series, angle × shape × tone")) +
    theme_halftone() + theme(legend.position = "bottom", legend.justification = "left", legend.key.size = unit(4, "mm"), plot.subtitle = element_text(size = 6))
  p + scale_screen_discrete(name = NULL)
}
for (n in c(4, 6, 8, 9)) ggsave_journal(paste0("scr_", n, ".png"), mk(n, LETTERS[match(n, c(4, 6, 8, 9))]), "single", height = 62, dpi = 600)
cat("ok\n")
