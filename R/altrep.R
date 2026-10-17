#' Inspect a mai ALTREP vector
#'
#' With `mai_eval(.altrep = TRUE)` a result stays in mai's output, mapped
#' into memory, and R sees an ALTREP vector over it. `mai_vec_info()` says
#' whether `x` is such a vector and counts what R has asked it for: single
#' elements (`elt`), runs of elements (`region`), the whole data pointer
#' (`dataptr`, which most arithmetic needs) and, on an R built with the
#' proposed `Extract_array_subset` ALTREP method, whole `x[i, j, ...]`
#' requests (`array_subset`).
#'
#' Integer results are used in place. Doubles are too, once mai's `NA`
#' values have been rewritten as R's (this happens in memory, on the first
#' full data request). Logical results are converted to R's 4-byte layout
#' on the first full data request.
#'
#' @param x Any R object.
#' @return `NULL` if `x` is not a mai ALTREP vector, otherwise a list with
#'   `mapped` (logical) and the counts `elt`, `region`, `dataptr` and
#'   `array_subset`. `mai_has_array_subset()` returns `TRUE` when rmai was
#'   built against an R that offers `Extract_array_subset`.
#' @examples
#' if (mai_available()) {
#'   m <- mai_eval("m * 2.0", m = matrix(runif(12), 3), .altrep = TRUE)
#'   m[2, 3:4]
#'   mai_vec_info(m)
#' }
#' @useDynLib rmai, .registration = TRUE
#' @export
mai_vec_info <- function(x) .Call(rmai_vec_info, x)

#' @rdname mai_vec_info
#' @export
mai_has_array_subset <- function() .Call(rmai_has_array_subset)

mai_vec_from_file <- function(path, type, dim = NULL) {
  code <- match(type, c("double", "int", "boolean")) - 1L
  if (is.na(code)) stop("unknown mai element type '", type, "'.", call. = FALSE)
  .Call(rmai_vec_from_file, normalizePath(path), code, dim)
}
