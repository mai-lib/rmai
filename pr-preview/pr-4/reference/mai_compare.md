# Time the same computation in mai and in R

Runs \`mai_code\` and \`r_code\` \`reps\` times each after one warm-up,
and reports the median elapsed seconds. Each side must define a function
\`run()\` taking no arguments; only the calls to \`run()\` are timed,
not start-up or data set-up.

## Usage

``` r
mai_compare(mai_code, r_code, reps = 5)
```

## Arguments

- mai_code:

  mai code defining \`run()\`.

- r_code:

  R code (a string) defining \`run()\`.

- reps:

  Number of timed repetitions.

## Value

A data frame with columns \`language\`, \`seconds\` and \`speedup\` (R
seconds over mai seconds).

## Examples

``` r
if (mai_available()) {
  mai_compare(
    "const run = function() { var s = 0.0
       for(int i = 1; i <= 1000000; i = i + 1) s = s + 1.0 / i
       s }",
    "run <- function() { s <- 0; for (i in 1:1e6) s <- s + 1 / i; s }",
    reps = 3)
}
#>   language  seconds  speedup
#> 1      mai 0.008151 1.962949
#> 2        R 0.016000 1.000000
```
