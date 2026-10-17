skip_if_not(mai_available(), "mai executable not found")

test_that("mai_run returns printed output without the nil trailer", {
  out <- mai_run("print(sum(1:10))")
  expect_s3_class(out, "mai_output")
  expect_equal(as.character(out), "55")
  expect_null(attr(out, "error"))
})

test_that("drop_nil = FALSE keeps the trailer", {
  out <- mai_run("print(1)", drop_nil = FALSE)
  expect_equal(tail(as.character(out), 1), "<nil>")
})

test_that("multi-line code and typed functions work", {
  out <- mai_run(c("const sq = function(double x) : double x * x",
                   "print(sq(1.5))"))
  expect_equal(as.character(out), "2.25")
})

test_that("run-time errors are detected", {
  expect_warning(out <- mai_run('stop("boom")'), "stop: boom")
  expect_equal(attr(out, "error"), "stop: boom")
  expect_error(mai_run('stop("boom")', error = "stop"), "boom")
  expect_silent(mai_run('stop("boom")', error = "ignore"))
})

test_that("syntax errors are detected", {
  expect_warning(mai_run("print(1 +)"), "syntax error")
})

test_that("mai_source runs a file and resolves include relative to it", {
  d <- tempfile()
  dir.create(d)
  writeLines("const helper = function(x) x + 100", file.path(d, "lib.mai"))
  writeLines(c('include "lib.mai"', "print(helper(1))"), file.path(d, "main.mai"))
  expect_equal(as.character(mai_source(file.path(d, "main.mai"))), "101")
})

test_that("mai_compare times both languages", {
  res <- mai_compare("const run = function() sum(1:1000)",
                     "run <- function() sum(1:1000)", reps = 3)
  expect_equal(res$language, c("mai", "R"))
  expect_true(all(res$seconds >= 0))
  expect_named(res, c("language", "seconds", "speedup"))
})
