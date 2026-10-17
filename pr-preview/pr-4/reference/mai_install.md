# Build and install the mai executable

Downloads the mai source from GitHub (or uses a local checkout), builds
it with \`make\`, and copies the executable to a per-user directory
where \[mai_path()\] will find it. Building needs Linux with glibc, a C
compiler, GNU Bison 3, GNU M4, GNU readline and the valgrind headers.

## Usage

``` r
mai_install(src = NULL, ref = "main", portable = FALSE, quiet = TRUE)
```

## Arguments

- src:

  A local checkout of \`mai-lib/mai\`, or \`NULL\` to download one.

- ref:

  Branch, tag or commit to download when \`src\` is \`NULL\`.

- portable:

  If \`TRUE\`, build without \`-march=native\`.

- quiet:

  Suppress build output.

## Value

The path of the installed executable, invisibly.
