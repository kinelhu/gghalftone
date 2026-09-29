# with_halftone.R: halftone the FILL of any ggplot2 layer, at draw time
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

# vectorised weave: for each multi-ink cell (bitmask m over polygons 1..np), pick the (phase+1)-th ink present, where
# phase = weave_phase(row, col, k) mod k and k is the number of inks in the cell
weave_pick <- function(m, r, c, np) {
  B <- vapply(seq_len(np), function(j) bitwAnd(as.integer(m), as.integer(2^(j - 1))) > 0, logical(length(m)))
  B <- matrix(B, ncol = np); k <- rowSums(B); want <- (weave_phase(r, c, k) %% k) + 1
  cum <- B * 0; cum[, 1] <- B[, 1]; if (np > 1) for (j in 2:np) cum[, j] <- cum[, j - 1] + B[, j]
  max.col(B & cum == want, ties.method = "first")
}
# clip region = union of the FILLED shapes only. Building it from the original grob is wrong: an open outline
# polyline (geom_area's upper edge, say) gets implicitly closed and combined even-odd, cutting holes in neighbours.
clip_from_polys <- function(polys) {
  xs <- unlist(lapply(polys, `[[`, "x")); ys <- unlist(lapply(polys, `[[`, "y")); ids <- rep(seq_along(polys), lengths(lapply(polys, `[[`, "x")))
  pathGrob(x = unit(xs, "mm"), y = unit(ys, "mm"), id = ids, rule = "winding", gp = gpar(fill = "black", col = NA))
}
#' @rdname with_halftone
#' @order 2
#' @param x A `halftone_fill` grob (internal; `makeContent` method).
#' @export
makeContent.halftone_fill <- function(x) {
  p <- x$params; W <- convertWidth(unit(1, "npc"), "mm", TRUE); H <- convertHeight(unit(1, "npc"), "mm", TRUE)
  polys <- collect_polys(x$orig)
  polys <- lapply(polys, function(q) { ok <- is.finite(q$x) & is.finite(q$y); q$x <- q$x[ok]; q$y <- q$y[ok]; q })
  polys <- Filter(function(q) !is.na(q$fill) && length(q$x) >= 3, polys)
  # alpha is not printable: fold the fill's alpha (and gp alpha) into tone, and strip it from the ink
  polys <- lapply(polys, function(q) { rgba <- grDevices::col2rgb(q$fill, alpha = TRUE); q$cov <- (rgba[4] / 255) * (q$alpha %||% 1)
    q$fill <- grDevices::rgb(rgba[1], rgba[2], rgba[3], maxColorValue = 255); q$alpha <- 1; q })
  poly_cols <- vapply(polys, function(q) scales::alpha(q$fill, q$alpha), "")   # one colour per polygon, indexed per cell
  lat <- halftone_lattice(p, W, H, phase = press_phase(p$press, p$pitch)); X <- lat$X; Y <- lat$Y; ins <- lat$inside
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
      R <- scan_fill_cpp(rx, ry, q$x, q$y)   # rows = ry, cols = rx; scanline, not per-cell point-in-polygon
      # "vertical" is normalised per column by the kernel, so every column reaches full tone at its own middle.
      # "radial" is normalised over the whole shape, so a narrow arm stays lighter than the body.
      Dn <- if (p$profile == "vertical") dt_col_cpp(R) else { D <- dt_cpp(R) * cellmm; D / max(D, 1e-9) }
      ix <- pmin(pmax(round((X - rx[1]) / cellmm) + 1, 1), length(rx)); iy <- pmin(pmax(round((Y - ry[1]) / cellmm) + 1, 1), length(ry))
      dd <- matrix(Dn[cbind(as.vector(iy), as.vector(ix))], nrow(X))
      # dd in [0,1]: 0 at the edge, 1 on the medial line. "centre" is the gaussian profile that won the KM comparison (soft edge, not a tent)
      # likelihood: the normal density of the estimate across a (1 - alpha) interval, 1 on the estimate, dnorm(z)/dnorm(0) at
      # the limit (0.146 for 95 %). "centre" is the older exp(-2 u^2), within a hair of the same curve.
      zq <- stats::qnorm(1 - (1 - p$level) / 2)
      v <- switch(p$tone, likelihood = exp(-0.5 * (zq * (1 - dd))^2), centre = exp(-2 * (1 - dd)^2), tent = dd, edge = 1 - dd, vignette = 1 - 0.55 * dd, "centre-soft" = sqrt(dd)); v * inp }
    tk <- tk^p$gamma * p$tone_max * q$cov
    owner2[inp & cnt > 0] <- k; owner[inp & cnt == 0] <- k; cnt[inp] <- cnt[inp] + 1L; tone[inp] <- pmax(tone[inp], tk[inp]); mask[inp] <- mask[inp] + 2^(k - 1)
  }
  tone <- press_gain(press_mottle(tone, p$press, X, Y), p$press, press_cover(p$dot_max, p$grid, p$shape))
  if (p$shape == "line") {
    COL <- matrix(NA_character_, nrow(X), ncol(X)); ok <- owner > 0
    COL[ok] <- poly_cols[owner[ok]]
    kids <- gList(line_strips_grob(X, Y, tone, COL, ok, p$angle, p$dot_max * p$pitch * 0.9, if (p$clip) p$pitch else p$pitch / 2, p$min_feature))
    if (p$clip) kids <- gList(gTree(children = kids, vp = viewport(clip = clip_from_polys(polys))))
    if (p$outline) kids <- gList(kids, strip_fill(x$orig)); return(setChildren(x, kids)) }
  Dm <- quantise_tone(tone, p$levels, p$algorithm, p$bayer_n)
  Dm <- floor_dither(Dm, dot_floor(p), row(Dm), col(Dm)); keep <- owner > 0 & Dm > tone_floor
  kids <- gList()
  if (any(keep)) {
    who <- owner[keep]; multi <- cnt[keep] > 1 & p$overlap == "overprint"
    if (p$overlap == "stack") who[cnt[keep] > 1] <- owner2[keep][cnt[keep] > 1]     # last drawn wins (nested intervals, ridgelines)
    if (any(multi)) {
      # woven overprint among ALL inks present: a hex lattice is 3-colourable, so up to three inks interleave with no
      # same-ink neighbours; phase = (col + 2*row) mod k generalises (checkerboard for k = 2)
      ii <- which(keep)[multi]; ri <- row(X)[ii]; ci <- col(X)[ii]
      who[multi] <- weave_pick(mask[ii], ri, ci, length(polys))
    }
    cols <- poly_cols[who]
    r <- p$dot_max * p$pitch / 2 * sqrt(Dm[keep])
    kids <- gList(press_dots(X[keep], Y[keep], r, cols, p$shape, p$pitch, p$press))
  }
  # clip the screen to the exact fill region (grid clipping paths, R >= 4.1; honoured by ragg/cairo/pdf)
  if (p$clip && length(kids)) kids <- gList(gTree(children = kids, vp = viewport(clip = clip_from_polys(polys))))
  if (p$outline) kids <- gList(kids, strip_fill(x$orig))
  setChildren(x, kids)
}

