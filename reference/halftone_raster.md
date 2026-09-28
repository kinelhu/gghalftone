# Image to field

Reads an image from a path or a `magick` image object and returns a
field data frame (`x`, `y`, `z` and `r`, `g`, `b`) for
[`geom_halftone()`](https://kinelhu.github.io/gghalftone/reference/geom_halftone.md)
or
[`geom_halftone_cmyk()`](https://kinelhu.github.io/gghalftone/reference/cmyk.md).
When `invert = TRUE`, dark pixels get high tone. Requires the magick
package.

## Usage

``` r
halftone_raster(
  img,
  max_px = 160,
  channel = c("luminance", "red", "green", "blue"),
  invert = TRUE
)
```

## Arguments

- img:

  A file path or a `magick-image`.

- max_px:

  Longest side of the resampled image in cells.

- channel:

  Which channel becomes `z`.

- invert:

  Map dark to high tone.

## Value

A data frame.
