# with_halftone.R — halftone the FILL of any ggplot2 layer, at draw time
#   with_halftone(geom_area(...)), with_halftone(geom_col(...)), with_halftone(geom_ribbon(...)), with_halftone(geom_density(...)),
#   with_halftone(geom_polygon(...)), with_halftone(geom_sf(...)) ...
# The wrapped geom draws as usual; we walk its grob tree, take every filled polygon/rect/path, rasterise it onto the
# millimetre lattice (point-in-polygon in C++), derive a tone field from the shape (flat / centre / edge, via a
# distance transform), dither, and draw dots in the polygon's own fill colour. The original outline is kept (fill removed).


# Euclidean distance (in cells) from each TRUE cell to the nearest FALSE cell, two-pass (Danielsson-style, good enough)

# per-column 1D distance: for each TRUE cell, distance (cells) to the nearest FALSE cell above or below, normalised by the run's half-length

# collect filled shapes from a grob tree as list(x_mm, y_mm, fill, alpha, id)
collect_polys <- function(gr, vp_stack = NULL) {
  out <- list()
  walk <- function(g) {
    if (inherits(g, "gTree") || inherits(g, "gList")) { kids <- if (inherits(g, "gTree")) g$children else g
      if (inherits(g, "gTree") && !is.null(g$vp)) pushViewport(g$vp)
      for (k in kids) walk(k)
      if (inherits(g, "gTree") && !is.null(g$vp)) upViewport(if (inherits(g$vp, "vpTree")) depth(g$vp) else 1)
      return(invisible()) }
    if (!is.null(g$vp)) pushViewport(g$vp)
    if (inherits(g, "polygon") || inherits(g, "pathgrob") || inherits(g, "rect")) {
      fill <- g$gp$fill; if (is.null(fill)) fill <- NA
      if (inherits(g, "rect")) {
        x <- convertX(g$x, "mm", TRUE); y <- convertY(g$y, "mm", TRUE); w <- convertWidth(g$width, "mm", TRUE); h <- convertHeight(g$height, "mm", TRUE)
        hj <- if (is.character(g$just)) switch(g$just[1], left = 0, right = 1, 0.5) else g$just[1]; vj <- if (length(g$just) > 1) { if (is.character(g$just)) switch(g$just[2], bottom = 0, top = 1, 0.5) else g$just[2] } else 0.5
        if (!is.null(g$hjust)) hj <- g$hjust; if (!is.null(g$vjust)) vj <- g$vjust
        x0 <- x - w * hj; y0 <- y - h * vj; fills <- rep_len(fill, length(x))
        for (i in seq_along(x)) out[[length(out) + 1]] <<- list(x = c(x0[i], x0[i] + w[i], x0[i] + w[i], x0[i]), y = c(y0[i], y0[i], y0[i] + h[i], y0[i] + h[i]), fill = fills[i], alpha = g$gp$alpha %||% 1)
      } else {
        x <- convertX(g$x, "mm", TRUE); y <- convertY(g$y, "mm", TRUE)
        id <- if (!is.null(g$id)) g$id else if (!is.null(g$id.lengths)) rep(seq_along(g$id.lengths), g$id.lengths) else rep(1L, length(x))
        ids <- unique(id); fills <- rep_len(fill, length(ids))
        for (k in seq_along(ids)) { s <- id == ids[k]; out[[length(out) + 1]] <<- list(x = x[s], y = y[s], fill = fills[k], alpha = g$gp$alpha %||% 1) }
      }
    }
    if (!is.null(g$vp)) upViewport(1)
  }
  walk(gr); out
}
strip_fill <- function(g) {   # keep outlines, remove fills, recursively
  if (inherits(g, "gTree")) { g$children <- do.call(gList, lapply(g$children, strip_fill)); return(g) }
  if (inherits(g, c("polygon", "pathgrob", "rect"))) { g$gp$fill <- NA; if (is.null(g$gp$col) || all(is.na(g$gp$col))) g$gp$col <- NA }
  g
}

