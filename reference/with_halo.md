# Paper halo under a line or point layer

Draws the layer twice: first in paper colour with `width` mm added to
each side of every stroke, then as is. Use it for a line that crosses a
dot field, such as a step curve over a screened confidence band or
contours over an elevation field. Keep the width small: 0.09 mm (0.25
pt, the printable minimum) against dots, 0.15 mm against a line screen.
A wider halo looks like a second line.

## Usage

``` r
with_halo(layer, width = 0.09, colour = "white")
```

## Arguments

- layer:

  A ggplot2 layer drawing lines, paths, steps, contours or points; a
  list holding one; or a whole plot or patchwork, in which case every
  layer in it is wrapped. The object handed in is left alone.

- width:

  Halo width in mm on each side of the stroke.

- colour:

  Halo colour. Use the paper colour of the plot; the default is white.

## Value

The layer, with its geom replaced by a halo-drawing subclass.

## Examples

``` r
ggplot2::ggplot(mtcars, ggplot2::aes(wt, mpg)) + with_halo(ggplot2::geom_line())
```
