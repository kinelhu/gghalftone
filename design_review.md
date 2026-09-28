# Design review 1: gghalftone gallery (review_panel.png, 15 items)

Reviewer stance: outside designer, print background, no knowledge of the build history. Judged at the intended size (89 mm single column, 600 dpi) and at the panel's downscaled view. Ratings: **keep / rework / cut**.

## Overall

The set has a real idea (tone as texture, physically pitched, explicit about overlap) and the best items (1A, 5, 11, 12, 14) prove it. But the gallery as a whole is not yet a *system*. Three things undercut it:

1. **Inconsistent ink weight.** Dot screens range from feather-light (4, 6) to fully saturated blocks (8, parts of 1A). A print series needs one tonal register; right now each figure was tuned alone.
2. **The halftone is often decorative.** In 2, 7, 13, 15 it encodes nothing a flat fill would not. The screen has to earn its place by carrying a variable or by surviving greyscale, not by looking printed.
3. **Typography is competent but generic.** Liberation Sans at 7 pt is fine for submission; it is not a design. Panel tags, axis titles and legend titles are all the same weight and nearly the same size. There is no hierarchy inside a figure.

## Item by item

| # | Item | Verdict | Notes |
|---|------|---------|-------|
| 1 | Fig. 1 (KM, GAM, dot plot) | **keep**, tighten | A is the strongest argument in the set: three overlapping CIs stay readable. But the woven overlap zone at 500–900 d is the busiest region on the page and the ochre ink is still the weakest of the three. B is clean. C: the tone encoding inside discs is legible only above ~1.5 mm radius; the small discs carry no information. Either enlarge or drop tone for small discs. The three panels have three different y-axis conventions (%, g, none). |
| 2 | Bars, dot fill | **cut or rework** | Dots add nothing. If kept, the only defensible version is 15 (hatching as categorical encoding). One of the two should go. |
| 3 | Densities, dot fill | **rework** | Edge-fade fill on densities looks like a rendering gradient, not a screen. The overlap weave is honest but muddy. Compare 13: the same data with line screens is far more legible; prefer that. |
| 4 | Forecast fan (co2) | **keep** | Correct chart, correct data, one ink deepening inward. The 80%/95% distinction is faint. Separate the alpha steps more (0.15 / 0.45 / 1). Legend keys are too small to show the difference; make them at least 5 mm. |
| 5 | Choropleth | **keep** | Best colour figure in the set. The 45° screen reads as a printed map. Legend title "Murder per 100k" wraps awkwardly; shorten. |
| 6 | Facets + groups | **cut from gallery** | Fine as a regression test, weak as a showcase: bands are barely visible at this size and the four class colours fight. |
| 7 | Ridgelines | **rework or cut** | At 0.5 mm the fills read as solid; nothing halftone about it. Either coarsen deliberately (0.9 mm, editorial style) or drop. |
| 8 | Expression heatmap | **rework** | Grey cell grid + dots + diverging colour is three textures. Remove the grid; let the dot area carry magnitude and colour carry sign only (two inks, no gradient). The saturated red/blue blocks are correct but the mid-tones are noise. |
| 9 | Screens: angle by shape | **keep** | Reads correctly now; legend keys show the difference. Slightly heavy at the bottom series. Lighten the base screen by about 15%. |
| 10 | Elevation, dots | **keep** | Good tonal range, contours crisp. Legend bar is oversized relative to the panel. |
| 11 | Engraving, lines | **keep**, the hero | The only item that looks like it belongs in a book. Use it as the first image of the README. |
| 12 | KM one ink, crosshatch | **keep** | Legitimate B&W figure. The subtitle text overlaps the tag "B"; fix. Consider 0.7 mm pitch. At 0.6 the crosshatch moirés slightly where three strata overlap. |
| 13 | Densities, line screens | **keep** | Better than 3 by a distance. Combine colour + angle only when you have to; here angle alone would suffice and the colour could go. |
| 14 | Blue-noise stipple | **keep** | Excellent. Add the KDE outline (one contour) so it reads as a density and not a scatter. |
| 15 | Hatched bars | **keep** (instead of 2) | Classic and correct. Bar outlines are heavier than the hatch; match weights. |

## System-level fixes (do these before adding anything)

- **One tonal register.** Pick a target ink coverage for mid-tone (say 35–45%) and calibrate `tone_max`/`dot_max` defaults so every figure lands near it. Right now 4 is ~20% and 8's blocks are ~90%.
- **Hierarchy inside figures.** Tag 10 pt bold, axis titles 8 pt regular, tick labels 7 pt, legend 7 pt *light* (or grey). Legend titles should not be bold if the axis titles are not.
- **Kill the grey ground everywhere.** 8 is the only offender left; grey under halftone reads as a printing error.
- **Consistent legend geometry.** Colourbars in 5, 8, 10 are three different sizes. Fix one size (e.g. 2.5 × 18 mm).
- **Decide what dots are for.** Keep dot screens for tone-carrying fills (CIs, densities, fields, maps). Use line screens for categorical hatching. Never use either purely as a fill texture. That is 2 and 7's problem.
- **Halo width** is now right (hairline). Keep it there; do not let it creep back up for "visibility."

