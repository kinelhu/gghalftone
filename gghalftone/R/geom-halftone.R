# geom_halftone.R: draw-time halftone geom (prototype v3)
#
# geom_halftone(aes(x, y, z = value, colour = value))
#   * input: a gridded field (geom_raster-style: x, y, z), optionally colour/fill/alpha mapped on it
#   * the dot grid is generated at DRAW time in millimetres -> pitch is physical, aspect automatic,
#     screen angle geometrically correct, dot area proportional to tone (true halftone)
#   * colour scales are applied by ggplot2 to the source field; each dot inherits the nearest cell's colour
# params: pitch (mm), angle (deg), grid ("square"/"hex"), levels, algorithm, bayer_n, dot_max (fraction of pitch)


#' Threshold matrices and dithering
#'
#' The threshold matrices behind `levels = k` quantisation. `bayer_matrix()` is the ordered-dither matrix of size
#' `n` (a power of two); `blue_noise_matrix()` is a void-and-cluster matrix (cached, seeded) whose thresholds are evenly
#' spread with no periodic structure. `dither_bayer()` and `dither_blue_noise()` quantise a tone matrix `z` in `[0, 1]`
#' to `levels` steps and dither the remainder with the tiled matrix.
#'
#' Use Bayer for graded tone and blue noise for a binary stipple (`levels = 1`). You rarely need to call these
#' functions directly. Pass `levels` and `algorithm` to [geom_halftone()] or [with_halftone()] instead. By default,
#' tone is continuous and no dithering takes place.
#' @param n Matrix size (Bayer: 2, 4, 8, ...; blue noise: 32 by default).
#' @param sigma Gaussian width, in cells, of the energy filter used to build the blue-noise matrix.
#' @param z Numeric matrix of tone in `[0, 1]`.
#' @param levels Number of quantisation steps.
#' @return A numeric matrix of thresholds in `(0, 1)` (matrices), or a quantised tone matrix (dither functions).
#' @references
#' Bayer, B. E. (1973). An optimum method for two-level rendition of continuous-tone pictures. IEEE International Conference on Communications, 26, 11-15.
#' Floyd, R. W., and Steinberg, L. (1976). An adaptive algorithm for spatial greyscale. Proceedings of the Society for Information Display, 17(2), 75-77.
#' Ulichney, R. (1993). The void-and-cluster method for dither array generation. Proceedings of SPIE, 1913, 332-343. <https://doi.org/10.1117/12.152707>
#' @examples
#' bayer_matrix(2)
#' range(blue_noise_matrix(32))
#' @name dither
NULL
#' @rdname dither
#' @export
bayer_matrix <- function(n = 4) {
  m <- matrix(0, 1, 1)
  while (nrow(m) < n) m <- rbind(cbind(4 * m, 4 * m + 2), cbind(4 * m + 3, 4 * m + 1))
  (m + 0.5) / (n * n)
}
#' @rdname dither
#' @export
blue_noise_matrix <- local({
  cache <- NULL
  function(n = 32, sigma = 1.5) {
    if (!is.null(cache) && nrow(cache) == n) return(cache)
    set.seed(7); N <- n * n
    gauss <- outer(seq_len(n), seq_len(n), function(i, j) { di <- pmin(abs(i - 1), n - abs(i - 1)); dj <- pmin(abs(j - 1), n - abs(j - 1)); exp(-(di^2 + dj^2) / (2 * sigma^2)) })
    G <- fft(gauss)
    energy <- function(b) Re(fft(fft(b) * G, inverse = TRUE)) / N          # toroidal blur of the binary pattern
    b <- matrix(0, n, n); b[sample(N, round(N / 10))] <- 1
    repeat { e <- energy(b); tc <- which.max(ifelse(b == 1, e, -Inf)); b[tc] <- 0; e <- energy(b); lv <- which.min(ifelse(b == 0, e, Inf))
      if (lv == tc) { b[tc] <- 1; break }; b[lv] <- 1 }
    rank <- matrix(NA_real_, n, n); ones <- sum(b); pat <- b
    for (r in seq(ones - 1, 0)) { e <- energy(pat); tc <- which.max(ifelse(pat == 1, e, -Inf)); pat[tc] <- 0; rank[tc] <- r }   # phase 2
    pat <- b
    for (r in seq(ones, N - 1)) { e <- energy(pat); lv <- which.min(ifelse(pat == 0, e, Inf)); pat[lv] <- 1; rank[lv] <- r }  # phase 3 (fills to full)
    cache <<- (rank + 0.5) / N; cache
  }
})
#' @rdname dither
#' @export
dither_blue_noise <- function(z, levels = 1, n = 32) {
  b <- blue_noise_matrix(n); nr <- nrow(z); nc <- ncol(z)
  thr <- b[((seq_len(nr) - 1) %% n) + 1, ((seq_len(nc) - 1) %% n) + 1, drop = FALSE]
  pmin(pmax(floor(z * levels + thr) / levels, 0), 1)
}
#' @rdname dither
#' @export
dither_bayer <- function(z, levels = 1, n = 4) {
  b <- bayer_matrix(n); nr <- nrow(z); nc <- ncol(z)
  thr <- b[((seq_len(nr) - 1) %% n) + 1, ((seq_len(nc) - 1) %% n) + 1, drop = FALSE]
  pmin(pmax(floor(z * levels + thr) / levels, 0), 1)
}
if (TRUE) {
    dither_floyd_steinberg <- function(z, levels = 1) fs_cpp(z, levels)
} else {
  dither_floyd_steinberg <- function(z, levels = 1) {
    nr <- nrow(z); nc <- ncol(z); out <- matrix(0, nr, nc)
    for (i in seq_len(nr)) for (j in seq_len(nc)) {
      old <- z[i, j]; new <- round(old * levels) / levels; out[i, j] <- new; err <- old - new
      if (j < nc) z[i, j + 1] <- z[i, j + 1] + err * 7/16; if (i < nr && j > 1) z[i + 1, j - 1] <- z[i + 1, j - 1] + err * 3/16
      if (i < nr) z[i + 1, j] <- z[i + 1, j] + err * 5/16; if (i < nr && j < nc) z[i + 1, j + 1] <- z[i + 1, j + 1] + err * 1/16
    }
    pmin(pmax(out, 0), 1)
  }
}

