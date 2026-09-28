# readme_figures.R: assemble gghalftone/man/figures/ from the accepted renders.
# The README shows seven images. Six are copies of renders the other scripts produce; gallery.png is a montage built
# here. Without this step man/figures/ drifts from figures/v2/ and the README shows work that no script reproduces.
# Run from the project root, after gallery2.R and showcase.R: Rscript prototypes/readme_figures.R
suppressPackageStartupMessages({library(magick)})

dest <- "gghalftone/man/figures"
dir.create(dest, showWarnings = FALSE, recursive = TRUE)

# README image  <-  the render it comes from
copies <- c(
  "km.png"         = "figures/v2/km.png",
  "km_bw.png"      = "figures/v2/km_bw.png",
  "engraving.png"  = "figures/v2/elevation.png",
  "photograph.png" = "figures/v2/showcase/photograph.png",
  "press.png"      = "figures/v2/press/map.png",
  "wind_rose.png"  = "figures/v2/showcase/wind_rose.png"
)
miss <- copies[!file.exists(copies)]
if (length(miss)) stop("missing render(s): ", paste(miss, collapse = ", "), ". Run gallery2.R and showcase.R first.",
                       call. = FALSE)
# The renders are 600 dpi plates. A README is read on a screen, and these ship inside the package, so they are
# resized to a web width and quantised. At full size man/figures/ was 22 MB and the source tarball with it.
web <- function(src, out, width = 1400, colours = 160) {
  im <- image_read(src)
  if (image_info(im)$width > width) im <- image_scale(im, as.character(width))
  image_write(image_quantize(im, colours, dither = FALSE), out, format = "png")
}
ok <- vapply(seq_along(copies), function(i)
  isTRUE(tryCatch({ web(copies[i], file.path(dest, names(copies)[i])); TRUE }, error = function(e) FALSE)), logical(1))
cat(sprintf("copied %d/%d\n", sum(ok), length(ok)))
if (!all(ok)) stop("copy failed for: ", paste(names(copies)[!ok], collapse = ", "), call. = FALSE)

# the montage: six gallery figures on two rows, scaled to a common width
tiles <- c("figures/v2/km.png", "figures/v2/smooth.png", "figures/v2/densities.png",
           "figures/v2/map.png", "figures/v2/km_bw.png", "figures/v2/stipple.png")
if (!all(file.exists(tiles))) stop("missing gallery renders for the montage", call. = FALSE)
im <- image_join(lapply(tiles, function(f) image_border(image_scale(image_read(f), "620"), "white", "10x10")))
montage <- image_append(c(image_append(im[1:3]), image_append(im[4:6])), stack = TRUE)
image_write(image_quantize(montage, 160, dither = FALSE), file.path(dest, "gallery.png"), format = "png")
cat("montage ok\n")

# the whole-plot figure: the same plot as given, through halftone_plot(), and composed layer by layer
suppressPackageStartupMessages({library(gghalftone); library(ggplot2); library(patchwork)})
m <- loess(dist ~ speed, cars, span = 0.9)
nd <- data.frame(speed = seq(4, 25, length.out = 80))
pr <- predict(m, nd, se = TRUE)
nd$fit <- pr$fit; nd$lo <- pr$fit - 1.96 * pr$se.fit; nd$hi <- pr$fit + 1.96 * pr$se.fit
lab <- labs(x = "Speed (mph)", y = "Stopping distance (ft)")
given <- ggplot(nd, aes(speed)) + geom_ribbon(aes(ymin = lo, ymax = hi), fill = "steelblue") +
  geom_line(aes(y = fit), linewidth = 0.6) + geom_point(data = cars, aes(speed, dist), size = 1) +
  lab + theme_classic(base_size = 8)
hand <- ggplot(nd, aes(speed)) +
  with_halftone(geom_ribbon(aes(ymin = lo, ymax = hi), fill = halftone_inks[["blue"]])) +
  with_halo(geom_line(aes(y = fit), colour = halftone_inks[["blue"]], linewidth = 0.35)) +
  geom_point(data = cars, aes(speed, dist), shape = 21, fill = "white", size = 0.8, stroke = 0.3) +
  lab + theme_classic(base_size = 8) + theme_halftone()
# a panel title sits above the axis text, not beside it: base_size is 8, so the title is 11
titled <- function(p, s) p + labs(title = s) +
  theme(plot.title = element_text(size = 11, face = "bold", hjust = 0, margin = margin(b = 3)))
eng <- tempfile(fileext = ".png")
ggsave_journal(eng, titled(given, "as given") | titled(halftone_plot(given), "halftone_plot(p)") |
  titled(hand, "composed by hand"), width = 3 * 70, height = 58, dpi = 300)
web(eng, file.path(dest, "engine.png"), width = 1600); unlink(eng)
cat("engine figure ok\n")

if (!file.exists("figures/v2/showcase/whole_plot.png"))
  stop("missing figures/v2/showcase/whole_plot.png; run showcase.R first", call. = FALSE)
web("figures/v2/showcase/whole_plot.png", file.path(dest, "whole_plot.png"), width = 1600)
cat("whole-plot figure ok\n")