## What would make this stand out

- A single, deliberately *editorial* piece in the gallery (the cover) beside the journal set, to show the same engine at two registers.
- 11 rendered at poster scale with a real DEM.
- A figure where halftone is the *only* way to show the data: three overlapping CIs in one ink with crosshatch (12) is already that. Lead with it in the README's B&W section.

---

# Brief for forwarding

> Attached: `review_panel.png`, 15 figures from an R/ggplot2 package that renders fills as print-style halftone (dot and line screens, physical mm pitch, overlaps woven rather than hidden). Target: journal figures at 89/183 mm, 600 dpi, and a secondary editorial style. Please review as a print designer: (1) which items earn their halftone and which are decorative; (2) tonal consistency across the set; (3) typographic hierarchy inside figures; (4) legend and colourbar consistency; (5) anything that reads as a rendering artefact rather than a design choice. Be specific about pitch, ink weight and halo width where relevant. Do not grade on effort or novelty. Grade only on what a reader of a journal or a book would see.

---

# Design review 2: defaults pass (2026-09-21)

Stance: same as review 1, but judged on what the package draws with **no arguments**. The gallery script overrode pitch,
levels, dot_max, gamma, tone and tone_max in every call, which meant the defaults had never been looked at. Rendered
eleven bare-default plots at 600 dpi (`prototypes/gallery2.R` is the successor), compared against the tuned keepset.

## What was wrong with the bare defaults

| Problem | Cause | Fix |
|---|---|---|
| `geom_halftone()` looked like a 1980s dot-matrix print: 1.2 mm square lattice, 4 quantised levels, Bayer dither visible as a 4x4 crosshatch texture | `pitch = 1.2, grid = "square", levels = 4` | 0.6 mm hex, **continuous tone** (`levels = NULL`): dot area follows tone exactly, no dither. `levels = k` still quantises and dithers for a stipple look. |
| Ribbons and densities carried dust: hundreds of sub-0.05 mm dots at the tone edge, reading as dirt | no floor on drawn tone | cells below 2 % tone are not drawn |
| Dot lattice had a horizontal axis, so every horizontal edge (bar tops, step plateaus) aliased against the rows | `angle = 0` | default 15 deg on hex: no lattice axis is horizontal or vertical (the hex analogue of the classic 45 deg square screen) |
| Bars, areas and polygons were drawn with the gaussian centre profile: bars faded to nothing at their edges | one profile for every geom | profile follows the geometry: bars / tiles / areas / polygons / sf are **flat**; ribbons **centre**; densities and violins a soft **vignette** (was "edge", which reviewer 1 rightly called a rendering gradient) |
| Every figure sat at a different ink weight | `tone_max = 1` everywhere | one register: flat 0.45, centre 0.85, vignette 0.7, so mid-tone lands at ~35–45 % coverage across the set |
| Square and diamond dots printed heavier than circles at the same tone | shapes sized by radius, not area | shapes are area-matched (square half-side sqrt(pi)/2 r, diamond sqrt(pi/2) r) |
| A mapped `screen` on a density still faded, so the pattern and the vignette fought | tone profile applied regardless | a mapped screen is a categorical pattern, hence flat, unless `tone` is given explicitly |
| Line-screen legend keys showed dots; hatch angles 0/30/60 made "horizontal" the first pattern | one recipe for dots and lines | screen specs carry a 4th field, the hatching angle (45, 135, 0, 90, ...); keys hatch when the layer is a line screen; specs are absolute, so `angle=` on the layer is an offset only when given |
| Theme requested Liberation Sans / EB Garamond / Inconsolata, none installed here; ragg silently substituted | hard-coded families | `theme_halftone()` resolves the first installed family from a preference list via systemfonts (journal: Liberation Sans, Arial, Helvetica; editorial: EB Garamond, Garamond, Georgia; mono: Inconsolata, Menlo, Courier New) |
| Default ggplot2 hues under a print halftone | no palette hook | on ggplot2 >= 4.0 the theme sets the ink palette for discrete colour/fill and a sepia ramp (`halftone_ramp`) for continuous scales |
| Every KM script re-implemented the step-ribbon frame and the hairline halo by hand | missing helpers | `km_steps()`, `km_censor()`, `km_risk()` (survfit -> frames), `with_halo(layer, width = 0.08)` (paper stroke under any line or point layer) |

## Verdicts on the new gallery (`figures/v2/`)