#' Screen the fill of any layer
#'
#' Wraps a ggplot2 layer so that its fill is drawn as a halftone. The wrapped geom draws as usual. At draw time,
#' every filled polygon, rectangle or path in its grob tree is rasterised onto a millimetre lattice, given a tone
#' field derived from its geometry, and drawn as dots or hatch in its fill colour, clipped to the shape. Works with
#' ribbons, areas, bars and columns, densities and violins, polygons, tiles and `geom_sf()`.
#'
#' @section Tone profile:
#' With `tone = NULL`, the profile depends on the geometry:
#' * bars, columns, tiles, areas, polygons and sf: `"flat"`, because for those the interior carries the value;
#' * ribbons (intervals): `"likelihood"`, the normal density of the estimate across the interval: 1 on the
#'   estimate, 0.146 at a 95% limit (`level`);
#' * densities and violins: `"vignette"`, a soft fade towards the outline, so that overlapping groups stay legible;
#' * line screens: always `"flat"`, because a tapered hatch looks like fringe;
#' * a mapped `screen`: always `"flat"`, because it is a categorical pattern.
#'
#' @section Register:
#' `tone_max = NULL` sets one tone ceiling across figure types: flat 0.45 (polygons and sf 0.6), centre 0.6, vignette
#' 0.7, hatching 0.4, hatched intervals a hairline (the strip width that equals `min_feature`). Alpha on the fill is
#' folded into tone: a fill with 30% alpha prints as a 30% screen, and the output holds no partial transparency.
#'
#' @inheritParams geom_halftone
#' @param layer A ggplot2 layer, for example `geom_ribbon(aes(ymin = lo, ymax = hi, fill = g))`; a list holding
#'   one, which is what `geom_sf()` returns; or a whole plot or patchwork, in which case every layer in it is
#'   wrapped and the object handed in is left alone. Screening a whole plot gives a usable figure in one call, but
#'   it screens the fill and nothing else: add [with_halo()] to the lines that cross a screen and
#'   [theme_halftone()] for the paper ground and the ink palette.
#' @param pitch Lattice spacing in mm (0.35, 73 lines per inch). Coarsen deliberately for a poster, or where several hatched groups overlap.
#' @param angle Lattice angle in degrees. `NULL` picks 45 on a square lattice and for hatching, 15 for hex dots.
#' @param tone Tone profile: `NULL` (from the geometry, see below), `"likelihood"`, `"flat"`, `"vignette"`, `"centre"`
#'   (the older gaussian, within a hair of likelihood), `"edge"`, `"tent"` or `"centre-soft"`.
#' @param level Confidence level the ribbon represents, for the `"likelihood"` profile.
#' @param redundant Also give each fill group its own screen (angle and shape), so colour is never the only encoding.
#'   `NULL` means yes for geoms whose groups tile the plane (bars, areas, polygons, tiles, sf) and no for intervals and
#'   densities, whose overlapping groups are woven on one lattice; separate lattices there moire.
#' @param profile Distance used by the non-flat profiles. `"vertical"` measures to the top and bottom edge along each
#'   column and is normalised per column, so every column reaches full tone at its own middle; this is right for
#'   ribbons and densities. `"radial"` measures to the nearest point of the outline and is normalised over the whole
#'   shape, so a narrow arm stays lighter than the body.
#' @param tone_max Tone ceiling; `NULL` picks the register above.
#' @param outline Keep the layer's own outline (with its fill removed) on top of the screen.
#' @param clip Clip the screen to the exact fill region (grid clipping path; ragg, cairo and pdf honour it).
#' @param overlap `"overprint"` weaves all inks present in a cell (default); `"stack"` lets the last-drawn shape win,
#'   for nested intervals and ridgelines.
#' @return The layer, with its geom replaced by a halftone-drawing subclass.
#' @order 1
#' @examples
#' x <- seq(0, 10, length.out = 60)
#' d <- data.frame(x, y = sin(x), lo = sin(x) - 0.5, hi = sin(x) + 0.5)
#' ggplot2::ggplot(d, ggplot2::aes(x)) +
#'   with_halftone(ggplot2::geom_ribbon(ggplot2::aes(ymin = lo, ymax = hi),
#'                                       fill = halftone_inks[["blue"]])) +
#'     with_halo(ggplot2::geom_line(ggplot2::aes(y = y), colour = halftone_inks[["blue"]])) +
#'   ggplot2::theme_classic() + theme_halftone()
#' @export
with_halftone <- function(layer, pitch = 0.35, angle = NULL, grid = "hex", tone = NULL, profile = c("vertical", "radial"),
                          levels = NULL, bayer_n = 4, dot_max = 0.9, gamma = 1, tone_max = NULL, outline = TRUE,
                          shape = "circle", algorithm = "bayer", clip = TRUE, overlap = c("overprint", "stack"), level = 0.95, min_feature = 0.09,
                          redundant = NULL) {
  overlap <- match.arg(overlap); profile <- match.arg(profile)   # match.arg needs this frame's formals, so it runs before the wrapper
  wrap_layers(layer, function(layer) {
  angle_user <- !is.null(angle); angle <- angle %||% default_angle(grid, shape)
  # defaults encode the print rules: line screens are constant weight with a hard edge; outline-defined shapes
  # (densities, violins) are edge-weighted so overlaps stay legible; everything else fades from the centre (gaussian)
  parent0 <- layer$geom; tone_user <- !is.null(tone); tone_max_user <- !is.null(tone_max)
  tone <- tone %||% if (shape == "line") "flat" else if (inherits(parent0, c("GeomDensity", "GeomViolin"))) "vignette" else
    if (inherits(parent0, c("GeomRect", "GeomTile", "GeomArea", "GeomPolygon", "GeomSf"))) "flat" else "likelihood"   # GeomBar/GeomCol inherit GeomRect
  tone <- match.arg(tone, c("likelihood", "centre", "flat", "tent", "edge", "vignette", "centre-soft")); parent <- layer$geom
  # colour is redundant by default where groups tile the plane (bars, areas, polygons, tiles): each group also gets its
  # own screen, so the figure survives greyscale. Not for intervals and densities: there overlapping groups are woven
  # on ONE lattice, and separate lattices at different angles moire (tested; see design_review.md)
  is_flat_geom <- inherits(parent0, c("GeomRect", "GeomTile", "GeomArea", "GeomPolygon", "GeomSf")) && !inherits(parent0, c("GeomDensity", "GeomViolin"))   # GeomDensity inherits GeomArea
  redundant <- redundant %||% is_flat_geom
  # one tonal register. flat: 0.45 (hatch 0.4), but 0.6 for polygons/sf whose fill colour is the value; centre 0.6 so three
  # overprinted intervals stay light; vignette 0.7. Hatched intervals (ribbons) are hairline (0.15): several overlap, and
  # the hatch must sit under the estimate lines, not compete with them
  is_map <- inherits(parent0, c("GeomPolygon", "GeomSf")); is_interval <- inherits(parent0, "GeomRibbon") && !inherits(parent0, "GeomArea")
  hairline <- min_feature / (dot_max * pitch * 0.9)   # the strip width that is exactly the printable minimum
  tone_max <- tone_max %||% switch(tone, flat = if (shape == "line") (if (is_interval) hairline else 0.4) else if (is_map) 0.6 else 0.45, likelihood = 0.6, centre = 0.6, vignette = 0.7, 1)
  if (shape == "line" && tone_max_user && tone_max < hairline) message(sprintf("with_halftone(): hatch strips at tone_max = %.2f would be %.3f mm wide, under the printable minimum (%.2f mm); they are drawn at the minimum", tone_max, tone_max * dot_max * pitch * 0.9, min_feature))
  if (shape == "line" && tone != "flat") message("with_halftone(): line screens usually look better with tone = \"flat\" (hard edge); tapered strokes read as fringe")
  P <- list(pitch = pitch, angle = angle, grid = grid, tone = tone, profile = profile, levels = levels, bayer_n = bayer_n, dot_max = dot_max, gamma = gamma, tone_max = tone_max, outline = outline, shape = shape, algorithm = algorithm, clip = clip, overlap = overlap, level = level, min_feature = min_feature,
            tone_auto = !tone_user, tone_max_auto = !tone_max_user, angle_user = angle_user)
  keymap <- new.env(parent = emptyenv())   # fill colour -> auto screen spec, written at draw time, read by the legend key
  wrapped <- ggproto(NULL, parent,
    .halftone_wrapper = "with_halftone",   # read by halftone_plot(), so a layer wrapped by hand is left as it is
    parameters = keep_parameters(parent),
    default_aes = do.call(aes, c(as.list(parent$default_aes), list(screen = NA))),
    draw_panel = function(self, data, panel_params, coord, ...) {
      if (!is.null(data$screen) && !all(is.na(data$screen))) {          # per-group screen: one halftone_fill per group, own angle
        # a mapped screen is a categorical pattern, and patterns are flat: unless the user chose a tone, drop the profile
        # a screen spec may also switch shape per group ("45|line" beside "15|circle"): dots and hatching in one layer
        kids <- lapply(split(data, data$group), function(d) { sp <- parse_screen(d$screen[1]); Pk <- P
          if (!is.null(sp$shape) && (P$shape != "line" || sp$shape == "line")) Pk$shape <- sp$shape   # a line layer stays hatched unless the spec says "line"
          Pk$angle <- (if (P$angle_user) P$angle else 0) + screen_angle(sp, Pk$shape)
          if (P$tone_auto && P$tone != "flat") { Pk$tone <- "flat"; if (P$tone_max_auto) Pk$tone_max <- 0.45 }
          Pk$tone_max <- Pk$tone_max * sp$tone   # the spec's third field multiplies tone: an ordinal scale in one ink
          gTree(orig = ggproto_parent(parent, self)$draw_panel(d, panel_params, coord, ...), params = Pk, cl = "halftone_fill") })
        return(do.call(grobTree, kids)) }
      groups <- split(data, data$group)
      if (redundant && length(groups) > 1 && !is.null(data$fill) && length(unique(data$fill)) > 1) {
        # auto-redundant screens: the k-th group gets the k-th screen of the recipe; the tone profile is kept
        specs <- screen_recipe(length(groups), if (grid == "hex") 60 else 90)
        kids <- lapply(seq_along(groups), function(k) { d <- groups[[k]]; sp <- parse_screen(specs[k]); Pk <- P
          if (!is.null(sp$shape) && (P$shape != "line" || sp$shape == "line")) Pk$shape <- sp$shape
          Pk$angle <- (if (P$angle_user) P$angle else 0) + screen_angle(sp, Pk$shape)
          assign(as.character(d$fill[1]), specs[k], envir = keymap)
          gTree(orig = ggproto_parent(parent, self)$draw_panel(d, panel_params, coord, ...), params = Pk, cl = "halftone_fill") })
        return(do.call(grobTree, kids)) }
      orig <- ggproto_parent(parent, self)$draw_panel(data, panel_params, coord, ...)
      gTree(orig = orig, params = P, cl = "halftone_fill")
    },
    draw_key = function(data, params, size) { data$colour <- data$fill %||% data$colour
      if ((is.null(data$screen) || is.na(data$screen)) && !is.null(data$fill) && exists(as.character(data$fill), envir = keymap, inherits = FALSE)) data$screen <- get(as.character(data$fill), envir = keymap)
      draw_key_halftone(data, utils::modifyList(params, c(P[c("shape", "angle", "angle_user", "pitch", "dot_max", "grid", "min_feature", "levels", "bayer_n", "algorithm")], list(key_tone = P$tone_max))), size) })
  layer$geom <- wrapped; layer
  })
}
