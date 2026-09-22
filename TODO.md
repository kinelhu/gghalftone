# gghalftone — hand-off TODO

Status (2026-09-21): builds and installs on R 4.6.1 / ggplot2 4.0.3; 85 regression tests pass; `R CMD check` (with vignettes) clean. Git repo initialised. Full gallery renders in ~11 s at the 0.35 mm default. Defaults pass done (see `design_review.md`, review 2): bare `with_halftone()` / `geom_halftone()` calls now produce the gallery in `figures/v2/` (`prototypes/gallery2.R`). API considered stable for `geom_halftone()`, `geom_spot()`, `with_halftone()`, `with_halo()`, `km_steps()`, the `screen` aesthetic, `theme_halftone()`. No Rd docs yet.

## Priority order

1. ~~Use it on real data.~~ Done on `survival::lung` (`figures/v2/km.png`, `km_bw.png`): `km_steps()` + `with_halftone(geom_ribbon())` + `with_halo(geom_step())` + `km_censor()` + `km_risk()`. Next: run it on your own cohort and see what breaks.
2. ~~Rd documentation~~ Done: every export documented, `R CMD check --no-manual` is clean (0 errors, 0 warnings, 0 notes). Arguments rationalised: `dot_max` (ink weight at full tone), `tone_max` (tone ceiling), `gamma` (tone curve) survive; `gain` (dot spread) and `size_map` (radius mapping) were removed, both unused and both wrong for print. `levels = NULL` is continuous; `algorithm`/`bayer_n` only matter when it is set.
3. ~~`scale_tone()`~~ Done: `aes(tone = )` + `scale_tone_continuous()` on both `geom_spot()` and `geom_halftone()`; `halftone_tone_legend()` removed.
4. **Blue-noise tiling**: the 32x32 void-and-cluster matrix repeats visibly on large flat fills (bars specimen, tile 7). Options: 64x64 (generation is 0.1 s at 32, scales ~n^2 log n), or a per-row phase offset from a second matrix.
5. ~~`geom_spot()` parity~~ Done: `aes(screen = )`, `shape = "line"`, square/diamond dots; rosette rotates with the screen angle; keys follow.
6. **Performance**: profiled (2026-09-21). The fine-raster point-in-polygon was 40 % of a KM draw; replaced by a scanline rasteriser (`scan_fill_cpp`), whole gallery 25 s -> 11 s. What remains is grid drawing the circles (unavoidable) and `matrix()` allocations; the weave `mapply` and `sample_index()` binning are the next candidates.
7. ~~Vignettes~~ Done: three (`gghalftone`, `screens`, `fields`), built and checked; pkgdown site builds into `docs/` (gitignored; publish from a CI step or commit it when there is a remote).
8. ~~git init~~ Done (2026-09-21, branch `main`).

## Known issues / open design questions
- Fonts: Liberation Sans, EB Garamond and Inconsolata are installed (Homebrew casks, 2026-09-22, in `~/Library/Fonts`), and the theme resolves them. Base `pdf()` knows no system fonts: examples set `options(halftone.fonts = FALSE)` (generic families); real output goes through ragg or cairo_pdf.
- Vignette PNGs are quantised to 48 colours (halftone images compress poorly); the source tarball is 1.9 MB. The R magick package must be installed for the quantisation hook to run (it is now); without it the tarball is 5 MB.
- Two-ink weave has no perfect solution on a hex lattice (odd cycles); blue-noise assignment is used for k != 3. Fine at 600 dpi; document.
- KM lower-half density: overprint makes each stratum's lower half denser (it overlaps the neighbour's core). Not a bug; `overlap = "stack"` if it must be symmetric.
- Line screens + gaussian tone read as fringe; the wrapper warns. Keep the rule.
- `geom_sf` has not been tested through `with_halftone()` (sf not installed in the prototyping sandbox). It draws `pathgrob`s, which `collect_polys()` handles, so it should work; verify.
- `halftone_raster()` (magick) and `halftone_regions()` (maps) are Suggests with guards; untested since packaging.
- Editorial style (`options(halftone.style = "editorial")`) has had less attention than journal since loop 9.

## Design rules (non-negotiable unless a side-by-side at 600 dpi proves otherwise)
- Physical pitch in mm; 0.35 mm (73 lpi) is the default and the journal register: it reads as tone with a visible screen. 0.6 reads as dots (poster/editorial); 0.25 collapses into a flat tint and costs 5x the draw time.
- Continuous tone by default (`levels = NULL`); quantise only for a stipple or a poster.
- **No feature below 0.09 mm (0.25 pt)**, the journal minimum: `min_feature`. Enforced by dithering, not clipping: a cell below the floor prints at the floor with probability tone/floor, so coverage stays honest and light tone dissolves into sparse minimum dots or broken hairlines. Hairline hatch = the minimum, derived from pitch.
- No lattice axis horizontal or vertical: 15° on hex (default), 45° on square.
- Profile follows geometry: flat for bars/areas/polygons/maps, **likelihood** for ribbons (normal density of the estimate: 1 on the estimate, 0.146 at a 95 % limit, so the fade is the evidence), vignette for densities/violins. A mapped `screen` is a pattern, and patterns are flat.
- Colour is redundant on tiling geoms (bars, areas, polygons, tiles, sf): fills get their own screens automatically and the keys show both. Not on intervals/densities: separate lattices at different angles moire; those weave on one lattice.
- Journal theme: 0.7 pt rules, 8 pt bold tags, data lines 1 pt (linewidth 0.35). `ggsave_journal()` writes png/tiff/pdf by extension; PDF is vector. `halftone_proof()` renders true size plus a 4x crop.
- Inks: `halftone_inks` (muted sRGB, default) or `theme_halftone(palette = "process")` for one-or-two-plate press colours. One ink (black) is the headline workflow.
- Dot shapes are area-matched; one tonal register (flat 0.45, polygons/maps 0.6, centre 0.6, vignette 0.7; hatched intervals hairline 0.15, other hatching 0.4; binary stipple capped at 0.55).
- Line screens: same 0.35 mm pitch; 0.15 mm halo on lines crossing them (0.08 is invisible against hatch). Hatch runs extend a pitch past the last cell so strips reach the outline.
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
