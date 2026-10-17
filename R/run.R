#' Run mai code
#'
#' `mai_run()` runs a string of mai code and `mai_source()` runs a file. Each
#' call starts a fresh mai process, so nothing carries over between calls;
#' use `include "file.mai"` inside the code to share definitions.
#'
#' mai prints the value of a script's last expression after it runs. Because
#' `print()` returns `nil`, most scripts end with a blank line and `<nil>`;
#' `drop_nil = TRUE` removes that trailer.
#'
#' mai exits with status 0 even when the code fails, so errors are detected
#' from the output: a syntax error starts with `Error:`, and a run-time error
#' is a line such as `stop: message` after a blank line.
#'
#' @param code Character vector of mai code; elements are joined by newlines.
#' @param file Path to a `.mai` file.
#' @param drop_nil Drop the trailing `<nil>` result line.
#' @param error What to do if the output shows an error: `"warning"`,
#'   `"stop"` or `"ignore"`.
#' @param wd Working directory to run in, which is where `include` paths are
#'   resolved.
#' @param timeout Seconds before the process is killed (0 for no limit).
#' @return A character vector of output lines with class `mai_output`, and
#'   attributes `error` (the error message, or `NULL`) and `seconds` (wall
#'   time of the whole process).
#' @examples
#' if (mai_available()) {
#'   mai_run("print(sum(1:10))")
#'   mai_run(c("const sq = function(double x) : double x * x",
#'             "print(sq(1.5))"))
#' }
#' @export
mai_run <- function(code, drop_nil = TRUE, error = c("warning", "stop", "ignore"),
                    wd = getwd(), timeout = 0) {
  f <- tempfile(fileext = ".mai")
  on.exit(unlink(f), add = TRUE)
  writeLines(code, f)
  run_file(f, drop_nil = drop_nil, error = match.arg(error), wd = wd,
           timeout = timeout)
}

#' @rdname mai_run
#' @export
mai_source <- function(file, drop_nil = TRUE,
                       error = c("warning", "stop", "ignore"),
                       wd = dirname(file), timeout = 0) {
  file <- normalizePath(file, mustWork = TRUE)
  run_file(file, drop_nil = drop_nil, error = match.arg(error), wd = wd,
           timeout = timeout)
}

run_file <- function(file, drop_nil, error, wd, timeout) {
  bin <- require_mai()
  old <- setwd(wd)
  on.exit(setwd(old), add = TRUE)
  t0 <- proc.time()[["elapsed"]]
  out <- suppressWarnings(
    system2(bin, shQuote(file), stdout = TRUE, stderr = TRUE,
            timeout = timeout))
  secs <- proc.time()[["elapsed"]] - t0
  if (drop_nil) out <- drop_trailer(out)
  err <- find_error(out)
  if (!is.null(err)) {
    msg <- paste("mai:", err)
    if (error == "stop") stop(msg, call. = FALSE)
    if (error == "warning") warning(msg, call. = FALSE)
  }
  structure(out, class = "mai_output", error = err, seconds = secs)
}

drop_trailer <- function(out) {
  n <- length(out)
  if (n >= 1 && out[n] == "<nil>") {
    out <- out[-n]
    n <- n - 1
    if (n >= 1 && out[n] == "") out <- out[-n]
  }
  out
}

# A syntax or compile error is a line starting "Error: "; a run-time error is
# printed by the VM as a blank line then "where: message".
find_error <- function(out) {
  hit <- grep("^Error: ", out)
  if (length(hit)) return(sub("^Error: ", "", out[hit[1]]))
  for (i in seq_along(out)[-1]) {
    if (out[i - 1] == "" &&
        grepl("^[A-Za-z_.][A-Za-z0-9_.=\\[]*: ", out[i]) &&
        i == length(out)) {
      return(out[i])
    }
  }
  NULL
}

#' @export
print.mai_output <- function(x, ...) {
  if (length(x)) cat(x, sep = "\n")
  invisible(x)
}