# clip region = union of the FILLED shapes only. Building it from the original grob is wrong: an open outline
# polyline (geom_area's upper edge, say) gets implicitly closed and combined even-odd, cutting holes in neighbours.
clip_from_polys <- function(polys) {
  xs <- unlist(lapply(polys, `[[`, "x")); ys <- unlist(lapply(polys, `[[`, "y")); ids <- rep(seq_along(polys), lengths(lapply(polys, `[[`, "x")))
  pathGrob(x = unit(xs, "mm"), y = unit(ys, "mm"), id = ids, rule = "winding", gp = gpar(fill = "black", col = NA))
}
#' @export
makeContent.halftone_fill <- function(x) {
  p <- x$params; W <- convertWidth(unit(1, "npc"), "mm", TRUE); H <- convertHeight(unit(1, "npc"), "mm", TRUE)
  polys <- collect_polys(x$orig)
  polys <- lapply(polys, function(q) { ok <- is.finite(q$x) & is.finite(q$y); q$x <- q$x[ok]; q$y <- q$y[ok]; q })
  polys <- Filter(function(q) !is.na(q$fill) && length(q$x) >= 3, polys)
  # alpha is not printable: fold the fill's alpha (and gp alpha) into tone, and strip it from the ink
  polys <- lapply(polys, function(q) { rgba <- grDevices::col2rgb(q$fill, alpha = TRUE); q$cov <- (rgba[4] / 255) * (q$alpha %||% 1)
    q$fill <- grDevices::rgb(rgba[1], rgba[2], rgba[3], maxColorValue = 255); q$alpha <- 1; q })
  lat <- halftone_lattice(p, W, H); X <- lat$X; Y <- lat$Y; ins <- lat$inside
  # per-cell: which polygon (last wins, as in drawing order), tone
  owner <- matrix(0L, nrow(X), ncol(X)); owner2 <- owner; cnt <- owner; tone <- matrix(0, nrow(X), ncol(X))
  mask <- matrix(0, nrow(X), ncol(X))   # bitmask of polygons covering each cell (double: exact to 2^53)
  cellmm <- p$pitch / 2
  for (k in seq_along(polys)) {
    q <- polys[[k]]; bb <- ins & X >= min(q$x) - 1 & X <= max(q$x) + 1 & Y >= min(q$y) - 1 & Y <= max(q$y) + 1
    if (!any(bb)) next
    inp <- bb; inp[bb] <- pip_cpp(X[bb], Y[bb], q$x, q$y)
    if (!any(inp)) next
    tk <- if (p$tone == "flat") inp * 1 else {
      # distance transform on a fine raster of the polygon, then sample at lattice points
      rx <- seq(min(q$x) - cellmm, max(q$x) + cellmm, by = cellmm); ry <- seq(min(q$y) - cellmm, max(q$y) + cellmm, by = cellmm)
      R <- matrix(pip_cpp(rep(rx, each = length(ry)), rep(ry, times = length(rx)), q$x, q$y), length(ry), length(rx))
      if (p$profile == "vertical") Dn <- dt_col_cpp(R) else {
        D <- dt_cpp(R) * cellmm
        norm <- if (p$local && p$profile == "vertical") matrix(pmax(apply(D, 2, max), 1e-9), nrow(D), ncol(D), byrow = TRUE) else max(D, 1e-9)
        Dn <- D / norm }
      ix <- pmin(pmax(round((X - rx[1]) / cellmm) + 1, 1), length(rx)); iy <- pmin(pmax(round((Y - ry[1]) / cellmm) + 1, 1), length(ry))
      dd <- matrix(Dn[cbind(as.vector(iy), as.vector(ix))], nrow(X))
      # dd in [0,1]: 0 at the edge, 1 on the medial line. "centre" is the gaussian profile that won the KM comparison (soft edge, not a tent)
      v <- switch(p$tone, centre = exp(-2 * (1 - dd)^2), tent = dd, edge = 1 - dd, vignette = 1 - 0.55 * dd, "centre-soft" = sqrt(dd)); v * inp }
    tk <- tk^p$gamma * p$tone_max * q$cov
    owner2[inp & cnt > 0] <- k; owner[inp & cnt == 0] <- k; cnt[inp] <- cnt[inp] + 1L; tone[inp] <- pmax(tone[inp], tk[inp]); mask[inp] <- mask[inp] + 2^(k - 1)
  }
  if (p$shape == "line") {
    COL <- matrix(NA_character_, nrow(X), ncol(X)); ok <- owner > 0
    COL[ok] <- vapply(owner[ok], function(k) scales::alpha(polys[[k]]$fill, polys[[k]]$alpha), "")
    kids <- gList(line_strips_grob(X, Y, tone, COL, ok, p$angle, p$dot_max * p$pitch * 0.9))
    if (p$clip) kids <- gList(gTree(children = kids, vp = viewport(clip = clip_from_polys(polys))))
    if (p$outline) kids <- gList(kids, strip_fill(x$orig)); return(setChildren(x, kids)) }
  Dm <- quantise_tone(tone, p$levels, p$algorithm, p$bayer_n)
  keep <- owner > 0 & Dm > tone_floor
  kids <- gList()
  if (any(keep)) {
    who <- owner[keep]; multi <- cnt[keep] > 1 & p$overlap == "overprint"
    if (p$overlap == "stack") who[cnt[keep] > 1] <- owner2[keep][cnt[keep] > 1]     # last drawn wins (nested intervals, ridgelines)
    if (any(multi)) {
      # woven overprint among ALL inks present: a hex lattice is 3-colourable, so up to three inks interleave with no
      # same-ink neighbours; phase = (col + 2*row) mod k generalises (checkerboard for k = 2)
      ii <- which(keep)[multi]; ri <- row(X)[ii]; ci <- col(X)[ii]
      who[multi] <- mapply(function(m, r, c) { ks <- which(bitwAnd(as.integer(m), 2^(0:30)) > 0); k <- length(ks); ks[(weave_phase(r, c, k) %% k) + 1] }, mask[ii], ri, ci)
    }
    cols <- vapply(who, function(k) scales::alpha(polys[[k]]$fill, polys[[k]]$alpha), "")
    r <- p$dot_max * p$pitch / 2 * (if (p$size_map == "area") sqrt(Dm[keep]) else Dm[keep]) * (1 + p$gain * Dm[keep])
    kids <- gList(dot_grob(X[keep], Y[keep], r, cols, p$shape))
  }
  # clip the screen to the exact fill region (grid clipping paths, R >= 4.1; honoured by ragg/cairo/pdf)
  if (p$clip && length(kids)) kids <- gList(gTree(children = kids, vp = viewport(clip = clip_from_polys(polys))))
  if (p$outline) kids <- gList(kids, strip_fill(x$orig))
  setChildren(x, kids)
}