# index of the source cell containing each sample point (gridded exact; irregular = Chebyshev NN), NA outside
sample_index <- function(x, y, px, py, cutoff = 0.5) {
  ux <- sort(unique(x)); uy <- sort(unique(y))
  if (as.numeric(length(ux)) * length(uy) == length(x)) {
    idx <- matrix(NA_integer_, length(uy), length(ux)); idx[cbind(match(y, uy), match(x, ux))] <- seq_along(x)
    bx <- if (length(ux) > 1) c(ux[1] - diff(ux)[1] / 2, ux[-1] - diff(ux) / 2, ux[length(ux)] + diff(ux)[length(ux) - 1] / 2) else c(-Inf, Inf)
    by <- if (length(uy) > 1) c(uy[1] - diff(uy)[1] / 2, uy[-1] - diff(uy) / 2, uy[length(uy)] + diff(uy)[length(uy) - 1] / 2) else c(-Inf, Inf)
    ix <- findInterval(px, bx); iy <- findInterval(py, by)
    ok <- ix >= 1 & ix <= length(ux) & iy >= 1 & iy <= length(uy)
    out <- rep(NA_integer_, length(px)); out[ok] <- idx[cbind(iy[ok], ix[ok])]; return(out)
  }
  # irregular / projected: bin source points into cells of ~ typical spacing (panel space), then look up
  n <- length(x); s <- sqrt(diff(range(x)) * diff(range(y)) / n) * 1.2
  bx <- seq(min(x) - s, max(x) + s, by = s); by <- seq(min(y) - s, max(y) + s, by = s)
  cell <- matrix(NA_integer_, length(by), length(bx))
  ix <- findInterval(x, bx); iy <- findInterval(y, by)
  cell[cbind(iy, ix)] <- seq_len(n)                      # last point wins; fine for a lookup
  # fill single-cell holes from 4-neighbours so thin regions don't get pinholes
  # fill pinholes: a cell gets a value only if >= 2 of its 4 neighbours have one (edges stay crisp)
  nb <- vector("list", 4); k <- 0
  for (d in list(c(0, 1), c(0, -1), c(1, 0), c(-1, 0))) {
    sh <- matrix(NA_integer_, nrow(cell), ncol(cell)); r <- seq_len(nrow(cell)); c <- seq_len(ncol(cell))
    rs <- r + d[1]; cs <- c + d[2]; okr <- rs >= 1 & rs <= nrow(cell); okc <- cs >= 1 & cs <= ncol(cell)
    sh[r[okr], c[okc]] <- cell[rs[okr], cs[okc]]; k <- k + 1; nb[[k]] <- sh
  }
  cnt <- Reduce(`+`, lapply(nb, function(m) !is.na(m)))
  fill <- cell; hole <- is.na(cell) & cnt >= 2
  for (m in nb) { take <- hole & is.na(fill) & !is.na(m); fill[take] <- m[take] }
  qx <- findInterval(px, bx); qy <- findInterval(py, by)
  ok <- qx >= 1 & qx < length(bx) & qy >= 1 & qy < length(by)
  out <- rep(NA_integer_, length(px)); out[ok] <- fill[cbind(qy[ok], qx[ok])]; out
}

# tone -> printed tone. levels = NULL (default): continuous, dot area proportional to tone (classic AM halftone, no dither).
# integer levels: quantise to k steps and dither the remainder (bayer / blue_noise / floyd_steinberg) for a stipple look.
quantise_tone <- function(Z, levels = NULL, algorithm = "bayer", bayer_n = 4) {
  if (is.null(levels) || !is.finite(levels) || levels <= 0) return(pmin(pmax(Z, 0), 1))
  switch(algorithm, bayer = dither_bayer(Z, levels, bayer_n), floyd_steinberg = dither_floyd_steinberg(Z, levels), blue_noise = dither_blue_noise(Z, levels))
}
# Default lattice angle: no lattice axis horizontal or vertical. A square screen goes to 45, the classic
# print angle; a hex lattice to 15 for dots, and 45 for a line screen so the strips do not run along the rows.
default_angle <- function(grid, shape) if (identical(grid, "square")) 45 else if (identical(shape, "line")) 45 else 15
tone_floor <- 0.02   # absolute floor; the working floor is the printable minimum feature, see dot_floor()
# smallest tone whose dot (diameter dot_max * pitch * sqrt(tone)) is at least min_feature mm across. Journals ask for
# nothing finer than 0.25 pt (0.09 mm) at final size: below that a dot is a grey pixel on screen and mud on a press.
dot_floor <- function(p) max(tone_floor, (p$min_feature / (p$dot_max * p$pitch))^2)
# Enforce the floor by dithering, not clipping: a cell below the floor is drawn AT the floor with probability tone/floor
# (blue-noise threshold), else not at all. Mean coverage stays equal to tone, no feature is sub-printable, and light
# regions become sparse minimum-size dots or broken hairlines.
floor_dither <- function(D, floor, rows, cols) {
  if (floor <= tone_floor) return(D)
  bn <- blue_noise_matrix(32); low <- D > tone_floor & D < floor
  if (any(low)) { thr <- bn[cbind(((rows[low] - 1) %% 32) + 1, ((cols[low] - 1) %% 32) + 1)]; D[low] <- ifelse(thr < D[low] / floor, floor, 0) }
  D
}
norm01 <- function(z, rng) { if (!is.finite(diff(rng)) || diff(rng) <= 0) return(ifelse(is.na(z), 0, 1)); pmin(pmax((z - rng[1]) / diff(rng), 0), 1) }
halftone_lattice <- function(p, W, H, phase = c(0, 0)) {
  pitch <- p$pitch; px <- pitch; py <- if (p$grid == "hex") pitch * sqrt(3) / 2 else pitch
  L <- max(W, H)
  us <- seq(-0.6 * L, W + 0.6 * L, by = px) + phase[1] * px; vs <- seq(-0.6 * L, H + 0.6 * L, by = py) + phase[2] * py
  U <- matrix(us, length(vs), length(us), byrow = TRUE); V <- matrix(vs, length(vs), length(us))
  if (p$grid == "hex") U <- U + (row(U) %% 2) * px / 2
  a <- p$angle * pi / 180; cx <- W / 2; cy <- H / 2
  X <- cx + (U - cx) * cos(a) - (V - cy) * sin(a); Y <- cy + (U - cx) * sin(a) + (V - cy) * cos(a)
  list(X = X, Y = Y, inside = X >= 0 & X <= W & Y >= 0 & Y <= H)
}
halftone_dither_group <- function(d, lat, p, W, H) {
  idx <- matrix(NA_integer_, nrow(lat$X), ncol(lat$X))
  idx[lat$inside] <- sample_index(d$x, d$y, lat$X[lat$inside] / W, lat$Y[lat$inside] / H)
  Z <- matrix(0, nrow(lat$X), ncol(lat$X)); has <- !is.na(idx); Z[has] <- d$z01[idx[has]]
  D <- quantise_tone(Z, p$levels, p$algorithm, p$bayer_n)
  D[!has] <- 0
  list(D = D, idx = idx)
}
blend_inks <- function(cols, blend = "mix") {   # overprint colour for a cell carrying several inks
  m <- grDevices::col2rgb(cols) / 255
  v <- switch(blend, multiply = apply(m, 1, prod), mix = rowMeans(m) * 0.72)   # mix: average, darkened so overlaps print heavier
  grDevices::rgb(v[1], v[2], v[3])
}