| Figure | Verdict | Notes |
|---|---|---|
| km | keep | Three CIs, three inks, woven overlap; haloed steps; censor ticks; risk table. This is the README lead. Ochre is still the weakest ink at low tone; consider a deeper amber. |
| km_bw | keep | Two hatch angles plus dots in one layer (`scale_screen_manual(c("45|line","135|line","15|circle"))`). Triple overlap is busy but honest; at 0.6 mm the 45/135 crosshatch does not moire. |
| smooth | keep | One ink, centre profile. The band's soft edge now reads as uncertainty, not as a gradient. |
| densities | keep | Vignette at 0.7 is the right weight: solid enough to read as a fill, open enough that three overlaps stay legible. |
| densities_bw | keep | 45 / 135 / 0 hatching; the crosshatch in overlaps is the point. |
| bars | keep | A hatched, B dot-screened. B's dots are decorative (reviewer 1's objection stands); A is the version to use in a paper. |
| area | keep | Flat screen with white seams between series; no outline fighting the dots. |
| map | keep | Sepia ramp is the default now; 45 deg square lattice reads as a printed map. |
| elevation | keep | A continuous-tone dots; B the engraving. B remains the hero. |
| stipple | keep | Blue-noise binary stipple, one contour set. |
| dotplot | rework later | `geom_spot()` still needs `scale_tone()` for a proper guide (TODO 3). |

## Rules added to the design list

- Continuous tone by default; quantise (`levels`) only for a stipple or a poster.
- Nothing below 2 % tone is drawn.
- No lattice axis horizontal or vertical: 15 deg on hex, 45 deg on square.
- Profile follows geometry: flat for shapes whose interior is the value, centre for intervals, vignette for outline-defined shapes.
- A mapped screen is a pattern, and patterns are flat.
- Shapes are area-matched.

## Review 2, feedback round (same day)

Author's notes on the v2 proofs, and what changed:

| Figure | Note | Change |
|---|---|---|
| area | "hard to read without black lines; the pattern is the same for all three colours, intended?" | It was: groups shared one lattice so overlaps could weave. For stacked series nothing overlaps, so the gallery now maps `screen = series` and each ink gets its own angle and shape, as in print. Ink hairline between series. |
| bars | "quite mature, like the pattern variation in b&w" | unchanged |
| densities | "cute job on both" | unchanged |
| dotplot | "lackluster, white holes around the pattern within circles" | `geom_spot()` rewritten: one hex lattice per disc, centred (a symmetric rosette), dots clipped to the disc, no gap ring. `scale_tone_continuous()` gives tone a real legend of discs at the breaks; keys size themselves so labels never sit on the disc. |
| elevation | "hurts a little when you concentrate; maybe the halo?" | The 0.08 mm halo was invisible against 0.6 mm hatch, so lines and hatch fused. Engraving: default line-screen pitch is now 0.45 mm, halo 0.15 mm. Dots: back to the 45° square lattice with gamma 0.6, and the ochre-to-red ramp. |
| km colour | "lighter shades for the CIs?" | Centre profile register lowered from 0.85 to 0.6. Tinted inks were tried and rejected: they wash the legend out. |
| km b&w | "busy and difficult on the eyes" | Hatched intervals are now hairline by default (tone_max 0.15) and the gallery uses 0.8 mm because three overlap; dashed and dotted steps with a 0.1 mm halo. Dot screens at three angles were tried: the moire rosettes in the overlaps were worse. |
| map | "straight downgrade from the previous one" | Agreed. The continuous ramp is back to paper - ochre - red - near-black (`halftone_ramp`), polygons/sf print at 0.6, gallery uses the 45° square lattice. |
| smooth | "looks quite good" | unchanged |
| stipple | "you need to look at that one" | A binary stipple at full tone printed the bare lattice in the density core. `levels = 1` now caps tone at 0.55 by default (`tone_max` overrides), so the densest region stays a stipple. |

## Closing the open items (same day)

