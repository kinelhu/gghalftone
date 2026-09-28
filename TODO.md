# gghalftone: hand-off notes

Status (2026-09-28): on a remote, private, CI on every push to `main`. Builds and installs on R 4.6.1 and ggplot2 4.0.3. The regression suite passes (53 blocks, 236 expectations) and `R CMD check` with vignettes is clean. Git repository on branch `main`. The full gallery renders in about 11 s at the 0.35 mm default. Every export has a help page.

Four scripts render figures: `prototypes/gallery2.R` for the defaults gallery, `prototypes/showcase.R` for the wider API, `prototypes/press_gallery.R` for the press pairs, and `prototypes/readme_figures.R` to refresh `man/figures/` from them. Run all four after changing drawing code.

## Done

1. Real data: `survival::lung` through `km_steps()`, `with_halftone(geom_ribbon())`, `with_halo(geom_step())`, `km_censor()` and `km_risk()`. Next step: run it on your own cohort.
2. Documentation: every export documented. Arguments rationalised: `dot_max` (ink weight at full tone), `tone_max` (tone ceiling) and `gamma` (tone curve) remain. `gain` and `size_map` were removed. `levels = NULL` is continuous; `algorithm` and `bayer_n` apply only when `levels` is set.
3. Tone scale: `aes(tone = )` with `scale_tone_continuous()` on `geom_spot()` and `geom_halftone()`.
4. `geom_spot()`: `aes(screen = )`, `shape = "line"`, square and diamond dots.
5. Performance: profiled on the worst case (2 by 3 facets, three woven strata, 183 mm, 0.35 mm). 6.9 s to 5.5 s after vectorising the weave and the colour lookup. The package's own work is 0.5 s of that. The rest is ragg drawing about 500k circles, which is the fastest primitive available.
6. Vignettes: `gghalftone`, `screens`, `fields`. The pkgdown site builds into `docs/`.
7. Git and CI: workflows for R CMD check (macOS and Ubuntu) and pkgdown are in `.github/workflows/` and run on every push to `main`. The remote is <https://github.com/kinelhu/gghalftone>, private for now; GitHub Pages needs it public on a free account, so the pkgdown deploy will not publish until it is flipped.

## Open

Nothing outstanding.

## Known behaviour

- Comparing pixels across two renders in one session is only safe on a plot with no text. Panel size follows text
  metrics, and on macOS the first measurement of a session is not the second: two identical plot objects came back
  12 % apart in ink while every structural check said they matched. Tests that compare renders use `theme_void()`,
  and idempotence is asserted on the object rather than on the raster.
- `blue_noise_matrix()` is seeded so the matrix is identical every time, and it now restores the caller's RNG. It
  used to call `set.seed(7)` and leave it, from inside a draw: the first plot of a script silently reseeded the
  session and every random result after it changed. Anything in this package that seeds must save and restore, the
  way `withr_seed()` does.

- An unmapped geom colour comes from `theme(geom = )` on ggplot2 4.0, whose stock accent is `#3366FF`, the blue
  `geom_smooth()` draws its line in. `theme_halftone()` sets that accent to the first ink and `paper` to the ground.
  That is where a colour nobody chose belongs: the first attempt rewrote `aes_params` on the layer instead, which
  needed a copy, a neutral test and a mapped test, and could not read `default_aes` at all on 4.0 because the entries
  there are theme expressions rather than literals.
- `halftone_plot()` dispatches on geom class across the layer stack: fills are screened, paths, segments and points over
  a screen are haloed, everything else is left alone. The safe default is that an unrecognised layer draws exactly as
  it did, so the worst case is an unscreened layer. That is the difference from a converter such as ggplotly, which
  reimplements each geom and therefore carries a support matrix. Layer-stack dispatch is ordinary practice: ggpubr
  classifies by geom class, ggfun by stat class. ggdark avoids it and mutates global geom defaults instead, which
  needs an explicit undo.
- `geom_raster()` draws an image rather than polygons, so there is nothing to clip a screen to. It is a no-op, not
  an error. Use `geom_tile()`.
- Wrapped geoms carry `.halftone_wrapper`, which is what makes `halftone_plot()` idempotent and what stops it
  re-wrapping a layer wrapped by hand.

