# stat_halftone.R — vector-native halftone/dither layer for ggplot2 (prototype v2)
#
# Output columns: x, y, dot (dithered level in [0,1]), z (continuous value in [0,1]), level (integer bin)
#   -> size  = after_stat(dot)   graded dot size (classic halftone)
#   -> colour = after_stat(z)    any continuous colour scale drives the dots
#   -> colour = after_stat(level) discrete-ish banding
# Grid: square or hex, optional screen `angle` (45 deg = print convention, kills axis-aligned moire)

library(ggplot2)

bayer_matrix <- function(n = 4) {
  stopifnot(n >= 1, log2(n) %% 1 == 0)
  m <- matrix(0, 1, 1)
  while (nrow(m) < n) m <- rbind(cbind(4 * m, 4 * m + 2), cbind(4 * m + 3, 4 * m + 1))
  (m + 0.5) / (n * n)
}
dither_bayer <- function(z, levels = 1, n = 4) {
  b <- bayer_matrix(n); nr <- nrow(z); nc <- ncol(z)
  thr <- b[((seq_len(nr) - 1) %% n) + 1, ((seq_len(nc) - 1) %% n) + 1, drop = FALSE]
  pmin(pmax(floor(z * levels + thr) / levels, 0), 1)
}
dither_floyd_steinberg <- function(z, levels = 1) {
  nr <- nrow(z); nc <- ncol(z); out <- matrix(0, nr, nc)
  for (i in seq_len(nr)) for (j in seq_len(nc)) {
    old <- z[i, j]; new <- round(old * levels) / levels; out[i, j] <- new; err <- old - new
    if (j < nc)           z[i, j + 1]     <- z[i, j + 1]     + err * 7 / 16
    if (i < nr && j > 1)  z[i + 1, j - 1] <- z[i + 1, j - 1] + err * 3 / 16
    if (i < nr)           z[i + 1, j]     <- z[i + 1, j]     + err * 5 / 16
    if (i < nr && j < nc) z[i + 1, j + 1] <- z[i + 1, j + 1] + err * 1 / 16
  }
  pmin(pmax(out, 0), 1)
}

# sample z(x,y) at arbitrary points; exact lookup for gridded input, NN with cutoff otherwise
sample_field <- function(x, y, z, px, py, cutoff = 0.5) {
  ux <- sort(unique(x)); uy <- sort(unique(y))
  if (length(ux) * length(uy) == length(z)) {
    m <- matrix(NA_real_, length(uy), length(ux)); m[cbind(match(y, uy), match(x, ux))] <- z
    ix <- findInterval(px, c(-Inf, ux[-1] - diff(ux) / 2)); iy <- findInterval(py, c(-Inf, uy[-1] - diff(uy) / 2))
    return(m[cbind(iy, ix)])
  }
  sx <- if (length(ux) > 1) median(diff(ux)) else 1; sy <- if (length(uy) > 1) median(diff(uy)) else 1
  vapply(seq_along(px), function(k) {
    d <- pmax(abs(x - px[k]) / sx, abs(y - py[k]) / sy); i <- which.min(d)   # Chebyshev: cells are boxes
    if (d[i] > cutoff) NA_real_ else z[i]
  }, 1)
}

StatHalftone <- ggproto("StatHalftone", Stat,
  required_aes = c("x", "y", "z"),
  compute_group = function(data, scales, n = 80, algorithm = c("bayer", "floyd_steinberg"),
                           levels = 4, bayer_n = 4, grid = c("square", "hex"), angle = 0,
                           aspect = 1, range = NULL, drop_zero = TRUE, ...) {
    algorithm <- match.arg(algorithm); grid <- match.arg(grid)
    rng <- if (is.null(range)) range(data$z, na.rm = TRUE) else range
    z01 <- pmin(pmax((data$z - rng[1]) / diff(rng), 0), 1)
    xr <- range(data$x); yr <- range(data$y)
    # work in normalised panel space: x in [0, aspect], y in [0, 1]
    n <- rep_len(n, 2); px <- aspect / n[1]; py <- if (length(n) == 2 && n[2] != n[1]) 1 / n[2] else px
    if (grid == "hex") py <- px * sqrt(3) / 2
    # oversized grid so rotation still covers the panel
    us <- seq(-0.6 * aspect, 1.6 * aspect, by = px); vs <- seq(-0.6, 1.6, by = py)
    U <- matrix(us, length(vs), length(us), byrow = TRUE); V <- matrix(vs, length(vs), length(us))
    if (grid == "hex") U <- U + (row(U) %% 2) * px / 2
    a <- angle * pi / 180; cx <- aspect / 2; cy <- 0.5
    X <- cx + (U - cx) * cos(a) - (V - cy) * sin(a)
    Y <- cy + (U - cx) * sin(a) + (V - cy) * cos(a)
    inside <- X >= 0 & X <= aspect & Y >= 0 & Y <= 1
    # map back to data units and sample
    dx <- xr[1] + X / aspect * diff(xr); dy <- yr[1] + Y * diff(yr)
    Z <- matrix(NA_real_, nrow(X), ncol(X))
    Z[inside] <- sample_field(data$x, data$y, z01, dx[inside], dy[inside])
    Zs <- Z; Zs[is.na(Zs)] <- 0
    D <- switch(algorithm, bayer = dither_bayer(Zs, levels, bayer_n), floyd_steinberg = dither_floyd_steinberg(Zs, levels))
    keep <- inside & !is.na(Z)
    out <- data.frame(x = dx[keep], y = dy[keep], dot = D[keep], z = Z[keep])
    out$level <- round(out$dot * levels)
    if (drop_zero) out <- out[out$dot > 0, , drop = FALSE]
    out
  }
)

stat_halftone <- function(mapping = NULL, data = NULL, geom = "point", position = "identity", ...,
                          n = 80, algorithm = "bayer", levels = 4, bayer_n = 4, grid = "square",
                          angle = 0, aspect = 1, range = NULL, drop_zero = TRUE,
                          na.rm = FALSE, show.legend = NA, inherit.aes = TRUE) {
  layer(stat = StatHalftone, data = data, mapping = mapping, geom = geom, position = position,
        show.legend = show.legend, inherit.aes = inherit.aes,
        params = list(n = n, algorithm = algorithm, levels = levels, bayer_n = bayer_n, grid = grid,
                      angle = angle, aspect = aspect, range = range, drop_zero = drop_zero, na.rm = na.rm, ...))
}

# helper: dot size scale expressed as a fraction of the pitch, so dots never overlap at max
scale_size_halftone <- function(max = 1.0, min = 0.08, ...) scale_size(range = c(min, max), guide = "none", ...)
