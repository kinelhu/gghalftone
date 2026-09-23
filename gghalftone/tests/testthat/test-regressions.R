# One test per bug found during prototyping. Each renders to a raster device and inspects the grobs or pixels.
library(ggplot2)
render <- function(p, w = 60, h = 45, dpi = 300) { f <- tempfile(fileext = ".png"); ragg::agg_png(f, w, h, units = "mm", res = dpi); print(p); dev.off(); f }
px <- function(f) { im <- png::readPNG(f); if (length(dim(im)) == 3) im[, , 1:3] else im }

test_that("pitch is physical: dot lattice is invariant to output size", {
  vol <- data.frame(expand.grid(x = seq_len(ncol(volcano)), y = seq_len(nrow(volcano))), z = as.vector(t(volcano)))
  p <- ggplot(vol, aes(x, y, z = z)) + geom_halftone(pitch = 1, colour = "black") + theme_void()
  g <- function(w, dpi) { f <- render(p, w = w, h = w * 0.75, dpi = dpi); im <- px(f); mean(im < 0.5) }   # ink coverage fraction
  expect_equal(g(40, 300), g(120, 300), tolerance = 0.08)   # same coverage per unit area regardless of size
})

test_that("overlapping groups are overprinted, not hidden (last group must not erase the first)", {
  f <- expand.grid(x = seq(0, 10, 0.25), y = seq(0, 10, 0.25)); f$z <- 1
  d <- rbind(cbind(f, g = "a"), cbind(f, g = "b"))       # two identical fields, fully overlapping
  p <- ggplot(d, aes(x, y, z = z, colour = g)) + geom_halftone(pitch = 1.2, levels = 1, dot_max = 0.6, overlap = "overprint", blend = "alternate") +
    scale_colour_manual(values = c(a = "#FF0000", b = "#0000FF"), guide = "none") + theme_void()
  im <- px(render(p)); red <- im[, , 1] > 0.8 & im[, , 3] < 0.3; blue <- im[, , 3] > 0.8 & im[, , 1] < 0.3
  expect_gt(sum(red), 50); expect_gt(sum(blue), 50)
  expect_lt(abs(sum(red) - sum(blue)) / (sum(red) + sum(blue)), 0.3)   # woven roughly evenly
  im2 <- px(render(ggplot(d, aes(x, y, z = z, colour = g)) + geom_halftone(pitch = 1.2, levels = 1, dot_max = 0.6, overlap = "stack") +
    scale_colour_manual(values = c(a = "#FF0000", b = "#0000FF"), guide = "none") + theme_void()))
  expect_lt(sum(im2[, , 1] > 0.8 & im2[, , 3] < 0.3), 10)          # stack mode really does hide group a — documents the flaw
})

test_that("large projected fields do not overflow the gridded-field test (integer overflow bug)", {
  n <- 50000; d <- data.frame(x = runif(n), y = runif(n)); d$z <- d$x   # 50k unique x and y -> 2.5e9 product overflowed int32
  expect_no_error(gghalftone:::sample_index(d$x, d$y, runif(100), runif(100)))
})

test_that("ribbons with NA limits render through with_halftone", {
  d <- data.frame(x = 1:20, lo = c(rep(0.2, 15), rep(NA, 5)), hi = c(rep(0.8, 15), rep(NA, 5)))
  p <- ggplot(d, aes(x)) + with_halftone(geom_ribbon(aes(ymin = lo, ymax = hi), fill = "black")) + theme_void()
  expect_no_error(render(p))
})

test_that("with_halftone tone matrix is oriented correctly (rep order bug): a thin step ribbon is filled along its length, not in columns", {
  d <- data.frame(x = c(0, 5, 5, 10), lo = c(0.4, 0.4, 0.3, 0.3), hi = c(0.6, 0.6, 0.5, 0.5))
  p <- ggplot(d, aes(x)) + with_halftone(geom_ribbon(aes(ymin = lo, ymax = hi), fill = "black"), pitch = 0.6, tone = "flat", tone_max = 1, levels = 1, outline = FALSE) +
    scale_y_continuous(limits = c(0, 1)) + theme_void()
  im <- px(render(p, w = 60, h = 60)); ink <- im[, , 1] < 0.5
  rows <- rowSums(ink); cols <- colSums(ink)
  expect_gt(sum(cols > 0) / ncol(ink), 0.6)   # ink spans most columns along the ribbon
  expect_lt(sum(rows > 0) / nrow(ink), 0.45)  # but only a band of rows
})

test_that("screen recipe gives distinct specs and the aesthetic parses", {
  r <- gghalftone:::screen_recipe(9); expect_equal(length(unique(r)), 9)
  sp <- gghalftone:::parse_screen("60|square|0.85"); expect_equal(sp$angle, 60); expect_equal(sp$shape, "square"); expect_equal(sp$tone, 0.85)
  expect_equal(gghalftone:::parse_screen(45)$angle, 45)
})

test_that("blue-noise matrix is a permutation of ranks with good spectral spread", {
  b <- blue_noise_matrix(32); expect_equal(sort(as.vector(b)), (seq_len(32 * 32) - 0.5) / (32 * 32))
  th <- b < 0.5; expect_equal(sum(th), 512)
  # no 3x3 block fully on or fully off at 50% coverage (clustering check)
  bad <- 0; for (i in 2:31) for (j in 2:31) { s <- sum(th[(i-1):(i+1), (j-1):(j+1)]); if (s == 0 || s == 9) bad <- bad + 1 }
  expect_lt(bad, 5)
})


test_that("with_halftone weaves all inks in a triple overlap (hex 3-colouring), not just first and last", {
  d <- data.frame(x = rep(0:1, 3), lo = 0, hi = 1, g = rep(c("a", "b", "c"), each = 2))
  p <- ggplot(d, aes(x, group = g)) + with_halftone(geom_ribbon(aes(ymin = lo, ymax = hi, fill = g)), pitch = 1.2, tone = "flat", tone_max = 1, levels = 1, dot_max = 0.7, outline = FALSE) +
    scale_fill_manual(values = c(a = "#FF0000", b = "#00FF00", c = "#0000FF"), guide = "none") + theme_void()
  im <- px(render(p)); f <- function(ch) sum(im[, , ch] > 0.8 & rowSums(im[, , -ch, drop = FALSE], dims = 2) < 0.4)
  counts <- c(f(1), f(2), f(3)); expect_true(all(counts > 30)); expect_lt(diff(range(counts)) / mean(counts), 0.35)
})

test_that("with_halftone folds fill alpha into ink coverage", {
  d <- data.frame(x = 0:1, lo = 0, hi = 1)
  cov <- function(a) { p <- ggplot(d, aes(x)) + with_halftone(geom_ribbon(aes(ymin = lo, ymax = hi), fill = "black", alpha = a), pitch = 1, tone = "flat", tone_max = 1, levels = 4, outline = FALSE) + theme_void()
    im <- px(render(p)); mean(im[, , 1] < 0.5) }
  expect_lt(cov(0.3), cov(1) * 0.6)
})

test_that("clip is built from filled shapes only: an outline polyline must not cut holes in neighbouring bands", {
  d <- data.frame(t = rep(1:20, 2), v = rep(c(8, 6), each = 20) + rep(c(0, 1), 20), s = rep(c("A", "B"), each = 20))
  mk <- function(col) ggplot(d, aes(t, v, fill = s, group = s)) + with_halftone(geom_area(colour = col, position = position_stack(reverse = TRUE)), pitch = 0.8, tone = "flat", tone_max = 1, levels = 1, outline = FALSE) +
    scale_fill_manual(values = c(A = "#FF0000", B = "#0000FF"), guide = "none") + scale_y_continuous(expand = c(0, 0)) + theme_void()
  blue <- function(col) { im <- px(render(mk(col))); sum(im[, , 3] > 0.8 & im[, , 1] < 0.3) }
  expect_gt(blue("black"), blue(NA) * 0.9)   # outline must not remove blue ink
})

