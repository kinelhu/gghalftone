# relief.R: illuminated contours (Tanaka, 1950). Each contour segment is lit or shaded by the angle between the slope
# it stands on and a light from `light` degrees (azimuth, clockwise from north; 315 = upper left, the cartographic
# convention). Lit segments print in paper, shaded ones in ink, and both widen as the slope faces the light. Flanks
# parallel to the light carry only the hairline base. Over a line-screen or dot field the paper segments cut through
# the screen. The original was printed from two plates, one for the lit contours and one for the shaded.

#' Illuminated contours
#'
#' Wraps a contour layer, or any path layer, so that each segment is lit or shaded according to the direction of
#' its slope relative to a light source. This is Kitiro Tanaka's illuminated-contour method. Lit segments are drawn
#' in paper colour and shaded segments in ink. Both widen as the slope faces the light more directly. A hairline base
#' contour is drawn under both. Over a [geom_halftone()] field or a hatched engraving, the paper segments cut through
#' the screen and the surface appears in relief.
#'
#' With `uphill = "auto"`, the uphill side of each contour is inferred from the nearest neighbouring contour at
#' another level. A closed ring with no such neighbour is treated as a summit. For a path that is not a contour, set
#' `uphill` explicitly.
#'
#' Draw this over a screened field. Lit segments are paper-coloured, so on bare paper they are invisible and only the
#' shaded half of each contour appears.
#' @param layer A `geom_contour()`, `geom_path()` or `geom_line()` layer, or a list holding one.
#' @param light Azimuth of the light in degrees, clockwise from north; 315 is upper left.
#' @param width Line width in mm at grazing and at full illumination, `c(min, max)`.
#' @param colours Named vector: `lit` (the paper colour of the plot), `shade` (ink), `base` (the hairline contour
#'   under both; `NA` for none).
#' @param uphill `"auto"`, `"left"` or `"right"` of the path direction.
#' @return The layer, with its geom replaced by a relief-drawing subclass.
#' @references
#' Tanaka, K. (1950). The relief contour method of representing topography on maps. Geographical Review, 40(3), 444-456. <https://doi.org/10.2307/211219>
#' @examples
#' vol <- data.frame(expand.grid(x = seq_len(ncol(volcano)), y = seq_len(nrow(volcano))), z = as.vector(t(volcano)))
#' ggplot2::ggplot(vol, ggplot2::aes(x, y, z = z)) + geom_halftone(shape = "line", colour = "black", angle = 30) +
#'   with_relief(ggplot2::geom_contour(bins = 10)) + ggplot2::coord_equal(expand = FALSE) + ggplot2::theme_bw() + theme_halftone()
#' @export
with_relief <- function(layer, light = 315, width = c(0.05, 0.35), colours = c(lit = "white", shade = "black", base = "#8A8A8A"), uphill = c("auto", "left", "right")) {
  uphill <- match.arg(uphill)
  wrap_layers(layer, function(layer) {
  parent <- layer$geom
  P <- list(light = light, width = width, colours = colours, uphill = uphill)
  wrapped <- ggproto(NULL, parent,
    parameters = keep_parameters(parent),
    draw_panel = function(self, data, panel_params, coord, ...) {
      cc <- coord$transform(data, panel_params)
      keep <- intersect(c("x", "y", "group", "level", "PANEL"), names(cc))
      gTree(data = cc[order(cc$group), keep], params = P, cl = "relief")
    })
  layer$geom <- wrapped; layer
  })
}

