#' Locate the mai executable
#'
#' Searches, in order: `getOption("rmai.path")`, the `MAI_PATH` environment
#' variable, the executable installed by [mai_install()], and `mai` on the
#' `PATH`.
#'
#' @return `mai_path()` returns the path, or `NA` if none is found;
#'   `mai_available()` returns `TRUE` or `FALSE`.
#' @export
mai_path <- function() {
  candidates <- c(
    getOption("rmai.path", ""),
    Sys.getenv("MAI_PATH", ""),
    installed_path(),
    Sys.which("mai")
  )
  for (p in candidates) {
    if (nzchar(p) && file.exists(p)) return(normalizePath(p))
  }
  NA_character_
}

#' @rdname mai_path
#' @export
mai_available <- function() !is.na(mai_path())

installed_path <- function() {
  file.path(tools::R_user_dir("rmai", "data"), "bin", "mai")
}

require_mai <- function() {
  p <- mai_path()
  if (is.na(p)) {
    stop("can't find the mai executable. Run rmai::mai_install(), ",
         "or set options(rmai.path = ) or the MAI_PATH environment variable.",
         call. = FALSE)
  }
  p
}

#' Version of the mai source an installed executable was built from
#'
#' @return The git commit recorded by [mai_install()], or `NA`.
#' @export
mai_version <- function() {
  f <- file.path(tools::R_user_dir("rmai", "data"), "VERSION")
  if (file.exists(f)) readLines(f, n = 1) else NA_character_
}