# ---- happy-defaults pass (design review 2) ------------------------------------------------------------------------
library(grid)
find_grob <- function(g, cl) { if (inherits(g, cl)) return(g); kids <- if (inherits(g, "gTree")) g$children else if (inherits(g, "gList")) g else NULL
  for (k in kids) { r <- find_grob(k, cl); if (!is.null(r)) return(r) }; NULL }
# the drawn content of the first grob of class cl in the panel, made inside a w x h mm viewport on a raster device
content <- function(p, cl, w = 40, h = 40) { g <- ggplotGrob(p); pan <- g$grobs[[grep("^panel", g$layout$name)[1]]]; gt <- find_grob(pan, cl)
  f <- tempfile(fileext = ".png"); ragg::agg_png(f, w, h, units = "mm", res = 300); on.exit(dev.off())
  pushViewport(viewport(width = unit(w, "mm"), height = unit(h, "mm"))); makeContent(gt) }
radii <- function(k) as.numeric(find_grob(k, "circle")$r)
band <- data.frame(x = 0:1, lo = 0, hi = 1)

test_that("default tone is continuous (dot area follows tone, no dither); levels = k quantises; nothing below the tone floor is drawn", {
  mk <- function(...) ggplot(band, aes(x)) + with_halftone(geom_ribbon(aes(ymin = lo, ymax = hi), fill = "black"), pitch = 1, outline = FALSE, ...) + theme_void()
  r_cont <- radii(content(mk(), "halftone_fill")); r_q <- radii(content(mk(levels = 4), "halftone_fill"))
  expect_gt(length(unique(round(r_cont, 4))), 20)
  expect_lte(length(unique(round(r_q, 4))), 4)
  expect_gt(min(r_cont), 0.9 / 2 * sqrt(0.02) * 0.99)
  vol <- data.frame(expand.grid(x = seq_len(ncol(volcano)), y = seq_len(nrow(volcano))), z = as.vector(t(volcano)))
  r_field <- radii(content(ggplot(vol, aes(x, y, z = z)) + geom_halftone(pitch = 1) + theme_void(), "halftone"))
  expect_gt(length(unique(round(r_field, 4))), 20)
})

test_that("tone profile follows the geometry: bars are flat (one dot size), ribbons fade from the centre", {
  r_bar <- radii(content(ggplot(data.frame(g = "a", n = 1), aes(g, n)) + with_halftone(geom_col(fill = "black"), pitch = 1, outline = FALSE) + theme_void(), "halftone_fill"))
  expect_equal(length(unique(round(r_bar, 4))), 1)
  r_rib <- radii(content(ggplot(band, aes(x)) + with_halftone(geom_ribbon(aes(ymin = lo, ymax = hi), fill = "black"), pitch = 1, outline = FALSE) + theme_void(), "halftone_fill"))
  expect_gt(length(unique(round(r_rib, 4))), 20)
})

test_that("square and diamond dots carry the same ink as circles at the same tone", {
  cov <- function(s) { p <- ggplot(band, aes(x)) + with_halftone(geom_ribbon(aes(ymin = lo, ymax = hi), fill = "black"), pitch = 1, tone = "flat", tone_max = 0.5, shape = s, outline = FALSE) + theme_void()
    im <- px(render(p)); mean(im[, , 1] < 0.5) }
  cs <- c(cov("circle"), cov("square"), cov("diamond")); expect_lt(diff(range(cs)) / mean(cs), 0.1)
})

test_that("a mapped screen is a flat pattern: the density vignette is dropped unless tone is given explicitly", {
  p <- ggplot(iris, aes(Sepal.Length, screen = Species, group = Species)) + with_halftone(geom_density(fill = "black"), pitch = 1, outline = FALSE) + scale_screen_discrete() + theme_void()
  expect_equal(length(unique(round(radii(content(p, "halftone_fill")), 4))), 1)
  p2 <- ggplot(iris, aes(Sepal.Length, screen = Species, group = Species)) + with_halftone(geom_density(fill = "black"), pitch = 1, outline = FALSE, tone = "vignette") + scale_screen_discrete() + theme_void()
  expect_gt(length(unique(round(radii(content(p2, "halftone_fill")), 4))), 5)
})

test_that("screen specs carry a line angle (4th field) used only by line screens; recipe starts 45/135/0/90 relative to the layer angle", {
  sp <- gghalftone:::parse_screen("0|square|0.85|90"); expect_equal(sp$line, 90)
  expect_equal(gghalftone:::screen_angle(sp, "line"), 90); expect_equal(gghalftone:::screen_angle(sp, "circle"), 0)
  expect_null(gghalftone:::parse_screen("60|square|0.85")$line)
  expect_equal(sapply(strsplit(gghalftone:::screen_recipe(4), "|", fixed = TRUE), `[`, 4), c("45", "135", "0", "90"))
  expect_equal(as.numeric(sapply(strsplit(gghalftone:::screen_recipe(3), "|", fixed = TRUE), `[`, 1)), c(15, 35, 55))
})

test_that("with_halo draws a paper-coloured stroke under the line, and a wider width gives more halo", {
  d <- data.frame(x = c(0, 1), y = 0.5)
  base <- ggplot(d, aes(x, y)) + annotate("rect", xmin = -Inf, xmax = Inf, ymin = -Inf, ymax = Inf, fill = "black") + theme_void() + theme(plot.background = element_rect(fill = "black", colour = NA))
  white <- function(p) { im <- px(render(p, w = 30, h = 30)); sum(im[, , 1] > 0.9 & im[, , 2] > 0.9) }
  expect_equal(white(base + geom_line(colour = "red")), 0)
  expect_gt(white(base + with_halo(geom_line(colour = "red"), width = 0.3)), 50)
  expect_gt(white(base + with_halo(geom_line(colour = "red"), width = 0.3)), white(base + with_halo(geom_line(colour = "red"), width = 0.1)))
})

test_that("km_steps / km_censor / km_risk turn a survfit into step-ready frames", {
  skip_if_not_installed("survival")
  fit <- survival::survfit(survival::Surv(time, status) ~ sex, data = survival::lung)
  s <- km_steps(fit); expect_equal(levels(s$strata), c("1", "2"))
  for (g in split(s, s$strata)) {
    expect_equal(g$time[1], 0); expect_equal(g$surv[1], 1); expect_true(all(diff(g$surv) <= 1e-12)); expect_true(all(diff(g$time) >= 0))
    expect_true(all(g$lo <= g$surv + 1e-12 & g$surv <= g$hi + 1e-12))
    expect_equal(nrow(g), 2 * (fit$strata[[as.integer(as.character(g$strata[1]))]] + 1) - 1)
  }
  expect_equal(nrow(km_censor(fit)), sum(fit$n.censor > 0))
  r <- km_risk(fit, c(0, 500)); expect_equal(r$n.risk[r$time == 0], unname(fit$n))
  one <- km_steps(survival::survfit(survival::Surv(time, status) ~ 1, data = survival::lung)); expect_equal(unique(as.character(one$strata)), "all")
})

test_that("theme_halftone is an incomplete modifier: paper ground, no grid, screen-sized keys, palettes; the host theme keeps its fonts", {
  t <- theme_halftone(); expect_false(isTRUE(attr(t, "complete")))
  expect_s3_class(t$panel.grid, "element_blank"); expect_equal(t$panel.background$fill, "white"); expect_equal(theme_halftone(paper = halftone_paper)$plot.background$fill, halftone_paper)
  host <- theme_classic(base_family = "serif", base_size = 13) + theme_halftone()
  expect_equal(host$text$family, "serif"); expect_equal(host$text$size, 13); expect_s3_class(host$panel.grid.major, "element_blank")
  skip_if(utils::packageVersion("ggplot2") < "4.0.0")
  b <- ggplot_build(ggplot(mtcars, aes(wt, mpg, fill = factor(cyl))) + geom_point(shape = 21) + theme_classic() + theme_halftone())
  expect_true(all(unique(b$data[[1]]$fill) %in% halftone_inks))
  expect_null(theme_halftone(palette = "none")$palette.fill.discrete)
})

