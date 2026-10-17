skip_if_not(mai_available(), "mai executable not found")
skip_if(mai_run('print(typeof(read_vec))', error = "ignore")[1] == "",
        "mai is too old for mai_eval (needs read_vec)")

test_that("doubles round-trip exactly, including NA and tiny values", {
  x <- c(runif(100), NA, 1e-300, -2.5)
  expect_identical(mai_eval("x", x = x), x)
  expect_identical(mai_eval("x * 2.0", x = x), x * 2)
})

test_that("integer and logical vectors keep their types and NAs", {
  expect_identical(mai_eval("i + 1", i = c(1L, NA, 3L)), c(2L, NA, 4L))
  expect_identical(mai_eval("!b", b = c(TRUE, NA, FALSE)), c(FALSE, NA, TRUE))
})

test_that("scalars come back as length-one vectors", {
  expect_identical(mai_eval("sum(x)", x = c(1, 2, 3.5)), 6.5)
  expect_identical(mai_eval("length(x)", x = 1:7), 7L)
})

test_that("matrices keep their shape", {
  m <- matrix(as.double(1:6), 2)
  expect_identical(mai_eval("m * 10.0", m = m), m * 10)
  expect_identical(mai_eval("shape(m)", m = m), c(2L, 3L))
})

test_that("multi-statement expressions and .setup work", {
  res <- mai_eval(
    "var n = length(x), s = 0.0
     for(int i = 1; i <= n; i = i + 1) s = s + sq(x[i])
     s",
    x = c(1, 2, 3),
    .setup = "const sq = function(double v) : double v * v")
  expect_identical(res, 14)
})

test_that("printed output is shown and non-numeric results warn", {
  expect_output(res <- mai_eval('print("hi"); 1'), '"hi"')
  expect_identical(res, 1L)
  expect_warning(s <- mai_eval('"text"'), "no R equivalent")
  expect_identical(s, '"text"')
})

test_that("bad input is rejected in R", {
  expect_error(mai_eval("1", 1:3), "must be named")
  expect_error(mai_eval("1", x = "a"), "can't pass")
  expect_error(mai_eval("stop(\"no\")"), "no")
})
