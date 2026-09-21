# geom_halftone.R — draw-time halftone geom (prototype v3)
#
# geom_halftone(aes(x, y, z = value, colour = value))
#   * input: a gridded field (geom_raster-style: x, y, z), optionally colour/fill/alpha mapped on it
#   * the dot grid is generated at DRAW time in millimetres -> pitch is physical, aspect automatic,
#     screen angle geometrically correct, dot area proportional to tone (true halftone)
#   * colour scales are applied by ggplot2 to the source field; each dot inherits the nearest cell's colour
# params: pitch (mm), angle (deg), grid ("square"/"hex"), levels, algorithm, bayer_n, dot_max (fraction of pitch)


#' @export
bayer_matrix <- function(n = 4) {
  m <- matrix(0, 1, 1)
  while (nrow(m) < n) m <- rbind(cbind(4 * m, 4 * m + 2), cbind(4 * m + 3, 4 * m + 1))
  (m + 0.5) / (n * n)
}
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
#' @export
dither_blue_noise <- function(z, levels = 1, n = 32) {
  b <- blue_noise_matrix(n); nr <- nrow(z); nc <- ncol(z)
  thr <- b[((seq_len(nr) - 1) %% n) + 1, ((seq_len(nc) - 1) %% n) + 1, drop = FALSE]
  pmin(pmax(floor(z * levels + thr) / levels, 0), 1)
}
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
tone_floor <- 0.02   # cells below this tone are not drawn: sub-0.05 mm dots read as dirt, not tone
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
  v <- switch(blend, multiply = apply(m, 1, prod), mix = rowMeans(m) * 0.72)   # mix: average, darkened so overlap reads as heavier
  grDevices::rgb(v[1], v[2], v[3])
}

#' @export
makeContent.halftone <- function(x) {
  d <- x$data; p <- x$params
  W <- convertWidth(unit(1, "npc"), "mm", valueOnly = TRUE); H <- convertHeight(unit(1, "npc"), "mm", valueOnly = TRUE)
  if (!is.null(x$groups)) return(make_overprint(x, W, H))
  pitch <- p$pitch
  lat <- halftone_lattice(p, W, H, phase = p$phase); X <- lat$X; Y <- lat$Y
  r0 <- halftone_dither_group(d, lat, p, W, H); D <- r0$D; idx <- r0$idx
  keep <- D > tone_floor
  if (!any(keep)) return(setChildren(x, gList()))
  if (p$shape == "line") return(setChildren(x, gList(line_screen_grob(lat, r0, d, p, W, H))))
  tone <- if (p$size_map == "area") sqrt(D[keep]) else D[keep]   # area (print-correct) or radius (bolder)
  r <- p$dot_max * pitch / 2 * tone * (1 + p$gain * D[keep])   # gain: ink spread grows with tone
  src <- idx[keep]
  col <- scales::alpha(d$colour[src], d$alpha[src])
  xs <- X[keep]; ys <- Y[keep]
  setChildren(x, gList(dot_grob(xs, ys, r, col, p$shape)))
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
  keep <- Dmax > tone_floor
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
  draw_panel = function(data, panel_params, coord, pitch = NULL, angle = NULL, grid = "hex",
                        levels = NULL, algorithm = "bayer", bayer_n = 4, dot_max = 0.9, range = NULL, size_map = "area",
                        shape = "circle", gamma = 1, gain = 0, overlap = c("stack", "interleave", "overprint"), blend = "mix", tone_max = NULL) {
    pitch <- pitch %||% if (shape == "line") 0.45 else 0.6              # line screens read coarse above 0.5 mm
    tone_max <- tone_max %||% if (isTRUE(levels == 1)) 0.55 else 1       # a binary stipple must never saturate into the bare lattice
    overlap <- match.arg(overlap); angle_user <- !is.null(angle); angle <- angle %||% 15   # screen specs are absolute unless the user gave an angle offset
    rng <- if (is.null(range)) range(data$z, na.rm = TRUE) else range
    prep <- function(d) { cc <- coord$transform(d, panel_params); cc$z01 <- norm01(d$z, rng)^gamma * tone_max; cc$alpha[is.na(cc$alpha)] <- 1; cc }
    P <- list(pitch = pitch, angle = angle, grid = grid, levels = levels, algorithm = algorithm, bayer_n = bayer_n,
              dot_max = dot_max, size_map = size_map, shape = shape, gain = gain, phase = c(0, 0), blend = blend)
    groups <- split(data, data$group)
    has_screen <- !all(is.na(data$screen))
    if (overlap == "overprint" && length(groups) > 1 && !has_screen && shape != "line")
      return(gTree(data = NULL, groups = lapply(groups, prep), params = P, cl = "halftone"))
    ng <- length(groups)
    kids <- lapply(seq_along(groups), function(k) {
      Pk <- P; if (overlap == "interleave" && ng > 1 && !has_screen) Pk$phase <- c((k - 1) / ng, ((k - 1) %% 2) * 0.5)
      if (has_screen) { sp <- parse_screen(groups[[k]]$screen[1]); Pk$angle <- (if (angle_user) angle else 0) + screen_angle(sp, shape)
        if (!is.null(sp$shape)) Pk$shape <- sp$shape; Pk$dot_max <- dot_max * sp$tone }
      gTree(data = prep(groups[[k]]), params = Pk, cl = "halftone") })
    do.call(grobTree, kids)
  }
)

