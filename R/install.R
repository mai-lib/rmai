#' Build and install the mai executable
#'
#' Downloads the mai source from GitHub (or uses a local checkout), builds it
#' with `make`, and copies the executable to a per-user directory where
#' [mai_path()] will find it. Building needs Linux with glibc, a C compiler,
#' GNU Bison 3, GNU M4, GNU readline and the valgrind headers.
#'
#' @param src A local checkout of `mai-lib/mai`, or `NULL` to download one.
#' @param ref Branch, tag or commit to download when `src` is `NULL`.
#' @param portable If `TRUE`, build without `-march=native`.
#' @param quiet Suppress build output.
#' @return The path of the installed executable, invisibly.
#' @export
mai_install <- function(src = NULL, ref = "main", portable = FALSE,
                        quiet = TRUE) {
  if (.Platform$OS.type != "unix" || Sys.info()[["sysname"]] != "Linux") {
    stop("mai currently builds only on Linux.", call. = FALSE)
  }
  if (is.null(src)) {
    tmp <- tempfile("mai-src")
    dir.create(tmp)
    tarball <- file.path(tmp, "mai.tar.gz")
    url <- sprintf("https://github.com/mai-lib/mai/archive/%s.tar.gz", ref)
    utils::download.file(url, tarball, quiet = quiet, mode = "wb")
    utils::untar(tarball, exdir = tmp)
    src <- list.dirs(tmp, recursive = FALSE)[1]
    version <- ref
  } else {
    src <- normalizePath(src, mustWork = TRUE)
    version <- tryCatch(
      system2("git", c("-C", shQuote(src), "rev-parse", "--short", "HEAD"),
              stdout = TRUE, stderr = FALSE),
      error = function(e) "local", warning = function(w) "local")
  }
  args <- c("-C", shQuote(src), "build", if (portable) "CTUNE=")
  out <- if (quiet) FALSE else ""
  status <- system2("make", args, stdout = out, stderr = out)
  bin <- file.path(src, "build", "main")
  if (!identical(status, 0L) || !file.exists(bin)) {
    stop("building mai failed; rerun with quiet = FALSE to see why.",
         call. = FALSE)
  }
  dest_dir <- tools::R_user_dir("rmai", "data")
  dir.create(file.path(dest_dir, "bin"), recursive = TRUE, showWarnings = FALSE)
  dest <- installed_path()
  file.copy(bin, dest, overwrite = TRUE)
  Sys.chmod(dest, "755")
  writeLines(version[1], file.path(dest_dir, "VERSION"))
  if (!quiet) message("installed mai to ", dest)
  invisible(dest)
}