# ---- review-2 feedback pass -------------------------------------------------------------------------------------------
test_that("a binary stipple (levels = 1) is capped so it never saturates into the bare lattice; tone_max overrides", {
  f <- expand.grid(x = seq(0, 10, 0.25), y = seq(0, 10, 0.25)); f$z <- 1
  cov <- function(...) { p <- ggplot(f, aes(x, y, z = z)) + geom_halftone(levels = 1, algorithm = "blue_noise", colour = "black", pitch = 1, ...) + theme_void()
    k <- content(p, "halftone"); length(find_grob(k, "circle")$x) }
  full <- cov(tone_max = 1); expect_lt(cov(), full * 0.65); expect_gt(cov(), full * 0.45)
})

test_that("geom_halftone defaults to a 0.35 mm pitch", {
  vol <- data.frame(expand.grid(x = seq_len(ncol(volcano)), y = seq_len(nrow(volcano))), z = as.vector(t(volcano)))
  n_strips <- function(...) { k <- content(ggplot(vol, aes(x, y, z = z)) + geom_halftone(shape = "line", ...) + theme_void(), "halftone"); length(find_grob(k, "polygon")$id.lengths) }
  expect_gt(n_strips(), n_strips(pitch = 0.6) * 1.5); expect_equal(n_strips(), n_strips(pitch = 0.35))
})

test_that("geom_spot: per-disc lattice is clipped to the disc, tone comes from scale_tone_continuous(), keys show the break tone", {
  d <- data.frame(x = 1:3, y = 1, v = c(0, 5, 10))
  p <- ggplot(d, aes(x, y, tone = v)) + geom_spot(r = 3, pitch = 0.6) + scale_tone_continuous() + theme_void()
  b <- ggplot_build(p); expect_equal(range(b$data[[1]]$tone), c(0, 1))
  k <- content(p, "spot", w = 60, h = 30)
  clips <- 0; walk <- function(g) { if (inherits(g, "gTree")) { if (!is.null(g$vp) && inherits(g$vp$clip, "GridClipPath")) clips <<- clips + 1; for (ch in g$children) walk(ch) } }
  walk(k); expect_equal(clips, 2)                         # the tone-0 disc draws no dots and therefore no clip group
  disc <- find_grob(k, "circle"); expect_true(all(as.numeric(disc$r) > 0))
  key <- draw_key_spot(data.frame(colour = "black", tone = 0.8, size = NA), list(r = 3, pitch = 0.6, ring_lwd = 0.3), 5)
  expect_gt(length(find_grob(key, "circle")$x), 5)
  expect_error(content(ggplot(d, aes(x, y)) + geom_spot() + theme_void(), "spot"), "tone")
})

test_that("register: centre profile prints lighter (0.6) than before; polygons flat at 0.6, bars flat at 0.45", {
  r_rib <- max(radii(content(ggplot(band, aes(x)) + with_halftone(geom_ribbon(aes(ymin = lo, ymax = hi), fill = "black"), pitch = 1, outline = FALSE) + theme_void(), "halftone_fill")))
  expect_lt(r_rib, 0.9 / 2 * sqrt(0.62)); expect_gt(r_rib, 0.9 / 2 * sqrt(0.5))
  r_bar <- radii(content(ggplot(data.frame(g = "a", n = 1), aes(g, n)) + with_halftone(geom_col(fill = "black"), pitch = 1, outline = FALSE) + theme_void(), "halftone_fill"))[1]
  r_pol <- radii(content(ggplot(data.frame(x = c(0, 1, 1, 0), y = c(0, 0, 1, 1)), aes(x, y)) + with_halftone(geom_polygon(fill = "black"), pitch = 1, outline = FALSE) + theme_void(), "halftone_fill"))[1]
  expect_equal(r_bar, 0.9 / 2 * sqrt(0.45), tolerance = 1e-6); expect_equal(r_pol, 0.9 / 2 * sqrt(0.6), tolerance = 1e-6)
})

test_that("hatched ribbons are a hairline (min_feature) while hatched bars keep 0.4", {
  strip_w <- function(p) { k <- content(p, "halftone_fill"); g <- find_grob(k, "polygon"); x <- as.numeric(g$x); y <- as.numeric(g$y); n <- g$id.lengths[1]
    sqrt((x[1] - x[n])^2 + (y[1] - y[n])^2) }   # first strip: first and last vertex are the two edges at the same end
  w_rib <- strip_w(ggplot(band, aes(x)) + with_halftone(geom_ribbon(aes(ymin = lo, ymax = hi), fill = "black"), pitch = 1, shape = "line", outline = FALSE) + theme_void())
  w_bar <- strip_w(ggplot(data.frame(g = "a", n = 1), aes(g, n)) + with_halftone(geom_col(fill = "black"), pitch = 1, shape = "line", outline = FALSE) + theme_void())
  expect_equal(w_rib, 0.09, tolerance = 1e-6); expect_equal(w_bar, 0.4 * 0.9 * 0.9, tolerance = 1e-6)
})

test_that("a line-screen layer with a mapped screen recipe stays hatched (the recipe's dot shapes do not override shape = 'line')", {
  d <- data.frame(g = c("a", "b"), n = c(1, 2))
  p <- ggplot(d, aes(g, n, screen = g)) + with_halftone(geom_col(fill = "black"), shape = "line", pitch = 1, outline = FALSE) + scale_screen_discrete() + theme_void()
  k <- content(p, "halftone_fill"); expect_null(find_grob(k, "circle")); expect_false(is.null(find_grob(k, "polygon")))
  key <- draw_key_halftone(data.frame(colour = "black", screen = gghalftone:::screen_recipe(1)), list(shape = "line", angle = 45, angle_user = FALSE), 5)
  expect_false(is.null(find_grob(key, "polygon")))   # a hatch key is drawn as strips, like the panel
  mixed <- function(vals) content(ggplot(d, aes(g, n, screen = g)) + with_halftone(geom_col(fill = "black"), pitch = 1, outline = FALSE) + scale_screen_manual(values = vals) + theme_void(), "halftone_fill")
  expect_false(is.null(find_grob(mixed(c("45|line", "15|circle")), "polygon")))   # first group hatched (content() renders the first group)
  expect_false(is.null(find_grob(mixed(c("15|circle", "45|line")), "circle")))    # first group dotted
})

test_that("geom_halftone takes aes(tone = ) through scale_tone_continuous(), and errors without z or tone", {
  f <- expand.grid(x = 1:20, y = 1:20); f$v <- f$x * 5
  p <- ggplot(f, aes(x, y, tone = v)) + geom_halftone(pitch = 1) + scale_tone_continuous() + theme_void()
  expect_equal(range(ggplot_build(p)$data[[1]]$tone), c(0, 1))
  r <- radii(content(p, "halftone")); expect_gt(length(unique(round(r, 4))), 10)
  expect_error(content(ggplot(f, aes(x, y)) + geom_halftone(pitch = 1) + theme_void(), "halftone"), "tone")
})

test_that("hatch strips reach the outline: every run is extended by half a pitch at each end and clipped, so no white margin combs inside a bar", {
  # horizontal hatch in a bar: the ink must reach within a hairline of both vertical edges on every strip row
  d <- data.frame(g = "a", n = 1)
  p <- ggplot(d, aes(g, n)) + with_halftone(geom_col(fill = "black", width = 0.6), shape = "line", angle = 0, pitch = 1, outline = FALSE) + scale_y_continuous(expand = c(0, 0)) + theme_void()
  im <- px(render(p, w = 40, h = 40)); ink <- im[, , 1] < 0.5
  cols <- which(colSums(ink) > 0); left <- min(cols); right <- max(cols)
  rows <- which(rowSums(ink) > 0)
  reach <- sapply(rows, function(r) { on <- which(ink[r, ]); c(min(on) - left, right - max(on)) })   # px short of the bar's extreme ink columns
  expect_lt(max(reach), 3)     # at 300 dpi, 3 px = 0.25 mm; the old code left up to pitch/2 = 0.5 mm (6 px) on alternate rows
  # a single-cell run still draws a strip
  k <- gghalftone:::line_strips_grob(matrix(c(0, 5), 1), matrix(c(0, 0), 1), matrix(c(1, 0), 1), "black", matrix(c(TRUE, FALSE), 1), 0, 0.5, 0.5)
  expect_s3_class(k, "polygon"); expect_equal(diff(range(as.numeric(k$x))), 1)
})