#' @rdname with_relief
#' @param x A `relief` grob (internal; `makeContent` method).
#' @export
makeContent.relief <- function(x) {
  d <- x$data; p <- x$params
  W <- convertWidth(unit(1, "npc"), "mm", valueOnly = TRUE); H <- convertHeight(unit(1, "npc"), "mm", valueOnly = TRUE)
  d$x <- d$x * W; d$y <- d$y * H
  groups <- split(d, d$group); groups <- Filter(function(g) nrow(g) >= 2, groups)
  if (!length(groups)) return(setChildren(x, gList()))
  has_level <- "level" %in% names(d)
  segs <- lapply(groups, function(g) { n <- nrow(g); data.frame(x0 = g$x[-n], y0 = g$y[-n], x1 = g$x[-1], y1 = g$y[-1], level = if (has_level) g$level[1] else NA_real_, group = g$group[1]) })
  segs <- do.call(rbind, segs)
  dx <- segs$x1 - segs$x0; dy <- segs$y1 - segs$y0; L <- sqrt(dx^2 + dy^2); ok <- L > 1e-9
  segs <- segs[ok, ]; dx <- dx[ok]; dy <- dy[ok]; L <- L[ok]
  nx <- -dy / L; ny <- dx / L                                  # left normal of the path direction
  up_left <- switch(p$uphill, left = rep(TRUE, nrow(segs)), right = rep(FALSE, nrow(segs)), auto = uphill_left(segs, d, has_level, nx, ny))
  ux <- ifelse(up_left, nx, -nx); uy <- ifelse(up_left, ny, -ny)   # uphill normal
  az <- p$light * pi / 180; lx <- sin(az); ly <- cos(az)          # unit vector towards the light
  illum <- -(ux * lx + uy * ly)                                    # downhill faces the light: lit
  w <- p$width[1] + (p$width[2] - p$width[1]) * abs(illum)
  lwd <- function(mm) mm * 96 / 25.4
  kids <- gList()
  if (!is.na(p$colours[["base"]]))
    kids <- gList(kids, segmentsGrob(unit(segs$x0, "mm"), unit(segs$y0, "mm"), unit(segs$x1, "mm"), unit(segs$y1, "mm"), gp = gpar(col = p$colours[["base"]], lwd = lwd(p$width[1]), lineend = "round")))
  col <- ifelse(illum > 0, p$colours[["lit"]], p$colours[["shade"]])
  draw <- abs(illum) > 0.05
  if (any(draw))
    kids <- gList(kids, segmentsGrob(unit(segs$x0[draw], "mm"), unit(segs$y0[draw], "mm"), unit(segs$x1[draw], "mm"), unit(segs$y1[draw], "mm"),
                                     gp = gpar(col = col[draw], lwd = lwd(w[draw]), lineend = "round")))
  setChildren(x, kids)
}
# per line: is uphill on the left of the path direction? Vote over the line's segments using the nearest point on any
# contour at a different level; a line with no such neighbour is a closed ring around a summit (uphill inside) or,
# failing that, left.
uphill_left <- function(segs, d, has_level, nx, ny) {
  out <- rep(TRUE, nrow(segs))
  for (g in unique(segs$group)) {
    i <- which(segs$group == g); lev <- segs$level[i[1]]
    q <- if (has_level) d[d$level != lev & !is.na(d$level), ] else d[0, ]
    if (nrow(q)) {
      mx <- (segs$x0[i] + segs$x1[i]) / 2; my <- (segs$y0[i] + segs$y1[i]) / 2
      # nearest other-level point per midpoint (chunked distance matrix; contours are a few hundred points)
      j <- vapply(seq_along(mx), function(k) which.min((q$x - mx[k])^2 + (q$y - my[k])^2), 1L)
      side <- (q$x[j] - mx) * nx[i] + (q$y[j] - my) * ny[i]         # > 0: neighbour on the left
      votes <- (q$level[j] > lev) == (side > 0)                     # higher neighbour on the left => uphill left
      out[i] <- mean(votes) >= 0.5
    } else {
      pts <- d[d$group == g, ]; n <- nrow(pts)
      closed <- n > 3 && abs(pts$x[1] - pts$x[n]) < 1e-6 && abs(pts$y[1] - pts$y[n]) < 1e-6
      if (closed) { area <- sum(pts$x[-n] * pts$y[-1] - pts$x[-1] * pts$y[-n]) / 2; out[i] <- area > 0 }   # CCW: interior on the left
    }
  }
  out
}
