options(halftone.style = "journal"); source("geom_halftone.R", local = TRUE); source("theme_halftone.R", local = TRUE); source("with_halftone.R", local = TRUE); source("halftone_helpers.R", local = TRUE)
library(patchwork); ink <- halftone_inks
pal6 <- c(ink[["red"]], ink[["blue"]], ink[["ochre"]], ink[["green"]], ink[["violet"]], "#2A7F8E")
mk <- function(k) { set.seed(3); d <- do.call(rbind, lapply(seq_len(k), function(i) data.frame(x = rnorm(300, 5 + 0.45 * (i - 1), 0.9), g = paste0("G", i))))
  ggplot(d, aes(x, fill = g)) + with_halftone(geom_density(colour = "black", linewidth = 0.3), pitch = 0.5) + scale_fill_manual(values = pal6[seq_len(k)], name = NULL) +
    labs(x = NULL, y = NULL, title = paste(k, "inks")) + theme_halftone() + theme(legend.position = c(0.9, 0.85), legend.key.size = unit(3.5, "mm"), plot.title = element_text(size = 8, face = "bold")) }
for (k in 4:6) ggsave_journal(paste0("ink_", k, ".png"), mk(k), "single", height = 55, dpi = 600); cat("ok\n")
