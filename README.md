# gghalftone

Halftone, dither and line-screen fills for ggplot2. The package lives in `gghalftone/`.

## Getting oriented

- `gghalftone/README.md` is the package tour, with figures.
- `TODO.md` holds the design rules, the known behaviour, and what is open.
- `CLAUDE.md` holds the working conventions for this repository.
- `design_review.md` is the review log, newest entry last.

## Build and test

```sh
cd gghalftone && Rscript -e 'Rcpp::compileAttributes(); roxygen2::roxygenise()'
cd .. && R CMD INSTALL gghalftone
Rscript -e 'library(gghalftone); testthat::test_dir("gghalftone/tests/testthat")'
```

Installing needs an Rcpp toolchain. Rendering needs ragg. `gghalftone/README.md` has the routes for loading it from another project, including renv.

## Render the figures

```sh
Rscript prototypes/gallery2.R        # figures/v2/,          the defaults gallery
Rscript prototypes/showcase.R        # figures/v2/showcase/, the wider API
Rscript prototypes/press_gallery.R   # figures/v2/press/,    every figure as printed
```

Run all three after changing drawing code. Older scripts in `prototypes/` are history and are not kept in sync.