- **Ochre**: four candidates side by side on the three-strata KM (ochre #A8741C, amber #9C6A0F, umber #8A5A12, green). Amber wins: clearly heavier than ochre at the band edge, still a distinct hue from red, unlike umber which drifts towards it. `halftone_inks[["ochre"]]` is now #9C6A0F; the continuous ramp keeps the lighter ochre as its mid stop.
- **Arguments**: `gain` and `size_map` removed. Dot area, not radius, follows tone, and ink spread is a press property that has no place in a figure.
- **Tone aesthetic** on `geom_halftone()` too; `halftone_tone_legend()` retired.
- **Docs**: every export has an Rd page; check is clean.

## Pitch ladder (same day)

Author: "I can't help but wonder if the patterns we're using are too coarse." Ladder at 0.6 / 0.45 / 0.35 / 0.25 mm
(42 / 56 / 73 / 102 lpi) on the three-strata KM, the hatched bars and the iris densities, single column, 600 dpi:

| pitch | dots | hatch | draw time (single KM) |
|---|---|---|---|
| 0.60 | reads as dots; the screen is the subject | coarse, poster-like | 1.0 s |
| 0.45 | texture; still countable | good | ~1.7 s |
| 0.35 | tone with a visible screen; overlaps weave without moire | fine hatch, reads as engraving | ~2.8 s |
| 0.25 | flat tint; no screen structure left to read | too fine to read as hatch | 5.3 s |

Default moved from 0.6 to **0.35 mm** for `geom_halftone()`, `with_halftone()` and `geom_spot()`. The map is the clearest
win (it now looks like the printed original), the stipple is a real stipple, and the engraving gains its fine line.
Gallery figures that set a pitch explicitly were scaled with it (B&W KM 0.5 because three hatches overlap). Whole gallery
renders in ~25 s. Also fixed in the same round: hatch strips stopped at the last lattice centre inside the shape, which
on a hex lattice combed the ends and left a white margin inside every hatched bar (the "snaking tube"); runs now extend
a pitch past the last cell and are clipped.

## Press-honest pass (same day)

Author asked whether the figures follow journal practice and how the idea could improve; then "OK on everything".

- **Minimum feature.** The 2 % tone floor produced 0.13 pt dots and a 0.12 pt hairline hatch, under the 0.25 pt journal
  minimum: one pixel at 600 dpi, mud on a press. `min_feature = 0.09` mm now governs dots, strips, spot dots and the halo.
  Clipping at the floor was tried first and gave the engraving a hard shelf with a uniform hairline plateau; the floor
  is now enforced by dithering (draw at the floor with probability tone/floor, blue-noise thresholded), which keeps
  mean coverage and lets light tone dissolve into sparse dots or broken hairlines, as a press does.
- **Likelihood profile.** The interval profile is the normal density of the estimate (0.146 at a 95 % limit, `level`);
  the old "centre" gaussian was within a hair of it, so the look is unchanged and the fade now means something.
- **Redundant screens.** Fills on tiling geoms get automatic screens; legend keys read them from a map written at draw
  time. Intervals and densities are excluded on the evidence of the earlier moire test.
- **Export.** PNG for proofs, TIFF (LZW) and vector PDF (cairo) by extension. A TIFF wrapper that hid ragg's formals
  behind `...` produced a 72 dpi thumbnail: ggsave reads the device's formals to decide what to pass.
- **Theme.** Rules 0.25 mm (0.7 pt, were 1.1 pt), tags 8 pt, gallery data lines 0.35 mm (1 pt, were 1.4 pt).
- **Process palette.** K, M+Y, C+M, C+Y, C, M at 100 % beside the muted inks on the KM and bars: legible, harsher.
  Opt-in via `theme_halftone(palette = "process")`; the muted inks stay the screen default.
- **Performance.** Scanline rasteriser for the tone-profile raster: gallery 25 s -> 11 s.

## Follow-through (2026-09-22)

- `geom_spot()` gained hatching (`shape = "line"`), square and diamond dots, and the `screen` aesthetic; the rosette
  rotates with the screen angle so hatched discs read as one family with hatched bars.
- Three vignettes carry the gallery as prose: the journal figure, one-ink screens, fields. pkgdown builds.
- The intended fonts are installed; every render since is in Liberation Sans, EB Garamond, Inconsolata. Nothing in the
  proofs changed visibly except the editorial piece, which finally has its Garamond.

- Performance closed out: the weave and the colour lookup were the last package-side hot spots; after vectorising them the draw is device-bound. CI workflows written, awaiting a remote.

## Illuminated contours (2026-09-22)

Author asked whether an asymmetric halo would be more authentic. Answer: a one-sided halo on a line over a screen is
misregistration, the fault trap allowances exist to hide; the authentic asymmetry is Tanaka's illuminated contours
(1950), where lit segments print in paper and shaded ones in ink, widening as the slope faces the light. `with_relief()`
implements it; uphill is inferred per contour from neighbouring levels (ggplot2's contour lines are consistently
oriented within a line but not across lines, measured on the volcano). Rendered four ways: over the hatched engraving
(the new gallery panel B, and the best figure in the set), over the sepia dot field, and alone on a light screen. The
symmetric `with_halo()` stays for lines over intervals.

## Tags and the editorial piece (2026-09-22)

- Panel tags were positioned at the plot corner inside the plot area (`plot.tag.position = c(0, 1)`) and overlapped
  panel borders and axes. They now live in their own layout cell (`plot.tag.location = "margin"`), which is what a
  journal compositor does: the tag is outside the figure, aligned to its top-left.
- The editorial image in the README was a font-check placeholder: a sine wave at 0.9 mm on a column width, with the
  page register's 17.6 pt title. Replaced by a real plate: Maunga Whau, line screen at 0.45 mm with illuminated
  contours, Garamond title, mono subtitle and caption, cream paper, 120 mm wide. The editorial type sizes were reduced
  (title 1.5x, labels 0.7x of base) so subtitles and captions fit a 120 mm page; the register is documented as a page
  register, not a column one.

## No theme (2026-09-22)

Author: "Not a huge fan of our halftone theme" and, on the suggestion of shipping none, "Sure". The complete theme is
gone, and with it the editorial register, the font fallback chain and the `halftone.style` option. `theme_halftone()`
is now an incomplete modifier that adds only what a halftone needs to whatever theme the user has: paper ground, no
gridlines, legend keys 6 by 4 mm so a screen fits, and the ink palettes on ggplot2 4.0. The gallery renders on
`theme_classic(base_size = 8)`, `theme_bw()` and `theme_minimal()` plus the modifier; the Maunga Whau plate is
`theme_void()` with a serif title and a monospace caption set in the gallery script. Side by side with the previous
proofs nothing that mattered changed, and the figures now look like the user's own ggplot2, which is the claim the
README makes.

Found while re-rendering: densities were getting automatic per-group screens, because `GeomDensity` inherits from
`GeomArea` and the tiling test matched it. The overlaps showed the moire that rule exists to prevent. Excluded, with
a test.

## One-ink KM legibility, and dropping the plate (2026-09-22)

Author: the line styles in `km_bw` are hard to see inside the shading. Four candidates at 600 dpi: the current
treatment; a wider halo with a heavier line and longer dashes; solid steps at three line weights; and the same as the
second with a coarser hatch. The last wins, and the fix is four settings acting together rather than any one of them:

| setting | before | after | why |
|---|---|---|---|
| pitch | 0.5 mm | 0.7 mm | three overlapping hatches make a dense mesh; a coarser one leaves white for the line |
| halo | 0.09 mm | 0.2 mm | the line needs its own channel through the mesh, wider than against dots |
| linewidth | 0.35 | 0.5 | more ink in the line than in any hatch stroke |
| dashes | 42, 12 | 62, 22 | a short dash is the same length as a hatch stroke and disappears into it |

Solid steps at three weights were legible but the weights are harder to tell apart than dash patterns, and the heaviest
line was too black beside a hairline hatch.

The editorial plate is removed from the gallery, the README and `figures/v2/`. It was there to show a second register;
with the editorial theme gone it only showed a plot with a serif title, which is not what an R package README is for.
The engraving already carries the line screen in the README.

## Stress sweep (2026-09-22)

Fourteen combinations the gallery does not reach, rendered to see what breaks: sf, polar coordinates, free-scale
facets, violins, four-colour process from a photograph, ridgelines, Floyd-Steinberg, tile heatmaps, log scales, tiny
multiples, stacked bars, relief on a plain path, flipped coordinates, and spots with size, screen and hatching at once.

Two real bugs:

- **`geom_sf()` was rejected.** It returns a list of a layer and a `CoordSf`, and all three wrappers assumed a bare
  layer. They now accept either, through `wrap_layers()`. `match.arg(profile)` had to move out of the per-layer
  function, because it reads the formals of the frame it is called from.
- **The test harness hid two blanks.** Handling warnings with `tryCatch` aborted the print, so polar and violin came
  out empty and looked broken. They were fine. The lesson is `withCallingHandlers` for warnings in a render sweep.

Three pieces of behaviour worth documenting rather than changing: the ink palettes stop at six, so a seventh group
silently gets no fill (ggplot2 does warn); the wrappers replace a layer's geom in place, because a ggproto layer is
an environment; and `with_relief()` on bare paper shows only the shaded half of each contour, since lit segments are
paper-coloured.

Polygons with holes were the suspected third bug and turned out correct: the clip path combines rings with the
winding rule, so an inner ring cancels the outer one. Tested.

The best of the sweep became `prototypes/showcase.R`: a photograph in four-colour process beside the same photograph
as a one-ink newspaper screen, an sf choropleth, a wind rose whose categorical encoding is hatch angle in polar
coordinates, ridgelines, one-ink violins, and the same figure saved at 40, 89 and 183 mm with crops at equal
magnification, which is the first direct demonstration that the screen does not scale with the figure.

## The wind rose, and legend keys (2026-09-22)

Author: the wind rose looks bad apart from the shading. Two faults, both mine:

- **The hatch encoded direction, which the angle already encoded.** It was decoration. It now encodes wind speed,
  stacked within each direction sector, which is what a wind rose is for and gives the hatch a job. Three speed bins
  rather than four, at 0.75 mm, because twenty-four hatched regions meet in one panel.
- **The furniture floated.** The radial scale expanded well past the data, so the rings and the direction labels sat
  far outside the rose in white space. Tight limits with no expansion.

A third fault, caught on the next proof: the rings and spokes were grey, and every other figure in the set has no grey
at all. A polar chart still needs a radial reference, so the rings stay, but as hairline ink at 0.12 mm, which is the
same register as every other rule in the set. Spokes went entirely. Two alternatives were rendered and rejected: an
outer ring alone leaves the radial labels with nothing to anchor to, and a radial ruler drawn as data turns into a
spoke, because in polar coordinates an x position is an angle.

Chasing why the horizontal hatch looked heavier than the diagonals turned up a real bug in the legend key rather than
in the screen. Ink coverage on the panel is constant across angles, measured at 0.309 to 0.310 over eight angles. The
key was drawing a fixed count of strokes across the key box at a fixed line width, so its density changed with angle
and matched the panel at no angle at all. The key is now a true sample of the screen: strips one lattice row apart
(pitch times sqrt(3)/2 on a hex lattice) at the screen's own strip width, clipped to the key box.

## Legend keys, again (2026-09-22)

Using the package on a real paper found the key wrong a second time. The first fix made the key's strip
width and spacing match the panel's by re-deriving the panel's formulas. That held until an ordinal
tone ramp put some levels below the printable minimum: the panel breaks those strips into hairline
dashes by floor-dithering, and the key, having only the width formula, drew them as continuous thin
lines. Keys and bars for the same level looked like different screens.

The formula approach was the mistake. A key now runs the real lattice over a key-sized area and draws
it with the same grobs the panel uses, so pitch, angle, tone, quantisation, dithering and the minimum
feature all behave identically by construction rather than by agreement. The test renders a key and the
bar it stands for and compares ink coverage, at a tone above the minimum and at one below it.

## Bug hunt on the seams (2026-09-22)

Every bug this session came from a place where two code paths are meant to agree but are maintained
apart: the legend key against the panel, twice, and the two geoms against each other. So the hunt went
there, with invariants rather than eyeballs.

Held: ink coverage does not depend on pitch (2.4 % spread for dots over 0.4 to 0.9 mm, 0.1 % for line
screens), coverage is linear in `tone_max`, the two geoms agree to 0.0 % for the same specification,
all three overlap modes behave (overprint prints one dot per cell, interleave 1.25x for two
phase-shifted lattices, stack 1.01x), every dither and every tone profile renders, and the field
helpers all run.

Two real faults:

- **A square lattice defaulted to 15 degrees** while the help and the design rules promise 45, the
  classic print angle. Every square-lattice figure in the gallery passes `angle = 45` by hand, which is
  the happy-defaults failure in miniature. Both geoms now take the angle from the grid and the shape
  through one `default_angle()`.
- **`local` was a dead parameter.** It was consulted only inside the branch where `profile != "vertical"`,
  under a condition requiring `profile == "vertical"`, so it could never be true. The vertical profile is
  normalised per column by the kernel and the radial profile over the whole shape, each unconditionally.
  A documented knob that cannot move is worse than no knob, so it is gone, and a test pins what each
  profile actually does: a narrow tail reaches full tone under `"vertical"` and stays lighter under
  `"radial"`.

## The vector path was wrong (2026-09-23)

The one output nothing had ever inspected was the PDF. Rendering the same three plots to ragg and to
`cairo_pdf`, rasterising the PDF with poppler and comparing ink: a polygon with a hole agreed to 1 %, a
hatched bar chart to 1 %, and three overlapping densities disagreed by **93 %**. The vector dots were
visibly fatter and merged into blobs.

Isolating it away from the package: `grid.circle` at radii 0.05, 0.10, 0.20 and 0.40 mm renders at
diameters 0.34, 0.36, 0.38 and 0.78 mm on `cairo_pdf`, against 0.09, 0.19, 0.40 and 0.78 on ragg and on
base `pdf()`. Cairo enforces a floor of about 0.34 mm on a small filled circle, and clears it only above
roughly 0.2 mm radius. Every dot this package places is smaller than that, so every cairo PDF it had
ever written was too dark, and the finer the pitch the worse the error.

Polygons are faithful: a 16-sided approximation at the same radii measures 0.106, 0.191, 0.381, 0.783 on
cairo, identical to ragg. So dots now go through `round_dots()`, which uses `circleGrob` on the devices
where it is known to be faithful (ragg, base `pdf`, postscript) and a 12-sided polygon everywhere else,
including any device it does not recognise. Correct by default, with the fast primitive kept where it is
proven. The raster path is unchanged and the gallery still renders in the same time.

The test renders the same plot to ragg and to `cairo_pdf`, rasterises the PDF and compares coverage. It
needs poppler, so it skips where that is missing.

## Closing the last two open items (2026-09-23)

**Blend modes, judged at 600 dpi on a three-ink CMY overlap.** `alternate` weaves and every ink stays
visible, which is the only mode that answers "which criteria are present here". `multiply` is the
subtractive physics, the product of the reflectances, and sends a full-strength three-ink overlap to
black, correctly. `mix` averages and darkens by an arbitrary factor and turns the whole panel one muddy
brown; it is neither honest nor physical. All three are documented for what they are; the default stays
`alternate`.

**The blue-noise repeat does not exist.** The hand-off note claimed the 32 by 32 void-and-cluster matrix
repeats visibly on large flat fills. On a 60 by 30 mm stipple at 0.45 mm the autocorrelation of the
rendered field at the 32-cell period is -0.005, indistinguishable from a non-period lag, and the crop
shows no structure by eye. The lattice rotation and the field-to-lattice mapping break any alignment
between the matrix tiling and the page. Closed as not reproducible rather than fixed.

## Press artefacts, and a parameter bug they exposed (2026-09-23)

The `with_*()` architecture turns out to be established practice rather than invention: ggfx is built on
it and gives the same reason, that a modifier works with any geom while a special geom does not. ggfx
already has `with_halftone_dither()`, but its filters run on the rasterised layer, so the dot size is in
pixels. That is the sharpest statement of what this package is for, and it now opens the README.

`with_press()` adds dot gain and plate misregistration, composed around a halftone layer. Gain follows
`tone + g * sin(pi * tone)`, so it vanishes at paper and at solid and peaks in the midtones, which is
where a press gains most; `g` is the trade's tone value increase at a 50 % screen. (Superseded on
2026-09-25: the curve runs on coverage, not on tone. See the last entry.) Measured on a flat
field at 0.8 mm: a 0.25 tone gains 42 % of its area at `g = 0.15`, matching the curve. Past `g = 0.5`
the midtone dots grow beyond the pitch, touch and bridge, which is the blotting of a heavy impression,
and it falls out of the model rather than being drawn specially.

