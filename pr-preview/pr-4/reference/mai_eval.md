# Evaluate mai code on R data and return an R value

\`mai_eval()\` passes R vectors and matrices into a mai program,
evaluates \`expr\` there, and returns the result to R. Data travels in
binary through temporary files (see \`read_vec()\` and \`write_vec()\`
in mai), so doubles come back exactly and large inputs are cheap.

## Usage

``` r
mai_eval(
  expr,
  ...,
  .setup = NULL,
  .wd = getwd(),
  .altrep = getOption("rmai.altrep", FALSE)
)
```

## Arguments

- expr:

  mai code, as a string.

- ...:

  Named R vectors, matrices or arrays (double, integer or logical) to
  make available in mai.

- .setup:

  mai code to run first, such as function definitions.

- .wd:

  Working directory for the mai process.

- .altrep:

  If \`TRUE\`, a vector or array result is not read into R but returned
  as an ALTREP vector over mai's output, mapped into memory. It behaves
  as an ordinary R vector; see \[mai_vec_info()\]. The default comes
  from \`getOption("rmai.altrep", FALSE)\`.

## Value

An R vector or array.

## Details

Each argument in \`...\` becomes a \`const\` global of the same name in
mai: a double vector becomes \`vector(double)\`, an integer vector
\`vector(int)\`, a logical vector \`vector(boolean)\`, and a matrix or
array of those becomes an \`array\` of the same shape. \`NA\` is
preserved.

\`expr\` is the body of a block, so it may hold several statements; its
last value is the result. A result that is an \`int\`, \`double\` or
\`boolean\` scalar, vector or array comes back as the matching R vector
or array. Anything else (a string, a list) comes back as its printed
text, with a warning. Output that \`expr\` prints itself is shown in the
console.

## Examples

``` r
if (mai_available()) {
  mai_eval("sum(sqrt(x))", x = c(1, 4, 9))

  mai_eval(
    "var n = length(x), s = 0.0
     for(int i = 1; i <= n; i = i + 1) s = s + x[i] * x[i]
     s",
    x = runif(1000)
  )

  m <- matrix(1:6, 2)
  mai_eval("m * 10", m = m)
}
#>      [,1] [,2] [,3]
#> [1,]   10   30   50
#> [2,]   20   40   60
```