- Cairo devices draw a small filled circle far too large: a 0.05 mm radius comes back at 0.17 mm, clearing only above about 0.2 mm, which is larger than any halftone dot. Dots therefore go through `round_dots()`, which uses a grid circle only on devices where it is faithful (ragg, base `pdf`, postscript) and a 12-sided polygon elsewhere. Do not replace that with `circleGrob`.
- Clipping paths are honoured by ragg, cairo and base `pdf`, verified by rasterising a polygon with a hole.
- The blue-noise tile does not repeat visibly. On a 60 by 30 mm flat stipple at 0.45 mm the rendered autocorrelation at the 32-cell period is -0.005, the same as at a non-period lag. The lattice rotation and the field mapping break any alignment between the matrix tiling and the page. The earlier note claiming a visible repeat is not reproducible.
- Of the three blend modes, only `"alternate"` keeps ink identity. `"multiply"` is correct subtractive physics and sends a three-ink overlap to black. `"mix"` is a darkened average and is decorative.

- The ink palettes hold six colours. Past six groups ggplot2 warns and the extra groups get no fill. Map `scale_screen_discrete()` instead of colour, or set your own palette.
- A ggproto layer is an environment, so the wrappers replace its geom in place. `with_halftone(p$layers[[1]])` would modify `p`.
- A legend key is generated by running the real screen over a key-sized area, not by re-deriving the panel's formulas. Keep it that way: the two drifted twice when the key had its own arithmetic.
- Is the press just more ink? Measured on a flat field at 0.6 tone, matched by raising `dot_max` from 0.90 to 1.22
  until the plain screen lays down the same 0.790 coverage: mottle (tile SD) 0.064 pressed against 0.003 plain, and
  ink runs 23 % longer along the slur axis than across it. Neither is reachable from any setting on the plain figure.
  Gain on its own is: on a flat field it is exactly a `dot_max` tweak, and across a tone range it differs only in
  curve shape, running up to 8 coverage points darker in the midtones and lighter in the shadows at a matched mean.
  That is why the press gallery has three panels and a control sheet, not a before and after.
- The fillet is done in tiles of about 600 dots. A union of a few thousand overlapping dots overflows R's protection
  stack when polyclip runs at the depth of a draw, so any filleted shadow bigger than a swatch used to crash. The
  closing is local, so tiling is exact; the clips overlap by 0.03 mm, because edges that merely abut leave an
  anti-aliased light line along every join.
- `with_press()` takes a plot or a patchwork as well as a layer, and copies every layer it wraps. Without the copy it
  would press the plot the caller still holds, because a ggproto layer is an environment, and a before-and-after pair
  would print the same figure twice. `prototypes/press_gallery.R` is that pair for every gallery figure.
- A pressed layer's key is pressed too, through `params$press`. Gain, slur and the fillet apply; mottle and
  registration do not, because both are properties of a place on the sheet and a key is a sample of the screen.
- Dot gain is applied to ink coverage, not to the tone the screen was asked for. The two differ because `dot_max`
  caps coverage below 1: at the defaults a full-tone hex cell covers 0.73 of the paper. Applying the curve to tone
  gave a full-tone cell `sin(pi * 1) = 0` gain, so the shadows never filled in and `with_press(fillet = )` had
  nothing to bridge at any setting the docs recommended. Coverage is capped at 1, and that cap is the shadow fill-in.
- `fillet` acts only where dots meet, so it does nothing without `gain` above about 0.2 (or `dot_max` near 1). Both
  regression tests for it reached for a non-default `dot_max` to make it fire, which is what hid this.
- Dots handed to polyclip become 24-gons, and their circumradius is scaled so the polygon carries the circle's area.
  The same correction applies to the 12-gon `round_dots()` draws on cairo devices, which was 4.7 % light.
- `with_relief()` draws lit segments in paper colour, so on bare paper only the shaded half of each contour appears. It is meant to sit over a screened field.

- The two-ink weave has no perfect solution on a hex lattice. Blue-noise assignment is used for k other than 3. Acceptable at 600 dpi.
- With overprinting, the lower half of each Kaplan-Meier band is denser because it overlaps the neighbour's core. Use `overlap = "stack"` if the bands must be symmetric.
- Line screens with a tapered tone profile look like fringe. The wrapper warns.
- The package sets no fonts. The gallery uses stock ggplot2 themes.
- `figures/` is not tracked. Three scripts produce every file under it, and at 600 dpi each render writes fresh
  multi-megabyte PNGs that do not delta, which took the repository to 220 MB across 41 commits. History was rewritten
  with `git filter-repo --path figures/ --invert-paths` before the first push, when it was still free to do, and the
  repository is 38 MB. A bundle of the old history was taken first.