Building it exposed a bug that had been there since the first wrapper. ggplot2 decides which parameters
a geom accepts by reading the formals of its `draw_panel`, and a wrapper's are only `...`; it then falls
back to `draw_group`, which for most geoms is the empty base method. So a wrapped layer reported no
parameters and ggplot2 dropped every one of them. `with_press(geom_halftone(pitch = 0.8))` silently drew
at the default pitch, and `with_halo(geom_line(arrow = ...))` silently dropped the arrow. `with_halftone`
escaped only by accident, because ribbons define `draw_group` and it inherited those formals. All four
wrappers now delegate `parameters()` to the geom they wrap, with a test comparing wrapped against
unwrapped for each.

## Mottle, and the fillet declined (2026-09-23)

`with_press()` gained `mottle`, the slow variation in ink density that separates a real impression from
a clean digital screen. It is value noise on a grid of `mottle_scale` millimetres, smoothstepped so the
field has no creases at the cell joins, multiplying tone so a light area mottles less than a dark one,
as ink does. The test checks that density now varies between tiles while the mean is preserved, that
the field is smooth rather than white noise, and that a seed reproduces it exactly.

The surface-tension fillet was declined here and then built, on the author's call. Reversing was right:
at 1:1 the bridge is clearly visible, the junctions become smooth arcs instead of cusps, and the
interstices shrink to curved triangles rather than lenses.

