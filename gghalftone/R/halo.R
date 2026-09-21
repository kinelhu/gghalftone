# halo.R — draw a line or point layer twice: first in paper colour with a hairline extra width, then as is.
# A line crossing a dot field needs this (a step curve over a CI screen, contours over an elevation field); the
# design rule is ~0.08 mm, never wider, or the halo starts to read as a second line.

#' Paper halo under a line or point layer
#'
#' Draws the layer twice: first in paper colour with `width` mm added to each side of every stroke, then as is. A
#' line crossing a dot field needs this to stay readable; a step curve over a screened confidence band, contours
#' over an elevation field. Keep it a hairline: 0.08 mm against dots, 0.15 mm against a line screen. Wider and it
#' reads as a second line.
#' @param layer A ggplot2 layer drawing lines, paths, steps, contours or points.
#' @param width Halo width in mm on each side of the stroke.
#' @param colour Halo colour; `NULL` uses white, or the editorial paper colour under
#'   `options(halftone.style = "editorial")`.
#' @return The layer, with its geom replaced by a halo-drawing subclass.
#' @examples
#' ggplot2::ggplot(mtcars, ggplot2::aes(wt, mpg)) + with_halo(ggplot2::geom_line())
#' @export
with_halo <- function(layer, width = 0.08, colour = NULL) {
  parent <- layer$geom
  paper <- colour %||% if (identical(getOption("halftone.style", "journal"), "editorial")) halftone_paper else "white"
  extra <- 2 * width * 96 / 25.4   # grid lwd is in 1/96 inch
  wrapped <- ggproto(NULL, parent,
    draw_panel = function(self, data, panel_params, coord, ...) {
      orig <- ggproto_parent(parent, self)$draw_panel(data, panel_params, coord, ...)
      grobTree(halo_grob(orig, paper, extra), orig)
    })
  layer$geom <- wrapped; layer
}
halo_grob <- function(g, paper, extra) {
  if (inherits(g, "gList")) return(do.call(gList, lapply(g, halo_grob, paper = paper, extra = extra)))
  if (inherits(g, "gTree")) { g$children <- halo_grob(g$children, paper, extra); g$name <- paste0(g$name, ".halo"); return(g) }
  if (inherits(g, "null")) return(g)
  if (is.null(g$gp)) g$gp <- gpar()
  if (!is.null(g$gp$fill)) g$gp$fill <- NA   # stroke only: a filled halo would knock out the field underneath
  g$gp$col <- paper; g$gp$lwd <- (g$gp$lwd %||% 1) + extra; g$name <- paste0(g$name, ".halo")
  g
}
