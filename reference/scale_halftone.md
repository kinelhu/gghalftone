# Ink palette scales

Manual colour and fill scales over
[halftone_inks](https://kinelhu.github.io/gghalftone/reference/halftone_inks.md).
On ggplot2 4.0 and later,
[`theme_halftone()`](https://kinelhu.github.io/gghalftone/reference/theme_halftone.md)
sets the inks as the default palette. Use these scales with older
ggplot2 versions or without the modifier.

## Usage

``` r
scale_colour_halftone(...)

scale_fill_halftone(...)
```

## Arguments

- ...:

  Passed to
  [`ggplot2::scale_colour_manual()`](https://ggplot2.tidyverse.org/reference/scale_manual.html)
  /
  [`ggplot2::scale_fill_manual()`](https://ggplot2.tidyverse.org/reference/scale_manual.html).

## Value

A ggplot2 scale.
