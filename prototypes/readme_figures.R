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
ok <- file.copy(copies, file.path(dest, names(copies)), overwrite = TRUE)
cat(sprintf("copied %d/%d\n", sum(ok), length(ok)))
if (!all(ok)) stop("copy failed for: ", paste(names(copies)[!ok], collapse = ", "), call. = FALSE)

# the montage: six gallery figures on two rows, scaled to a common width
tiles <- c("figures/v2/km.png", "figures/v2/smooth.png", "figures/v2/densities.png",
           "figures/v2/map.png", "figures/v2/km_bw.png", "figures/v2/stipple.png")
if (!all(file.exists(tiles))) stop("missing gallery renders for the montage", call. = FALSE)
im <- image_join(lapply(tiles, function(f) image_border(image_scale(image_read(f), "1200"), "white", "18x18")))
image_write(image_append(c(image_append(im[1:3]), image_append(im[4:6])), stack = TRUE),
            file.path(dest, "gallery.png"))
cat("montage ok\n")