#' @rdname geom_halftone
#' @order 2
#' @param x A `halftone` grob (internal; `makeContent` method).
#' @export
makeContent.halftone <- function(x) {
  d <- x$data; p <- x$params
  W <- convertWidth(unit(1, "npc"), "mm", valueOnly = TRUE); H <- convertHeight(unit(1, "npc"), "mm", valueOnly = TRUE)
  if (!is.null(x$groups)) return(make_overprint(x, W, H))
  pitch <- p$pitch
  lat <- halftone_lattice(p, W, H, phase = p$phase); X <- lat$X; Y <- lat$Y
  r0 <- halftone_dither_group(d, lat, p, W, H); D <- r0$D; idx <- r0$idx
  D <- floor_dither(D, dot_floor(p), row(D), col(D)); keep <- D > tone_floor
  if (!any(keep)) return(setChildren(x, gList()))
  if (p$shape == "line") return(setChildren(x, gList(line_screen_grob(lat, r0, d, p, W, H))))
  r <- p$dot_max * pitch / 2 * sqrt(D[keep])   # dot AREA proportional to tone (print-correct)
  src <- idx[keep]
  col <- scales::alpha(d$colour[src], d$alpha[src])
  xs <- X[keep]; ys <- Y[keep]
  setChildren(x, gList(dot_grob(xs, ys, r, col, p$shape)))
}

# line screen: every lattice row becomes a strip whose width follows the (continuous) tone; rotated with the lattice.
# Z: tone matrix on the lattice; COL: colour matrix (or single colour); on: logical matrix of cells to draw
# Every run is extended by `extend` mm at both ends. Without this the strips stop at the last cell centre inside the
# shape and, on a hex lattice where alternate rows are offset by half a pitch, the ends comb: a white margin with a
# ragged edge inside the outline. A clipped fill extends by a full pitch (the last centre can be anywhere within a pitch
# of the edge; the clip removes the excess); an unclipped field by half a pitch, the cell boundary.
# Strip width is wmax * tone, clamped below to min_feature (the printable minimum, 0.25 pt); cells whose strip would be
# under half of that are not drawn. Light tone therefore shortens strips instead of thinning them.
line_strips_grob <- function(X, Y, Z, COL, on, angle, wmax, extend, min_feature = 0) {
  a <- angle * pi / 180; nx <- -sin(a); ny <- cos(a); ex <- cos(a) * extend; ey <- sin(a) * extend
  zfloor <- max(tone_floor, min_feature / wmax)
  if (zfloor > tone_floor) Z <- floor_dither(Z, zfloor, row(Z), col(Z))   # light tone: broken hairlines, not thinner ones
  polys_x <- list(); polys_y <- list(); cols <- character(0)
  for (i in seq_len(nrow(X))) {
    z <- Z[i, ]; oo <- on[i, ] & z > tone_floor   # after floor_dither, z is 0 or >= zfloor
    if (!any(oo)) next
    runs <- rle(oo); ends <- cumsum(runs$lengths); starts <- ends - runs$lengths + 1
    for (k in which(runs$values)) { s <- starts[k]:ends[k]
      w <- pmax(wmax * z[s], min_feature) / 2; xs <- X[i, s]; ys <- Y[i, s]
      w <- c(w[1], w, w[length(w)]); xs <- c(xs[1] - ex, xs, xs[length(xs)] + ex); ys <- c(ys[1] - ey, ys, ys[length(ys)] + ey)
      polys_x[[length(polys_x) + 1]] <- c(xs + nx * w, rev(xs - nx * w)); polys_y[[length(polys_y) + 1]] <- c(ys + ny * w, rev(ys - ny * w))
      cols <- c(cols, if (is.matrix(COL)) COL[i, s[1]] else COL[1]) }
  }
  if (!length(polys_x)) return(nullGrob())
  polygonGrob(x = unit(unlist(polys_x), "mm"), y = unit(unlist(polys_y), "mm"), id.lengths = lengths(polys_x), gp = gpar(fill = cols, col = NA))
}
line_screen_grob <- function(lat, r0, d, p, W, H) {
  X <- lat$X; Y <- lat$Y; idx <- r0$idx; has <- !is.na(idx)
  Z <- matrix(0, nrow(X), ncol(X)); Z[has] <- d$z01[idx[has]]
  COL <- matrix(NA_character_, nrow(X), ncol(X)); COL[has] <- scales::alpha(d$colour[idx[has]], d$alpha[idx[has]])
  line_strips_grob(X, Y, Z, COL, has, p$angle, p$dot_max * p$pitch * 0.9, p$pitch / 2, p$min_feature)
}

