# km.R: survfit -> data frames ready for with_halftone(geom_ribbon()) + with_halo(geom_step()).
# Every KM script in the prototypes rebuilt the step-ribbon frame by hand; this is that frame, once.

#' Kaplan-Meier frames for halftone survival plots
#'
#' Convert a `survival::survfit` object into data frames for `with_halftone(geom_ribbon())` and
#' `with_halo(geom_step())`. `km_steps()` returns the step outline with one row per corner (`time`, `surv`, `lo`,
#' `hi`, `strata`), starting at `(0, 1)`, so that a ribbon between `lo` and `hi` follows the steps exactly.
#' `km_censor()` returns the censor marks (`time`, `surv`, `strata`). `km_risk()` returns the number at risk at
#' `times`. Strata labels are the level values without the variable name; `"ph.ecog=1"` becomes `"1"`.
#' @param fit A `survfit` object.
#' @param conf Include the confidence limits (`lo`, `hi`); otherwise both equal `surv`.
#' @param times Times at which to report the number at risk.
#' @return A data frame.
#' @references
#' Loprinzi, C. L., Laurie, J. A., Wieand, H. S., et al. (1994). Prospective evaluation of prognostic variables from patient-completed questionnaires. North Central Cancer Treatment Group. Journal of Clinical Oncology, 12(3), 601-607. \doi{10.1200/JCO.1994.12.3.601}. Distributed as `survival::lung`.
#' @examples
#' if (requireNamespace("survival", quietly = TRUE)) {
#'   fit <- survival::survfit(survival::Surv(time, status) ~ sex, data = survival::lung)
#'   s <- km_steps(fit)
#'   ggplot2::ggplot(s, ggplot2::aes(time, group = strata)) +
#'     with_halftone(ggplot2::geom_ribbon(ggplot2::aes(ymin = lo, ymax = hi, fill = strata))) +
#'       with_halo(ggplot2::geom_step(ggplot2::aes(y = surv, colour = strata))) +
#'   ggplot2::theme_classic() + theme_halftone()
#' }
#' @export
km_steps <- function(fit, conf = TRUE) {
  stopifnot(inherits(fit, "survfit"))
  d <- km_frame(fit, conf)
  do.call(rbind, lapply(split(d, d$strata), function(s) {
    s <- rbind(data.frame(time = 0, surv = 1, lo = 1, hi = 1, n.censor = 0, strata = s$strata[1]), s[order(s$time), ])
    n <- nrow(s); i <- c(1, rep(seq_len(n)[-1], each = 2)); j <- c(rep(seq_len(n - 1), each = 2), n)   # step: x from row i, y from row j
    data.frame(time = s$time[i], surv = s$surv[j], lo = s$lo[j], hi = s$hi[j], strata = s$strata[1], row.names = NULL)
  }))
}
#' @rdname km_steps
#' @export
km_censor <- function(fit) { d <- km_frame(fit, FALSE); d <- d[d$n.censor > 0, c("time", "surv", "strata")]; rownames(d) <- NULL; d }
#' @rdname km_steps
#' @export
km_risk <- function(fit, times) {
  s <- summary(fit, times = times, extend = TRUE)
  strata <- if (is.null(s$strata)) factor("all") else factor(km_strata_labels(as.character(s$strata)), levels = km_strata_labels(names(fit$strata)))
  data.frame(time = s$time, n.risk = s$n.risk, strata = strata)
}
km_strata_labels <- function(x) gsub("[^=,]*=", "", x)   # "ph.ecog=0" -> "0"; "a=1, b=2" -> "1, 2"
km_frame <- function(fit, conf) {
  strata <- if (is.null(fit$strata)) factor(rep("all", length(fit$time))) else
    factor(rep(km_strata_labels(names(fit$strata)), fit$strata), levels = km_strata_labels(names(fit$strata)))
  lo <- if (conf && !is.null(fit$lower)) fit$lower else fit$surv; hi <- if (conf && !is.null(fit$upper)) fit$upper else fit$surv
  d <- data.frame(time = fit$time, surv = fit$surv, lo = lo, hi = hi, n.censor = fit$n.censor, strata = strata)
  d$lo[is.na(d$lo)] <- 0; d$hi[is.na(d$hi)] <- d$surv[is.na(d$hi)]
  d
}
