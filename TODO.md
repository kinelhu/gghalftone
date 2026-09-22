# gghalftone: hand-off notes

Status (2026-09-22): builds and installs on R 4.6.1 and ggplot2 4.0.3. 86 regression tests pass. `R CMD check` with vignettes is clean. Git repository on branch `main`. The full gallery renders in about 11 s at the 0.35 mm default. Every export has a help page.

## Done

1. Real data: `survival::lung` through `km_steps()`, `with_halftone(geom_ribbon())`, `with_halo(geom_step())`, `km_censor()` and `km_risk()`. Next step: run it on your own cohort.
2. Documentation: every export documented. Arguments rationalised: `dot_max` (ink weight at full tone), `tone_max` (tone ceiling) and `gamma` (tone curve) remain. `gain` and `size_map` were removed. `levels = NULL` is continuous; `algorithm` and `bayer_n` apply only when `levels` is set.
3. Tone scale: `aes(tone = )` with `scale_tone_continuous()` on `geom_spot()` and `geom_halftone()`.
4. `geom_spot()`: `aes(screen = )`, `shape = "line"`, square and diamond dots.
5. Performance: profiled on the worst case (2 by 3 facets, three woven strata, 183 mm, 0.35 mm). 6.9 s to 5.5 s after vectorising the weave and the colour lookup. The package's own work is 0.5 s of that. The rest is ragg drawing about 500k circles, which is the fastest primitive available.
6. Vignettes: `gghalftone`, `screens`, `fields`. The pkgdown site builds into `docs/`.
7. Git and CI: workflows for R CMD check (macOS and Ubuntu) and pkgdown are in `.github/workflows/`. They run on the first push once a remote exists. Set `url:` in `_pkgdown.yml` at that point.

## Open

- Blue-noise tiling: the 32 by 32 void-and-cluster matrix repeats visibly on large flat fills. Options: a 64 by 64 matrix, or a per-row phase offset from a second matrix.
- `geom_sf` has not been tested through `with_halftone()`. It draws path grobs, which `collect_polys()` handles.
- `halftone_raster()` (magick) and `halftone_regions()` (maps) are guarded Suggests and untested since packaging.

## Known behaviour

- The two-ink weave has no perfect solution on a hex lattice. Blue-noise assignment is used for k other than 3. Acceptable at 600 dpi.
- With overprinting, the lower half of each Kaplan-Meier band is denser because it overlaps the neighbour's core. Use `overlap = "stack"` if the bands must be symmetric.
- Line screens with a tapered tone profile look like fringe. The wrapper warns.
- Fonts: Liberation Sans, EB Garamond and Inconsolata are installed as user fonts (Homebrew casks, 2026-09-22). Base `pdf()` has no system fonts, so examples set `options(halftone.fonts = FALSE)`. Real output goes through ragg or cairo_pdf.
- Vignette PNGs are quantised to 48 colours because halftone images compress poorly. The source tarball is 1.9 MB. The R magick package must be installed for the quantisation hook to run; without it the tarball is 5 MB.
- The editorial style is a page register: base 11 pt for 120 to 183 mm. Use `base_size = 8` at column width. The gallery piece is the Maunga Whau plate in `figures/v2/editorial.png`.

## Design rules

Change a rule only when a side-by-side comparison at 600 dpi shows the change is better.

- Pitch is physical, in mm. 0.35 mm (73 lpi) is the default and the journal register. Editorial plates at 120 to 183 mm use 0.45. At 0.6 and above the screen prints as dots and suits posters. At 0.25 the screen collapses into a flat tint and costs five times the draw time.
- Tone is continuous by default (`levels = NULL`). Quantise only for a stipple or a poster.
- No feature is smaller than 0.09 mm (0.25 pt), the journal minimum (`min_feature`). The floor is enforced by dithering, not clipping: a cell below the floor prints at the floor with probability tone/floor. Coverage is preserved and light tone becomes sparse minimum dots or broken hairlines. The hairline hatch width equals the minimum.
- No lattice axis is horizontal or vertical: 15 degrees on hex (default), 45 degrees on square.
- The tone profile follows the geometry: flat for bars, areas, polygons and maps; likelihood for ribbons (normal density of the estimate, 1 on the estimate, 0.146 at a 95% limit); vignette for densities and violins. A mapped `screen` is a pattern and is flat.
- Colour is redundant on tiling geoms (bars, areas, polygons, tiles, sf): fills get their own screens and the keys show both. Not on intervals and densities, because separate lattices at different angles produce moire. Those overlap on one lattice.
- Journal theme: 0.7 pt rules, 8 pt bold tags in the layout margin, data lines 1 pt (linewidth 0.35). `ggsave_journal()` writes PNG, TIFF or vector PDF by extension. `halftone_proof()` renders at final size plus a 4x crop.
- Inks: `halftone_inks` (muted sRGB) by default, or `theme_halftone(palette = "process")` for press colours of one or two plates. One ink (black) is the primary workflow.
- Dot shapes are area-matched. One tonal register: flat 0.45, polygons and maps 0.6, likelihood 0.6, vignette 0.7, hatching 0.4, hatched intervals at the hairline, binary stipple capped at 0.55.
- Line screens use the same 0.35 mm pitch. Lines crossing them get a 0.15 mm halo; 0.09 mm is invisible against hatch. Hatch runs extend one pitch past the last cell so strips reach the outline.
- Dots fade with a soft edge. Line screens are flat with a hard edge.
- Overlap is a panel property: overprint by default, `stack` only for nested intervals and ridgelines.
- Alpha is ink coverage. Nothing translucent reaches the page.
- Clip from filled polygons only, never from grobs with open outlines.
- The halo on lines crossing dot fields is a symmetric hairline (0.09 mm). It is the printer's knockout channel. Asymmetry belongs to surfaces: `with_relief()` for contours over a field, lit from 315 degrees.
- Typographic hierarchy: tag 8 pt bold, axis title 8 pt, tick labels 7 pt, legend 7 pt grey.
- Angle alone distinguishes three screens. Beyond that, vary shape and tone.
- Do not judge line art from thumbnails. Render at 600 dpi and compare side by side with the last accepted version.

## Environment

- Fonts: Liberation Sans (journal), EB Garamond and Inconsolata (editorial). Use `theme_halftone(base_family = )` to substitute.
- Render with `ragg::agg_png` for clipping paths and glyphs. Run R in a UTF-8 locale.
- The Rcpp toolchain is required to install. There are five kernels in `src/kernels.cpp`.