# weave phase for k inks on the hex lattice. k = 3 has an exact 3-colouring (no same-ink neighbours). A triangular
# lattice has no perfect 2-colouring (odd cycles), so for k != 3 inks are assigned by the blue-noise matrix: evenly
# spread, no periodic stripes.
weave_phase <- function(r, c, k) {
  bn <- blue_noise_matrix(32); n <- nrow(bn)
  ifelse(k == 3, (c + 2 * r) %% 3, floor(pmax(k, 1) * bn[cbind(((r - 1) %% n) + 1, ((c - 1) %% n) + 1)]))
}
# dots of a given shape at (x, y) mm with radius r mm. Shapes carry equal ink at a given r: square half-side sqrt(pi)/2 r,
# diamond half-diagonal sqrt(pi/2) r, so a mixed-shape screen stays in one tonal register
sq_k <- sqrt(pi) / 2; di_k <- sqrt(pi / 2)
dot_grob <- function(xs, ys, r, col, shape = "circle") {
  gp <- gpar(fill = col, col = NA)
  switch(shape,
    square  = rectGrob(x = unit(xs, "mm"), y = unit(ys, "mm"), width = unit(2 * r * sq_k, "mm"), height = unit(2 * r * sq_k, "mm"), gp = gp),
    diamond = polygonGrob(x = unit(rep(xs, each = 4) + rep(c(-1, 0, 1, 0), length(xs)) * rep(r, each = 4) * di_k, "mm"),
                          y = unit(rep(ys, each = 4) + rep(c(0, 1, 0, -1), length(xs)) * rep(r, each = 4) * di_k, "mm"), id = rep(seq_along(xs), each = 4), gp = gp),
    circleGrob(x = unit(xs, "mm"), y = unit(ys, "mm"), r = unit(r, "mm"), gp = gp))
}
make_overprint <- function(x, W, H) {
  p <- x$params; gs <- x$groups; pitch <- p$pitch
  lat <- halftone_lattice(p, W, H); X <- lat$X; Y <- lat$Y
  res <- lapply(gs, function(d) halftone_dither_group(d, lat, p, W, H))
  Dmax <- Reduce(pmax, lapply(res, `[[`, "D")); nk <- Reduce(`+`, lapply(res, function(r) r$D > 0))
  Dmax <- floor_dither(Dmax, dot_floor(p), row(Dmax), col(Dmax)); keep <- Dmax > tone_floor
  # colour per cell: single ink, or multiply-blend of all inks present
  cols <- character(sum(keep)); cells <- which(keep)
  colmat <- sapply(seq_along(gs), function(k) { cc <- rep(NA_character_, length(cells)); ok <- res[[k]]$D[cells] > 0
    cc[ok] <- scales::alpha(gs[[k]]$colour[res[[k]]$idx[cells][ok]], gs[[k]]$alpha[res[[k]]$idx[cells][ok]]); cc })
  colmat <- matrix(colmat, ncol = length(gs))
  single <- nk[cells] == 1
  cols[single] <- apply(colmat[single, , drop = FALSE], 1, function(r) r[!is.na(r)][1])
  if (any(!single)) {
    if (p$blend == "alternate") {                    # weave: cell parity picks which of the present inks to print
      par <- weave_phase(row(X)[cells], col(X)[cells], nk[cells])[!single]
      cols[!single] <- mapply(function(i, pr) { r <- colmat[i, ]; r <- r[!is.na(r)]; r[(pr %% length(r)) + 1] }, which(!single), par)
    } else cols[!single] <- apply(colmat[!single, , drop = FALSE], 1, function(r) blend_inks(r[!is.na(r)], p$blend))
  }
  r <- p$dot_max * pitch / 2 * sqrt(Dmax[keep])
  setChildren(x, gList(circleGrob(x = unit(X[keep], "mm"), y = unit(Y[keep], "mm"), r = unit(r, "mm"), gp = gpar(fill = cols, col = NA))))
}

GeomHalftone <- ggproto("GeomHalftone", Geom,
  required_aes = c("x", "y"), optional_aes = c("z", "tone"),
  default_aes = aes(colour = "#8B1A1A", alpha = 1, screen = NA, z = NA, tone = NA),
  draw_key = function(data, params, size) draw_key_halftone(data, params, size),
  draw_panel = function(data, panel_params, coord, pitch = NULL, angle = NULL, grid = "hex",
                        levels = NULL, algorithm = "bayer", bayer_n = 4, dot_max = 0.9, range = NULL,
                        shape = "circle", gamma = 1, overlap = c("stack", "interleave", "overprint"), blend = "mix", tone_max = NULL, min_feature = 0.09) {
    pitch <- pitch %||% 0.35   # 73 lpi (pitch ladder, design_review.md)
    tone_max <- tone_max %||% if (isTRUE(levels == 1)) 0.55 else 1       # a binary stipple must never saturate into the bare lattice
    overlap <- match.arg(overlap); angle_user <- !is.null(angle); angle <- angle %||% default_angle(grid, shape)   # screen specs are absolute unless the user gave an angle offset
    use_tone <- !all(is.na(data$tone))
    if (!use_tone && all(is.na(data$z))) stop("geom_halftone() needs aes(z = ) or aes(tone = ) (through scale_tone_continuous())")
    rng <- if (is.null(range)) range(data$z, na.rm = TRUE) else range
    prep <- function(d) { cc <- coord$transform(d, panel_params)
      t01 <- if (use_tone) pmin(pmax(d$tone, 0), 1) else norm01(d$z, rng); t01[is.na(t01)] <- 0
      cc$z01 <- t01^gamma * tone_max; cc$alpha[is.na(cc$alpha)] <- 1; cc }
    P <- list(pitch = pitch, angle = angle, grid = grid, levels = levels, algorithm = algorithm, bayer_n = bayer_n,
              dot_max = dot_max, shape = shape, phase = c(0, 0), blend = blend, min_feature = min_feature)
    groups <- split(data, data$group)
    has_screen <- !all(is.na(data$screen))
    if (overlap == "overprint" && length(groups) > 1 && !has_screen && shape != "line")
      return(gTree(data = NULL, groups = lapply(groups, prep), params = P, cl = "halftone"))
    ng <- length(groups)
    kids <- lapply(seq_along(groups), function(k) {
      Pk <- P; if (overlap == "interleave" && ng > 1 && !has_screen) Pk$phase <- c((k - 1) / ng, ((k - 1) %% 2) * 0.5)
      dk <- prep(groups[[k]])
      if (has_screen) { sp <- parse_screen(groups[[k]]$screen[1]); Pk$angle <- (if (angle_user) angle else 0) + screen_angle(sp, shape)
        if (!is.null(sp$shape)) Pk$shape <- sp$shape
        dk$z01 <- dk$z01 * sp$tone }   # the spec's third field multiplies TONE: "0.5" is half the ink
      gTree(data = dk, params = Pk, cl = "halftone") })
    do.call(grobTree, kids)
  }
)

