#' Evaluate mai code on R data and return an R value
#'
#' `mai_eval()` passes R vectors and matrices into a mai program, evaluates
#' `expr` there, and returns the result to R. Data travels in binary through
#' temporary files (see `read_vec()` and `write_vec()` in mai), so doubles
#' come back exactly and large inputs are cheap.
#'
#' Each argument in `...` becomes a `const` global of the same name in mai:
#' a double vector becomes `vector(double)`, an integer vector
#' `vector(int)`, a logical vector `vector(boolean)`, and a matrix or array
#' of those becomes an `array` of the same shape. `NA` is preserved.
#'
#' `expr` is the body of a block, so it may hold several statements; its
#' last value is the result. A result that is an `int`, `double` or
#' `boolean` scalar, vector or array comes back as the matching R vector or
#' array. Anything else (a string, a list) comes back as its printed text,
#' with a warning. Output that `expr` prints itself is shown in the console.
#'
#' @param expr mai code, as a string.
#' @param ... Named R vectors, matrices or arrays (double, integer or
#'   logical) to make available in mai.
#' @param .setup mai code to run first, such as function definitions.
#' @param .wd Working directory for the mai process.
#' @return An R vector or array.
#' @examples
#' if (mai_available()) {
#'   mai_eval("sum(sqrt(x))", x = c(1, 4, 9))
#'
#'   mai_eval(
#'     "var n = length(x), s = 0.0
#'      for(int i = 1; i <= n; i = i + 1) s = s + x[i] * x[i]
#'      s",
#'     x = runif(1000)
#'   )
#'
#'   m <- matrix(1:6, 2)
#'   mai_eval("m * 10", m = m)
#' }
#' @export
mai_eval <- function(expr, ..., .setup = NULL, .wd = getwd()) {
  data <- list(...)
  if (length(data) && (is.null(names(data)) || any(!nzchar(names(data))))) {
    stop("every argument in ... must be named.", call. = FALSE)
  }
  dir <- tempfile("rmai")
  dir.create(dir)
  on.exit(unlink(dir, recursive = TRUE), add = TRUE)
  prelude <- unlist(Map(function(name, value) {
    put_value(name, value, file.path(dir, paste0(name, ".bin")))
  }, names(data), data), use.names = FALSE)
  res_file <- file.path(dir, "result.bin")
  code <- c(
    prelude,
    .setup,
    "const rmai_result = {",
    expr,
    "}",
    emit_code(res_file)
  )
  out <- mai_run(code, error = "stop", wd = .wd)
  at <- match("\"rmai:result\"", out)
  if (is.na(at)) {
    stop("mai did not produce a result:\n", paste(out, collapse = "\n"),
         call. = FALSE)
  }
  if (at > 1) cat(out[seq_len(at - 1)], sep = "\n")
  info <- out[-seq_len(at)]
  get_value(info, res_file)
}

mai_type <- function(value) {
  switch(typeof(value),
         double = "double",
         integer = "int",
         logical = "boolean",
         stop("can't pass an object of type '", typeof(value), "' to mai; ",
              "use double, integer or logical vectors and arrays.",
              call. = FALSE))
}

eltsize <- c(double = 8L, int = 4L, boolean = 1L)

put_value <- function(name, value, path) {
  if (!grepl("^[A-Za-z_][A-Za-z0-9_.]*$", name)) {
    stop("'", name, "' is not a usable mai variable name.", call. = FALSE)
  }
  type <- mai_type(value)
  write_raw(value, type, path)
  p <- encode_string(path)
  dims <- dim(value)
  if (is.null(dims)) {
    return(sprintf('const vector(%s) %s = read_vec(%s, type(%s))',
                   type, name, p, type))
  }
  # arrays travel flat and are reshaped by a compiled loop in mai
  fill <- switch(type, double = "0.0", int = "0", boolean = "false")
  c(sprintf('const array(%s) %s = array(type(%s), vec(%s), %s)',
            type, name, type, paste(dims, collapse = ", "), fill),
    "{",
    sprintf('    let flat = read_vec(%s, type(%s))', p, type),
    sprintf('    for(int i = 1; i <= length(flat); i = i + 1) %s[i] = flat[i]',
            name),
    "}")
}

# mai's double NA is a NaN with payload 0xdeadbeef; R's NA_real_ is another
# NaN, so translate explicitly in both directions.
mai_na_bytes <- as.raw(c(0xef, 0xbe, 0xad, 0xde, 0x00, 0x00, 0xf8, 0x7f))

write_raw <- function(value, type, path) {
  con <- file(path, "wb")
  on.exit(close(con))
  value <- as.vector(value)
  switch(type,
    double = {
      na <- which(is.na(value) & !is.nan(value))
      if (!length(na)) {
        writeBin(as.double(value), con, size = 8, endian = "little")
      } else {
        r <- writeBin(as.double(value), raw(), size = 8, endian = "little")
        for (i in na) r[(i - 1) * 8 + 1:8] <- mai_na_bytes
        writeBin(r, con)
      }
    },
    int = writeBin(as.integer(value), con, size = 4),
    boolean = writeBin(as.raw(ifelse(is.na(value), 255L, as.integer(value))), con)
  )
}

read_raw <- function(path, type) {
  n <- file.size(path) / eltsize[[type]]
  switch(type,
    double = {
      x <- readBin(path, "double", n, size = 8, endian = "little")
      nan <- which(is.nan(x))
      if (length(nan)) {
        r <- readBin(path, "raw", n * 8)
        for (i in nan) {
          if (identical(r[(i - 1) * 8 + 1:8], mai_na_bytes)) x[i] <- NA_real_
        }
      }
      x
    },
    int = readBin(path, "integer", n, size = 4),
    boolean = {
      b <- as.integer(readBin(path, "raw", n))
      ifelse(b == 255L, NA, b != 0L)
    }
  )
}

encode_string <- function(x) {
  paste0('"', gsub('(["\\\\])', "\\\\\\1", x), '"')
}

emit_code <- function(path) {
  p <- encode_string(path)
  c(
    'print("rmai:result")',
    "{",
    "    let t = typeof(rmai_result)",
    "    print(t)",
    "    if(subtype(t, type(array)) || subtype(t, type(vector))) {",
    "        if(subtype(t, type(array))) print(shape(rmai_result))",
    "        let e = elt_type(t)",
    "        if(subtype(e, type(double)) || subtype(e, type(int)) || subtype(e, type(boolean)))",
    sprintf("            write_vec(rmai_result, %s)", p),
    "        else print(rmai_result)",
    "    } else if(subtype(t, type(double)) || subtype(t, type(int)) || subtype(t, type(boolean)))",
    sprintf("        write_vec(vec(rmai_result), %s)", p),
    "    else print(rmai_result)",
    "}"
  )
}

get_value <- function(info, path) {
  type_line <- info[1]
  elt <- sub("^(vector|array)\\((.*)\\)$", "\\2", type_line)
  if (!file.exists(path) || !elt %in% names(eltsize)) {
    warning("mai returned a ", type_line, ", which has no R equivalent; ",
            "returning its printed form.", call. = FALSE)
    return(paste(info[-1], collapse = "\n"))
  }
  x <- read_raw(path, elt)
  if (startsWith(type_line, "array(")) {
    shape_line <- info[3]
    dims <- as.integer(strsplit(trimws(sub("^\\[[0-9 ]+\\]", "", shape_line)),
                                "[[:space:]]+")[[1]])
    dim(x) <- dims
  }
  x
}
