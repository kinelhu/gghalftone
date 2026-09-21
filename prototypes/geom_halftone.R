# geom_halftone.R — draw-time halftone geom (prototype v3)
#
# geom_halftone(aes(x, y, z = value, colour = value))
#   * input: a gridded field (geom_raster-style: x, y, z), optionally colour/fill/alpha mapped on it
#   * the dot grid is generated at DRAW time in millimetres -> pitch is physical, aspect automatic,
#     screen angle geometrically correct, dot area proportional to tone (true halftone)
#   * colour scales are applied by ggplot2 to the source field; each dot inherits the nearest cell's colour
# params: pitch (mm), angle (deg), grid ("square"/"hex"), levels, algorithm, bayer_n, dot_max (fraction of pitch)

library(ggplot2); library(grid)

bayer_matrix <- function(n = 4) {
  m <- matrix(0, 1, 1)
  while (nrow(m) < n) m <- rbind(cbind(4 * m, 4 * m + 2), cbind(4 * m + 3, 4 * m + 1))
  (m + 0.5) / (n * n)
}
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
dither_blue_noise <- function(z, levels = 1, n = 32) {
  b <- blue_noise_matrix(n); nr <- nrow(z); nc <- ncol(z)
  thr <- b[((seq_len(nr) - 1) %% n) + 1, ((seq_len(nc) - 1) %% n) + 1, drop = FALSE]
  pmin(pmax(floor(z * levels + thr) / levels, 0), 1)
}
dither_bayer <- function(z, levels = 1, n = 4) {
  b <- bayer_matrix(n); nr <- nrow(z); nc <- ncol(z)
  thr <- b[((seq_len(nr) - 1) %% n) + 1, ((seq_len(nc) - 1) %% n) + 1, drop = FALSE]
  pmin(pmax(floor(z * levels + thr) / levels, 0), 1)
}
if (requireNamespace("Rcpp", quietly = TRUE)) {
  Rcpp::cppFunction('NumericMatrix fs_cpp(NumericMatrix z, int levels) {
    int nr = z.nrow(), nc = z.ncol(); NumericMatrix out(nr, nc); NumericMatrix w = clone(z);
    for (int i = 0; i < nr; i++) for (int j = 0; j < nc; j++) {
      double old = w(i, j); double nw = std::round(old * levels) / levels; out(i, j) = std::min(1.0, std::max(0.0, nw));
      double e = old - nw;
      if (j + 1 < nc)           w(i, j + 1)     += e * 7 / 16;
      if (i + 1 < nr && j > 0)  w(i + 1, j - 1) += e * 3 / 16;
      if (i + 1 < nr)           w(i + 1, j)     += e * 5 / 16;
      if (i + 1 < nr && j + 1 < nc) w(i + 1, j + 1) += e * 1 / 16;
    }
    return out; }')
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
  D <- switch(p$algorithm, bayer = dither_bayer(Z, p$levels, p$bayer_n), floyd_steinberg = dither_floyd_steinberg(Z, p$levels), blue_noise = dither_blue_noise(Z, p$levels))
  D[!has] <- 0
  list(D = D, idx = idx)
}
blend_inks <- function(cols, blend = "mix") {   # overprint colour for a cell carrying several inks
  m <- grDevices::col2rgb(cols) / 255
  v <- switch(blend, multiply = apply(m, 1, prod), mix = rowMeans(m) * 0.72)   # mix: average, darkened so overlap reads as heavier
  grDevices::rgb(v[1], v[2], v[3])
}