#' Halftone screen of a gridded field
#'
#' Draws a gridded field (`x`, `y` and a value) as a halftone. Dots or hatch lines are placed at draw time on a
#' lattice with a physical pitch in millimetres. The area of each dot follows the tone at that point. The screen is
#' the same whether the figure is saved at 89 mm or 183 mm. Colour and fill scales apply to the field as usual, and
#' every dot inherits the colour of the cell it samples.
#'
#' You can give the value in two ways. `aes(z = )` is normalised to `[0, 1]` inside the geom, over `range` or the
#' data range. `aes(tone = )` goes through [scale_tone_continuous()], which adds a legend. Groups that share the panel
#' (through `colour`, `fill` or `group`) are printed on one lattice by default, so every ink stays visible where
#' groups overlap.
#'
#' @section Defaults:
#' A 0.35 mm hex lattice (73 lines per inch) rotated 15 degrees, so that no lattice axis is horizontal or vertical
#' (a square lattice, and any line screen, goes to 45).
#' Continuous tone and circular dots. Coarser pitches print as a dot pattern rather than as tone; 0.6 mm suits a
#' poster. A binary stipple (`levels = 1`) is capped at 55% tone so that the densest region remains a stipple.
#' Set `tone_max` to override.
#'
#' @inheritParams ggplot2::layer
#' @param ... Other arguments passed to [ggplot2::layer()], such as fixed aesthetics (`colour = "black"`).
#' @param pitch Lattice spacing in mm; `NULL` means 0.35. Journal figures want 0.3 to 0.45. Coarser pitches suit posters.
#' @param angle Rotation of the lattice in degrees. `NULL` picks the default: 45 on a square lattice and for line
#'   screens, 15 for hex dots, so that no lattice axis is horizontal or vertical. When `screen` is mapped, the screen
#'   specs are absolute and `angle` (if given) is added to them.
#' @param grid `"hex"` (default) or `"square"`. A 45-degree square lattice is the classic map and photo screen.
#' @param levels `NULL` for continuous tone (dot area follows tone exactly). An integer quantises tone to that many
#'   steps and dithers the remainder with `algorithm`; `levels = 1` is a binary stipple.
#' @param algorithm Dither used when `levels` is set: `"bayer"` (graded tone), `"blue_noise"` (stipple) or
#'   `"floyd_steinberg"` (photographs).
#' @param bayer_n Size of the Bayer matrix when `algorithm = "bayer"`.
#' @param dot_max Diameter of a full-tone dot as a fraction of `pitch` (0.9). Above 1 dots merge; it is the ink weight
#'   of the screen at 100 % tone. For line screens it is the full-tone strip width, as a fraction of pitch.
#' @param range Value range mapped to tone 0..1 when `z` is used; `NULL` uses the data range. A wider range lightens
#'   the screen.
#' @param shape `"circle"`, `"square"`, `"diamond"` (area-matched, so a mixed-shape screen stays in one register) or
#'   `"line"` for a line screen whose strip width follows tone.
#' @param gamma Tone curve: tone is raised to this power before printing. Below 1 lifts mid-tones, above 1 deepens them.
#' @param overlap How groups sharing the panel combine: `"overprint"` (woven on one lattice, default), `"interleave"`
#'   (each group on its own phase-shifted lattice) or `"stack"` (last group drawn wins; hides overlaps).
#' @param blend Colour of a cell carrying several inks under `"overprint"`: `"alternate"` (weave, default), `"mix"`
#'   or `"multiply"`.
#' @param tone_max Tone ceiling in `[0, 1]`. `NULL` means 1, or 0.55 for a binary stipple.
#' @param min_feature Smallest printable feature in mm (0.09, i.e. 0.25 pt, the minimum line weight in journal artwork
#'   guidelines; see References). Dots that would
#'   be smaller are not drawn; hatch strips are never thinner. Set to 0 to disable.
#' @param na.rm Remove missing values silently.
#' @return A ggplot2 layer.
#' @order 1
#' @references
#' Nature Portfolio. Formatting guide: figures. <https://www.nature.com/nature/for-authors/formatting-guide>
#' Elsevier. Artwork and media instructions. <https://www.elsevier.com/about/policies-and-standards/author/artwork-and-media-instructions>
#' @seealso [with_halftone()] to screen the fill of an existing layer, [geom_spot()] for per-point discs,
#'   [scale_screen_discrete()] for colour-free encodings, [with_halo()] for lines drawn over a screen.
#' @examples
#' vol <- data.frame(expand.grid(x = seq_len(ncol(volcano)), y = seq_len(nrow(volcano))), z = as.vector(t(volcano)))
#' ggplot2::ggplot(vol, ggplot2::aes(x, y, z = z)) + geom_halftone() + ggplot2::theme_bw() + theme_halftone()
#' # engraving: a line screen, plus contours with a paper halo
#' ggplot2::ggplot(vol, ggplot2::aes(x, y, z = z)) + geom_halftone(shape = "line", angle = 30) +
#'   with_halo(ggplot2::geom_contour(colour = "black", linewidth = 0.2), width = 0.15) + ggplot2::theme_bw() + theme_halftone()
#' @export
geom_halftone <- function(mapping = NULL, data = NULL, stat = "identity", position = "identity", ...,
                          pitch = NULL, angle = NULL, grid = "hex", levels = NULL, algorithm = "bayer",
                          bayer_n = 4, dot_max = 0.9, range = NULL, shape = "circle", gamma = 1, overlap = "overprint", blend = "alternate", tone_max = NULL, min_feature = 0.09,
                          na.rm = FALSE, show.legend = NA, inherit.aes = TRUE) {
  layer(geom = GeomHalftone, mapping = mapping, data = data, stat = stat, position = position,
        show.legend = show.legend, inherit.aes = inherit.aes,
        params = list(pitch = pitch, angle = angle, grid = grid, levels = levels, algorithm = algorithm,
                      bayer_n = bayer_n, dot_max = dot_max, range = range, shape = shape, gamma = gamma, overlap = overlap, blend = blend, tone_max = tone_max, min_feature = min_feature, na.rm = na.rm, ...))
}

