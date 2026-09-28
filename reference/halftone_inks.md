# Inks, paper, ramp and column widths

Named constants shared by the geoms and
[`theme_halftone()`](https://kinelhu.github.io/gghalftone/reference/theme_halftone.md).

## Usage

``` r
halftone_inks

halftone_paper

halftone_ink

halftone_widths

halftone_process

halftone_ramp
```

## Format

Character vectors of hex colours, or a named numeric vector of widths.

## Details

- `halftone_inks`: the six-ink palette (red, blue, ochre, green, violet,
  grey). On ggplot2 4.0 and later the theme sets it as the default
  palette for mapped colour and fill. It stops at six, which is already
  more inks than a press would use. Beyond six groups ggplot2 warns and
  the extra groups get no fill, so use
  [`scale_screen_discrete()`](https://kinelhu.github.io/gghalftone/reference/scale_screen_discrete.md),
  facets, or your own palette instead.

- `halftone_process`: press colours, each made of one or two process
  plates at 100% (K, M+Y, C+M, C+Y, C, M).

- `halftone_ramp`: the default continuous ramp (paper, ochre, red,
  near-black).

- `halftone_paper`, `halftone_ink`: a cream paper colour and a
  near-black ink colour, for plates.

- `halftone_widths`: journal column widths in mm.