makeContent.halftone <- function(x) {
  d <- x$data; p <- x$params
  W <- convertWidth(unit(1, "npc"), "mm", valueOnly = TRUE); H <- convertHeight(unit(1, "npc"), "mm", valueOnly = TRUE)
  if (!is.null(x$groups)) return(make_overprint(x, W, H))
  pitch <- p$pitch
  lat <- halftone_lattice(p, W, H, phase = p$phase); X <- lat$X; Y <- lat$Y
  r0 <- halftone_dither_group(d, lat, p, W, H); D <- r0$D; idx <- r0$idx
  keep <- D > 0
  if (!any(keep)) return(setChildren(x, gList()))
  if (p$shape == "line") return(setChildren(x, gList(line_screen_grob(lat, r0, d, p, W, H))))
  tone <- if (p$size_map == "area") sqrt(D[keep]) else D[keep]   # area (print-correct) or radius (bolder)
  r <- p$dot_max * pitch / 2 * tone * (1 + p$gain * D[keep])   # gain: ink spread grows with tone
  src <- idx[keep]
  col <- scales::alpha(d$colour[src], d$alpha[src])
  xs <- X[keep]; ys <- Y[keep]
  grob <- switch(p$shape,
    circle  = circleGrob(x = unit(xs, "mm"), y = unit(ys, "mm"), r = unit(r, "mm"), gp = gpar(fill = col, col = NA)),
    square  = rectGrob(x = unit(xs, "mm"), y = unit(ys, "mm"), width = unit(2 * r, "mm"), height = unit(2 * r, "mm"), gp = gpar(fill = col, col = NA)),
    diamond = polygonGrob(x = unit(rep(xs, each = 4) + rep(c(-1, 0, 1, 0), length(xs)) * rep(r, each = 4) * 1.15, "mm"),
                          y = unit(rep(ys, each = 4) + rep(c(0, 1, 0, -1), length(xs)) * rep(r, each = 4) * 1.15, "mm"),
                          id = rep(seq_along(xs), each = 4), gp = gpar(fill = col, col = NA)))
  setChildren(x, gList(grob))
}