# ---- press-honest pass ----------------------------------------------------------------------------------------------------
test_that("no drawn feature is smaller than min_feature (0.09 mm): dots, spot dots, hatch strips; 0 disables it", {
  r_rib <- radii(content(ggplot(band, aes(x)) + with_halftone(geom_ribbon(aes(ymin = lo, ymax = hi), fill = "black"), pitch = 0.35, outline = FALSE) + theme_void(), "halftone_fill"))
  expect_gte(min(2 * r_rib), 0.09 - 1e-9)
  r_off <- radii(content(ggplot(band, aes(x)) + with_halftone(geom_ribbon(aes(ymin = lo, ymax = hi), fill = "black"), pitch = 0.35, outline = FALSE, min_feature = 0, tone = "tent") + theme_void(), "halftone_fill"))   # tent goes to 0 at the edge; likelihood bottoms out at 0.146
  expect_lt(min(2 * r_off), 0.09)
  vol <- data.frame(expand.grid(x = seq_len(ncol(volcano)), y = seq_len(nrow(volcano))), z = as.vector(t(volcano)))
  expect_gte(min(2 * radii(content(ggplot(vol, aes(x, y, z = z)) + geom_halftone() + theme_void(), "halftone"))), 0.09 - 1e-9)
  k <- gghalftone:::line_strips_grob(matrix(c(0, 1, 2, 3), 1), matrix(0, 1, 4), matrix(c(0.5, 0.05, 0.3, 0.3), 1), "black", matrix(TRUE, 1, 4), 0, 0.2, 0, 0.09)
  ys <- as.numeric(k$y); w <- sapply(split(ys, rep(seq_along(k$id.lengths), k$id.lengths)), function(v) diff(range(v)))
  expect_true(all(w >= 0.09 - 1e-9))   # strips below the minimum are drawn at the minimum (dithered by tone) or not at all
  expect_true(length(w) %in% 1:3)
  # the floor is enforced by dithering: mean coverage of a light flat field is preserved to within the blue-noise error
  D <- matrix(0.03, 40, 40); Dd <- gghalftone:::floor_dither(D, 0.1, row(D), col(D))
  expect_true(all(Dd %in% c(0, 0.1))); expect_equal(mean(Dd), 0.03, tolerance = 0.15)
})

test_that("hatched intervals are a hairline equal to min_feature; the interval profile is the likelihood, 0.146 at a 95% limit", {
  strip_w <- function(p) { k <- content(p, "halftone_fill"); g <- find_grob(k, "polygon"); x <- as.numeric(g$x); y <- as.numeric(g$y); n <- g$id.lengths[1]; sqrt((x[1] - x[n])^2 + (y[1] - y[n])^2) }
  expect_equal(strip_w(ggplot(band, aes(x)) + with_halftone(geom_ribbon(aes(ymin = lo, ymax = hi), fill = "black"), pitch = 0.5, shape = "line", outline = FALSE) + theme_void()), 0.09, tolerance = 1e-6)
  expect_message(with_halftone(geom_ribbon(aes(ymin = lo, ymax = hi)), shape = "line", tone_max = 0.05), "printable minimum")
  r <- radii(content(ggplot(band, aes(x)) + with_halftone(geom_ribbon(aes(ymin = lo, ymax = hi), fill = "black"), pitch = 1, outline = FALSE, min_feature = 0) + theme_void(), "halftone_fill"))
  expect_equal(max(r), 0.9 / 2 * sqrt(0.6), tolerance = 1e-3)                     # 1 on the estimate, times the register
  r99 <- radii(content(ggplot(band, aes(x)) + with_halftone(geom_ribbon(aes(ymin = lo, ymax = hi), fill = "black"), pitch = 1, outline = FALSE, min_feature = 0, level = 0.99) + theme_void(), "halftone_fill"))
  expect_lt(min(r99), min(r))                                                       # a 99 % band fades further at its limit
})

test_that("colour is redundant by default on tiling geoms (bars get distinct screens; keys follow) and not on intervals", {
  angles <- function(p) { g <- ggplotGrob(p); pan <- g$grobs[[grep("^panel", g$layout$name)[1]]]; out <- c()
    walk <- function(x) { if (inherits(x, "halftone_fill")) out <<- c(out, x$params$angle) else if (inherits(x, "gTree")) for (k in x$children) walk(k) else if (inherits(x, "gList")) for (k in x) walk(k) }
    walk(pan); out }
  d <- data.frame(g = c("a", "b", "c"), n = 3:1)
  a_bar <- angles(ggplot(d, aes(g, n, fill = g)) + with_halftone(geom_col(), pitch = 1) + theme_void())
  expect_equal(length(a_bar), 3); expect_equal(length(unique(a_bar)), 3)
  expect_equal(length(angles(ggplot(d, aes(g, n, fill = g)) + with_halftone(geom_col(), pitch = 1, redundant = FALSE) + theme_void())), 1)
  d2 <- data.frame(x = rep(0:1, 2), lo = 0, hi = 1, g = rep(c("a", "b"), each = 2))
  expect_equal(length(angles(ggplot(d2, aes(x, group = g)) + with_halftone(geom_ribbon(aes(ymin = lo, ymax = hi, fill = g)), pitch = 1) + theme_void())), 1)
  expect_equal(length(angles(ggplot(iris, aes(Sepal.Length, fill = Species, group = Species)) + with_halftone(geom_density(), pitch = 1) + theme_void())), 1)   # GeomDensity inherits GeomArea but is not a tiling geom
  # legend keys pick up the auto screens: three keys, hatched at distinct angles for a line layer
  p <- ggplot(d, aes(g, n, fill = g)) + with_halftone(geom_col(), pitch = 1, shape = "line") + theme_classic() + theme_halftone()
  # a hatch key is drawn by the panel's own strip code, so each key is a polygon; its long axis is the angle
  g <- ggplotGrob(p); keys <- c()
  walk <- function(x) { if (inherits(x, "polygon") && !is.null(x$id.lengths)) {
      m <- x$id.lengths[1]; xs <- as.numeric(x$x)[1:m]; ys <- as.numeric(x$y)[1:m]
      keys <<- c(keys, atan2(ys[m / 2] - ys[1], xs[m / 2] - xs[1]) %% pi) }
    kids <- if (inherits(x, "gtable")) x$grobs else if (inherits(x, "gTree")) x$children else if (inherits(x, "gList")) x else NULL; for (k in kids) walk(k) }
  for (gr in g$grobs[grep("guide-box", g$layout$name)]) walk(gr)
  expect_equal(length(keys), 3); expect_equal(length(unique(round(keys, 2))), 3)
})

test_that("ggsave_journal writes png, tiff and vector pdf by extension; halftone_proof returns full and zoom files", {
  p <- ggplot(band, aes(x)) + with_halftone(geom_ribbon(aes(ymin = lo, ymax = hi), fill = "black"), pitch = 1) + theme_classic() + theme_halftone()
  td <- tempdir()
  for (ext in c("png", "tiff", "pdf")) { f <- file.path(td, paste0("j.", ext)); ggsave_journal(f, p, "single", height = 30); expect_gt(file.size(f), 1000) }
  # vector, not an embedded raster: the file grows with the number of dots (cairo compresses streams, so grep for operators is useless)
  p_fine <- ggplot(band, aes(x)) + with_halftone(geom_ribbon(aes(ymin = lo, ymax = hi), fill = "black"), pitch = 0.4) + theme_classic() + theme_halftone()
  ggsave_journal(file.path(td, "fine.pdf"), p_fine, "single", height = 30); expect_gt(file.size(file.path(td, "fine.pdf")), 3 * file.size(file.path(td, "j.pdf")))
  info <- png::readPNG(file.path(td, "j.png")); expect_equal(dim(info)[2], round(89 / 25.4 * 600))   # 600 dpi at 89 mm
  skip_if_not_installed("magick")
  pf <- halftone_proof(p, "single", height = 30, dir = td, size = 10); expect_true(all(file.exists(pf))); expect_named(pf, c("full", "zoom"))
})