# ---- geom_spot: each point is a disc of radius r (mm) filled with a halftone whose tone is the value ----------------
# tone: aes(tone = ) through scale_tone_continuous() (0..1, with a guide), or aes(z = ) normalised in the geom (no guide).
# Each disc gets its own hex lattice centred on the disc (a symmetric rosette), and the dots are clipped to the disc.
spot_grob <- function(cx, cy, rad, tone, col, pitch, dot_max, ring, ring_lwd, levels = NULL, bayer_n = 4, min_feature = 0.09, angle = 0, shape = "circle") {
  py <- pitch * sqrt(3) / 2; k <- ceiling(rad / pitch) + 1
  us <- seq(-k, k) * pitch; vs <- seq(-k, k) * py
  U <- matrix(us, length(vs), length(us), byrow = TRUE); V <- matrix(vs, length(vs), length(us)); U <- U + (row(U) %% 2) * pitch / 2
  a <- angle * pi / 180; U0 <- U; U <- U0 * cos(a) - V * sin(a); V <- U0 * sin(a) + V * cos(a)   # rotate the rosette
  inside <- U^2 + V^2 <= (rad + pitch / 2)^2
  clipvp <- viewport(clip = circleGrob(x = unit(cx, "mm"), y = unit(cy, "mm"), r = unit(rad, "mm")))
  ringg <- if (ring) circleGrob(x = unit(cx, "mm"), y = unit(cy, "mm"), r = unit(rad, "mm"), gp = gpar(fill = NA, col = col, lwd = ring_lwd)) else NULL
  if (shape == "line") {   # hatched disc: strips along lattice rows, width follows tone, clipped to the disc
    Z <- matrix(0, nrow(U), ncol(U)); Z[inside] <- tone
    strips <- line_strips_grob(cx + U, cy + V, Z, col, inside, angle, dot_max * pitch * 0.9, pitch, min_feature)
    kids <- if (inherits(strips, "null")) gList() else gList(gTree(children = gList(strips), vp = clipvp))
    return(gTree(children = if (is.null(ringg)) kids else gList(kids, ringg))) }
  D <- if (is.null(levels)) rep(tone, sum(inside)) else {
    b <- bayer_matrix(bayer_n); thr <- b[cbind((row(U)[inside] - 1) %% bayer_n + 1, (col(U)[inside] - 1) %% bayer_n + 1)]
    pmin(pmax(floor(tone * levels + thr) / levels, 0), 1) }
  D <- floor_dither(D, max(tone_floor, (min_feature / (dot_max * pitch))^2), row(U)[inside], col(U)[inside]); keep <- D > tone_floor
  kids <- gList()
  if (any(keep)) {
    dots <- dot_grob(cx + U[inside][keep], cy + V[inside][keep], dot_max * pitch / 2 * sqrt(D[keep]), col, shape)
    kids <- gList(gTree(children = gList(dots), vp = clipvp))
  }
  if (!is.null(ringg)) kids <- gList(kids, ringg)
  gTree(children = kids)
}
#' @rdname geom_spot
#' @order 2
#' @param x A `spot` grob (internal; `makeContent` method).
#' @export
makeContent.spot <- function(x) {
  d <- x$data; p <- x$params
  W <- convertWidth(unit(1, "npc"), "mm", valueOnly = TRUE); H <- convertHeight(unit(1, "npc"), "mm", valueOnly = TRUE)
  cx <- d$x * W; cy <- d$y * H; rad <- if (is.null(d$size)) rep(p$r, nrow(d)) else d$size   # size aes = radius (mm)
  kids <- lapply(seq_len(nrow(d)), function(k) { sp <- parse_screen(d$screen[k]); shp <- if (p$shape == "line" && !identical(sp$shape, "line")) "line" else sp$shape %||% p$shape
    spot_grob(cx[k], cy[k], rad[k], d$z01[k] * sp$tone, scales::alpha(d$colour[k], d$alpha[k]), p$pitch, p$dot_max, p$ring, p$ring_lwd, p$levels, p$bayer_n, p$min_feature,
              (if (p$angle_user) p$angle else 0) + screen_angle(sp, shp), shp) })
  setChildren(x, do.call(gList, kids))
}
GeomSpot <- ggproto("GeomSpot", Geom,
  required_aes = c("x", "y"), optional_aes = c("z", "tone"),
  default_aes = aes(colour = "#151515", alpha = 1, size = NA, tone = NA, z = NA, screen = NA),
  draw_key = function(data, params, size) draw_key_spot(data, params, size),
  draw_panel = function(data, panel_params, coord, r = 3, pitch = 0.35, levels = NULL, bayer_n = 4, dot_max = 0.9,
                        range = NULL, ring = TRUE, ring_lwd = 0.3, min_feature = 0.09, angle = NULL, shape = "circle") {
    angle_user <- !is.null(angle); angle <- angle %||% if (shape == "line") 45 else 15
    coords <- coord$transform(data, panel_params)
    if (!all(is.na(data$tone))) coords$z01 <- pmin(pmax(data$tone, 0), 1)
    else if (!all(is.na(data$z))) { rng <- if (is.null(range)) range(data$z, na.rm = TRUE) else range; coords$z01 <- norm01(data$z, rng) }
    else stop("geom_spot() needs aes(tone = ) (through scale_tone_continuous()) or aes(z = )")
    coords$z01[is.na(coords$z01)] <- 0
    coords$alpha[is.na(coords$alpha)] <- 1
    if (all(is.na(coords$size))) coords$size <- NULL
    gTree(data = coords, params = list(r = r, pitch = pitch, levels = levels, bayer_n = bayer_n, dot_max = dot_max, ring = ring, ring_lwd = ring_lwd, min_feature = min_feature, angle = angle, angle_user = angle_user, shape = shape), cl = "spot")
  }
)
#' Tone discs
#'
#' Each point becomes a disc of radius `r` mm (or `aes(size = )`, in mm) filled with a halftone whose tone is the
#' point's value. Use it for a dot plot in which a second quantity is shown by ink density instead of a colour ramp.
#' Each disc has its own centred hex lattice, clipped to the disc, and a ring in the disc's colour.
#'
#' Tone comes from `aes(tone = )` through [scale_tone_continuous()], which gives it a legend of discs at the breaks,
#' or from `aes(z = )` normalised inside the geom.
#'
#' @inheritParams geom_halftone
#' @param r Disc radius in mm when `size` is not mapped.
#' @param pitch Lattice spacing inside the discs, in mm.
#' @param ring Draw the disc outline.
#' @param ring_lwd Line width of the ring.
#' @param angle Rotation of the rosette in degrees; `NULL` means 15 for dots and 45 for hatching. Added to a mapped
#'   `screen` spec's angle only when given.
#' @param shape `"circle"`, `"square"`, `"diamond"` or `"line"` (hatched discs, for one-ink dot plots). `aes(screen = )`
#'   with [scale_screen_discrete()] varies angle and shape per group.
#' @return A ggplot2 layer.
#' @order 1
#' @examples
#' d <- expand.grid(gene = c("A", "B", "C"), cluster = 1:4); d$expr <- runif(12); d$pct <- runif(12)
#' ggplot2::ggplot(d, ggplot2::aes(cluster, gene, tone = expr, size = pct)) + geom_spot() +
#'   scale_tone_continuous() + ggplot2::scale_radius(range = c(1, 2.2)) + ggplot2::theme_minimal() + theme_halftone()
#' @export
geom_spot <- function(mapping = NULL, data = NULL, stat = "identity", position = "identity", ..., r = 3, pitch = 0.35,
                      levels = NULL, bayer_n = 4, dot_max = 0.9, range = NULL, ring = TRUE, ring_lwd = 0.3, min_feature = 0.09, angle = NULL, shape = "circle",
                      na.rm = FALSE, show.legend = NA, inherit.aes = TRUE) {
  layer(geom = GeomSpot, mapping = mapping, data = data, stat = stat, position = position, show.legend = show.legend,
        inherit.aes = inherit.aes, params = list(r = r, pitch = pitch, levels = levels, bayer_n = bayer_n, dot_max = dot_max,
        range = range, ring = ring, ring_lwd = ring_lwd, min_feature = min_feature, angle = angle, shape = shape, na.rm = na.rm, ...))
}
# tone as a real aesthetic: a continuous scale onto [0, 1] (or a narrower range) with a legend of tone discs at the breaks
#' Tone scale
#'
#' Maps a continuous variable to the `tone` aesthetic of [geom_spot()] and [geom_halftone()]: ink density in
#' `[0, 1]`. The legend shows discs (or swatches) at the scale breaks. `scale_tone()` is an alias.
#' @inheritParams ggplot2::continuous_scale
#' @param range Output tone range; narrow it (e.g. `c(0.1, 0.9)`) to keep the lightest value visible.
#' @param ... Passed to [ggplot2::continuous_scale()] (`limits`, `breaks`, `labels`, `trans`, ...).
#' @return A ggplot2 scale.
#' @export
scale_tone_continuous <- function(name = waiver(), ..., range = c(0, 1), guide = "legend") {
  continuous_scale("tone", palette = scales::pal_rescale(range), name = name, guide = guide, ...)
}
#' @rdname scale_tone_continuous
#' @export
scale_tone <- scale_tone_continuous

