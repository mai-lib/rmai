# rmai

[![R-CMD-check](https://github.com/mai-lib/rmai/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/mai-lib/rmai/actions/workflows/R-CMD-check.yaml)
[![Docs](https://img.shields.io/badge/docs-mai--lib.github.io%2Frmai-blue)](https://mai-lib.github.io/rmai/)

Use [mai](https://github.com/mai-lib/mai), the compiled statistical
computing language from Brendan McArdle's 2018 University of Auckland PhD
thesis, from R.

mai reads a lot like R, but compiles loops and function calls to fast
bytecode. rmai builds the mai executable, passes R data to it and brings
results back, and lets you write `{mai}` chunks in R Markdown and Quarto.
The [package site](https://mai-lib.github.io/rmai/) has the function
reference and the vignette,
[Using mai from R](https://mai-lib.github.io/rmai/articles/rmai.html).

```r
# install.packages("remotes")
remotes::install_github("mai-lib/rmai")
rmai::mai_install()        # download and build mai (Linux: needs gcc, bison, m4, readline, valgrind headers)
```

## Evaluate mai code on R data

```r
library(rmai)
x <- runif(1e6)

mai_eval("sum(sqrt(x))", x = x)

mai_eval(
  "var n = length(x), s = 0.0
   for(int i = 1; i <= n; i = i + 1) s = s + x[i] * x[i]
   s",
  x = x
)

mai_eval("m * 10.0", m = matrix(as.double(1:6), 2))
```

Named arguments become `const` globals in mai. Double, integer and logical
vectors, matrices and arrays go in and come back exactly, `NA` included.

## Results as ALTREP vectors

With `.altrep = TRUE` (or `options(rmai.altrep = TRUE)`), a vector or array
result is not read into R. It stays in mai's output, mapped into memory,
and R gets an ALTREP vector over it that behaves as an ordinary vector,
matrix or array.

```r
r <- mai_eval("m * 2.0", m = matrix(runif(1e6), 1000), .altrep = TRUE)
r[10, 1:5]          # reads 5 values, not a million
mai_vec_info(r)     # what R has asked for: elt, region, dataptr, array_subset
```

Integers are used in place. Doubles are too, once mai's `NA` values are
rewritten as R's on the first full data request. Logicals are converted to
R's layout on the first full data request, since mai stores them in one
byte.

On stock R, `r[i, j, k]` asks for one element at a time. On an R with the
proposed `Extract_array_subset` ALTREP method (the `array-subset` variant
in [mdsumner/r-variants](https://github.com/mdsumner/r-variants)), rmai
answers it in one call, and `mai_has_array_subset()` is `TRUE`.
`tools/r-variants-array-subset.sh` runs the ALTREP tests in that image.

Once rmai runs mai as a library rather than a separate process, the same
vectors can point at mai's memory directly.

## Run scripts and code

```r
mai_run("print(sum(1:100))")
mai_source("analysis.mai")
```

## Compare with R

```r
mai_compare(
  "const fib = function(n) if(n <= 2) 1 else fib(n - 2) + fib(n - 1)
   const run = function() fib(25)",
  "fib <- function(n) if (n <= 2) 1 else fib(n - 2) + fib(n - 1)
   run <- function() fib(25)"
)
```

## mai chunks in R Markdown and Quarto

Loading rmai registers a `mai` knitr engine:

````
```{r}
library(rmai)
```

```{mai, helpers}
const sq = function(double x) : double x * x
```

```{mai, mai.include = "helpers"}
print(sq(1.5))
```
````

Each chunk runs in a fresh mai process; `mai.include` names earlier chunks
to run first.

## Finding the executable

`mai_path()` looks at `options(rmai.path)`, then `MAI_PATH`, then the copy
installed by `mai_install()`, then `mai` on the `PATH`.

## Read before writing much mai

mai is not R. See [Differences from R](https://mai-lib.github.io/mai/differences-from-r/):
for example `7 / 2` is `3`, and assigning to an undeclared variable inside a
function sets a global.

## Licence

GPL-2, the same as mai.
