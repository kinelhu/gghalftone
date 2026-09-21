options(halftone.style = "editorial")
source("geom_halftone.R", local = TRUE); source("theme_halftone.R", local = TRUE); source("halftone_helpers.R", local = TRUE); source("halftone_raster.R", local = TRUE)
library(patchwork); ink <- halftone_inks; paper <- halftone_paper; inkc <- halftone_ink; mono <- "Inconsolata"

## 1. CMYK colour halftone of ImageMagick's built-in "rose:" image
rose <- halftone_raster("rose:", max_px = 120)
p1 <- ggplot() + geom_halftone_cmyk(rose, pitch = 1.1, levels = 6) + coord_equal(expand = FALSE) +
  labs(title = "Four-colour process", subtitle = "CMYK SCREENS AT 15° / 75° / 0° / 45°  ·  magick 'rose:'", x = NULL, y = NULL) +
  theme_halftone(axes = "box") + theme(axis.text = element_blank(), axis.ticks = element_blank())

## 2. Ridgelines: temperature by month, halftone fill fading to the baseline
aq <- airquality; aq$Month <- factor(month.abb[aq$Month], levels = rev(month.abb[5:9]))
rg <- halftone_ridges(aq$Temp, aq$Month, scale = 1.8)
p2 <- ggplot()
for (i in seq_along(rg$fields)) p2 <- p2 +
  geom_halftone(data = rg$fields[[i]], aes(x, y, z = z), pitch = 0.9, grid = "hex", levels = 4, range = c(0, 1),
                colour = c(ink[["blue"]], ink[["green"]], ink[["ochre"]], ink[["red"]], ink[["violet"]])[i]) +
  geom_line(data = rg$lines[[i]], aes(x, y), colour = paper, linewidth = 1.8) +
  geom_line(data = rg$lines[[i]], aes(x, y), colour = inkc, linewidth = 0.5) +
  annotate("segment", x = min(rg$lines[[i]]$x), xend = max(rg$lines[[i]]$x), y = i, yend = i, colour = inkc, linewidth = 0.3)
p2 <- p2 + scale_y_continuous(breaks = seq_along(rg$levels), labels = rg$levels, expand = expansion(c(0.02, 0.08))) +
  labs(x = "DAILY MAX TEMPERATURE (°F)", y = NULL, title = "Ridgelines", subtitle = "NEW YORK 1973  ·  DENSITY FILL FADES TOWARD THE BASELINE") +
  theme_halftone() + theme(axis.line.y = element_blank(), axis.ticks.y = element_blank())

## 3. Spots on a scatter: mtcars, tone = horsepower, ring colour = cylinders
mt <- mtcars; mt$cyl <- factor(mt$cyl)
p3 <- ggplot(mt, aes(wt, mpg, z = hp, colour = cyl)) +
  geom_spot(r = 2.6, pitch = 0.55, levels = 6, ring_lwd = 0.7) +
  scale_colour_manual(values = c(`4` = ink[["blue"]], `6` = ink[["ochre"]], `8` = ink[["red"]]), name = "CYLINDERS") +
  labs(x = "WEIGHT (1000 LB)", y = "MILES PER GALLON", title = "Spots", subtitle = "EACH POINT IS A HALFTONE DISC  ·  TONE = HORSEPOWER, INK = CYLINDERS") +
  theme_halftone() + guides(colour = guide_legend(override.aes = list(size = 3)))

## 4. scRNA-style dot plot: size = % cells expressing, tone = mean expression (simulated)
set.seed(7); genes <- paste0(c("CD3E","CD8A","NKG7","MS4A1","CD79A","LYZ","S100A8","FCGR3A","PPBP","HBB"), ""); cl <- paste0("C", 1:8)
dp <- expand.grid(gene = genes, cluster = cl)
dp$pct <- runif(nrow(dp), 0.05, 1); dp$expr <- rbeta(nrow(dp), 0.7, 1.8) * 3
# plant a marker structure
for (i in seq_along(genes)) { j <- ((i - 1) %% 8) + 1; k <- which(dp$gene == genes[i] & dp$cluster == cl[j]); dp$pct[k] <- 0.9; dp$expr[k] <- 2.6 + runif(1, 0, 0.4) }
dp$r <- 0.7 + 2.3 * dp$pct
p4 <- ggplot(dp, aes(cluster, gene, z = expr, r = r)) +
  geom_spot(pitch = 0.5, levels = 6, colour = ink[["violet"]], ring_lwd = 0.4, range = c(0, 3)) +
  labs(x = "CLUSTER", y = NULL, title = "Marker dot plot", subtitle = "DISC RADIUS = % CELLS EXPRESSING  ·  HALFTONE TONE = MEAN EXPRESSION") +
  theme_halftone(axes = "none") + theme(axis.ticks = element_blank(), axis.text.y = element_text(face = "italic", family = "EB Garamond", size = rel(1)))

gal <- (p1 | p2) / (p3 | p4) + plot_annotation(theme = theme(plot.background = element_rect(fill = paper, colour = NA)))
ggsave("gallery6.png", gal, width = 13, height = 11, dpi = 150, bg = paper, device = ragg::agg_png)
cat("gallery ok\n")
