# gghalftone: context for Claude Code

R package: halftone, dither and line-screen fills for ggplot2. Dots are placed at draw time (grid `makeContent`) on a lattice with a physical pitch in mm, so figures do not change with output size. See `TODO.md` for priorities and design rules, `design_review.md` for the review log, and `figures/v2/` for accepted output.

## Layout
- `gghalftone/`: the package (R/, src/kernels.cpp, tests/testthat/test-regressions.R, vignettes/, README.md).
- `prototypes/gallery2.R`: the current gallery. It uses `library(gghalftone)` with package defaults and renders to `figures/v2/`.
- `prototypes/showcase.R`: examples that reach corners the gallery does not (sf, polar, process colour, error diffusion, ridgelines, violins, pitch invariance). Renders to `figures/v2/showcase/`. Run it after changing the drawing code; it covers more of the API than the gallery.
- Older scripts in `prototypes/` are history and are not kept in sync.
- `figures/v2/`: current accepted renders. `figures/*.png` are the previous set.

## Working conventions
- Build and test: `cd gghalftone && Rscript -e 'Rcpp::compileAttributes(); roxygen2::roxygenise()' && cd .. && R CMD INSTALL gghalftone && Rscript -e 'library(gghalftone); testthat::test_dir("gghalftone/tests/testthat")'`.
- For every visual change, render at 600 dpi with `ggsave_journal()`, crop the region of interest, and compare with the previous accepted figure side by side. Do not judge from thumbnails.
- Every bug gets a test in `test-regressions.R`, at pixel level through ragg and png.
- Defaults are the product. Before adding an argument to a gallery call, ask whether the default should change. See `design_review.md`.
- Default pitch is 0.35 mm. The pitch ladder in `design_review.md` shows why. Coarsen only for a poster.
- The package sets no fonts, so examples run on the base pdf device without special handling.
- Vignettes in `gghalftone/vignettes/` are the prose gallery. `_pkgdown.yml` builds the site into `docs/`, which is gitignored.
- `theme_halftone()` is a modifier, not a complete theme. The gallery adds it to stock ggplot2 themes through `th()` in `gallery2.R`.
- Prose in docs, vignettes, help pages and figure text: short sentences, no em dashes, no middots, no aphorisms.

## Key functions
- `with_halftone(layer, ...)`: screen the fill of any layer. The tone profile follows the geometry.
- `with_halo(layer)`: paper hairline under a line layer.
- `with_relief(layer, light)`: Tanaka illuminated contours.
- `geom_halftone()`: screen a gridded field.
- `geom_spot()`: one tone disc per point. Use `aes(tone = )` with `scale_tone_continuous()`.
- `scale_screen_discrete()` and `scale_screen_manual()`: specifications of the form `"angle|shape|tone|line_angle"`.
- `km_steps()`, `km_censor()`, `km_risk()`: survfit to data frames.
- `theme_halftone()`: incomplete theme (paper ground, no gridlines, screen-sized keys, ink palette on ggplot2 4.0 and later). `ggsave_journal()`, `halftone_proof()`.
- Helpers: `halftone_band()`, `halftone_bars()`, `halftone_regions()`, `halftone_ridges()`, `halftone_raster()`, `halftone_cmyk()`.