## The fillet, built (2026-09-23)

A morphological closing of the union of the touching dots: offset out by the fillet radius with round
joins, then back in by the same. That rounds concave corners and leaves convex boundaries alone, which
is exactly the bridge surface tension pulls across the notch where two circles cross.

Two things had to be got right. The radius is a fraction of the pitch and the useful range is much
smaller than it first appears: at 0.15 the closing swallows the interstices entirely and the shadows go
solid black. (Superseded on 2026-09-25: with gain measured correctly the ladder moved. At `gain = 0.25`,
0.02 rounds the cusp, 0.04 draws a clear bridge, and 0.08 pulls the fill-in down into the midtones.)

The cost is acceptable only because the closing runs on the dots that can reach a neighbour and nowhere
else: a gained ramp at 0.9 mm went from 0.25 s to 0.36 s, against 1.7 s for twenty thousand dots
unioned blind. (Superseded on 2026-09-25: the union also runs in tiles, or it overflows the protection
stack. See the entry below.)

It also bridges a small gap, not only an overlap, which is correct: tension reaches across a gap
narrower than twice the fillet radius. The test uses dots far enough apart that nothing can reach, and
checks they are untouched, then a dot size just past contact and checks the bridge adds ink.

## Slur, and where the examples live (2026-09-23)

