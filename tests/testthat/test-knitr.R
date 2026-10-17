skip_if_not(mai_available(), "mai executable not found")
skip_if_not_installed("knitr")

test_that("mai chunks knit, and mai.include chains them", {
  rmd <- tempfile(fileext = ".Rmd")
  writeLines(c(
    "```{r, include = FALSE}",
    "library(rmai)",
    "```",
    "```{mai, defs}",
    "const sq = function(double x) : double x * x",
    "```",
    "```{mai, use, mai.include = 'defs'}",
    "print(sq(3.0))",
    "```"
  ), rmd)
  md <- knitr::knit(rmd, output = tempfile(fileext = ".md"), quiet = TRUE)
  txt <- readLines(md)
  expect_true(any(grepl("^## 9.0$", txt)))
})
