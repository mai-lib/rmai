# Using mai from R

[mai](https://github.com/mai-lib/mai) is the compiled statistical
computing language from Brendan McArdle’s 2018 University of Auckland
PhD thesis. It reads like R, but compiles loops and function calls to
fast bytecode. rmai lets you use it from R.

## Getting the executable

``` r

rmai::mai_install()          # downloads mai-lib/mai and builds it (Linux)
rmai::mai_install("~/src/mai", portable = TRUE)   # or from a local checkout
```

[`mai_path()`](https://mai-lib.github.io/rmai/reference/mai_path.md)
shows which executable rmai will use. You can also point it at one with
`options(rmai.path = "/path/to/mai")` or the `MAI_PATH` environment
variable.

``` r

mai_available()
#> [1] TRUE
```

## Running code

``` r

mai_run("print(sum(1:100))")
#> 5050

mai_run(c(
  "const harmonic = function(int n) : double {",
  "    var s = 0.0",
  "    for(int i = 1; i <= n; i = i + 1) s = s + 1.0 / i",
  "    s",
  "}",
  "print(harmonic(1000000))"
))
#> 14.392727
```

Errors in mai code become R warnings by default (`error = "stop"` makes
them R errors):

``` r

out <- mai_run('stop("something went wrong")')
#> Warning: mai: stop: something went wrong
attr(out, "error")
#> [1] "stop: something went wrong"
```

`mai_source("script.mai")` runs a file, with `include` paths resolved
relative to the file’s directory.

## Passing R data in and getting R values back

[`mai_eval()`](https://mai-lib.github.io/rmai/reference/mai_eval.md) is
the most natural way to use mai from R. Named arguments become `const`
globals in mai, the expression is evaluated there, and the result comes
back as an R vector or array. Data moves in binary, so doubles are exact
and large inputs are cheap.

``` r

x <- runif(1e5)
mai_eval("sum(sqrt(x))", x = x)
#> [1] 66643.22
sum(sqrt(x))
#> [1] 66643.22
```

The expression can be a whole block. Here a loop that would be slow in
plain R runs as compiled mai, with a helper defined in `.setup`:

``` r

mai_eval(
  "var n = length(x), s = 0.0
   for(int i = 1; i <= n; i = i + 1) s = s + sq(x[i] - 0.5)
   s / n",
  x = x,
  .setup = "const sq = function(double v) : double v * v"
)
#> [1] 0.08314382
```

Integer and logical vectors keep their types, matrices keep their shape,
and `NA` survives the trip:

``` r

m <- matrix(c(1, NA, 3, 4), 2)
mai_eval("m * 10.0", m = m)
#>      [,1] [,2]
#> [1,]   10   30
#> [2,]   NA   40
mai_eval("!b", b = c(TRUE, NA, FALSE))
#> [1] FALSE    NA  TRUE
```

For large results, `.altrep = TRUE` (or `options(rmai.altrep = TRUE)`)
leaves the result in mai’s output file, mapped into memory, and returns
an ALTREP vector over it, so R reads only the elements you use. See
[`?mai_eval`](https://mai-lib.github.io/rmai/reference/mai_eval.md) and
[`?mai_vec_info`](https://mai-lib.github.io/rmai/reference/mai_vec_info.md).

## mai chunks in R Markdown and Quarto

Loading rmai registers a `mai` knitr engine. Each chunk runs in a fresh
mai process. To build on an earlier chunk, label it and name it in
`mai.include`:

    ```{mai, helpers}
    const dotprod = function(x, y) sum(x * y)
    const norm = function(x) sqrt(dotprod(x, x))
    ```

``` mai
const dotprod = function(x, y) sum(x * y)
const norm = function(x) sqrt(dotprod(x, x))
```

    ```{mai, mai.include = "helpers"}
    print(norm(vec(3.0, 4.0)))
    ```

``` mai
print(norm(vec(3.0, 4.0)))
#> 5.0
```

## Comparing with R

[`mai_compare()`](https://mai-lib.github.io/rmai/reference/mai_compare.md)
times a `run()` function defined in each language:

``` r

mai_compare(
  "const fib = function(n) if(n <= 2) 1 else fib(n - 2) + fib(n - 1)
   const run = function() fib(24)",
  "fib <- function(n) if (n <= 2) 1 else fib(n - 2) + fib(n - 1)
   run <- function() fib(24)",
  reps = 3
)
#>   language  seconds  speedup
#> 1      mai 0.010059 2.982404
#> 2        R 0.030000 1.000000
```

See the [mai documentation](https://mai-lib.github.io/mai/), especially
[Differences from R](https://mai-lib.github.io/mai/differences-from-r/),
before writing much mai: for example `7 / 2` is `3`, and assigning to an
undeclared variable inside a function sets a global.
