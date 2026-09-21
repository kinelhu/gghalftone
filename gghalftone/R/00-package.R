#' @keywords internal
"_PACKAGE"

#' @import ggplot2 grid
#' @importFrom stats median density approx fft rnorm setNames
#' @importFrom grDevices col2rgb rgb
#' @importFrom Rcpp sourceCpp
#' @useDynLib gghalftone, .registration = TRUE
NULL
`%||%` <- function(a, b) if (is.null(a)) b else a

#' Inks, paper, ramp and column widths
#'
#' Named constants shared by the geoms and [theme_halftone()]. `halftone_inks` is the six-ink palette that the theme
#' makes the default for mapped colour and fill on ggplot2 >= 4.0 (red, blue, ochre, green, violet, grey);
#' `halftone_ramp` is the default continuous ramp (paper, ochre, red, near-black); `halftone_paper` and `halftone_ink`
#' are the editorial paper and ink colours; `halftone_widths` are journal column widths in mm.
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
halftone_ramp <- c("#E7D9B8", "#A8741C", "#8B1A1A", "#3A0A0A")   # paper -> ochre -> red -> near-black (review 1: "best colour figure in the set")
utils::globalVariables(c("x", "y", "z", "n.risk"))