#' @export
with_halftone <- function(layer, pitch = 0.6, angle = NULL, grid = "hex", tone = NULL, profile = c("vertical", "radial"), local = TRUE,
                          levels = NULL, bayer_n = 4, dot_max = 0.9, size_map = "area", gamma = 1, tone_max = NULL, outline = TRUE,
                          shape = "circle", algorithm = "bayer", clip = TRUE, overlap = c("overprint", "stack"), gain = 0) {
  overlap <- match.arg(overlap)
  angle_user <- !is.null(angle); angle <- angle %||% if (shape == "line") 45 else 15   # hatching at 45; dots on a hex lattice at 15 so no lattice axis is horizontal or vertical
  # defaults encode the print rules: line screens are constant weight with a hard edge; outline-defined shapes
  # (densities, violins) are edge-weighted so overlaps stay legible; everything else fades from the centre (gaussian)
  parent0 <- layer$geom; tone_user <- !is.null(tone); tone_max_user <- !is.null(tone_max)
  tone <- tone %||% if (shape == "line") "flat" else if (inherits(parent0, c("GeomDensity", "GeomViolin"))) "vignette" else
    if (inherits(parent0, c("GeomRect", "GeomTile", "GeomArea", "GeomPolygon", "GeomSf"))) "flat" else "centre"   # GeomBar/GeomCol inherit GeomRect
  tone <- match.arg(tone, c("centre", "flat", "tent", "edge", "vignette", "centre-soft")); profile <- match.arg(profile); parent <- layer$geom
  # one tonal register. flat: 0.45 (hatch 0.4), but 0.6 for polygons/sf whose fill colour is the value; centre 0.6 so three
  # overprinted intervals stay light; vignette 0.7. Hatched intervals (ribbons) are hairline (0.15): several overlap, and
  # the hatch must sit under the estimate lines, not compete with them
  is_map <- inherits(parent0, c("GeomPolygon", "GeomSf")); is_interval <- inherits(parent0, "GeomRibbon") && !inherits(parent0, "GeomArea")
  tone_max <- tone_max %||% switch(tone, flat = if (shape == "line") (if (is_interval) 0.15 else 0.4) else if (is_map) 0.6 else 0.45, centre = 0.6, vignette = 0.7, 1)
  if (shape == "line" && tone != "flat") message("with_halftone(): line screens usually look better with tone = \"flat\" (hard edge); tapered strokes read as fringe")
  P <- list(pitch = pitch, angle = angle, grid = grid, tone = tone, profile = profile, local = local, levels = levels, bayer_n = bayer_n, dot_max = dot_max, size_map = size_map, gamma = gamma, tone_max = tone_max, outline = outline, shape = shape, algorithm = algorithm, clip = clip, overlap = overlap, gain = gain,
            tone_auto = !tone_user, tone_max_auto = !tone_max_user, angle_user = angle_user)
  wrapped <- ggproto(NULL, parent,
    default_aes = do.call(aes, c(as.list(parent$default_aes), list(screen = NA))),
    draw_panel = function(self, data, panel_params, coord, ...) {
      if (!is.null(data$screen) && !all(is.na(data$screen))) {          # per-group screen: one halftone_fill per group, own angle
        # a mapped screen is a categorical pattern, and patterns are flat: unless the user chose a tone, drop the profile
        # a screen spec may also switch shape per group ("45|line" beside "15|circle"): dots and hatching in one layer
        kids <- lapply(split(data, data$group), function(d) { sp <- parse_screen(d$screen[1]); Pk <- P
          if (!is.null(sp$shape)) Pk$shape <- sp$shape
          Pk$angle <- (if (P$angle_user) P$angle else 0) + screen_angle(sp, Pk$shape)
          if (P$tone_auto && P$tone != "flat") { Pk$tone <- "flat"; if (P$tone_max_auto) Pk$tone_max <- 0.45 }
          gTree(orig = ggproto_parent(parent, self)$draw_panel(d, panel_params, coord, ...), params = Pk, cl = "halftone_fill") })
        return(do.call(grobTree, kids)) }
      orig <- ggproto_parent(parent, self)$draw_panel(data, panel_params, coord, ...)
      gTree(orig = orig, params = P, cl = "halftone_fill")
    },
    draw_key = function(data, params, size) { data$colour <- data$fill %||% data$colour; draw_key_halftone(data, utils::modifyList(params, P[c("shape", "angle", "angle_user")]), size) })
  layer$geom <- wrapped; layer
}