test_that("process palette is one or two plates and switchable", {
  expect_equal(length(halftone_process), 6); expect_true(all(grepl("^#[0-9A-F]{6}$", halftone_process)))
  skip_if(utils::packageVersion("ggplot2") < "4.0.0")
  b <- ggplot_build(ggplot(mtcars, aes(wt, mpg, fill = factor(cyl))) + geom_point(shape = 21) + theme_halftone(palette = "process"))
  expect_true(all(unique(b$data[[1]]$fill) %in% halftone_process))
})

test_that("scanline fill agrees with point-in-polygon on a concave polygon (the fine raster of the tone profile)", {
  vx <- c(0, 10, 10, 6, 6, 4, 4, 0); vy <- c(0, 0, 8, 8, 3, 3, 8, 8)   # a U shape
  rx <- seq(-1, 11, by = 0.37); ry <- seq(-1, 9, by = 0.41)
  a <- gghalftone:::scan_fill_cpp(rx, ry, vx, vy)
  b <- matrix(gghalftone:::pip_cpp(rep(rx, each = length(ry)), rep(ry, times = length(rx)), vx, vy), length(ry), length(rx))
  expect_equal(dim(a), c(length(ry), length(rx))); expect_gt(mean(a), 0.3); expect_equal(a, b)
})

test_that("geom_spot: shape = 'line' hatches the discs; aes(screen = ) rotates per group; keys follow", {
  d <- data.frame(x = 1:3, y = 1, v = c(0.3, 0.6, 0.9), g = c("a", "b", "c"))
  kh <- content(ggplot(d, aes(x, y, tone = v)) + geom_spot(r = 3, pitch = 0.5, shape = "line") + scale_tone_continuous() + theme_void(), "spot", w = 60, h = 30)
  rs <- c(); walk0 <- function(g) { if (inherits(g, "circle")) rs <<- c(rs, as.numeric(g$r)); if (inherits(g, "gTree")) for (k in g$children) walk0(k) }
  walk0(kh); expect_true(all(abs(rs - 3) < 1e-9)); expect_false(is.null(find_grob(kh, "polygon")))   # only ring circles (r = 3 mm), hatch strips carry the tone
  ps <- ggplot(d, aes(x, y, tone = v, screen = g)) + geom_spot(r = 3, pitch = 0.5) + scale_tone_continuous() + scale_screen_manual(values = c("15|circle", "45|line", "75|square")) + theme_void()
  ks <- content(ps, "spot", w = 60, h = 30)
  cls <- c(); walk <- function(g) { if (inherits(g, c("circle", "polygon", "rect"))) cls <<- c(cls, class(g)[1]); if (inherits(g, "gTree")) for (k in g$children) walk(k) }
  walk(ks); expect_true(all(c("circle", "polygon", "rect") %in% cls))
  key <- draw_key_spot(data.frame(colour = "black", tone = 0.7, size = NA, screen = "45|line"), list(r = 3, pitch = 0.5), 5)
  expect_false(is.null(find_grob(key, "polygon")))
})

test_that("vectorised weave picks the same ink as the per-cell rule", {
  set.seed(3); np <- 4; n <- 500; m <- sample(1:(2^np - 1), n, TRUE); r <- sample(1:64, n, TRUE); c <- sample(1:64, n, TRUE)
  ref <- mapply(function(m, r, c) { ks <- which(bitwAnd(as.integer(m), 2^(0:30)) > 0); k <- length(ks); ks[(gghalftone:::weave_phase(r, c, k) %% k) + 1] }, m, r, c)
  expect_equal(gghalftone:::weave_pick(m, r, c, np), unname(ref))
})

test_that("with_relief: on a cone lit from the NW, paper segments face NW and ink segments SE; the light angle moves them; widths stay in range", {
  g <- expand.grid(x = seq(0, 10, length.out = 60), y = seq(0, 10, length.out = 60)); g$z <- -sqrt((g$x - 5)^2 + (g$y - 5)^2)
  mk <- function(light) ggplot(g, aes(x, y, z = z)) + with_relief(geom_contour(bins = 6), light = light) + coord_cartesian(xlim = c(0, 10), ylim = c(0, 10), expand = FALSE) + theme_void()
  lit_dir <- function(light) { k <- content(mk(light), "relief", w = 60, h = 60); s <- Filter(function(z) inherits(z, "segments"), k$children)[[2]]
    mx <- (as.numeric(s$x0) + as.numeric(s$x1)) / 2 - 30; my <- (as.numeric(s$y0) + as.numeric(s$y1)) / 2 - 30; w <- s$gp$col == "white"
    expect_true(all(s$gp$lwd >= 0.05 * 96 / 25.4 - 1e-9 & s$gp$lwd <= 0.35 * 96 / 25.4 + 1e-9))
    c(x = mean(mx[w]), y = mean(my[w]), bx = mean(mx[!w]), by = mean(my[!w])) }
  d <- lit_dir(315); expect_lt(d[["x"]], 0); expect_gt(d[["y"]], 0); expect_gt(d[["bx"]], 0); expect_lt(d[["by"]], 0)   # lit NW, shaded SE
  d2 <- lit_dir(135); expect_gt(d2[["x"]], 0); expect_lt(d2[["y"]], 0)                                                   # light from the SE flips it
  # uphill inference: the summit ring has no higher neighbour and is closed; it still lights on the NW side (tested above via the innermost ring)
  d3 <- data.frame(x = c(0, 1, 1, 0, 0), y = c(0, 0, 1, 1, 0))
  expect_no_error(content(ggplot(d3, aes(x, y)) + with_relief(geom_path(), uphill = "left") + theme_void(), "relief"))
})

test_that("the wrappers accept a list of layers, as geom_sf() returns, and leave non-layer elements alone", {
  skip_if_not_installed("sf")
  for (f in list(with_halftone, with_halo, with_relief)) {
    lay <- ggplot2::geom_sf()                                # a list of a Layer and a CoordSf
    w <- f(lay)
    expect_type(w, "list"); expect_equal(length(w), 2)
    expect_true(inherits(w[[1]], "Layer")); expect_s3_class(w[[2]], "CoordSf")
    # a ggproto Layer is an environment, so wrapping replaces its geom in place; compare with a fresh layer
    expect_false(identical(w[[1]]$geom, ggplot2::geom_sf()[[1]]$geom))
    expect_true(inherits(w[[1]]$geom, "GeomSf"))             # still an sf geom, with a new draw_panel
  }
  expect_error(with_halftone("not a layer"), "expected a ggplot2 layer")
})

test_that("a polygon with a hole keeps the hole empty", {
  skip_if_not_installed("sf")
  outer <- rbind(c(0, 0), c(10, 0), c(10, 10), c(0, 10), c(0, 0)); hole <- rbind(c(3, 3), c(3, 7), c(7, 7), c(7, 3), c(3, 3))
  ring <- sf::st_sf(id = 1, geometry = sf::st_sfc(sf::st_polygon(list(outer, hole))))
  p <- ggplot(ring) + with_halftone(ggplot2::geom_sf(fill = "black", colour = NA), pitch = 1) + theme_void()
  im <- px(render(p, w = 50, h = 50)); n <- nrow(im)
  inner <- im[round(n * 0.42):round(n * 0.58), round(n * 0.42):round(n * 0.58), 1]
  band  <- im[round(n * 0.15):round(n * 0.25), round(n * 0.40):round(n * 0.60), 1]
  expect_equal(mean(inner < 0.5), 0); expect_gt(mean(band < 0.5), 0.1)
})

