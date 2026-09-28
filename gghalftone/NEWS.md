# gghalftone 0.0.0.9000

* `with_halftone()` screens the fill of any layer at draw time, on a lattice whose pitch is in millimetres, so a figure saved at 89 mm and at 183 mm gets the same screen. The tone profile follows the geometry: flat for bars, areas, polygons and maps, the likelihood of the estimate for intervals, a soft vignette for densities.
* `halftone_plot()` screens a whole plot, or a patchwork, in one call. It screens the filled layers, haloes the lines and points that sit over a screen, and adds the theme modifier. A geom it does not recognise draws exactly as it did before.
* `geom_halftone()` screens a gridded field, `geom_halftone_cmyk()` separates one into four process inks, and `geom_spot()` draws one tone disc per point.
* `with_halo()` draws the printer's knockout channel under a line. `with_relief()` implements illuminated contours (Tanaka 1950).
* The `screen` aesthetic maps a discrete variable to a lattice angle, a dot shape and a hatch angle, through `scale_screen_discrete()` and `scale_screen_manual()`. Legend keys run the real screen over a key-sized area rather than re-deriving the panel's arithmetic.
* Line screens, and Bayer, blue-noise and Floyd-Steinberg dithering for quantised tone.
* `with_press()` draws a screen as a press puts it on paper: dot gain, slur, ink bridges, mottle and plate misregistration. Gain is measured on coverage rather than on tone, which is what lets it fill a shadow in. It is off by default and outside the journal register.
* No feature is smaller than 0.09 mm, the journal minimum. The floor is held by dithering, so coverage is preserved and light tone becomes sparse minimum dots or broken hairlines.
* `ggsave_journal()` writes PDFs through base `pdf()` rather than `cairo_pdf()`. It is one of the devices where a small filled circle comes back the size it was asked for, and it needs neither cairo nor X11, which the macOS CRAN build of R has neither of.
* Drawing a screen no longer reseeds the caller's session. `blue_noise_matrix()` is seeded so the matrix is identical every time, and it now puts the RNG back where it found it.
* `theme_halftone()` is a modifier rather than a complete theme: paper ground, no gridlines, screen-sized legend keys, the ink palette, and the geom accent. `ggsave_journal()` writes PNG, TIFF or vector PDF at a column width. `halftone_proof()` renders at final size plus a magnified crop.
* `km_steps()`, `km_censor()` and `km_risk()` turn a `survfit` object into the frames these layers want.
* `design_review.md` carries the review log, newest entry last.