#' @export
geom_halftone <- function(mapping = NULL, data = NULL, stat = "identity", position = "identity", ...,
                          pitch = NULL, angle = NULL, grid = "hex", levels = NULL, algorithm = "bayer",
                          bayer_n = 4, dot_max = 0.9, range = NULL, size_map = "area", shape = "circle", gamma = 1, gain = 0, overlap = "overprint", blend = "alternate", tone_max = NULL,
                          na.rm = FALSE, show.legend = NA, inherit.aes = TRUE) {
  layer(geom = GeomHalftone, mapping = mapping, data = data, stat = stat, position = position,
        show.legend = show.legend, inherit.aes = inherit.aes,
        params = list(pitch = pitch, angle = angle, grid = grid, levels = levels, algorithm = algorithm,
                      bayer_n = bayer_n, dot_max = dot_max, range = range, size_map = size_map, shape = shape, gamma = gamma, gain = gain, overlap = overlap, blend = blend, tone_max = tone_max, na.rm = na.rm, ...))
}

# ---- geom_spot: each point is a disc of radius r (mm) filled with a halftone whose tone is the value ----------------
# tone: aes(tone = ) through scale_tone_continuous() (0..1, with a guide), or aes(z = ) normalised in the geom (no guide).
# Each disc gets its own hex lattice centred on the disc (a symmetric rosette), and the dots are clipped to the disc.
spot_grob <- function(cx, cy, rad, tone, col, pitch, dot_max, ring, ring_lwd, levels = NULL, bayer_n = 4) {
  py <- pitch * sqrt(3) / 2; k <- ceiling(rad / pitch) + 1
  us <- seq(-k, k) * pitch; vs <- seq(-k, k) * py
  U <- matrix(us, length(vs), length(us), byrow = TRUE); V <- matrix(vs, length(vs), length(us)); U <- U + (row(U) %% 2) * pitch / 2
  inside <- U^2 + V^2 <= (rad + pitch / 2)^2
  D <- if (is.null(levels)) rep(tone, sum(inside)) else {
    b <- bayer_matrix(bayer_n); thr <- b[cbind((row(U)[inside] - 1) %% bayer_n + 1, (col(U)[inside] - 1) %% bayer_n + 1)]
    pmin(pmax(floor(tone * levels + thr) / levels, 0), 1) }
  keep <- D > tone_floor
  kids <- gList()
  if (any(keep)) {
    dots <- circleGrob(x = unit(cx + U[inside][keep], "mm"), y = unit(cy + V[inside][keep], "mm"), r = unit(dot_max * pitch / 2 * sqrt(D[keep]), "mm"), gp = gpar(fill = col, col = NA))
    kids <- gList(gTree(children = gList(dots), vp = viewport(clip = circleGrob(x = unit(cx, "mm"), y = unit(cy, "mm"), r = unit(rad, "mm")))))
  }
  if (ring) kids <- gList(kids, circleGrob(x = unit(cx, "mm"), y = unit(cy, "mm"), r = unit(rad, "mm"), gp = gpar(fill = NA, col = col, lwd = ring_lwd)))
  gTree(children = kids)
}
#' @export
makeContent.spot <- function(x) {
  d <- x$data; p <- x$params
  W <- convertWidth(unit(1, "npc"), "mm", valueOnly = TRUE); H <- convertHeight(unit(1, "npc"), "mm", valueOnly = TRUE)
  cx <- d$x * W; cy <- d$y * H; rad <- if (is.null(d$size)) rep(p$r, nrow(d)) else d$size   # size aes = radius (mm)
  kids <- lapply(seq_len(nrow(d)), function(k) spot_grob(cx[k], cy[k], rad[k], d$z01[k], scales::alpha(d$colour[k], d$alpha[k]), p$pitch, p$dot_max, p$ring, p$ring_lwd, p$levels, p$bayer_n))
  setChildren(x, do.call(gList, kids))
}
GeomSpot <- ggproto("GeomSpot", Geom,
  required_aes = c("x", "y"), optional_aes = c("z", "tone"),
  default_aes = aes(colour = "#151515", alpha = 1, size = NA, tone = NA, z = NA),
  draw_key = function(data, params, size) draw_key_spot(data, params, size),
  draw_panel = function(data, panel_params, coord, r = 3, pitch = 0.5, levels = NULL, bayer_n = 4, dot_max = 0.9,
                        range = NULL, ring = TRUE, ring_lwd = 0.3, gain = 0) {
    coords <- coord$transform(data, panel_params)
    if (!all(is.na(data$tone))) coords$z01 <- pmin(pmax(data$tone, 0), 1)
    else if (!all(is.na(data$z))) { rng <- if (is.null(range)) range(data$z, na.rm = TRUE) else range; coords$z01 <- norm01(data$z, rng) }
    else stop("geom_spot() needs aes(tone = ) (through scale_tone_continuous()) or aes(z = )")
    coords$z01[is.na(coords$z01)] <- 0
    coords$alpha[is.na(coords$alpha)] <- 1
    if (all(is.na(coords$size))) coords$size <- NULL
    gTree(data = coords, params = list(r = r, pitch = pitch, levels = levels, bayer_n = bayer_n, dot_max = dot_max, ring = ring, ring_lwd = ring_lwd, gain = gain), cl = "spot")
  }
)
#' @export
geom_spot <- function(mapping = NULL, data = NULL, stat = "identity", position = "identity", ..., r = 3, pitch = 0.5,
                      levels = NULL, bayer_n = 4, dot_max = 0.9, range = NULL, ring = TRUE, ring_lwd = 0.3, gain = 0,
                      na.rm = FALSE, show.legend = NA, inherit.aes = TRUE) {
  layer(geom = GeomSpot, mapping = mapping, data = data, stat = stat, position = position, show.legend = show.legend,
        inherit.aes = inherit.aes, params = list(r = r, pitch = pitch, levels = levels, bayer_n = bayer_n, dot_max = dot_max,
        range = range, ring = ring, ring_lwd = ring_lwd, gain = gain, na.rm = na.rm, ...))
}
# tone as a real aesthetic: a continuous scale onto [0, 1] (or a narrower range) with a legend of tone discs at the breaks
#' @export
scale_tone_continuous <- function(name = waiver(), ..., range = c(0, 1), guide = "legend") {
  continuous_scale("tone", palette = scales::pal_rescale(range), name = name, guide = guide, ...)
}
#' @export
scale_tone <- scale_tone_continuous

