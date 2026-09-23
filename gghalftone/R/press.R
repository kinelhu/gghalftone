# press.R: simulation of what a press does to a screen, as opposed to what the screen says.
# Everything here makes a figure LESS faithful to its data, so it is a separate entry point, off by
# default, and never used in the journal register.

#' Press artefacts
#'
#' Wraps a halftone layer so that its screen is drawn the way a press would put it on paper rather than
#' the way the plate describes it. Compose it around [with_halftone()] or a halftone geom:
#' `with_press(with_halftone(geom_col()), gain = 0.3)`.
#'
#' @section Dot gain:
#' Ink spreads into paper, so a printed dot is larger than its plate. The trade measures this as tone
#' value increase, the extra coverage at a 50 % screen: roughly 0.10 to 0.20 for offset on coated stock
#' and 0.25 to 0.35 on newsprint. `gain` is that number. The increase follows `sin(pi * tone)`, so it
#' vanishes at paper and at solid and peaks in the midtones, which is where a press gains most. Above
#' about 0.5 the midtone dots grow past the lattice pitch, touch and bridge, which is the blotting of a
#' heavily inked impression.
#'
#' @section Mottle:
#' Ink does not lie down evenly. `mottle` adds a slow random variation in density across the sheet, smooth at the
#' scale of `mottle_scale` millimetres, which is what separates a real impression from a clean digital screen. It
#' varies tone, so it survives resizing like everything else here.
#'
#' @section Slur:
#' A sheet moving under the plate smears each dot along its direction of travel, so the dot prints as a capsule
#' rather than a circle. `slur` is the length of that smear as a fraction of the pitch and `slur_angle` its
#' direction. It is drawn as the true swept shape rather than a second faint impression, because nothing
#' translucent reaches the page here.
#'
#' @section Ink bridges:
#' Where two dots overlap, the circles cross in a sharp concave cusp. Wet ink does not: surface tension pulls a
#' fillet across the notch. `fillet` is the radius of that bridge as a fraction of the pitch, applied as a
#' morphological closing of the union of the overlapping dots, which rounds concave corners and leaves convex
#' boundaries alone. Only dots close enough to reach a neighbour are processed, so a figure pays for it in its
#' shadows and nowhere else. A bridge is ink, so it darkens the shadows a little on top of `gain`.
#'
#' It needs the polyclip package and it is the one setting here with a real cost: budget about a second per twenty
#' thousand touching dots.
#'
#' @section Registration:
#' Each ink is a separate plate and the plates never align perfectly. `registration` is the standard
#' deviation, in mm, of a random offset applied to this layer's lattice. It only shows when a figure is
#' built from several halftone layers, one per ink, as [geom_halftone_cmyk()] does. Values around
#' 0.05 mm read as a good press, 0.2 mm as a cheap one.
#'
#' @param layer A halftone layer, or a list holding one.
#' @param gain Tone value increase at a 50 % screen. 0 leaves the screen alone.
#' @param slur Length of the smear, as a fraction of the lattice pitch, in the direction the sheet travelled.
#'   0.1 is a press running a little fast, 0.3 a visible fault. 0 leaves the dots round.
#' @param slur_angle Direction of that smear in degrees, measured anticlockwise from the x axis.
#' @param fillet Radius of the ink bridge where two dots meet, as a fraction of the lattice pitch. Useful values are
#'   small: 0.02 rounds the cusp, 0.05 draws a clear bridge, and much above 0.08 the closing swallows the gaps
#'   between dots and the shadows go solid. 0 leaves the cusp where the circles cross. Needs the polyclip package.
#' @param mottle Relative standard deviation of the slow variation in ink density across the sheet. 0.1 is a
#'   visible but unremarkable impression, 0.25 a poor one.
#' @param mottle_scale Distance in mm over which that variation changes. Real mottle runs at a few millimetres.
#' @param registration Standard deviation in mm of this layer's plate offset. 0 is perfect registration.
#' @param seed Seed for the plate offset, so a figure rebuilds identically. `NULL` draws a new one.
#' @return The layer, with its geom replaced by one that carries the press settings.
#' @examples
#' d <- data.frame(x = seq(0, 10, length.out = 60))
#' d$y <- sin(d$x); d$lo <- d$y - 0.5; d$hi <- d$y + 0.5
#' ggplot2::ggplot(d, ggplot2::aes(x)) +
#'   with_press(with_halftone(ggplot2::geom_ribbon(ggplot2::aes(ymin = lo, ymax = hi), fill = "black")),
#'              gain = 0.3) +
#'   ggplot2::theme_classic() + theme_halftone()
#' @export
with_press <- function(layer, gain = 0.2, slur = 0, slur_angle = 90, fillet = 0, mottle = 0, mottle_scale = 4,
                       registration = 0, seed = NULL) {
  stopifnot(gain >= 0, slur >= 0, fillet >= 0, mottle >= 0, mottle_scale > 0, registration >= 0)
  if (fillet > 0 && !requireNamespace("polyclip", quietly = TRUE))
    stop("with_press(fillet = ) needs the polyclip package", call. = FALSE)
  press <- list(gain = gain, slur = slur, slur_angle = slur_angle, fillet = fillet, mottle = mottle,
                mottle_scale = mottle_scale, registration = registration,
                seed = seed %||% sample.int(.Machine$integer.max, 1L))
  wrap_layers(layer, function(layer) {
    parent <- layer$geom
    layer$geom <- ggproto(NULL, parent, parameters = keep_parameters(parent),
      draw_panel = function(self, data, panel_params, coord, ...) {
      set_press(ggproto_parent(parent, self)$draw_panel(data, panel_params, coord, ...), press)
    })
    layer
  })
}

