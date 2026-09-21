#' @import ggplot2 grid
#' @importFrom stats median density approx fft rnorm setNames
#' @importFrom grDevices col2rgb rgb
#' @importFrom Rcpp sourceCpp
#' @useDynLib gghalftone, .registration = TRUE
NULL
`%||%` <- function(a, b) if (is.null(a)) b else a

#' Ink palette, paper colour and journal column widths used by the halftone theme
#' @export
halftone_inks <- c(red = "#8B1A1A", blue = "#1F4E79", ochre = "#A8741C", green = "#2F5D3A", violet = "#5B3A6E", grey = "#5A5A5A")
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
utils::globalVariables(c("x", "y", "z"))
