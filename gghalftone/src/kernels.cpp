#include <Rcpp.h>
using namespace Rcpp;

// [[Rcpp::export]]
NumericMatrix fs_cpp(NumericMatrix z, int levels) {
  int nr = z.nrow(), nc = z.ncol(); NumericMatrix out(nr, nc); NumericMatrix w = clone(z);
  for (int i = 0; i < nr; i++) for (int j = 0; j < nc; j++) {
    double old = w(i, j); double nw = std::round(old * levels) / levels; out(i, j) = std::min(1.0, std::max(0.0, nw));
    double e = old - nw;
    if (j + 1 < nc)               w(i, j + 1)     += e * 7 / 16;
    if (i + 1 < nr && j > 0)      w(i + 1, j - 1) += e * 3 / 16;
    if (i + 1 < nr)               w(i + 1, j)     += e * 5 / 16;
    if (i + 1 < nr && j + 1 < nc) w(i + 1, j + 1) += e * 1 / 16;
  }
  return out;
}

// [[Rcpp::export]]
LogicalVector pip_cpp(NumericVector px, NumericVector py, NumericVector vx, NumericVector vy) {
  int n = px.size(), m = vx.size(); LogicalVector out(n);
  for (int k = 0; k < n; k++) { bool c = false;
    for (int i = 0, j = m - 1; i < m; j = i++) {
      if (((vy[i] > py[k]) != (vy[j] > py[k])) && (px[k] < (vx[j] - vx[i]) * (py[k] - vy[i]) / (vy[j] - vy[i]) + vx[i])) c = !c; }
    out[k] = c; }
  return out;
}

// [[Rcpp::export]]
NumericMatrix dt_cpp(LogicalMatrix m) {
  int nr = m.nrow(), nc = m.ncol(); double INF = 1e9; NumericMatrix d(nr, nc);
  for (int i = 0; i < nr; i++) for (int j = 0; j < nc; j++) d(i, j) = m(i, j) ? INF : 0;
  for (int i = 0; i < nr; i++) for (int j = 0; j < nc; j++) { if (d(i,j) == 0) continue; double b = d(i,j);
    if (i > 0) b = std::min(b, d(i-1,j) + 1); if (j > 0) b = std::min(b, d(i,j-1) + 1);
    if (i > 0 && j > 0) b = std::min(b, d(i-1,j-1) + 1.4142); if (i > 0 && j < nc-1) b = std::min(b, d(i-1,j+1) + 1.4142); d(i,j) = b; }
  for (int i = nr-1; i >= 0; i--) for (int j = nc-1; j >= 0; j--) { if (d(i,j) == 0) continue; double b = d(i,j);
    if (i < nr-1) b = std::min(b, d(i+1,j) + 1); if (j < nc-1) b = std::min(b, d(i,j+1) + 1);
    if (i < nr-1 && j < nc-1) b = std::min(b, d(i+1,j+1) + 1.4142); if (i < nr-1 && j > 0) b = std::min(b, d(i+1,j-1) + 1.4142); d(i,j) = b; }
  return d;
}

// [[Rcpp::export]]
NumericMatrix dt_col_cpp(LogicalMatrix m) {
  int nr = m.nrow(), nc = m.ncol(); NumericMatrix d(nr, nc);
  for (int j = 0; j < nc; j++) { int i = 0; while (i < nr) { if (!m(i, j)) { d(i, j) = 0; i++; continue; }
      int s = i; while (i < nr && m(i, j)) i++; int e = i - 1; double half = (e - s + 1) / 2.0;
      for (int k = s; k <= e; k++) { double dd = std::min(k - s + 1, e - k + 1); d(k, j) = dd / half; } } }
  return d;
}
