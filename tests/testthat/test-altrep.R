# These build mai's raw vector files in R, so they don't need mai itself.
mai_file <- function(value, type) {
  path <- tempfile(fileext = ".bin")
  write_raw(value, type, path)
  path
}

test_that("double, int and boolean files read back exactly as ALTREP", {
  x <- c(1.5, NA, NaN, -Inf, 1e-300)
  v <- mai_vec_from_file(mai_file(x, "double"), "double")
  expect_false(is.null(mai_vec_info(v)))
  expect_identical(v[2], NA_real_)
  expect_true(is.nan(v[3]))
  expect_identical(v[], x)
  expect_identical(sum(v, na.rm = TRUE), sum(x, na.rm = TRUE))

  i <- c(1L, NA, -3L)
  expect_identical(mai_vec_from_file(mai_file(i, "int"), "int")[], i)

  b <- c(TRUE, NA, FALSE)
  vb <- mai_vec_from_file(mai_file(b, "boolean"), "boolean")
  expect_identical(vb[2], NA)
  expect_identical(vb[], b)
  expect_identical(!vb, !b)
})

test_that("element reads don't need the whole vector", {
  v <- mai_vec_from_file(mai_file(as.double(1:1000), "double"), "double")
  expect_identical(v[[10]], 10)
  info <- mai_vec_info(v)
  expect_equal(info$dataptr, 0)
  expect_true(info$elt + info$region >= 1)
  expect_identical(v + 1, as.double(1:1000) + 1)
  expect_gte(mai_vec_info(v)$dataptr, 1)
})

test_that("arrays keep their shape and subset like R arrays", {
  a <- array(as.double(1:60), c(3, 4, 5))
  a[2, 3, 4] <- NA
  v <- mai_vec_from_file(mai_file(a, "double"), "double", dim(a))
  expect_identical(dim(v), dim(a))
  expect_identical(v[2:3, c(1, 4), 4:5], a[2:3, c(1, 4), 4:5])
  expect_identical(v[2, 3, ], a[2, 3, ])
  expect_identical(v[cbind(1:3, 1:3, 1:3)], a[cbind(1:3, 1:3, 1:3)])
  m <- matrix(c(TRUE, FALSE, NA, TRUE), 2)
  vm <- mai_vec_from_file(mai_file(m, "boolean"), "boolean", dim(m))
  expect_identical(vm[2, ], m[2, ])
})

test_that("x[i, j, k] is one request where R offers Extract_array_subset", {
  skip_if_not(mai_has_array_subset(), "R without Extract_array_subset")
  a <- array(as.double(1:60), c(3, 4, 5))
  v <- mai_vec_from_file(mai_file(a, "double"), "double", dim(a))
  expect_identical(v[1:2, 2:4, c(1, 5)], a[1:2, 2:4, c(1, 5)])
  info <- mai_vec_info(v)
  expect_equal(info$array_subset, 1)
  expect_equal(info$elt, 0)
  expect_equal(info$dataptr, 0)
  expect_identical(v[NA, 1, 1], a[NA, 1, 1])
})

test_that("modifying a copy leaves the original alone", {
  x <- c(1, 2, NA)
  v <- mai_vec_from_file(mai_file(x, "double"), "double")
  w <- v
  w[1] <- 100
  expect_identical(v[], x)
  expect_identical(w, c(100, 2, NA))
})

test_that("ALTREP vectors serialise as plain vectors", {
  a <- matrix(c(1L, NA, 3L, 4L), 2)
  v <- mai_vec_from_file(mai_file(a, "int"), "int", dim(a))
  f <- tempfile(fileext = ".rds")
  saveRDS(v, f)
  r <- readRDS(f)
  expect_identical(r, a)
  expect_null(mai_vec_info(r))
})

test_that("the file can go away once mapped", {
  path <- mai_file(c(1, 2, 3), "double")
  v <- mai_vec_from_file(path, "double")
  unlink(path)
  expect_identical(v[], c(1, 2, 3))
})

test_that("empty files give ordinary empty vectors", {
  expect_identical(mai_vec_from_file(mai_file(double(), "double"), "double"),
                   double())
})

test_that("mai_eval(.altrep = TRUE) returns the same values", {
  skip_if_not(mai_available(), "mai executable not found")
  skip_if(mai_run('print(typeof(read_vec))', error = "ignore")[1] == "",
          "mai is too old for mai_eval (needs read_vec)")
  x <- c(runif(50), NA)
  r <- mai_eval("x * 2.0", x = x, .altrep = TRUE)
  expect_false(is.null(mai_vec_info(r)))
  expect_identical(r[], x * 2)
  m <- matrix(1:6, 2)
  rm <- mai_eval("m * 10", m = m, .altrep = TRUE)
  expect_identical(dim(rm), dim(m))
  expect_identical(rm[2, 2:3], (m * 10L)[2, 2:3])
  b <- mai_eval("!b", b = c(TRUE, NA, FALSE), .altrep = TRUE)
  expect_identical(b[], c(FALSE, NA, TRUE))
  expect_null(mai_vec_info(mai_eval("x * 2.0", x = x)))
})
