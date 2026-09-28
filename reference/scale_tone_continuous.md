# Tone scale

Maps a continuous variable to the `tone` aesthetic of
[`geom_spot()`](https://kinelhu.github.io/gghalftone/reference/geom_spot.md)
and
[`geom_halftone()`](https://kinelhu.github.io/gghalftone/reference/geom_halftone.md):
ink density in `[0, 1]`. The legend shows discs (or swatches) at the
scale breaks. `scale_tone()` is an alias.

## Usage

``` r
scale_tone_continuous(name = waiver(), ..., range = c(0, 1), guide = "legend")

scale_tone(name = waiver(), ..., range = c(0, 1), guide = "legend")
```

## Arguments

- name:

  The name of the scale. Used as the axis or legend title. If
  `waiver()`, the default, the name of the scale is taken from the first
  mapping used for that aesthetic. If `NULL`, the legend title will be
  omitted.

- ...:

  Passed to
  [`ggplot2::continuous_scale()`](https://ggplot2.tidyverse.org/reference/continuous_scale.html)
  (`limits`, `breaks`, `labels`, `trans`, ...).

- range:

  Output tone range; narrow it (e.g. `c(0.1, 0.9)`) to keep the lightest
  value visible.

- guide:

  A function used to create a guide or its name. See
  [`guides()`](https://ggplot2.tidyverse.org/reference/guides.html) for
  more information.

## Value

A ggplot2 scale.