# walk the grob the wrapped geom produced and hand the settings to every halftone grob in it
set_press <- function(g, press) {
  if (inherits(g, c("halftone", "halftone_fill", "spot"))) { g$params$press <- press; return(g) }
  if (inherits(g, "gTree")) { g$children <- do.call(gList, lapply(g$children, set_press, press = press)); return(g) }
  if (inherits(g, "gList")) return(do.call(gList, lapply(g, set_press, press = press)))
  g
}

# Tone value increase. Peaks in the midtones and is allowed past 1, because a press that gains that
# hard fills its shadows in: the dots grow past the pitch, touch, and read as solid with holes.
press_gain <- function(tone, press) {
  if (is.null(press) || press$gain <= 0) return(tone)
  pmin(tone + press$gain * sin(pi * pmin(pmax(tone, 0), 1)), 1.6)
}
# Dots that can reach a neighbour are unioned and morphologically closed, which rounds the concave cusp where two
# circles cross and leaves the convex outline untouched: the bridge surface tension pulls. Dots too small to touch
# anything are drawn as dots, so only the shadows pay. Inks are filleted separately; ink does not bridge to another
# plate's ink.
# One dot as the shape the ink actually covers: a circle, or a capsule when the sheet slurred under the plate.
ink_shape <- function(cx, cy, r, slur, angle, k = 16) {
  if (slur <= 0) { a <- seq(0, 2 * pi, length.out = k + 1)[-(k + 1)]; return(list(x = cx + r * cos(a), y = cy + r * sin(a))) }
  th <- angle * pi / 180; h <- slur / 2
  a1 <- seq(th - pi / 2, th + pi / 2, length.out = k / 2 + 1)
  a2 <- seq(th + pi / 2, th + 3 * pi / 2, length.out = k / 2 + 1)
  list(x = c(cx + h * cos(th) + r * cos(a1), cx - h * cos(th) + r * cos(a2)),
       y = c(cy + h * sin(th) + r * sin(a1), cy - h * sin(th) + r * sin(a2)))
}
press_dots <- function(xs, ys, r, cols, shape, pitch, press, k = 16) {
  slur <- if (is.null(press) || is.null(press$slur)) 0 else press$slur * pitch
  fillet <- if (is.null(press) || is.null(press$fillet)) 0 else press$fillet
  round_only <- identical(shape, "circle")
  if ((fillet <= 0 && slur <= 0) || !round_only) return(dot_grob(xs, ys, r, cols, shape))
  if (fillet > 0 && !requireNamespace("polyclip", quietly = TRUE)) fillet <- 0
  shapes <- function(i) Map(function(X, Y, R) ink_shape(X, Y, R, slur, press$slur_angle %||% 90, k), xs[i], ys[i], r[i])
  as_path <- function(u, cl) pathGrob(unit(unlist(lapply(u, `[[`, "x")), "mm"), unit(unlist(lapply(u, `[[`, "y")), "mm"),
                                      id.lengths = lengths(lapply(u, `[[`, "x")), rule = "evenodd", gp = gpar(fill = cl, col = NA))
  if (fillet <= 0) {   # slur alone: no union needed, each dot is just a capsule
    kids <- gList()
    for (cl in unique(cols)) { s <- which(cols == cl); kids <- gList(kids, as_path(shapes(s), cl)) }
    return(gTree(children = kids))
  }
  touch <- r >= pitch * 0.40                     # nearest neighbours on either lattice sit one pitch apart
  if (!any(touch) && slur <= 0) return(dot_grob(xs, ys, r, cols, shape))
  f <- fillet * pitch
  kids <- gList()
  for (cl in unique(cols[!touch])) { s <- which(!touch & cols == cl); if (length(s)) kids <- gList(kids, as_path(shapes(s), cl)) }
  for (cl in unique(cols[touch])) {
    s <- which(touch & cols == cl)
    u <- polyclip::polysimplify(shapes(s), filltype = "nonzero")
    u <- polyclip::polyoffset(polyclip::polyoffset(u, f, jointype = "round"), -f, jointype = "round")
    if (!length(u)) next
    kids <- gList(kids, as_path(u, cl))
  }
  gTree(children = kids)
}

