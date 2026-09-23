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
#' @section Registration:
#' Each ink is a separate plate and the plates never align perfectly. `registration` is the standard
#' deviation, in mm, of a random offset applied to this layer's lattice. It only shows when a figure is
#' built from several halftone layers, one per ink, as [geom_halftone_cmyk()] does. Values around
#' 0.05 mm read as a good press, 0.2 mm as a cheap one.
#'
#' @param layer A halftone layer, or a list holding one.
#' @param gain Tone value increase at a 50 % screen. 0 leaves the screen alone.
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
with_press <- function(layer, gain = 0.2, registration = 0, seed = NULL) {
  stopifnot(gain >= 0, registration >= 0)
  press <- list(gain = gain, registration = registration,
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
