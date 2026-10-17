#' Time the same computation in mai and in R
#'
#' Runs `mai_code` and `r_code` `reps` times each after one warm-up, and
#' reports the median elapsed seconds. Each side must define a function
#' `run()` taking no arguments; only the calls to `run()` are timed, not
#' start-up or data set-up.
#'
#' @param mai_code mai code defining `run()`.
#' @param r_code R code (a string) defining `run()`.
#' @param reps Number of timed repetitions.
#' @return A data frame with columns `language`, `seconds` and `speedup`
#'   (R seconds over mai seconds).
#' @examples
#' if (mai_available()) {
#'   mai_compare(
#'     "const run = function() { var s = 0.0
#'        for(int i = 1; i <= 1000000; i = i + 1) s = s + 1.0 / i
#'        s }",
#'     "run <- function() { s <- 0; for (i in 1:1e6) s <- s + 1 / i; s }",
#'     reps = 3)
#' }
#' @export
mai_compare <- function(mai_code, r_code, reps = 5) {
  harness <- sprintf(paste(
    "run()",
    "for(int k = 1; k <= %d; k = k + 1) {",
    "    var t0 = rt_time()",
    "    run()",
    "    print((rt_time() - t0)[1])",
    "}", sep = "\n"), as.integer(reps))
  out <- mai_run(c(mai_code, harness), error = "stop")
  mai_t <- suppressWarnings(as.numeric(out))
  mai_t <- mai_t[!is.na(mai_t)]
  if (length(mai_t) != reps) {
    stop("could not read mai timings from its output:\n",
         paste(out, collapse = "\n"), call. = FALSE)
  }
  env <- new.env(parent = globalenv())
  eval(parse(text = r_code), envir = env)
  run <- get("run", envir = env)
  invisible(run())
  r_t <- vapply(seq_len(reps),
                function(i) system.time(run())[["elapsed"]], numeric(1))
  res <- data.frame(language = c("mai", "R"),
                    seconds = c(stats_median(mai_t), stats_median(r_t)))
  res$speedup <- res$seconds[2] / res$seconds
  res
}

stats_median <- function(x) {
  x <- sort(x)
  n <- length(x)
  if (n %% 2) x[(n + 1) / 2] else mean(x[n / 2 + 0:1])
}
