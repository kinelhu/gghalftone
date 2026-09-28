# Legend keys

`draw_key_halftone()` draws a mid-tone swatch at the layer's screen
angle and shape: dots, or strips for a line screen. The key is a sample
of the screen itself, run over a key-sized area by the code that draws
the panel, so it reads at the density of the fill it stands for.
`draw_key_spot()` draws a disc at the break's tone or, for a size
legend, at the break's radius. Both are the default keys of the
corresponding geoms. They are exported for use with `key_glyph`.

## Usage

``` r
draw_key_halftone(data, params, size)

draw_key_spot(data, params, size)
```

## Arguments

- data:

  A single row data frame containing the scaled aesthetics to display in
  this key

- params:

  A list of additional parameters supplied to the geom.

- size:

  Width and height of key in mm.

## Value

A grob.
