# halftone_helpers.R: turn common statistical objects into fields for geom_halftone()

# estimate +/- interval -> field. profile: "tent" (1 on estimate -> 0 at edges), "flat" (1 inside), "gauss"
#' Fields from statistical objects
#'
#' Helpers that turn common objects into gridded fields (`x`, `y`, `z`) for [geom_halftone()]. Most figures do not
#' need them, because [with_halftone()] screens the fill of a ribbon, area, bar or polygon layer directly. Use them
#' when the tone field is computed rather than drawn: an estimate with a tent or gaussian profile
#' (`halftone_band()`), bars that fade towards the axis (`halftone_bars()`), map regions rasterised by
#' point-in-region lookup (`halftone_regions()`, requires the maps package), or ridgelines (`halftone_ridges()`).
#' @param x,est,lo,hi Positions, estimate and interval limits.
#' @param ny,nx Field resolution.
#' @param profile Tone profile across the band.
#' @param ylim,keep Vertical extent, and extra columns (one row per `x`) carried into the field.
#' @param cat,height,width,fade,extra Bar categories, heights, width, tone at the base, extra columns.
#' @param db,values,res,... Map database, named values per region, cell size in degrees, arguments to `maps::map()`.
#' @param groups,scale,n,bw Ridgeline groups, height scale, resolution, bandwidth for `stats::density()`.
#' @return A data frame (`halftone_ridges()`: a list of `fields`, `lines`, `levels`).
#' @name halftone_fields
NULL
#' @rdname halftone_fields
#' @export
halftone_band <- function(x, est, lo, hi, ny = 250, profile = c("tent", "gauss", "flat"), ylim = NULL, keep = NULL) {
  profile <- match.arg(profile)
  if (is.null(ylim)) ylim <- range(c(lo, hi), na.rm = TRUE)
  ys <- seq(ylim[1], ylim[2], length.out = ny)
  g <- expand.grid(x = x, y = ys); i <- match(g$x, x)
  half <- pmax(hi[i] - lo[i], 1e-9) / 2; mid <- (hi[i] + lo[i]) / 2; u <- abs(g$y - mid) / half
  g$z <- switch(profile, tent = pmax(0, 1 - u), flat = as.numeric(u <= 1), gauss = exp(-2 * u^2) * (u <= 1.5))
  if (!is.null(keep)) g <- cbind(g, keep[i, , drop = FALSE])
  g
}

# bars -> field. Each bar is a rectangle; z falls from 1 at the top of the bar to `base` at the axis (or flat)
#' @rdname halftone_fields
#' @export
halftone_bars <- function(cat, height, width = 0.8, nx = 25, ny = 120, fade = 0.35, extra = NULL) {
  do.call(rbind, lapply(seq_along(cat), function(k) {
    g <- expand.grid(x = k + seq(-width / 2, width / 2, length.out = nx), y = seq(0, height[k], length.out = ny))
    g$z <- fade + (1 - fade) * (g$y / height[k]); g$cat <- cat[k]
    if (!is.null(extra)) g <- cbind(g, extra[k, , drop = FALSE]); g }))
}

# region polygons (maps::map) + values -> field (rasterise by point-in-region lookup)
#' @rdname halftone_fields
#' @export
halftone_regions <- function(db = "state", values, res = 0.25, ...) {
  if (!requireNamespace("maps", quietly = TRUE)) stop("halftone_regions() needs the maps package")
  m <- maps::map(db, plot = FALSE, ...)
  g <- expand.grid(x = seq(m$range[1], m$range[2], by = res), y = seq(m$range[3], m$range[4], by = res))
  g$region <- maps::map.where(db, g$x, g$y)
  g$region <- sub(":.*$", "", g$region)
  g <- g[!is.na(g$region), ]
  g$z <- values[g$region]; g[!is.na(g$z), ]
}

#' Ink palette scales
#'
#' Manual colour and fill scales over [halftone_inks]. On ggplot2 4.0 and later, [theme_halftone()] sets the inks as
#' the default palette. Use these scales with older ggplot2 versions or without the theme.
#' @param ... Passed to [ggplot2::scale_colour_manual()] / [ggplot2::scale_fill_manual()].
#' @return A ggplot2 scale.
#' @name scale_halftone
#' @export
scale_colour_halftone <- function(...) scale_colour_manual(values = unname(halftone_inks), ...)
#' @rdname scale_halftone
#' @export
scale_fill_halftone <- function(...) scale_fill_manual(values = unname(halftone_inks), ...)

# RGB field (from halftone_raster) -> list of four CMYK fields; classic screen angles C15 M75 Y0 K45
#' Four-colour process screens
#'
#' `halftone_cmyk()` separates an RGB field (from [halftone_raster()]) into cyan, magenta, yellow and black tone
#' fields; `geom_halftone_cmyk()` returns the four [geom_halftone()] layers at the classic screen angles (C 15, M 75,
#' Y 0, K 45) in process inks.
#' @param field A field with `r`, `g`, `b` columns in `[0, 1]`.
#' @param pitch,levels,alpha,... Passed to [geom_halftone()].
#' @return A list of four fields, or a list of four layers to add to a plot.
#' @name cmyk
#' @export
halftone_cmyk <- function(field) {
  k <- 1 - pmax(field$r, field$g, field$b)
  den <- pmax(1 - k, 1e-9)
  list(C = transform(field, z = (1 - field$r - k) / den), M = transform(field, z = (1 - field$g - k) / den),
       Y = transform(field, z = (1 - field$b - k) / den), K = transform(field, z = k))
}
cmyk_inks <- c(C = "#00AEEF", M = "#EC008C", Y = "#FFF100", K = "#231F20"); cmyk_angles <- c(C = 15, M = 75, Y = 0, K = 45)
#' @rdname cmyk
#' @export
geom_halftone_cmyk <- function(field, pitch = 1, levels = 6, alpha = 0.85, ...) {
  f <- halftone_cmyk(field)
  lapply(c("Y", "C", "M", "K"), function(ch) geom_halftone(data = f[[ch]], aes(x, y, z = z), pitch = pitch, angle = cmyk_angles[[ch]],
         levels = levels, colour = cmyk_inks[[ch]], alpha = alpha, range = c(0, 1), dot_max = 1, ...))
}

# ridgelines: list of densities -> stacked fields + outlines
#' @rdname halftone_fields
#' @export
halftone_ridges <- function(values, groups, scale = 1.6, n = 256, fade = 0.35, bw = "nrd0") {
  lev <- if (is.factor(groups)) levels(groups) else unique(groups)
  dens <- lapply(lev, function(g) density(values[groups == g], n = n, bw = bw))
  xs <- seq(min(sapply(dens, function(d) min(d$x))), max(sapply(dens, function(d) max(d$x))), length.out = n)
  maxd <- max(sapply(dens, function(d) max(d$y)))
  fields <- lines <- vector("list", length(lev))
  for (i in seq_along(lev)) {
    yy <- approx(dens[[i]]$x, dens[[i]]$y, xs, rule = 2)$y / maxd * scale; base <- i
    g <- expand.grid(x = xs, y = seq(base, base + scale, length.out = 90)); top <- base + yy[match(g$x, xs)]
    g$z <- ifelse(g$y <= top, fade + (1 - fade) * (g$y - base) / pmax(top - base, 1e-9), 0); g$group <- lev[i]
    fields[[i]] <- g; lines[[i]] <- data.frame(x = xs, y = base + yy, group = lev[i])
  }
  list(fields = fields, lines = lines, levels = lev)
}
