# Threshold matrices and dithering

The threshold matrices behind `levels = k` quantisation.
`bayer_matrix()` is the ordered-dither matrix of size `n` (a power of
two); `blue_noise_matrix()` is a void-and-cluster matrix (cached,
seeded) whose thresholds are evenly spread with no periodic structure.
`dither_bayer()` and `dither_blue_noise()` quantise a tone matrix `z` in
`[0, 1]` to `levels` steps and dither the remainder with the tiled
matrix.

## Usage

``` r
bayer_matrix(n = 4)

blue_noise_matrix(n = 32, sigma = 1.5)

dither_blue_noise(z, levels = 1, n = 32)

dither_bayer(z, levels = 1, n = 4)
```

## Arguments

- n:

  Matrix size (Bayer: 2, 4, 8, ...; blue noise: 32 by default).

- sigma:

  Gaussian width, in cells, of the energy filter used to build the
  blue-noise matrix.

- z:

  Numeric matrix of tone in `[0, 1]`.

- levels:

  Number of quantisation steps.

## Value

A numeric matrix of thresholds in `(0, 1)` (matrices), or a quantised
tone matrix (dither functions).

## Details

Use Bayer for graded tone and blue noise for a binary stipple
(`levels = 1`). You rarely need to call these functions directly. Pass
`levels` and `algorithm` to
[`geom_halftone()`](https://kinelhu.github.io/gghalftone/reference/geom_halftone.md)
or
[`with_halftone()`](https://kinelhu.github.io/gghalftone/reference/with_halftone.md)
instead. By default, tone is continuous and no dithering takes place.

## References

Bayer, B. E. (1973). An optimum method for two-level rendition of
continuous-tone pictures. IEEE International Conference on
Communications, 26, 11-15. Floyd, R. W., and Steinberg, L. (1976). An
adaptive algorithm for spatial greyscale. Proceedings of the Society for
Information Display, 17(2), 75-77. Ulichney, R. (1993). The
void-and-cluster method for dither array generation. Proceedings of
SPIE, 1913, 332-343. <https://doi.org/10.1117/12.152707>

## Examples

``` r
bayer_matrix(2)
#>       [,1]  [,2]
#> [1,] 0.125 0.625
#> [2,] 0.875 0.375
range(blue_noise_matrix(32))
#> [1] 0.0004882812 0.9995117188
```
