# gghalftone: context for Claude Code

R package: halftone, dither and line-screen fills for ggplot2. Dots are placed at draw time (grid `makeContent`) on a lattice with a physical pitch in mm, so figures do not change with output size. See `TODO.md` for priorities and design rules, `design_review.md` for the review log, and `figures/v2/` for accepted output.

## Layout
- `gghalftone/`: the package (R/, src/kernels.cpp, tests/testthat/test-regressions.R, vignettes/, README.md).
- `prototypes/gallery2.R`: the current gallery. It uses `library(gghalftone)` with package defaults and renders to `figures/v2/`.
- `prototypes/readme_figures.R`: assembles `gghalftone/man/figures/` from the accepted renders, including the README montage. Run it after the other three, or the README shows figures no script reproduces.
- `prototypes/press_gallery.R`: every gallery figure in three panels (as prepared, dot gain only, the whole press) under one house press, plus `control.png`, which matches the plain screen's ink weight to the pressed one so the part that is not simply more ink is visible. It sources `gallery2.R` with `options(gallery.render = FALSE)` and reads its `FIGS` registry, so there is no second copy of the figure code. Renders to `figures/v2/press/`.
- `prototypes/showcase.R`: examples that reach corners the gallery does not (sf, polar, process colour, error diffusion, ridgelines, violins, pitch invariance). Renders to `figures/v2/showcase/`. Run it after changing the drawing code; it covers more of the API than the gallery.
- Older scripts in `prototypes/` are history and are not kept in sync.
- `figures/v2/`: current accepted renders. `figures/*.png` are the previous set. The whole `figures/` tree is gitignored: the scripts reproduce it, and tracking 600 dpi PNGs took the repository to 220 MB. What the README shows lives in `gghalftone/man/figures/`, which is tracked, web-sized and refreshed by `readme_figures.R`.

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
- `halftone_plot(plot, ...)`: screen a whole plot in one call. Screens the filled layers, haloes the lines that sit over a screen, adds the theme modifier. Dispatches on geom class; anything it does not recognise draws as it always did. Idempotent, and it leaves a layer you wrapped yourself alone. It chooses no colours: an unmapped geom colour comes from `theme(geom = )` on ggplot2 4.0, and `theme_halftone()` sets that accent.
- `with_halftone(layer, ...)`: screen the fill of any layer. The tone profile follows the geometry.
- `with_halo(layer)`: paper hairline under a line layer.
- `with_relief(layer, light)`: Tanaka illuminated contours.
- `with_press(layer, gain, slur, fillet, mottle, registration)`: press artefacts (dot gain, smear, ink bridges, mottle, plate offset). Off by default, never in the journal register. Takes a layer, a list of layers, a plot or a patchwork; given more than one layer each gets its own seed, so the plates miss each other. It copies what it is given, so the original prints unpressed. The fillet needs polyclip and only runs on dots close enough to touch, which needs `gain` above about 0.2.
- `geom_halftone()`: screen a gridded field.
- `geom_spot()`: one tone disc per point. Use `aes(tone = )` with `scale_tone_continuous()`.
- `scale_screen_discrete()` and `scale_screen_manual()`: specifications of the form `"angle|shape|tone|line_angle"`.
- `km_steps()`, `km_censor()`, `km_risk()`: survfit to data frames.
- `theme_halftone()`: incomplete theme (paper ground, no gridlines, screen-sized keys, ink palette on ggplot2 4.0 and later). `ggsave_journal()`, `halftone_proof()`.
- Helpers: `halftone_band()`, `halftone_bars()`, `halftone_regions()`, `halftone_ridges()`, `halftone_raster()`, `halftone_cmyk()`, `geom_halftone_cmyk()` (four-colour process from a raster field).