- `man/figures/` is resized to a web width and quantised by `prototypes/readme_figures.R`. At 600 dpi it was 22 MB
  and the source tarball 22 MB with it, which is past what anyone should install over a network. It is 1.8 MB and
  3.5 MB now.
- Loading it elsewhere: there is no remote, so `R CMD INSTALL gghalftone` for a plain project and a tarball in
  `renv/cellar/` for an renv one. Verified with an empty renv cache, so the restore really does come from the
  cellar. renv's own `renv/.gitignore` lists `cellar/`, so the tarball needs `git add -f` or a fresh clone restores
  against a file that is not there. Bump `Version:` on every rebuild or renv keeps the copy it has.
- Vignette PNGs are quantised to 48 colours because halftone images compress poorly. The R magick package must be installed for that hook to run. The source tarball is 3.1 MB, of which the four-colour photograph in the fields vignette is 0.6 MB.

## Design rules

Change a rule only when a side-by-side comparison at 600 dpi shows the change is better.

- Pitch is physical, in mm. 0.35 mm (73 lpi) is the default and the journal register. Editorial plates at 120 to 183 mm use 0.45. At 0.6 and above the screen prints as dots and suits posters. At 0.25 the screen collapses into a flat tint and costs about 1.8 times the draw time of the default (10.6 s against 18.8 s for a 183 by 90 mm ribbon at 600 dpi).
- Tone is continuous by default (`levels = NULL`). Quantise only for a stipple or a poster.
- No feature is smaller than 0.09 mm (0.25 pt), the journal minimum (`min_feature`). The floor is enforced by dithering, not clipping: a cell below the floor prints at the floor with probability tone/floor. Coverage is preserved and light tone becomes sparse minimum dots or broken hairlines. The hairline hatch width equals the minimum.
- No lattice axis is horizontal or vertical: 15 degrees on hex (default), 45 degrees on square.
- The tone profile follows the geometry: flat for bars, areas, polygons and maps; likelihood for ribbons (normal density of the estimate, 1 on the estimate, 0.146 at a 95% limit); vignette for densities and violins. A mapped `screen` is a pattern and is flat.
- Colour is redundant on tiling geoms (bars, areas, polygons, tiles, sf): fills get their own screens and the keys show both. Not on intervals and densities, because separate lattices at different angles produce moire. Those overlap on one lattice.
- The package ships no complete theme. `theme_halftone()` is a modifier: paper ground, no gridlines, screen-sized legend keys, ink palette. The gallery adds it to `theme_classic(base_size = 8)` with data lines at linewidth 0.35 and tags in the layout margin. `ggsave_journal()` writes PNG, TIFF or vector PDF by extension. `halftone_proof()` renders at final size plus a 4x crop.
- Inks: `halftone_inks` (muted sRGB) by default, or `theme_halftone(palette = "process")` for press colours of one or two plates. One ink (black) is the primary workflow.
- Dot shapes are area-matched. One tonal register: flat 0.45, polygons and maps 0.6, likelihood 0.6, vignette 0.7, hatching 0.4, hatched intervals at the hairline, binary stipple capped at 0.55.
- Line screens use the same 0.35 mm pitch. Lines crossing them get a 0.15 mm halo; 0.09 mm is invisible against hatch. Hatch runs extend one pitch past the last cell so strips reach the outline.
- Dots fade with a soft edge. Line screens are flat with a hard edge.
- Overlap is a panel property: overprint by default, `stack` only for nested intervals and ridgelines.
- Alpha is ink coverage. The output holds no partial transparency.
- Clip from filled polygons only, never from grobs with open outlines.
- The halo on lines crossing dot fields is a symmetric hairline (0.09 mm). It is the printer's knockout channel. Asymmetry belongs to surfaces: `with_relief()` for contours over a field, lit from 315 degrees.
- Angle alone distinguishes three screens. Beyond that, vary shape and tone.
- No grey chart furniture. The screen is the only texture, and rules, rings and borders are hairline ink. A polar chart's rings are its radial axis, so they are ink at 0.12 mm, not a grey grid.
- Do not judge line art from thumbnails. Render at 600 dpi and compare side by side with the last accepted version.

## Environment

- Render with `ragg::agg_png` for clipping paths and glyphs. Run R in a UTF-8 locale.
- The Rcpp toolchain is required to install. There are five kernels in `src/kernels.cpp`.