Slur is the last of the press set: a sheet moving under the plate smears each dot along its direction of
travel. It is drawn as the shape the ink actually covers, a capsule swept along `slur_angle`, rather than
as a second faint impression, because nothing translucent reaches the page here. The same `ink_shape()`
feeds the fillet's union, so a slurred screen bridges correctly too.

The press work had until now existed only in throwaway comparison sheets, which was a gap: four features
and nothing permanent to look at. `prototypes/showcase.R` now renders `press.png`, the four-colour
photograph three ways, as the plate describes it, printed, and badly printed. Misregistration needs each
ink wrapped separately with its own seed, which the script shows; a single `with_press()` around all four
layers gives them the same offset and no fringing at all.

## Dot gain on coverage, and the fillet that could never fire (2026-09-25)

The reader reported that the fillet looked underdone. It was doing nothing at all, at every setting the
documentation recommended. Two units errors.

Tone value increase is a measurement of ink coverage, and the code applied it to tone. The two differ
because `dot_max` caps coverage below 1: at the defaults a full-tone hex cell covers 0.73 of its
lattice cell, not all of it. So a full-tone cell received `sin(pi * 1) = 0` gain, its dots stayed a
tenth of a pitch clear of their neighbours, and no closing radius under 0.05 could reach across. The
curve now runs in coverage and is capped at the sheet. That cap is the shadow fill-in: the dots grow
past the pitch, touch, and print as solid with pinholes.

