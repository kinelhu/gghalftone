# Fields from statistical objects

Helpers that turn common objects into gridded fields (`x`, `y`, `z`) for
[`geom_halftone()`](https://kinelhu.github.io/gghalftone/reference/geom_halftone.md).
Most figures do not need them, because
[`with_halftone()`](https://kinelhu.github.io/gghalftone/reference/with_halftone.md)
screens the fill of a ribbon, area, bar or polygon layer directly. Use
them when the tone field is computed rather than drawn: an estimate with
a tent or gaussian profile (`halftone_band()`), bars that fade towards
the axis (`halftone_bars()`), map regions rasterised by point-in-region
lookup (`halftone_regions()`, requires the maps package), or ridgelines
(`halftone_ridges()`).

## Usage

``` r
halftone_band(
  x,
  est,
  lo,
  hi,
  ny = 250,
  profile = c("tent", "gauss", "flat"),
  ylim = NULL,
  keep = NULL
)

halftone_bars(
  cat,
  height,
  width = 0.8,
  nx = 25,
  ny = 120,
  fade = 0.35,
  extra = NULL
)

halftone_regions(db = "state", values, res = 0.25, ...)

halftone_ridges(values, groups, scale = 1.6, n = 256, fade = 0.35, bw = "nrd0")
```

## Arguments

- x, est, lo, hi:

  Positions, estimate and interval limits.

- ny, nx:

  Field resolution.

- profile:

  Tone profile across the band.

- ylim, keep:

  Vertical extent, and extra columns (one row per `x`) carried into the
  field.

- cat, height, width, fade, extra:

  Bar categories, heights, width, tone at the base, extra columns.

- db, values, res, ...:

  Map database, named values per region, cell size in degrees, arguments
  to [`maps::map()`](https://rdrr.io/pkg/maps/man/map.html).

- groups, scale, n, bw:

  Ridgeline groups, height scale, resolution, bandwidth for
  [`stats::density()`](https://rdrr.io/r/stats/density.html).

## Value

A data frame (`halftone_ridges()`: a list of `fields`, `lines`,
`levels`).
