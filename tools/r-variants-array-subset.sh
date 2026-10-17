#!/usr/bin/env bash
# Test rmai's ALTREP results against R-devel with the proposed
# Extract_array_subset ALTREP method (github.com/mdsumner/r-variants).
#
#   docker run --rm -v "$PWD":/rmai ghcr.io/mdsumner/r-variants:array-subset \
#     bash /rmai/tools/r-variants-array-subset.sh
#
# The ALTREP tests build mai's vector files in R, so mai itself is not
# needed; the mai_eval() tests are skipped unless MAI_PATH is set.
set -euo pipefail
PKG="${1:-/rmai}"
cat /opt/R/variant/VARIANT.txt 2>/dev/null || true
Rscript -e 'if (!requireNamespace("testthat", quietly = TRUE)) install.packages("testthat")'
R CMD INSTALL --preclean "$PKG"
Rscript -e 'stopifnot(rmai::mai_has_array_subset())'
Rscript -e 'testthat::test_file(file.path(commandArgs(TRUE)[1], "tests/testthat/test-altrep.R"), package = "rmai", load_package = "installed", stop_on_failure = TRUE)' "$PKG"
Rscript -e '
library(rmai)
a <- array(runif(1e6), c(100, 100, 100))
f <- tempfile(); rmai:::write_raw(a, "double", f)
v <- rmai:::mai_vec_from_file(f, "double", dim(a))
y <- v[1:10, 1:10, 1:10]
stopifnot(identical(y, a[1:10, 1:10, 1:10]))
str(mai_vec_info(v))   # array_subset 1, elt 0
'