# ---- legend keys: a small dithered swatch (geom_halftone) / a mid-tone disc (geom_spot) ------------------------
#' @export
draw_key_halftone <- function(data, params, size) {
  n <- 9; g <- expand.grid(i = 1:n, j = 1:n); tone <- rep(0.55, n * n)   # uniform mid-tone swatch
  sp <- parse_screen(data$screen); has_screen <- !is.null(data$screen) && !is.na(data$screen)
  shp <- if (identical(params$shape, "line") && !identical(sp$shape, "line")) "line" else sp$shape %||% params$shape %||% "circle"
  base <- if (has_screen) { if (is.null(params$angle_user)) params$angle %||% 0 else if (params$angle_user) params$angle else 0 } else params$angle %||% 15
  a <- (screen_angle(sp, shp) + base) * pi / 180
  if (shp == "line") return(key_hatch_grob(a, scales::alpha(data$colour %||% "black", data$alpha %||% 1)))
  u <- (g$i - (n + 1) / 2) / n; v <- (g$j - (n + 1) / 2) / n
  x <- 0.5 + u * cos(a) - v * sin(a); y <- 0.5 + u * sin(a) + v * cos(a)
  keep <- tone > 0 & x > 0.06 & x < 0.94 & y > 0.06 & y < 0.94
  r <- 0.5 / n * 0.9 * sqrt(tone[keep]) * sp$tone; gp <- gpar(fill = scales::alpha(data$colour %||% "black", data$alpha %||% 1), col = NA)
  switch(shp,
    square  = rectGrob(x = unit(x[keep], "npc"), y = unit(y[keep], "npc"), width = unit(2 * r * sq_k, "npc"), height = unit(2 * r * sq_k, "npc"), gp = gp),
    diamond = polygonGrob(x = unit(rep(x[keep], each = 4) + rep(c(-1, 0, 1, 0), sum(keep)) * rep(r, each = 4) * di_k, "npc"),
                          y = unit(rep(y[keep], each = 4) + rep(c(0, 1, 0, -1), sum(keep)) * rep(r, each = 4) * di_k, "npc"), id = rep(seq_len(sum(keep)), each = 4), gp = gp),
    circleGrob(x = unit(x[keep], "npc"), y = unit(y[keep], "npc"), r = unit(r, "npc"), gp = gp))
}
# hatched legend key: parallel strokes through the key box at the screen angle, clipped to the box
key_hatch_grob <- function(a, col, n = 5) {
  o <- seq(-1, 1, length.out = 2 * n + 1); nx <- -sin(a); ny <- cos(a); dx <- cos(a); dy <- sin(a)
  x0 <- 0.5 + o * nx - dx; y0 <- 0.5 + o * ny - dy; x1 <- 0.5 + o * nx + dx; y1 <- 0.5 + o * ny + dy
  gTree(children = gList(segmentsGrob(unit(x0, "npc"), unit(y0, "npc"), unit(x1, "npc"), unit(y1, "npc"), gp = gpar(col = col, lwd = 1.4))),
        vp = viewport(width = 0.88, height = 0.88, clip = "on"))
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
  ang <- (if (period == 60) 15 else 45) + c(0, period / 3, 2 * period / 3); shp <- c("circle", "square", "diamond"); tone <- c(1, 0.85, 1.1)   # absolute: first screen = the lattice default
  order <- c(1, 5, 9, 2, 6, 7, 3, 4, 8)   # (angle, shape) index pairs chosen so consecutive screens differ in both
  grid <- expand.grid(a = seq_along(ang), s = seq_along(shp))[order, ]
  rep_len(paste(ang[grid$a], shp[grid$s], tone[grid$s], line_recipe(9), sep = "|"), n)
}
# hatching angles for line screens: diagonal, counter-diagonal, horizontal, vertical, then the half-steps (absolute degrees)
line_recipe <- function(n) rep_len(c(45, 135, 0, 90, 22.5, 112.5, 67.5, 157.5), n)
# screen scales: map a discrete variable to lattice angles (square lattice repeats every 90°, hex every 60°)
#' @export
scale_screen_discrete <- function(..., grid = c("hex", "square"), name = waiver()) {
  grid <- match.arg(grid); period <- if (grid == "hex") 60 else 90
  discrete_scale("screen", "screen_d", palette = function(n) screen_recipe(n, period), name = name, ...)
}
#' @export
scale_screen_manual <- function(values, ..., name = waiver()) discrete_scale("screen", "screen_m", palette = function(n) values[seq_len(n)], name = name, ...)
#' @export
draw_key_spot <- function(data, params, size) {
  # a tone key shows the disc at the break's tone; a size key shows a mid-tone disc at that radius. The key reports its
  # own size (attr width/height, cm) so labels never sit on the disc.
  rad <- if (is.null(data$size) || is.na(data$size)) min(params$r %||% 3, 2.4) else data$size
  tone <- if (is.null(data$tone) || is.na(data$tone)) 0.55 else data$tone
  g <- spot_grob(0, 0, rad, tone, data$colour %||% "black", params$pitch %||% 0.5, params$dot_max %||% 0.9, TRUE, params$ring_lwd %||% 0.3, params$levels, params$bayer_n %||% 4)
  key <- gTree(children = gList(g), vp = viewport(x = 0.5, y = 0.5, width = unit(0, "mm"), height = unit(0, "mm"), clip = "off"))
  attr(key, "width") <- attr(key, "height") <- (2 * rad + 1.2) / 10
  key
}