test_that("a screen spec's third field multiplies tone in both geoms: 0.5 prints half the ink", {
  cov <- function(p) { im <- px(render(p, w = 40, h = 40)); mean(im[, , 1] < 0.5) }
  # with_halftone(): two bars, same angle and shape, tone multipliers 1 and 0.5
  d <- data.frame(g = c("a", "b"), n = 1)
  full <- cov(ggplot(d[1, ], aes(g, n, screen = g)) + with_halftone(geom_col(fill = "black"), pitch = 1, outline = FALSE) + scale_screen_manual(values = c(a = "15|circle|1")) + theme_void())
  half <- cov(ggplot(d[1, ], aes(g, n, screen = g)) + with_halftone(geom_col(fill = "black"), pitch = 1, outline = FALSE) + scale_screen_manual(values = c(a = "15|circle|0.5")) + theme_void())
  expect_lt(half, full * 0.62); expect_gt(half, full * 0.38)
  # geom_halftone(): same rule
  f <- expand.grid(x = seq(0, 10, 0.25), y = seq(0, 10, 0.25)); f$z <- 1
  gfull <- cov(ggplot(f, aes(x, y, z = z)) + geom_halftone(pitch = 1, colour = "black", screen = "15|circle|1") + theme_void())
  ghalf <- cov(ggplot(f, aes(x, y, z = z)) + geom_halftone(pitch = 1, colour = "black", screen = "15|circle|0.5") + theme_void())
  expect_lt(ghalf, gfull * 0.62); expect_gt(ghalf, gfull * 0.38)
})

test_that("a legend key carries the same ink as the fill it stands for, including the broken hairlines of a sub-minimum tone", {
  # the key runs the panel's own screen code, so a light hatch breaks in the key exactly as it does in the bar
  ink <- function(g, w = 6, h = 4) { f <- tempfile(fileext = ".png"); ragg::agg_png(f, w, h, units = "mm", res = 1200)
    grid.newpage(); grid.draw(g); dev.off(); im <- png::readPNG(f); mean(im[, , 1] < 0.5) }
  bar_cov <- function(spec, pitch = 0.5) {
    d <- data.frame(g = "a", n = 1)
    p <- ggplot(d, aes(g, n, screen = g)) + with_halftone(geom_col(fill = "black", colour = NA), shape = "line", pitch = pitch, outline = FALSE) +
      scale_screen_manual(values = c(a = spec)) + scale_y_continuous(expand = c(0, 0)) + scale_x_discrete(expand = c(0, 0)) + theme_void()
    im <- px(render(p, w = 20, h = 20, dpi = 1200)); mean(im[, , 1] < 0.5) }
  key_cov <- function(spec, pitch = 0.5)
    ink(draw_key_halftone(data.frame(colour = "black", screen = spec),
                          list(shape = "line", pitch = pitch, angle = 0, angle_user = FALSE, key_tone = 0.4, grid = "hex"), 5))
  for (mult in c("0.10", "1.00")) {
    spec <- paste0("45|line|", mult)
    expect_equal(key_cov(spec), bar_cov(spec), tolerance = 0.22)   # same ink weight, within rendering noise
  }
  # and the light key really is broken, not a continuous thin line: it carries far less ink than the dark one
  expect_lt(key_cov("45|line|0.10"), key_cov("45|line|1.00") * 0.5)
})

test_that("the default lattice angle follows the grid and the shape, and both geoms agree", {
  ang_field <- function(...) content(ggplot(local({g <- expand.grid(x = 1:20, y = 1:20); g$z <- 1; g}), aes(x, y, z = z)) + geom_halftone(pitch = 1, ...) + theme_void(), "halftone")$params$angle
  ang_fill  <- function(...) content(ggplot(band, aes(x)) + with_halftone(geom_ribbon(aes(ymin = lo, ymax = hi), fill = "black"), pitch = 1, ...) + theme_void(), "halftone_fill")$params$angle
  for (f in list(ang_field, ang_fill)) {
    expect_equal(f(), 15)                                   # hex dots
    expect_equal(f(grid = "square"), 45)                    # the classic square screen angle
    expect_equal(f(shape = "line"), 45)                     # strips must not run along the lattice rows
    expect_equal(f(grid = "square", shape = "line"), 45)
    expect_equal(f(angle = 30), 30)                         # an explicit angle still wins
  }
})

test_that("each tone profile has one fixed normalisation: vertical is per column, radial is over the whole shape", {
  # a wide body on the left, a narrow tail on the right
  x <- seq(0, 10, length.out = 120)
  d <- data.frame(x, lo = 0, hi = ifelse(x < 5, 1, 0.22))
  peak <- function(profile, side) {
    k <- content(ggplot(d, aes(x)) + with_halftone(geom_ribbon(aes(ymin = lo, ymax = hi), fill = "black"),
                 profile = profile, tone = "centre", pitch = 0.5, outline = FALSE) +
                 scale_x_continuous(expand = c(0, 0)) + scale_y_continuous(limits = c(0, 1), expand = c(0, 0)) + theme_void(), "halftone_fill", w = 60, h = 40)
    g <- find_grob(k, "circle"); xs <- as.numeric(g$x); rs <- as.numeric(g$r)
    max(rs[if (side == "body") xs < 25 else xs > 35]) }
  # per column: the narrow tail reaches the same peak tone as the body
  expect_equal(peak("vertical", "tail"), peak("vertical", "body"), tolerance = 0.02)
  # over the whole shape: the tail is further from its own medial line in absolute terms, so it stays lighter
  expect_lt(peak("radial", "tail"), peak("radial", "body") * 0.8)
})

test_that("dots come out the right size on a cairo device, where grid circles do not", {
  skip_on_cran()
  skip_if(Sys.which("pdftoppm") == "", "poppler not available")
  band <- data.frame(x = 0:1, lo = 0, hi = 1)
  p <- ggplot(band, aes(x)) + with_halftone(geom_ribbon(aes(ymin = lo, ymax = hi), fill = "black"),
        tone = "flat", tone_max = 0.45, pitch = 0.6, outline = FALSE) +
    scale_x_continuous(expand = c(0, 0)) + scale_y_continuous(expand = c(0, 0)) + theme_void()
  ink <- function(f) { im <- png::readPNG(f); if (length(dim(im)) == 3) im <- im[, , 1]; mean(im < 0.85) }
  d <- tempdir()
  raster <- file.path(d, "dev_raster.png"); ragg::agg_png(raster, 40, 40, units = "mm", res = 600); print(p); dev.off()
  vec <- file.path(d, "dev_vec.pdf"); grDevices::cairo_pdf(vec, width = 40 / 25.4, height = 40 / 25.4); print(p); dev.off()
  system2("pdftoppm", c("-r", "600", "-png", "-singlefile", shQuote(vec), shQuote(file.path(d, "dev_vec"))))
  expect_equal(ink(file.path(d, "dev_vec.png")), ink(raster), tolerance = 0.08)
})

test_that("a wrapped layer still accepts the parameters of the geom it wraps", {
  # ggplot2 reads draw_panel's formals to decide which params a geom takes, and a wrapper's are just `...`,
  # so without delegation the layer silently drops pitch, arrow and the rest
  expect_equal(with_press(geom_halftone())$geom$parameters(), geom_halftone()$geom$parameters())
  expect_equal(with_halo(geom_line())$geom$parameters(), geom_line()$geom$parameters())
  expect_equal(with_relief(geom_path())$geom$parameters(), geom_path()$geom$parameters())
  expect_equal(with_halftone(geom_ribbon())$geom$parameters(), geom_ribbon()$geom$parameters())
  # and the params really arrive: a non-default pitch changes the dot count
  n <- function(p) length(find_grob(content(p, "halftone"), "circle")$x)
  f <- local({ g <- expand.grid(x = seq(0, 10, 0.5), y = seq(0, 10, 0.5)); g$z <- 0.5; g })
  expect_lt(n(ggplot(f, aes(x, y, z = z)) + with_press(geom_halftone(pitch = 1), gain = 0) + theme_void()),
            n(ggplot(f, aes(x, y, z = z)) + with_press(geom_halftone(pitch = 0.5), gain = 0) + theme_void()) * 0.5)
})