# ---- legend keys: a small dithered swatch (geom_halftone) / a mid-tone disc (geom_spot) ------------------------
# A legend key is a SAMPLE of the screen: run the real lattice over a key-sized area and draw it with
# the same grobs the panel uses, so pitch, angle, tone, quantisation, dithering and the minimum feature
# all behave identically. Matching the panel by re-deriving its formulas is how the key drifted before:
# the widths agreed while the panel broke its lightest strips at the printable minimum and the key did not.
key_screen_grob <- function(tone, col, pitch, angle, grid, shape, dot_max, min_feature,
                            levels = NULL, bayer_n = 4, algorithm = "bayer", w = 6, h = 4) {
  lat <- halftone_lattice(list(pitch = pitch, grid = grid, angle = angle), w, h)
  Z <- matrix(pmin(pmax(tone, 0), 1), nrow(lat$X), ncol(lat$X))
  Z <- quantise_tone(Z, levels, algorithm, bayer_n)
  g <- if (identical(shape, "line")) {
    line_strips_grob(lat$X, lat$Y, Z, col, lat$inside, angle, dot_max * pitch * 0.9, pitch, min_feature)
  } else {
    D <- floor_dither(Z, max(tone_floor, (min_feature / (dot_max * pitch))^2), row(Z), col(Z))
    keep <- lat$inside & D > tone_floor
    if (any(keep)) dot_grob(lat$X[keep], lat$Y[keep], dot_max * pitch / 2 * sqrt(D[keep]), col, shape) else nullGrob()
  }
  gTree(children = gList(g), vp = viewport(x = 0.5, y = 0.5, width = unit(w, "mm"), height = unit(h, "mm"), clip = "on"))
}

