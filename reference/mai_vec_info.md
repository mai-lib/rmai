# Inspect a mai ALTREP vector

With \`mai_eval(.altrep = TRUE)\` a result stays in mai's output, mapped
into memory, and R sees an ALTREP vector over it. \`mai_vec_info()\`
says whether \`x\` is such a vector and counts what R has asked it for:
single elements (\`elt\`), runs of elements (\`region\`), the whole data
pointer (\`dataptr\`, which most arithmetic needs) and, on an R built
with the proposed \`Extract_array_subset\` ALTREP method, whole \`x\[i,
j, ...\]\` requests (\`array_subset\`).

## Usage

``` r
mai_vec_info(x)

mai_has_array_subset()
```

## Arguments

- x:

  Any R object.

## Value

\`NULL\` if \`x\` is not a mai ALTREP vector, otherwise a list with
\`mapped\` (logical) and the counts \`elt\`, \`region\`, \`dataptr\` and
\`array_subset\`. \`mai_has_array_subset()\` returns \`TRUE\` when rmai
was built against an R that offers \`Extract_array_subset\`.

## Details

Integer results are used in place. Doubles are too, once mai's \`NA\`
values have been rewritten as R's (this happens in memory, on the first
full data request). Logical results are converted to R's 4-byte layout
on the first full data request.

## Examples

``` r
if (mai_available()) {
  m <- mai_eval("m * 2.0", m = matrix(runif(12), 3), .altrep = TRUE)
  m[2, 3:4]
  mai_vec_info(m)
}
#> $mapped
#> [1] TRUE
#> 
#> $elt
#> [1] 2
#> 
#> $region
#> [1] 0
#> 
#> $dataptr
#> [1] 0
#> 
#> $array_subset
#> [1] 0
#> 
```