polyclip works on polygons, so a filleted dot became an inscribed 16-gon, which carries 4.7 % less ink
than its circle. A fillet below the bridging threshold therefore printed lighter than no fillet at all:
0.7271 coverage with none, 0.7118 with 0.04 or 0.05, the two identical because neither bridged. Dots
are now 24-gons with the circumradius scaled to match the circle's area, and `round_dots()` takes the
same correction for the 12-gon it draws on cairo.

Both existing fillet tests set `dot_max` away from its default to make the feature fire, which is what
hid this. A test that has to move a parameter off its default to see an effect is evidence the effect
is not there at the default.

## A filleted shadow of any size used to crash (2026-09-25)

polyclip overflows R's protection stack when it unions a few thousand overlapping dots at the depth of
a draw. Gain with slur and a fillet, or gain with a fillet and mottle, crashed at 1800 dots, which is a
20 mm square at 0.5 mm. In isolation the same call handles 5000, so the headroom depends on how deep
the draw already is, which is why the gallery got away with it.

A closing is local: whether a point is inked depends only on dots within twice the fillet radius. The
field is now cut into tiles of about 600 dots, each closed from the dots within a margin of it and
clipped back to the tile. Ink per unit area is the same at 6 mm and at 160 mm. The clips overlap by
0.03 mm, because edges that merely abut leave an anti-aliased light line along every join.

## The press gallery, and the control it needed (2026-09-25)

`with_press()` now takes a plot or a patchwork as well as a layer, so `prototypes/press_gallery.R`
builds its pairs from the gallery's own plot objects rather than a second copy of the figure code.
`wrap_layers()` copies every layer first: a ggproto layer is an environment, and pressing a plot in
place reached back into the plot the caller still held, so a before-and-after pair printed the same
figure twice.

The legend key missed the press and read lighter than the fill it stood for, the third time the key and
the panel have drifted apart. The wrapper now overrides the key as well as the panel. Gain, slur and
the fillet reach a key; mottle and registration do not, because both are properties of a place on the
sheet and a key is a sample of the screen rather than of a place.

Two panels could not answer the question they raised, whether the pressed half is anything more than
the plain half with more ink. Measured on a flat field at 0.6 tone, with `dot_max` raised from 0.90 to
1.22 so the plain screen lays down the same 0.790 coverage: mottle, as tile standard deviation, 0.064
against 0.003, and ink runs 23 % longer along the slur axis than across it. Neither is reachable from
any setting on the plain figure. Gain is: on a flat field it is exactly a `dot_max` tweak, and over a
tone range it differs only in curve shape, up to 8 coverage points darker in the midtones and lighter
in the shadows at a matched mean. So the gallery has three panels, as prepared, dot gain only, and the
whole press, with `control.png` carrying the matched comparison.

## Four showcase figures (2026-09-28)

`wind_rose` encoded an ordered variable, wind speed, as hatch angle. A reader cannot rank three angles,
and in a wedge that size cannot tell them apart at all. The three classes now sit on one lattice and
darken outward, through the tone field of a screen specification. Petals are 0.85 wide, so they no
longer abut and read as a stack of overlapping discs. The polar geometry itself was never wrong: plain
ggplot2 fills draw exactly the same wedges, checked twice.

`pitch_invariance` took its three crops at a fixed offset from three renders of a sine ribbon, so each
showed a different part of the curve and the reader compared shapes instead of dot size. It is now a
vertical tone ramp, where tone depends on y alone and every crop comes from the same place, with a
second row that ties the pitch to the output width for contrast.

`sf_choropleth` mapped a skewed rate through a linear ramp, leaving 69 of 100 counties below a quarter
of the maximum and the map flat. A square-root transform gives it a register. `photograph` panel B
filled in at gamma 1 and lost its subject; it is at 1.7.
