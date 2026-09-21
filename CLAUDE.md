# gghalftone — context for Claude Code

R package: print-style halftone / dither / line-screen fills for ggplot2. Dots are placed at draw time (grid `makeContent`) on a lattice with a physical pitch in mm, so figures are output-size invariant. See `TODO.md` for priorities and design rules, `design_review.md` for the last outside-style review, `figures/` for accepted output.

## Layout
- `gghalftone/` — the package (R/, src/kernels.cpp, tests/testthat/test-regressions.R, README.md with figures).
- `prototypes/` — `gallery2.R` is the current gallery (uses `library(gghalftone)`, bare defaults, renders to `figures/v2/`); `keepset.R`, `journal_gallery.R`, `specimen*.R` are the previous, hand-tuned gallery; older `apps*.R` are history.
- `figures/v2/` — current accepted renders; `figures/*.png` are the previous set.

## Working conventions
- Build & test: `cd gghalftone && Rscript -e 'Rcpp::compileAttributes(); roxygen2::roxygenise()' && cd .. && R CMD INSTALL gghalftone && Rscript -e 'library(gghalftone); testthat::test_dir("gghalftone/tests/testthat")'`.
- Every visual change: render at 600 dpi (`ggsave_journal()`), crop the region of interest, and compare against the previous accepted figure side-by-side. Thumbnails hide everything that matters.
- Every bug found gets a test in `test-regressions.R` (pixel-level, via ragg + png).
- New scripts use `library(gghalftone)` after `R CMD INSTALL`; the older prototype scripts `source()` copies of the R files and are not kept in sync.
- Defaults are the product: before adding an argument to a gallery call, ask whether the default should change instead (see `design_review.md`, review 2).
- Journal style is the default theme; `options(halftone.style = "editorial")` for the cream/Garamond look.

## Key functions
`geom_halftone()` (field -> screen), `geom_spot()` (per-point tone disc; `aes(tone = )` + `scale_tone_continuous()`), `with_halftone(layer, ...)` (screen the fill of any layer; tone profile from geometry), `with_halo(layer)` (paper hairline under a line layer), `km_steps()/km_censor()/km_risk()` (survfit -> frames), `scale_screen_discrete()/manual()` (specs `"angle|shape|tone|line_angle"`), `theme_halftone()` (also sets the ink palette on ggplot2 >= 4.0), `ggsave_journal()`, helpers `halftone_band/bars/regions/ridges/raster/cmyk`.
