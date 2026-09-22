#' @keywords internal
"_PACKAGE"

#' @import ggplot2 grid
#' @importFrom stats median density approx fft rnorm setNames
#' @importFrom grDevices col2rgb rgb
#' @importFrom Rcpp sourceCpp
#' @useDynLib gghalftone, .registration = TRUE
NULL
`%||%` <- function(a, b) if (is.null(a)) b else a

# geom_sf() returns a list of a layer and a coord, and other constructors return several layers. Apply `f` to every
# Layer in `x` and keep the structure, so the wrappers take whatever a geom constructor hands them.
wrap_layers <- function(x, f) {
  if (inherits(x, "Layer")) return(f(x))
  if (is.list(x) && any(vapply(x, inherits, logical(1), "Layer"))) { x[] <- lapply(x, function(e) if (inherits(e, "Layer")) f(e) else e); return(x) }
  stop("expected a ggplot2 layer, or a list containing one, but got ", paste(class(x), collapse = "/"))
}

#' Inks, paper, ramp and column widths
#'
#' Named constants shared by the geoms and [theme_halftone()].
#'
#' * `halftone_inks`: the six-ink palette (red, blue, ochre, green, violet, grey). On ggplot2 4.0 and later the theme
#'   sets it as the default palette for mapped colour and fill. It stops at six, which is already more inks than a
#'   press would use. Beyond six groups ggplot2 warns and the extra groups get no fill, so use
#'   [scale_screen_discrete()], facets, or your own palette instead.
#' * `halftone_process`: press colours, each made of one or two process plates at 100% (K, M+Y, C+M, C+Y, C, M).
#' * `halftone_ramp`: the default continuous ramp (paper, ochre, red, near-black).
#' * `halftone_paper`, `halftone_ink`: a cream paper colour and a near-black ink colour, for plates.
#' * `halftone_widths`: journal column widths in mm.
#' @format Character vectors of hex colours, or a named numeric vector of widths.
#' @export
halftone_inks <- c(red = "#8B1A1A", blue = "#1F4E79", ochre = "#9C6A0F", green = "#2F5D3A", violet = "#5B3A6E", grey = "#5A5A5A")
#' @rdname halftone_inks
#' @export
halftone_paper <- "#FBFAF5"
#' @rdname halftone_inks
#' @export
halftone_ink <- "#151515"
#' @rdname halftone_inks
#' @export
halftone_widths <- c(single = 89, onehalf = 120, double = 183)
#' @rdname halftone_inks
#' @export
halftone_process <- c(black = "#231F20", red = "#ED1C24", blue = "#2E3192", green = "#00A651", cyan = "#00AEEF", magenta = "#EC008C")   # K, M+Y, C+M, C+Y, C, M at 100 %: one or two plates, no tints, so a 0.3 mm dot survives the press
#' @rdname halftone_inks
#' @export
halftone_ramp <- c("#E7D9B8", "#A8741C", "#8B1A1A", "#3A0A0A")   # paper -> ochre -> red -> near-black (review 1: "best colour figure in the set")
utils::globalVariables(c("x", "y", "z", "n.risk"))
