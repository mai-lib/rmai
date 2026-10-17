# Locate the mai executable

Searches, in order: \`getOption("rmai.path")\`, the \`MAI_PATH\`
environment variable, the executable installed by \[mai_install()\], and
\`mai\` on the \`PATH\`.

## Usage

``` r
mai_path()

mai_available()
```

## Value

\`mai_path()\` returns the path, or \`NA\` if none is found;
\`mai_available()\` returns \`TRUE\` or \`FALSE\`.