# Slow variation in ink density: value noise on a grid of `mottle_scale` mm, smoothstepped so the field has no
# creases at the cell joins. Multiplies tone, so a light area mottles less than a dark one, as ink does.
press_mottle <- function(tone, press, X, Y) {
  if (is.null(press) || is.null(press$mottle) || press$mottle <= 0) return(tone)
  s <- press$mottle_scale
  i0 <- floor(as.vector(X) / s); j0 <- floor(as.vector(Y) / s)
  i1 <- min(i0); j1 <- min(j0); ni <- max(i0) - i1 + 2L; nj <- max(j0) - j1 + 2L
  n <- withr_seed(press$seed + 1L, matrix(stats::rnorm(ni * nj), nj, ni))
  ii <- i0 - i1 + 1L; jj <- j0 - j1 + 1L
  fx <- as.vector(X) / s - i0; fy <- as.vector(Y) / s - j0
  sx <- fx * fx * (3 - 2 * fx); sy <- fy * fy * (3 - 2 * fy)
  v <- (n[cbind(jj, ii)] * (1 - sx) + n[cbind(jj, ii + 1L)] * sx) * (1 - sy) +
       (n[cbind(jj + 1L, ii)] * (1 - sx) + n[cbind(jj + 1L, ii + 1L)] * sx) * sy
  out <- pmax(as.vector(tone) * (1 + press$mottle * v), 0)
  if (is.matrix(tone)) matrix(out, nrow(tone), ncol(tone)) else out
}
# The plate offset, in units of pitch, so it can go straight into halftone_lattice()'s phase.
press_phase <- function(press, pitch) {
  if (is.null(press) || press$registration <= 0) return(c(0, 0))
  withr_seed(press$seed, stats::rnorm(2, 0, press$registration) / pitch)
}
withr_seed <- function(seed, expr) {
  old <- if (exists(".Random.seed", .GlobalEnv)) get(".Random.seed", .GlobalEnv) else NULL
  set.seed(seed); on.exit(if (is.null(old)) rm(".Random.seed", envir = .GlobalEnv) else assign(".Random.seed", old, .GlobalEnv))
  force(expr)
}