# line screen: every lattice row becomes a strip whose width follows the (continuous) tone; rotated with the lattice.
# Z: tone matrix on the lattice; COL: colour matrix (or single colour); on: logical matrix of cells to draw
line_strips_grob <- function(X, Y, Z, COL, on, angle, wmax) {
  a <- angle * pi / 180; nx <- -sin(a); ny <- cos(a)
  polys_x <- list(); polys_y <- list(); cols <- character(0)
  for (i in seq_len(nrow(X))) {
    z <- Z[i, ]; oo <- on[i, ] & z > 0.02
    if (!any(oo)) next
    runs <- rle(oo); ends <- cumsum(runs$lengths); starts <- ends - runs$lengths + 1
    for (k in which(runs$values)) { s <- starts[k]:ends[k]; if (length(s) < 2) next
      w <- wmax * z[s] / 2; xs <- X[i, s]; ys <- Y[i, s]
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
  line_strips_grob(X, Y, Z, COL, has, p$angle, p$dot_max * p$pitch * 0.9)
}

# weave phase for k inks on the hex lattice. k = 3 has an exact 3-colouring (no same-ink neighbours). A triangular
# lattice has no perfect 2-colouring (odd cycles), so for k != 3 inks are assigned by the blue-noise matrix: evenly
# spread, no periodic stripes.
weave_phase <- function(r, c, k) {
  bn <- blue_noise_matrix(32); n <- nrow(bn)
  ifelse(k == 3, (c + 2 * r) %% 3, floor(pmax(k, 1) * bn[cbind(((r - 1) %% n) + 1, ((c - 1) %% n) + 1)]))
}
# dots of a given shape at (x, y) mm with radius r mm
dot_grob <- function(xs, ys, r, col, shape = "circle") {
  gp <- gpar(fill = col, col = NA)
  switch(shape,
    square  = rectGrob(x = unit(xs, "mm"), y = unit(ys, "mm"), width = unit(2 * r, "mm"), height = unit(2 * r, "mm"), gp = gp),
    diamond = polygonGrob(x = unit(rep(xs, each = 4) + rep(c(-1, 0, 1, 0), length(xs)) * rep(r, each = 4) * 1.15, "mm"),
                          y = unit(rep(ys, each = 4) + rep(c(0, 1, 0, -1), length(xs)) * rep(r, each = 4) * 1.15, "mm"), id = rep(seq_along(xs), each = 4), gp = gp),
    circleGrob(x = unit(xs, "mm"), y = unit(ys, "mm"), r = unit(r, "mm"), gp = gp))
}
make_overprint <- function(x, W, H) {
  p <- x$params; gs <- x$groups; pitch <- p$pitch
  lat <- halftone_lattice(p, W, H); X <- lat$X; Y <- lat$Y
  res <- lapply(gs, function(d) halftone_dither_group(d, lat, p, W, H))
  Dmax <- Reduce(pmax, lapply(res, `[[`, "D")); nk <- Reduce(`+`, lapply(res, function(r) r$D > 0))
  keep <- Dmax > 0
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
  tone <- if (p$size_map == "area") sqrt(Dmax[keep]) else Dmax[keep]
  r <- p$dot_max * pitch / 2 * tone * (1 + p$gain * Dmax[keep])
  setChildren(x, gList(circleGrob(x = unit(X[keep], "mm"), y = unit(Y[keep], "mm"), r = unit(r, "mm"), gp = gpar(fill = cols, col = NA))))
}

GeomHalftone <- ggproto("GeomHalftone", Geom,
  required_aes = c("x", "y", "z"),
  default_aes = aes(colour = "#8B1A1A", alpha = 1, screen = NA),
  draw_key = function(data, params, size) draw_key_halftone(data, params, size),
  draw_panel = function(data, panel_params, coord, pitch = 1.2, angle = 0, grid = "square",
                        levels = 4, algorithm = "bayer", bayer_n = 4, dot_max = 0.95, range = NULL, size_map = "area",
                        shape = "circle", gamma = 1, gain = 0, overlap = c("stack", "interleave", "overprint"), blend = "mix") {
    overlap <- match.arg(overlap)
    rng <- if (is.null(range)) range(data$z, na.rm = TRUE) else range
    prep <- function(d) { cc <- coord$transform(d, panel_params); cc$z01 <- pmin(pmax((d$z - rng[1]) / diff(rng), 0), 1)^gamma; cc$alpha[is.na(cc$alpha)] <- 1; cc }
    P <- list(pitch = pitch, angle = angle, grid = grid, levels = levels, algorithm = algorithm, bayer_n = bayer_n,
              dot_max = dot_max, size_map = size_map, shape = shape, gain = gain, phase = c(0, 0), blend = blend)
    groups <- split(data, data$group)
    has_screen <- !all(is.na(data$screen))
    if (overlap == "overprint" && length(groups) > 1 && !has_screen && shape != "line")
      return(gTree(data = NULL, groups = lapply(groups, prep), params = P, cl = "halftone"))
    ng <- length(groups)
    kids <- lapply(seq_along(groups), function(k) {
      Pk <- P; if (overlap == "interleave" && ng > 1 && !has_screen) Pk$phase <- c((k - 1) / ng, ((k - 1) %% 2) * 0.5)
      if (has_screen) { sp <- parse_screen(groups[[k]]$screen[1]); Pk$angle <- angle + sp$angle
        if (!is.null(sp$shape)) Pk$shape <- sp$shape; Pk$dot_max <- dot_max * sp$tone }
      gTree(data = prep(groups[[k]]), params = Pk, cl = "halftone") })
    do.call(grobTree, kids)
  }
)

geom_halftone <- function(mapping = NULL, data = NULL, stat = "identity", position = "identity", ...,
                          pitch = 1.2, angle = 0, grid = "square", levels = 4, algorithm = "bayer",
                          bayer_n = 4, dot_max = 0.95, range = NULL, size_map = "area", shape = "circle", gamma = 1, gain = 0, overlap = "overprint", blend = "alternate",
                          na.rm = FALSE, show.legend = NA, inherit.aes = TRUE) {
  layer(geom = GeomHalftone, mapping = mapping, data = data, stat = stat, position = position,
        show.legend = show.legend, inherit.aes = inherit.aes,
        params = list(pitch = pitch, angle = angle, grid = grid, levels = levels, algorithm = algorithm,
                      bayer_n = bayer_n, dot_max = dot_max, range = range, size_map = size_map, shape = shape, gamma = gamma, gain = gain, overlap = overlap, blend = blend, na.rm = na.rm, ...))
}

# ---- geom_spot: each point is a halftone disc of radius r (mm); tone = z01, colour from scale --------------
makeContent.spot <- function(x) {
  d <- x$data; p <- x$params
  W <- convertWidth(unit(1, "npc"), "mm", valueOnly = TRUE); H <- convertHeight(unit(1, "npc"), "mm", valueOnly = TRUE)
  pitch <- p$pitch; py <- pitch * sqrt(3) / 2
  # one global hex lattice for the whole panel so neighbouring spots share a screen
  us <- seq(-pitch, W + pitch, by = pitch); vs <- seq(-py, H + py, by = py)
  U <- matrix(us, length(vs), length(us), byrow = TRUE); V <- matrix(vs, length(vs), length(us)); U <- U + (row(U) %% 2) * pitch / 2
  b <- bayer_matrix(p$bayer_n); thr <- matrix(b[cbind(as.vector((row(U) - 1) %% p$bayer_n + 1), as.vector((col(U) - 1) %% p$bayer_n + 1))], nrow(U))
  cx <- d$x * W; cy <- d$y * H; rad <- if (is.null(d$size)) rep(p$r, nrow(d)) else d$size   # size aes = radius (mm)
  out <- vector("list", nrow(d)); rings <- vector("list", nrow(d))
  for (k in seq_len(nrow(d))) {
    inside <- (U - cx[k])^2 + (V - cy[k])^2 <= (rad[k] - p$dot_max * pitch / 2 * 0.5)^2
    if (!any(inside)) next
    D <- pmin(pmax(floor(d$z01[k] * p$levels + thr[inside]) / p$levels, 0), 1)
    keep <- D > 0
    if (any(keep)) out[[k]] <- circleGrob(x = unit(U[inside][keep], "mm"), y = unit(V[inside][keep], "mm"),
                                          r = unit(p$dot_max * pitch / 2 * sqrt(D[keep]), "mm"),
                                          gp = gpar(fill = scales::alpha(d$colour[k], d$alpha[k]), col = NA))
    if (p$ring) rings[[k]] <- circleGrob(x = unit(cx[k], "mm"), y = unit(cy[k], "mm"), r = unit(rad[k], "mm"),
                                         gp = gpar(fill = NA, col = d$colour[k], lwd = p$ring_lwd))
  }
  setChildren(x, do.call(gList, c(Filter(Negate(is.null), out), Filter(Negate(is.null), rings))))
}
GeomSpot <- ggproto("GeomSpot", Geom,
  required_aes = c("x", "y", "z"),
  default_aes = aes(colour = "#151515", alpha = 1, size = NA),
  draw_key = function(data, params, size) draw_key_spot(data, params, size),
  draw_panel = function(data, panel_params, coord, r = 3, pitch = 0.6, levels = 6, bayer_n = 4, dot_max = 0.95,
                        range = NULL, ring = TRUE, ring_lwd = 0.6, gain = 0) {
    coords <- coord$transform(data, panel_params)
    rng <- if (is.null(range)) range(data$z, na.rm = TRUE) else range
    coords$z01 <- pmin(pmax((data$z - rng[1]) / diff(rng), 0), 1)
    coords$alpha[is.na(coords$alpha)] <- 1
    if (all(is.na(coords$size))) coords$size <- NULL
    gTree(data = coords, params = list(r = r, pitch = pitch, levels = levels, bayer_n = bayer_n, dot_max = dot_max, ring = ring, ring_lwd = ring_lwd, gain = gain), cl = "spot")
  }
)
geom_spot <- function(mapping = NULL, data = NULL, stat = "identity", position = "identity", ..., r = 3, pitch = 0.6,
                      levels = 6, bayer_n = 4, dot_max = 0.95, range = NULL, ring = TRUE, ring_lwd = 0.6, gain = 0,
                      na.rm = FALSE, show.legend = NA, inherit.aes = TRUE) {
  layer(geom = GeomSpot, mapping = mapping, data = data, stat = stat, position = position, show.legend = show.legend,
        inherit.aes = inherit.aes, params = list(r = r, pitch = pitch, levels = levels, bayer_n = bayer_n, dot_max = dot_max,
        range = range, ring = ring, ring_lwd = ring_lwd, gain = gain, na.rm = na.rm, ...))
}

# ---- legend keys: a small dithered swatch (geom_halftone) / a mid-tone disc (geom_spot) ------------------------
draw_key_halftone <- function(data, params, size) {
  n <- 9; g <- expand.grid(i = 1:n, j = 1:n); thr <- bayer_matrix(4)[cbind((g$i - 1) %% 4 + 1, (g$j - 1) %% 4 + 1)]
  tone <- pmin(pmax(floor(0.6 * 3 + thr) / 3, 0), 1)
  sp <- parse_screen(data$screen); a <- (sp$angle + (params$angle %||% 0)) * pi / 180; shp <- sp$shape %||% params$shape %||% "circle"
  u <- (g$i - (n + 1) / 2) / n; v <- (g$j - (n + 1) / 2) / n
  x <- 0.5 + u * cos(a) - v * sin(a); y <- 0.5 + u * sin(a) + v * cos(a)
  keep <- tone > 0 & x > 0.06 & x < 0.94 & y > 0.06 & y < 0.94
  r <- 0.5 / n * 0.9 * sqrt(tone[keep]) * sp$tone; gp <- gpar(fill = scales::alpha(data$colour %||% "black", data$alpha %||% 1), col = NA)
  switch(shp,
    square  = rectGrob(x = unit(x[keep], "npc"), y = unit(y[keep], "npc"), width = unit(2 * r, "npc"), height = unit(2 * r, "npc"), gp = gp),
    diamond = polygonGrob(x = unit(rep(x[keep], each = 4) + rep(c(-1, 0, 1, 0), sum(keep)) * rep(r, each = 4) * 1.15, "npc"),
                          y = unit(rep(y[keep], each = 4) + rep(c(0, 1, 0, -1), sum(keep)) * rep(r, each = 4) * 1.15, "npc"), id = rep(seq_len(sum(keep)), each = 4), gp = gp),
    circleGrob(x = unit(x[keep], "npc"), y = unit(y[keep], "npc"), r = unit(r, "npc"), gp = gp))
}
# a screen spec is a number (angle) or "angle|shape|tone" (shape: circle/square/diamond; tone scales dot_max)
parse_screen <- function(s) {
  if (is.null(s) || length(s) == 0 || is.na(s[1])) return(list(angle = 0, shape = NULL, tone = 1))
  if (is.numeric(s)) return(list(angle = s[1], shape = NULL, tone = 1))
  parts <- strsplit(as.character(s[1]), "|", fixed = TRUE)[[1]]
  list(angle = as.numeric(parts[1]), shape = if (length(parts) > 1 && nzchar(parts[2])) parts[2] else NULL, tone = if (length(parts) > 2) as.numeric(parts[3]) else 1)
}
screen_recipe <- function(n, period = 90) {   # up to 9 distinct screens; the first three already differ in angle AND shape
  ang <- c(0, period / 3, 2 * period / 3); shp <- c("circle", "square", "diamond"); tone <- c(1, 0.85, 1.1)
  order <- c(1, 5, 9, 2, 6, 7, 3, 4, 8)   # (angle, shape) index pairs chosen so consecutive screens differ in both
  grid <- expand.grid(a = seq_along(ang), s = seq_along(shp))[order, ]
  rep_len(paste(ang[grid$a], shp[grid$s], tone[grid$s], sep = "|"), n)
}
# screen scales: map a discrete variable to lattice angles (square lattice repeats every 90°, hex every 60°)
scale_screen_discrete <- function(..., grid = c("square", "hex"), name = waiver()) {
  grid <- match.arg(grid); period <- if (grid == "hex") 60 else 90
  discrete_scale("screen", "screen_d", palette = function(n) screen_recipe(n, period), name = name, ...)
}
scale_screen_manual <- function(values, ..., name = waiver()) discrete_scale("screen", "screen_m", palette = function(n) values[seq_len(n)], name = name, ...)
draw_key_spot <- function(data, params, size) {
  rad <- if (is.null(data$size) || is.na(data$size)) params$r %||% 3 else data$size
  pitch <- params$pitch %||% 0.6; k <- ceiling(2 * rad / pitch)
  g <- expand.grid(i = seq_len(k), j = seq_len(k)); xs <- (g$i - (k + 1) / 2) * pitch; ys <- (g$j - (k + 1) / 2) * pitch
  inside <- xs^2 + ys^2 <= (rad - pitch * 0.4)^2
  thr <- bayer_matrix(4)[cbind((g$i - 1) %% 4 + 1, (g$j - 1) %% 4 + 1)]; tone <- pmin(pmax(floor(0.55 * 4 + thr) / 4, 0), 1)
  keep <- inside & tone > 0
  gTree(children = gList(
    circleGrob(x = unit(0.5, "npc") + unit(xs[keep], "mm"), y = unit(0.5, "npc") + unit(ys[keep], "mm"),
               r = unit(pitch / 2 * 0.95 * sqrt(tone[keep]), "mm"), gp = gpar(fill = data$colour %||% "black", col = NA)),
    circleGrob(x = 0.5, y = 0.5, r = unit(rad, "mm"), gp = gpar(fill = NA, col = data$colour %||% "black", lwd = 0.6))))
}
`%||%` <- function(a, b) if (is.null(a)) b else a

