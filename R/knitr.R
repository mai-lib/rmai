#' knitr engine for mai chunks
#'
#' Loading rmai registers this engine with knitr, so R Markdown and Quarto
#' documents can contain chunks with the engine name `mai`. Each chunk runs in a
#' fresh mai process. To build on earlier chunks, give them a `label` and
#' list those labels in the chunk option `mai.include`, or `include` a file.
#'
#' Chunk options: the usual `echo`, `eval`, `include`, `results` and
#' `error`, plus `mai.include` (labels of earlier mai chunks to prepend) and
#' `mai.nil` (keep the trailing `<nil>`; default `FALSE`).
#'
#' @param options Chunk options, supplied by knitr.
#' @return Formatted chunk output, as from [knitr::engine_output()].
#' @export
eng_mai <- function(options) {
  code <- options$code
  pre <- options$mai.include
  if (length(pre)) {
    prev <- unlist(lapply(pre, function(l) mai_chunks$get(l)))
    run_code <- c(prev, code)
  } else {
    run_code <- code
  }
  if (!is.null(options$label)) mai_chunks$set(options$label, code)
  if (!isTRUE(options$eval)) {
    return(knitr::engine_output(options, code, ""))
  }
  wd <- if (!is.null(knitr::opts_knit$get("output.dir"))) {
    knitr::opts_knit$get("output.dir")
  } else getwd()
  out <- mai_run(run_code, drop_nil = !isTRUE(options$mai.nil),
                 error = if (isTRUE(options$error)) "ignore" else "stop",
                 wd = wd)
  knitr::engine_output(options, code, paste(out, collapse = "\n"))
}

mai_chunks <- local({
  store <- list()
  list(
    get = function(label) {
      if (is.null(store[[label]])) {
        stop("mai.include: no earlier mai chunk labelled '", label, "'",
             call. = FALSE)
      }
      store[[label]]
    },
    set = function(label, code) store[[label]] <<- code
  )
})

.onLoad <- function(libname, pkgname) {
  if (requireNamespace("knitr", quietly = TRUE)) {
    knitr::knit_engines$set(mai = eng_mai)
  }
}
