# gghalftone — hand-off TODO

Status (2026-09-21): builds and installs on R 4.6.1 / ggplot2 4.0.3; 58 regression tests pass. Defaults pass done (see `design_review.md`, review 2): bare `with_halftone()` / `geom_halftone()` calls now produce the gallery in `figures/v2/` (`prototypes/gallery2.R`). API considered stable for `geom_halftone()`, `geom_spot()`, `with_halftone()`, `with_halo()`, `km_steps()`, the `screen` aesthetic, `theme_halftone()`. No Rd docs yet.

## Priority order

1. ~~Use it on real data.~~ Done on `survival::lung` (`figures/v2/km.png`, `km_bw.png`): `km_steps()` + `with_halftone(geom_ribbon())` + `with_halo(geom_step())` + `km_censor()` + `km_risk()`. Next: run it on your own cohort and see what breaks.
2. **Rd documentation** for every export (`roxygen2`). While doing it, rationalise overlapping arguments: `dot_max`, `tone_max`, `gamma`, `gain` (ink weight / tone ceiling / tone curve / dot spread) — decide which survive and document the difference. `levels` is now NULL (continuous) by default; `algorithm`/`bayer_n` only matter when it is set. Then `R CMD check` should be clean apart from figure size.
3. **`scale_tone()`**: tone as a real ggplot2 aesthetic with a guide, so `geom_spot()` and the heatmap stop needing `halftone_tone_legend()` insets. Needs a new aesthetic (`tone`), a continuous scale, and a `draw_key`/guide that draws a dithered swatch ramp.
4. **Blue-noise tiling**: the 32x32 void-and-cluster matrix repeats visibly on large flat fills (bars specimen, tile 7). Options: 64x64 (generation is 0.1 s at 32, scales ~n^2 log n), or a per-row phase offset from a second matrix.
5. **`geom_spot()` parity**: accept `aes(screen = )` and `shape = "line"` (hatched discs for B&W dot plots); reuse `dot_grob()`/`line_strips_grob()`.
6. **Performance**: nothing profiled. Worst case = facets x groups x 0.45 mm on 183 mm. Candidates: `sample_index()` binning, `pip_cpp` per polygon on the full lattice (bbox filter exists), `mapply` in the weave (vectorise with the bitmask).
7. **Vignettes**: the five specimen scripts (`prototypes/specimen.R`, `specimens2.R`) are the vignette bodies; add prose. Then pkgdown.
8. **git init** — there is no repo yet.

## Known issues / open design questions
- Ochre (`halftone_inks[["ochre"]]`) is the weakest ink at low tone in a three-ink weave; a deeper amber (#9C6A0F was used in the old keepset) may be the better default.
- `geom_spot()` legend keys use the size scale only; tone has no guide until `scale_tone()` exists.
- Fonts: none of Liberation Sans / EB Garamond / Inconsolata are installed on this machine; the theme falls back to Arial / Georgia / Menlo. Install the intended families before final renders.
- Two-ink weave has no perfect solution on a hex lattice (odd cycles); blue-noise assignment is used for k != 3. Fine at 600 dpi; document.
- KM lower-half density: overprint makes each stratum's lower half denser (it overlaps the neighbour's core). Not a bug; `overlap = "stack"` if it must be symmetric.
- Line screens + gaussian tone read as fringe; the wrapper warns. Keep the rule.
- `geom_sf` has not been tested through `with_halftone()` (sf not installed in the prototyping sandbox). It draws `pathgrob`s, which `collect_polys()` handles, so it should work; verify.
- `halftone_raster()` (magick) and `halftone_regions()` (maps) are Suggests with guards; untested since packaging.
- Editorial style (`options(halftone.style = "editorial")`) has had less attention than journal since loop 9.

## Design rules (non-negotiable unless a side-by-side at 600 dpi proves otherwise)
- Physical pitch in mm; 0.45–0.6 mm for journal figures, 0.9–1.2 for editorial.
- Continuous tone by default (`levels = NULL`); quantise only for a stipple or a poster. Nothing below 2 % tone is drawn.
- No lattice axis horizontal or vertical: 15° on hex (default), 45° on square.
- Profile follows geometry: flat for bars/areas/polygons/maps, centre for ribbons, vignette for densities/violins. A mapped `screen` is a pattern, and patterns are flat.
- Dot shapes are area-matched; one tonal register (flat 0.45, centre 0.85, vignette 0.7).
- Dots fade (gaussian, soft edge); line screens are flat with a hard edge.
- Outline-defined shapes (density, violin) are edge-weighted; bands/bars/areas/maps are not.
- Overlap is a panel property: overprint (woven) by default; `stack` only for nested intervals / ridgelines.
- Alpha is ink coverage; nothing translucent reaches the page.
- Clip from filled polygons only (never from grobs containing open outlines).
- Hairline halo (~0.08 mm) on lines crossing dot fields; never wider.
- One tonal register per figure set; typographic hierarchy: tag 10 bold > axis title 8 > ticks 7 > legend 7 grey.
- Angle alone distinguishes three screens; beyond that vary shape and tone.
- Never judge line art from thumbnails; render at 600 dpi and compare side-by-side with the last accepted version.

## Environment notes
- Fonts: Liberation Sans (journal), EB Garamond + Inconsolata (editorial). `theme_halftone(base_family=)` to substitute.
- Render with `ragg::agg_png` (clipping paths, glyphs). Run R in a UTF-8 locale.
- Rcpp toolchain required to install (four kernels in `src/kernels.cpp`).
