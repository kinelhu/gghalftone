# plot.R: screen a whole plot in one call. The wrappers in with-halftone.R, halo.R, relief.R and press.R each take a
# plot already, because wrap_layers() walks one. What they cannot do is decide WHICH layer gets which treatment, and
# that decision is the difference between a screened plot and a printed one.

# What a layer is for, from the geom it draws with. Inheritance does the work: GeomBar, GeomCol and GeomTile are all
# GeomRect; GeomArea and GeomDensity are GeomRibbon; GeomLine, GeomStep, GeomContour and GeomFunction are all
# GeomPath. Reference lines are their own geoms (GeomHline, GeomVline, GeomAbline) and so are never haloed, which is
# right: a rule is chart furniture, not data over a screen.
#
# Anything unlisted is left alone. That is the safe default here, because a layer this does not recognise draws
# exactly as it always did. Compare a converter such as ggplotly, which has to reimplement each geom and therefore
# has a support matrix: there, an unknown geom is a wrong figure rather than an unscreened one.
halftone_fillers <- c("GeomRibbon", "GeomRect", "GeomPolygon", "GeomSf", "GeomViolin", "GeomBoxplot", "GeomSmooth",
                      "GeomCrossbar")
halftone_liners  <- c("GeomPath", "GeomSegment")
layer_role <- function(l) {
  g <- l$geom
  w <- g$.halftone_wrapper
  if (!is.null(w)) return(if (identical(w, "with_halftone")) "screened" else "wrapped")
  if (inherits(g, halftone_fillers)) return("fill")
  if (inherits(g, halftone_liners)) return("line")
  "other"
}

#' Screen a whole plot
#'
#' Takes a finished plot and returns it printed: every filled layer screened, a paper hairline under every line that
#' crosses a screen, and the halftone theme modifier on top. One call, where [with_halftone()] and [with_halo()]
#' would otherwise be composed layer by layer.
#'
#' @section What it does to each layer:
#' The treatment follows the geom.
#'
#' * **Screened**: ribbons, areas, densities, bars, columns, histograms, tiles, rectangles, polygons, sf geometries,
#'   violins, boxplots, crossbars and smooths. Each gets the tone profile [with_halftone()] picks for it, so bars and
#'   maps come out flat, intervals follow the likelihood of the estimate, and densities get a soft vignette.
#' * **Haloed**: lines, paths, steps, contours and segments, but only where a screened layer sits underneath them.
#'   A line drawn before any screen has nothing to stay legible against and is left alone.
#' * **Left alone**: points, text, labels, error bars, rugs, reference lines, rasters, and any geom not listed above.
#'
#' A layer you wrapped yourself is left as you wrapped it, so `halftone_plot()` can be applied to a plot that is
#' already part screened, and applying it twice changes nothing the second time.
#'
#' @section What it does not do:
#' It screens the fill and nothing else. Line weights, point shapes and fill colours stay as the plot set them, so a
#' figure built for the screen from the start still looks better: see the package README for the pair. Set
#' `theme = FALSE` to keep your own theme untouched.
#'
#' `geom_raster()` draws an image rather than polygons, so there is nothing to clip a screen to and the layer prints
#' as it was. Use `geom_tile()` instead, or [geom_halftone()] on the field.
#'
#' @param plot A ggplot, or a patchwork of them. The object handed in is left alone.
#' @param halo Width in mm of the paper hairline drawn under lines that cross a screen, the printer's knockout
#'   channel. 0 turns it off.
#' @param theme Add [theme_halftone()]: paper ground, no gridlines under the screen, screen-sized legend keys and the
#'   ink palette. `FALSE` keeps the plot's own theme.
#' @param ... Passed to [with_halftone()] for every layer it screens, for example `pitch`, `shape`, `grid`, `levels`
#'   or `dot_max`.
#' @return The plot, with its layers wrapped.
#' @seealso [with_halftone()] to screen one layer, [with_press()] to print the result.
#' @examples
#' m <- loess(dist ~ speed, cars, span = 0.9)
#' nd <- data.frame(speed = seq(4, 25, length.out = 60))
#' pr <- predict(m, nd, se = TRUE)
#' nd$fit <- pr$fit; nd$lo <- pr$fit - 1.96 * pr$se.fit; nd$hi <- pr$fit + 1.96 * pr$se.fit
#' p <- ggplot2::ggplot(nd, ggplot2::aes(speed)) +
#'   ggplot2::geom_ribbon(ggplot2::aes(ymin = lo, ymax = hi), fill = "steelblue") +
#'   ggplot2::geom_line(ggplot2::aes(y = fit))
#' halftone_plot(p)
#' halftone_plot(p, pitch = 0.6, shape = "line")
#' @export
halftone_plot <- function(plot, halo = 0.09, theme = TRUE, ...) {
  stopifnot(is.numeric(halo), length(halo) == 1L, halo >= 0, is.logical(theme), length(theme) == 1L)
  if (inherits(plot, "patchwork")) {
    if (!is.list(plot$patches$plots))
      stop("cannot reach the plots inside this patchwork; screen them one at a time", call. = FALSE)
    plot$patches$plots <- lapply(plot$patches$plots, function(e)
      if (inherits(e, "ggplot")) halftone_plot(e, halo = halo, theme = theme, ...) else e)
  } else if (!inherits(plot, "ggplot")) {
    stop("halftone_plot() takes a ggplot or a patchwork, but got ", paste(class(plot), collapse = "/"), call. = FALSE)
  }
  plot$layers <- screen_stack(plot$layers, halo = halo, ...)
  if (isTRUE(theme)) plot <- plot + theme_halftone()
  plot
}

# A line is haloed only if a screen is drawn before it: ggplot2 draws layers in order, so "before" is "underneath".
screen_stack <- function(layers, halo, ...) {
  if (!length(layers)) return(layers)
  role <- vapply(layers, layer_role, character(1))
  over_screen <- cumsum(role %in% c("fill", "screened")) > 0
  Map(function(l, r, under) {
    if (identical(r, "fill")) with_halftone(l, ...)
    else if (identical(r, "line") && halo > 0 && under) with_halo(l, width = halo)
    else l
  }, layers, role, c(FALSE, utils::head(over_screen, -1)))
}
