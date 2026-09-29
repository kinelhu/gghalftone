# Halftone screen of a gridded field

Draws a gridded field (`x`, `y` and a value) as a halftone. Dots or
hatch lines are placed at draw time on a lattice with a physical pitch
in millimetres. The area of each dot follows the tone at that point. The
screen is the same whether the figure is saved at 89 mm or 183 mm.
Colour and fill scales apply to the field as usual, and every dot
inherits the colour of the cell it samples.

## Usage

``` r
geom_halftone(
  mapping = NULL,
  data = NULL,
  stat = "identity",
  position = "identity",
  ...,
  pitch = NULL,
  angle = NULL,
  grid = "hex",
  levels = NULL,
  algorithm = "bayer",
  bayer_n = 4,
  dot_max = 0.9,
  range = NULL,
  shape = "circle",
  gamma = 1,
  overlap = "overprint",
  blend = "alternate",
  tone_max = NULL,
  min_feature = 0.09,
  na.rm = FALSE,
  show.legend = NA,
  inherit.aes = TRUE
)

# S3 method for class 'halftone'
makeContent(x)
```

## Arguments

- mapping:

  Set of aesthetic mappings created by
  [`aes()`](https://ggplot2.tidyverse.org/reference/aes.html). If
  specified and `inherit.aes = TRUE` (the default), it is combined with
  the default mapping at the top level of the plot. You must supply
  `mapping` if there is no plot mapping.

- data:

  The data to be displayed in this layer. There are three options:

  If `NULL`, the default, the data is inherited from the plot data as
  specified in the call to
  [`ggplot()`](https://ggplot2.tidyverse.org/reference/ggplot.html).

  A `data.frame`, or other object, will override the plot data. All
  objects will be fortified to produce a data frame. See
  [`fortify()`](https://ggplot2.tidyverse.org/reference/fortify.html)
  for which variables will be created.

  A `function` will be called with a single argument, the plot data. The
  return value must be a `data.frame`, and will be used as the layer
  data. A `function` can be created from a `formula` (e.g.
  `~ head(.x, 10)`).

- stat:

  The statistical transformation to use on the data for this layer. When
  using a `geom_*()` function to construct a layer, the `stat` argument
  can be used to override the default coupling between geoms and stats.
  The `stat` argument accepts the following:

  - A `Stat` ggproto subclass, for example `StatCount`.

  - A string naming the stat. To give the stat as a string, strip the
    function name of the `stat_` prefix. For example, to use
    `stat_count()`, give the stat as `"count"`.

  - For more information and other ways to specify the stat, see the
    [layer
    stat](https://ggplot2.tidyverse.org/reference/layer_stats.html)
    documentation.

- position:

  A position adjustment to use on the data for this layer. This can be
  used in various ways, including to prevent overplotting and improving
  the display. The `position` argument accepts the following:

  - The result of calling a position function, such as
    `position_jitter()`. This method allows for passing extra arguments
    to the position.

  - A string naming the position adjustment. To give the position as a
    string, strip the function name of the `position_` prefix. For
    example, to use `position_jitter()`, give the position as
    `"jitter"`.

  - For more information and other ways to specify the position, see the
    [layer
    position](https://ggplot2.tidyverse.org/reference/layer_positions.html)
    documentation.

- ...:

  Other arguments passed to
  [`ggplot2::layer()`](https://ggplot2.tidyverse.org/reference/layer.html),
  such as fixed aesthetics (`colour = "black"`).

- pitch:

  Lattice spacing in mm; `NULL` means 0.35. Journal figures want 0.3 to
  0.45. Coarser pitches suit posters.

- angle:

  Rotation of the lattice in degrees. `NULL` picks the default: 45 on a
  square lattice and for line screens, 15 for hex dots, so that no
  lattice axis is horizontal or vertical. When `screen` is mapped, the
  screen specs are absolute and `angle` (if given) is added to them.

- grid:

  `"hex"` (default) or `"square"`. A 45-degree square lattice is the
  classic map and photo screen.

- levels:

  `NULL` for continuous tone (dot area follows tone exactly). An integer
  quantises tone to that many steps and dithers the remainder with
  `algorithm`; `levels = 1` is a binary stipple.

- algorithm:

  Dither used when `levels` is set: `"bayer"` (graded tone),
  `"blue_noise"` (stipple) or `"floyd_steinberg"` (photographs).

- bayer_n:

  Size of the Bayer matrix when `algorithm = "bayer"`.

- dot_max:

  Diameter of a full-tone dot as a fraction of `pitch` (0.9). Above 1
  dots merge; it is the ink weight of the screen at 100% tone. For line
  screens it is the full-tone strip width, as a fraction of pitch.

- range:

  Value range mapped to tone 0..1 when `z` is used; `NULL` uses the data
  range. A wider range lightens the screen.

- shape:

  `"circle"`, `"square"`, `"diamond"` (area-matched, so a mixed-shape
  screen stays in one register) or `"line"` for a line screen whose
  strip width follows tone.

- gamma:

  Tone curve: tone is raised to this power before printing. Below 1
  lifts mid-tones, above 1 deepens them.

- overlap:

  How groups sharing the panel combine: `"overprint"` (woven on one
  lattice, default), `"interleave"` (each group on its own phase-shifted
  lattice) or `"stack"` (last group drawn wins; hides overlaps).

- blend:

  Colour of a cell carrying several inks under `"overprint"`.
  `"alternate"` (default) weaves them, so a reader can still see which
  inks are present. `"multiply"` is the subtractive physics of real ink,
  the product of the reflectances, so cyan over magenta over yellow goes
  black. `"mix"` is a darkened average, which is decorative rather than
  physical, and it collapses every overlap to one colour.

- tone_max:

  Tone ceiling in `[0, 1]`. `NULL` means 1, or 0.55 for a binary
  stipple.

- min_feature:

  Smallest printable feature in mm (0.09, i.e. 0.25 pt, the minimum line
  weight in journal artwork guidelines; see References). A cell whose
  dot would be smaller prints at the floor with probability tone/floor,
  so coverage is preserved and light tone becomes sparse minimum dots or
  broken hairlines. Hatch strips are never thinner. Set to 0 to disable.

- na.rm:

  Remove missing values silently.

- show.legend:

  logical. Should this layer be included in the legends? `NA`, the
  default, includes if any aesthetics are mapped. `FALSE` never
  includes, and `TRUE` always includes. It can also be a named logical
  vector to finely select the aesthetics to display. To include legend
  keys for all levels, even when no data exists, use `TRUE`. If `NA`,
  all levels are shown in legend, but unobserved levels are omitted.

- inherit.aes:

  If `FALSE`, overrides the default aesthetics, rather than combining
  with them. This is most useful for helper functions that define both
  data and aesthetics and shouldn't inherit behaviour from the default
  plot specification, e.g.
  [`annotation_borders()`](https://ggplot2.tidyverse.org/reference/annotation_borders.html).

- x:

  A `halftone` grob (internal; `makeContent` method).

## Value

A ggplot2 layer.

## Details

You can give the value in two ways. `aes(z = )` is normalised to
`[0, 1]` inside the geom, over `range` or the data range. `aes(tone = )`
goes through
[`scale_tone_continuous()`](https://kinelhu.github.io/gghalftone/reference/scale_tone_continuous.md),
which adds a legend. Groups that share the panel (through `colour`,
`fill` or `group`) are printed on one lattice by default, so every ink
stays visible where groups overlap.

## Defaults

A 0.35 mm hex lattice (73 lines per inch) rotated 15 degrees, so that no
lattice axis is horizontal or vertical (a square lattice, and any line
screen, goes to 45). Continuous tone and circular dots. Coarser pitches
print as a dot pattern rather than as tone; 0.6 mm suits a poster. A
binary stipple (`levels = 1`) is capped at 55% tone so that the densest
region remains a stipple. Set `tone_max` to override.

## References

Nature Portfolio. Formatting guide: figures.
<https://www.nature.com/nature/for-authors/formatting-guide> Elsevier.
Artwork and media instructions.
<https://www.elsevier.com/about/policies-and-standards/author/artwork-and-media-instructions>

## See also

[`with_halftone()`](https://kinelhu.github.io/gghalftone/reference/with_halftone.md)
to screen the fill of an existing layer,
[`geom_spot()`](https://kinelhu.github.io/gghalftone/reference/geom_spot.md)
for per-point discs,
[`scale_screen_discrete()`](https://kinelhu.github.io/gghalftone/reference/scale_screen_discrete.md)
for colour-free encodings,
[`with_halo()`](https://kinelhu.github.io/gghalftone/reference/with_halo.md)
for lines drawn over a screen.

## Examples

``` r
vol <- data.frame(expand.grid(x = seq_len(ncol(volcano)), y = seq_len(nrow(volcano))),
                   z = as.vector(t(volcano)))
ggplot2::ggplot(vol, ggplot2::aes(x, y, z = z)) + geom_halftone() +
  ggplot2::theme_bw() + theme_halftone()

# engraving: a line screen, plus contours with a paper halo
ggplot2::ggplot(vol, ggplot2::aes(x, y, z = z)) + geom_halftone(shape = "line", angle = 30) +
  with_halo(ggplot2::geom_contour(colour = "black", linewidth = 0.2), width = 0.15) +
  ggplot2::theme_bw() + theme_halftone()
```
