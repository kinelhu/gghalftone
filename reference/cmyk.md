# Four-colour process screens

`halftone_cmyk()` separates an RGB field (from
[`halftone_raster()`](https://kinelhu.github.io/gghalftone/reference/halftone_raster.md))
into cyan, magenta, yellow and black tone fields; `geom_halftone_cmyk()`
returns the four
[`geom_halftone()`](https://kinelhu.github.io/gghalftone/reference/geom_halftone.md)
layers at the classic screen angles (C 15, M 75, Y 0, K 45) in process
inks.

## Usage

``` r
halftone_cmyk(field)

geom_halftone_cmyk(field, pitch = 1, levels = 6, alpha = 0.85, ...)
```

## Arguments

- field:

  A field with `r`, `g`, `b` columns in `[0, 1]`.

- pitch, levels, alpha, ...:

  Passed to
  [`geom_halftone()`](https://kinelhu.github.io/gghalftone/reference/geom_halftone.md).

## Value

A list of four fields, or a list of four layers to add to a plot.