test_that("dot gain adds ink, peaks in the midtones, and is a no-op at 0", {
  flat <- function(t) local({ g <- expand.grid(x = seq(0, 10, 0.3), y = seq(0, 10, 0.3)); g$z <- t; g })
  cov <- function(t, g) { p <- ggplot(flat(t), aes(x, y, z = z)) +
      (if (g > 0) with_press(geom_halftone(pitch = 1, colour = "black", range = c(0, 1)), gain = g)
       else geom_halftone(pitch = 1, colour = "black", range = c(0, 1))) +
      coord_cartesian(expand = FALSE) + theme_void()
    mean(px(render(p, w = 30, h = 30, dpi = 600))[, , 1] < 0.5) }
  expect_equal(cov(0.5, 0), cov(0.5, 0), tolerance = 1e-9)
  expect_equal(cov(0.5, 0), mean(px(render(ggplot(flat(0.5), aes(x, y, z = z)) +
      with_press(geom_halftone(pitch = 1, colour = "black", range = c(0, 1)), gain = 0) +
      coord_cartesian(expand = FALSE) + theme_void(), w = 30, h = 30, dpi = 600))[, , 1] < 0.5), tolerance = 0.02)
  mid  <- cov(0.5, 0.3) - cov(0.5, 0)
  high <- cov(0.9, 0.3) - cov(0.9, 0)
  expect_gt(mid, 0.05); expect_gt(mid, high)          # a press gains most in the midtones
  expect_equal(gghalftone:::press_gain(c(0, 1), list(gain = 0.3)), c(0, 1))   # nothing at paper or solid
})

test_that("registration offsets the plate, reproducibly for a seed and differently between seeds", {
  f <- local({ g <- expand.grid(x = seq(0, 10, 0.5), y = seq(0, 10, 0.5)); g$z <- 0.5; g })
  xs <- function(seed) { k <- content(ggplot(f, aes(x, y, z = z)) +
      with_press(geom_halftone(pitch = 1, colour = "black"), gain = 0, registration = 0.3, seed = seed) + theme_void(), "halftone")
    sort(as.numeric(find_grob(k, "circle")$x))[1:20] }
  expect_equal(xs(1), xs(1))
  expect_false(isTRUE(all.equal(xs(1), xs(2))))
  none <- function() { k <- content(ggplot(f, aes(x, y, z = z)) + geom_halftone(pitch = 1, colour = "black") + theme_void(), "halftone")
    sort(as.numeric(find_grob(k, "circle")$x))[1:20] }
  expect_equal(gghalftone:::press_phase(list(registration = 0), 1), c(0, 0))
  expect_false(isTRUE(all.equal(xs(1), none())))
})

test_that("mottle varies ink density across the sheet, smoothly, reproducibly, and not at all when 0", {
  flat <- local({ g <- expand.grid(x = seq(0, 40, 0.4), y = seq(0, 40, 0.4)); g$z <- 0.45; g })
  img <- function(...) { p <- ggplot(flat, aes(x, y, z = z)) +
      with_press(geom_halftone(pitch = 0.6, colour = "black", range = c(0, 1)), ...) +
      coord_equal(expand = FALSE) + theme_void()
    px(render(p, w = 40, h = 40, dpi = 600))[, , 1] < 0.5 }
  tile_sd <- function(m, k = 8) { n <- nrow(m) %/% k; c <- ncol(m) %/% k
    sd(outer(seq_len(k), seq_len(k), Vectorize(function(i, j)
      mean(m[((i - 1) * n + 1):(i * n), ((j - 1) * c + 1):(j * c)]))))}
  plain <- img(gain = 0.2, seed = 7)
  mot   <- img(gain = 0.2, mottle = 0.25, seed = 7)
  expect_gt(tile_sd(mot), tile_sd(plain) * 2)          # density now varies from place to place
  expect_equal(mean(mot), mean(plain), tolerance = 0.12)  # but the average is roughly preserved
  expect_equal(img(gain = 0.2, mottle = 0, seed = 7), plain)   # 0 is exactly a no-op
  expect_equal(img(gain = 0.2, mottle = 0.25, seed = 3), img(gain = 0.2, mottle = 0.25, seed = 3))
  expect_false(identical(img(gain = 0.2, mottle = 0.25, seed = 3), mot))
  # the field is smooth: neighbouring tiles differ less than distant ones
  t8 <- function(m, k = 8) { n <- nrow(m) %/% k; c <- ncol(m) %/% k
    outer(seq_len(k), seq_len(k), Vectorize(function(i, j) mean(m[((i-1)*n+1):(i*n), ((j-1)*c+1):(j*c)]))) }
  tm <- t8(mot)
  expect_lt(mean(abs(diff(tm))), mean(abs(tm[-1, ] - tm[rev(seq_len(nrow(tm) - 1)), ])))
})

test_that("the fillet bridges touching dots only, and leaves a field that cannot touch untouched", {
  skip_if_not_installed("polyclip")
  fld <- function(t) local({ g <- expand.grid(x = seq(0, 12, 0.3), y = seq(0, 12, 0.3)); g$z <- t; g })
  # dots far apart: too distant for surface tension to reach, and below the touching threshold, so nothing changes
  far <- function(f) { p <- ggplot(fld(1), aes(x, y, z = z)) +
      with_press(geom_halftone(pitch = 1, colour = "black", range = c(0, 1), dot_max = 0.5), gain = 0, fillet = f) +
      coord_cartesian(expand = FALSE) + theme_void()
    mean(px(render(p, w = 30, h = 30, dpi = 600))[, , 1] < 0.5) }
  expect_equal(far(0.05), far(0), tolerance = 1e-9)
  # dot_max just past 1 puts the dots in contact with small gaps left: bridging fills part of them
  big <- function(f) { p <- ggplot(fld(1), aes(x, y, z = z)) +
      with_press(geom_halftone(pitch = 1, colour = "black", range = c(0, 1), dot_max = 1.02), gain = 0, fillet = f) +
      coord_cartesian(expand = FALSE) + theme_void()
    mean(px(render(p, w = 30, h = 30, dpi = 600))[, , 1] < 0.5) }
  expect_gt(big(0.05), big(0) + 0.005)   # the bridge is ink, so the shadows darken a little
  expect_equal(big(0), big(0), tolerance = 1e-9)
  expect_error(with_press(geom_halftone(), fillet = -1))
  # the grob really is a path, not circles, once bridging happens
  k <- content(ggplot(fld(1), aes(x, y, z = z)) +
    with_press(geom_halftone(pitch = 1, colour = "black", range = c(0, 1), dot_max = 1.02), gain = 0, fillet = 0.05) +
    theme_void(), "halftone")
  expect_false(is.null(find_grob(k, "pathgrob")))
})

test_that("dot gain is measured on coverage, so it reaches the shadows and stops at the sheet", {
  # Tone value increase is a coverage measurement. Applying it to tone instead left the shadows alone: a full-tone
  # cell got sin(pi * 1) = 0 gain, its dots stayed a tenth of a pitch apart, and the fillet had nothing to bridge.
  fld <- function(t) local({ g <- expand.grid(x = seq(0, 12, 0.3), y = seq(0, 12, 0.3)); g$z <- t; g })
  cov <- function(t, ...) { p <- ggplot(fld(t), aes(x, y, z = z)) +
      with_press(geom_halftone(pitch = 1, colour = "black", range = c(0, 1)), ...) +
      coord_cartesian(expand = FALSE) + theme_void()
    mean(px(render(p, w = 30, h = 30, dpi = 600))[, , 1] < 0.5) }
  expect_gt(cov(1, gain = 0.25), cov(1, gain = 0) + 0.1)    # the shadows gain, which is where a press fills in
  expect_gt(cov(1, gain = 0.25), 0.85)                      # and they gain enough for neighbouring dots to meet
  expect_lte(cov(1, gain = 0.8), 1)                         # coverage stops at the sheet, however hard it gains
  expect_gt(cov(1, gain = 0.8), cov(1, gain = 0.25))
  # a full-tone cell covers pi/4 * dot_max^2 over a hex cell, not 1
  expect_equal(gghalftone:::press_cover(0.9, "hex", "circle"), pi / 4 * 0.81 / (sqrt(3) / 2))
  expect_equal(gghalftone:::press_cover(0.9, "square", "circle"), pi / 4 * 0.81)
  expect_gt(gghalftone:::press_cover(0.9, "hex", "line"), gghalftone:::press_cover(0.9, "hex", "circle"))
  expect_equal(gghalftone:::press_gain(0.5, list(gain = 0), 0.7), 0.5)
})

