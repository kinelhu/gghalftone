# halo.R — draw a line or point layer twice: first in paper colour with a hairline extra width, then as is.
# A line crossing a dot field needs this (a step curve over a CI screen, contours over an elevation field); the
# design rule is ~0.08 mm, never wider, or the halo starts to read as a second line.

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