#' Legend keys
#'
#' `draw_key_halftone()` draws a mid-tone dot swatch, or a hatch for line screens, at the layer's screen angle and
#' shape. A hatch key is a sample of the screen itself: strips one lattice row apart at the layer's strip width, so
#' the key reads at the density of the fill whatever the angle. `draw_key_spot()` draws a disc at the break's tone
#' or, for a size legend, at the break's radius. Both are the default keys of the corresponding geoms. They are
#' exported for use with `key_glyph`.
#' @inheritParams ggplot2::draw_key
#' @return A grob.
#' @name draw_key_halftone
#' @export
draw_key_halftone <- function(data, params, size) {
  sp <- parse_screen(data$screen); has_screen <- !is.null(data$screen) && !is.na(data$screen)
  shp <- if (identical(params$shape, "line") && !identical(sp$shape, "line")) "line" else sp$shape %||% params$shape %||% "circle"
  base <- if (has_screen) { if (is.null(params$angle_user)) params$angle %||% 0 else if (params$angle_user) params$angle else 0 } else params$angle %||% 15
  pitch <- params$pitch %||% if (identical(shp, "line")) 0.45 else 0.35
  key_screen_grob(tone = (params$key_tone %||% 0.55) * sp$tone,
                  col = scales::alpha(data$colour %||% "black", data$alpha %||% 1),
                  pitch = pitch, angle = screen_angle(sp, shp) + base, grid = params$grid %||% "hex",
                  shape = shp, dot_max = params$dot_max %||% 0.9, min_feature = params$min_feature %||% 0.09,
                  levels = params$levels, bayer_n = params$bayer_n %||% 4, algorithm = params$algorithm %||% "bayer")
}
# a screen spec is a number (angle) or "angle|shape|tone|line_angle" (shape: circle/square/diamond; tone scales dot_max;
# line_angle is used instead of angle when the screen is drawn as a line screen, so one scale serves both looks)
parse_screen <- function(s) {
  if (is.null(s) || length(s) == 0 || is.na(s[1])) return(list(angle = 0, shape = NULL, tone = 1, line = NULL))
  if (is.numeric(s)) return(list(angle = s[1], shape = NULL, tone = 1, line = NULL))
  parts <- strsplit(as.character(s[1]), "|", fixed = TRUE)[[1]]
  list(angle = as.numeric(parts[1]), shape = if (length(parts) > 1 && nzchar(parts[2])) parts[2] else NULL, tone = if (length(parts) > 2) as.numeric(parts[3]) else 1,
       line = if (length(parts) > 3) as.numeric(parts[4]) else NULL)
}
screen_angle <- function(sp, shape) if (shape == "line" && !is.null(sp$line)) sp$line else sp$angle
screen_recipe <- function(n, period = 60) {   # up to 9 distinct screens; the first three already differ in angle AND shape
  ang <- (if (period == 60) 15 else 45) + c(0, period / 3, 2 * period / 3); shp <- c("circle", "square", "diamond"); tone <- c(1, 1, 1)   # absolute: first screen = the lattice default; shapes are area-matched, so no weight compensation
  order <- c(1, 5, 9, 2, 6, 7, 3, 4, 8)   # (angle, shape) index pairs chosen so consecutive screens differ in both
  grid <- expand.grid(a = seq_along(ang), s = seq_along(shp))[order, ]
  rep_len(paste(ang[grid$a], shp[grid$s], tone[grid$s], line_recipe(9), sep = "|"), n)
}
# hatching angles for line screens: diagonal, counter-diagonal, horizontal, vertical, then the half-steps (absolute degrees)
line_recipe <- function(n) rep_len(c(45, 135, 0, 90, 22.5, 112.5, 67.5, 157.5), n)
# screen scales: map a discrete variable to lattice angles (square lattice repeats every 90°, hex every 60°)
#' Screen scales: colour-free encodings
#'
#' Map a discrete variable to the `screen` aesthetic of [geom_halftone()] and of any layer wrapped in
#' [with_halftone()]. A screen specification is a string `"angle|shape|tone|line_angle"`: the lattice angle in
#' degrees, the dot shape (`circle`, `square`, `diamond`, or `line` to hatch that group), a tone multiplier (`0.5`
#' prints half the ink, which is how an ordinal scale is drawn in one ink), and the
#' hatch angle used when the layer is a line screen. A bare number is an angle. Specifications are absolute. If the
#' layer has an `angle`, it is added.
#'
#' `scale_screen_discrete()` uses a recipe in which consecutive screens differ in both angle and shape: three angles
#' spaced over the lattice period (60 degrees for hex), and hatch angles 45, 135, 0, 90 and so on for line screens.
#' `scale_screen_manual()` takes your own specifications, for example `c("45|line", "135|line", "15|circle")` to
#' mix hatching and dots in one layer. Angle alone distinguishes three screens. For more groups, vary shape and
#' tone, or add a second ink.
#' @inheritParams ggplot2::discrete_scale
#' @param grid Lattice of the layer, which sets the angle period.
#' @param values Character or numeric vector of screen specs, one per level.
#' @param ... Passed to [ggplot2::discrete_scale()].
#' @return A ggplot2 scale.
#' @examples
#' d <- data.frame(g = c("a", "b", "c"), n = c(3, 2, 1))
#' ggplot2::ggplot(d, ggplot2::aes(g, n, screen = g)) +
#'   with_halftone(ggplot2::geom_col(fill = "black", colour = "black"), shape = "line") +
#'   scale_screen_discrete(name = NULL) + ggplot2::theme_classic() + theme_halftone()
#' @export
scale_screen_discrete <- function(..., grid = c("hex", "square"), name = waiver()) {
  grid <- match.arg(grid); period <- if (grid == "hex") 60 else 90
  discrete_scale("screen", "screen_d", palette = function(n) screen_recipe(n, period), name = name, ...)
}
#' @rdname scale_screen_discrete
#' @export
scale_screen_manual <- function(values, ..., name = waiver()) discrete_scale("screen", "screen_m", palette = function(n) values[seq_len(n)], name = name, ...)
#' @rdname draw_key_halftone
#' @export
draw_key_spot <- function(data, params, size) {
  # a tone key shows the disc at the break's tone; a size key shows a mid-tone disc at that radius. The key reports its
  # own size (attr width/height, cm) so labels never sit on the disc.
  rad <- if (is.null(data$size) || is.na(data$size)) min(params$r %||% 3, 2.4) else data$size
  tone <- if (is.null(data$tone) || is.na(data$tone)) 0.55 else data$tone
  sp <- parse_screen(data$screen); shp <- if (identical(params$shape, "line") && !identical(sp$shape, "line")) "line" else sp$shape %||% params$shape %||% "circle"
  ang <- (if (isTRUE(params$angle_user)) params$angle else if (is.null(data$screen) || is.na(data$screen)) params$angle %||% 0 else 0) + screen_angle(sp, shp)
  g <- spot_grob(0, 0, rad, tone * sp$tone, data$colour %||% "black", params$pitch %||% 0.35, params$dot_max %||% 0.9, TRUE, params$ring_lwd %||% 0.3, params$levels, params$bayer_n %||% 4, params$min_feature %||% 0.09, ang, shp)
  key <- gTree(children = gList(g), vp = viewport(x = 0.5, y = 0.5, width = unit(0, "mm"), height = unit(0, "mm"), clip = "off"))
  attr(key, "width") <- attr(key, "height") <- (2 * rad + 1.2) / 10
  key
}