test_that("the polygon a dot becomes for clipping carries the circle's ink", {
  # polyclip needs polygons, so a filleted dot is drawn as a k-gon. An inscribed k-gon is lighter than its circle,
  # and a fillet below the bridging threshold used to come out paler than no fillet at all.
  skip_if_not_installed("polyclip")
  expect_equal(gghalftone:::ngon_k(1e6), 1, tolerance = 1e-8)
  area <- function(q) abs(sum((q$x - q$x[c(length(q$x), seq_len(length(q$x) - 1))]) *
                              (q$y + q$y[c(length(q$y), seq_len(length(q$y) - 1))]))) / 2
  for (k in c(12, 16, 24)) expect_equal(area(gghalftone:::ink_shape(0, 0, 0.3, 0, 90, k)), pi * 0.3^2, tolerance = 0.002)
  fld <- local({ g <- expand.grid(x = seq(0, 12, 0.3), y = seq(0, 12, 0.3)); g$z <- 1; g })
  cov <- function(f) { p <- ggplot(fld, aes(x, y, z = z)) +
      with_press(geom_halftone(pitch = 1, colour = "black", range = c(0, 1)), gain = 0, fillet = f) +
      coord_cartesian(expand = FALSE) + theme_void()
    mean(px(render(p, w = 30, h = 30, dpi = 600))[, , 1] < 0.5) }
  expect_gte(cov(0.02), cov(0) - 0.005)    # below the bridging threshold a fillet must not lose ink
})

test_that("a filleted shadow of any size renders, with no tile seam and the same ink per unit area", {
  # A union of a few thousand overlapping dots overflowed R's protection stack when polyclip ran at the depth of a
  # draw, so any filleted shadow bigger than a swatch crashed. The closing is local, so it is done in tiles; the
  # clips overlap by a hairline, because edges that merely abut leave an anti-aliased light line along every join.
  skip_if_not_installed("polyclip")
  ink <- function(side, ...) {
    g <- expand.grid(x = seq(0, side, 0.5), y = seq(0, side, 0.5)); g$z <- 0.6
    p <- ggplot(g, aes(x, y, z = z)) +
      with_press(geom_halftone(pitch = 0.5, colour = "black", range = c(0, 1), tone_max = 1), ...) +
      coord_equal(expand = FALSE) + theme_void() +
      theme(plot.margin = margin(0, 0, 0, 0), panel.background = element_rect(fill = "white", colour = NA))
    mean(px(render(p, w = 40, h = 40, dpi = 300))[, , 1] < 0.5)
  }
  small <- ink(6, gain = 0.26, slur = 0.06, fillet = 0.06)     # one tile
  big   <- ink(60, gain = 0.26, slur = 0.06, fillet = 0.06)    # many
  expect_gt(small, 0.5)
  expect_equal(big, small, tolerance = 0.02)                   # ink per unit area does not depend on the field size
  expect_no_error(ink(60, gain = 0.26, fillet = 0.06, mottle = 0.13))
  # no seam: no interior row or column of the raster is short of ink
  g <- expand.grid(x = seq(0, 50, 0.5), y = seq(0, 50, 0.5)); g$z <- 0.62
  p <- ggplot(g, aes(x, y, z = z)) +
    with_press(geom_halftone(pitch = 1.2, colour = "black", range = c(0, 1), tone_max = 1), gain = 0.3, slur = 0.06, fillet = 0.06) +
    coord_equal(expand = FALSE) + theme_void() +
    theme(plot.margin = margin(0, 0, 0, 0), panel.background = element_rect(fill = "white", colour = NA))
  m <- 1 - px(render(p, w = 50, h = 50, dpi = 300))[, , 1]
  k <- 30:(nrow(m) - 30); mi <- m[k, k]
  expect_gt(min(colMeans(mi)) / stats::median(colMeans(mi)), 0.97)
  expect_gt(min(rowMeans(mi)) / stats::median(rowMeans(mi)), 0.97)
})

test_that("with_press() takes a plot or a patchwork, and leaves the one it was handed alone", {
  # A ggproto layer is an environment. Wrapping a plot in place would press the plot the caller still holds, so a
  # before-and-after pair would print the same figure twice.
  d <- data.frame(g = c("a", "b", "c"), n = c(3, 2, 1))
  p <- ggplot(d, aes(g, n, fill = g)) + with_halftone(geom_col()) + theme_void() + theme(legend.position = "none")
  ink <- function(x) mean(px(render(x, w = 40, h = 30, dpi = 300))[, , 1] < 0.5)
  a0 <- ink(p)
  expect_gt(ink(with_press(p, gain = 0.3, seed = 5)), a0 + 0.01)
  expect_equal(ink(p), a0, tolerance = 1e-9)
  expect_error(with_press(1:3), "expected a ggplot2 layer")
  skip_if_not_installed("patchwork")
  pw <- patchwork::wrap_plots(p, p)
  b0 <- ink(pw)
  expect_gt(ink(with_press(pw, gain = 0.3, seed = 5)), b0 + 0.01)       # reaches the plots inside the patchwork
  expect_equal(ink(pw), b0, tolerance = 1e-9)
  expect_gt(ink(with_press(patchwork::wrap_plots(pw, p), gain = 0.3, seed = 5)), ink(patchwork::wrap_plots(pw, p)) + 0.01)
})

test_that("a pressed layer's key is pressed too, and one colour serves a whole field", {
  # The key is drawn outside draw_panel, so it missed the press and read lighter than the fill it stood for. The key
  # passes a single colour for every dot, which the ink loops took for one colour per dot.
  key <- function(press) { g <- gghalftone:::key_screen_grob(0.55, "black", 0.35, 15, "hex", "circle", 0.9, 0.09, press = press)
    f <- tempfile(fileext = ".png"); ragg::agg_png(f, 8, 6, units = "mm", res = 600); grid::grid.draw(g); dev.off()
    mean(px(f)[, , 1] < 0.5) }
  P <- list(gain = 0.3, slur = 0.06, slur_angle = 90, fillet = 0.06, mottle = 0.2, mottle_scale = 8, registration = 0.3, seed = 41)
  expect_gt(key(P), key(NULL) + 0.02)
  expect_equal(key(P), key(P), tolerance = 1e-9)
  expect_no_warning(key(P))
  # mottle and registration are properties of a place on the sheet, and a key is not a place
  expect_equal(key(P), key(utils::modifyList(P, list(mottle = 0, registration = 0))), tolerance = 1e-9)
})

test_that("slur smears each dot into a capsule along its angle, and 0 leaves it round", {
  bbox <- function(...) { q <- gghalftone:::ink_shape(0, 0, r = 0.2, ...); c(w = diff(range(q$x)), h = diff(range(q$y))) }
  rnd <- bbox(slur = 0, angle = 90)
  expect_equal(unname(rnd[["w"]]), unname(rnd[["h"]]), tolerance = 1e-6)
  expect_equal(unname(rnd[["w"]]), 0.4, tolerance = 0.02)
  vert <- bbox(slur = 0.5, angle = 90)
  expect_equal(unname(vert[["h"]]), 0.9, tolerance = 0.02)   # 2r plus the smear
  expect_equal(unname(vert[["w"]]), 0.4, tolerance = 0.02)   # unchanged across it
  horz <- bbox(slur = 0.5, angle = 0)
  expect_equal(unname(horz[["w"]]), 0.9, tolerance = 0.02); expect_equal(unname(horz[["h"]]), 0.4, tolerance = 0.02)
  # and it shows on the page: a smeared screen carries more ink than a round one
  f <- local({ g <- expand.grid(x = seq(0, 12, 0.4), y = seq(0, 12, 0.4)); g$z <- 0.5; g })
  cov <- function(...) { p <- ggplot(f, aes(x, y, z = z)) +
      with_press(geom_halftone(pitch = 1, colour = "black", range = c(0, 1)), gain = 0, ...) +
      coord_cartesian(expand = FALSE) + theme_void()
    mean(px(render(p, w = 30, h = 30, dpi = 600))[, , 1] < 0.5) }
  expect_gt(cov(slur = 0.3), cov(slur = 0) * 1.3)
  expect_equal(cov(slur = 0), cov(slur = 0), tolerance = 1e-9)
})
