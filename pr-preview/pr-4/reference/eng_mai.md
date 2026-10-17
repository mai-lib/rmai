# knitr engine for mai chunks

Loading rmai registers this engine with knitr, so R Markdown and Quarto
documents can contain chunks with the engine name \`mai\`. Each chunk
runs in a fresh mai process. To build on earlier chunks, give them a
\`label\` and list those labels in the chunk option \`mai.include\`, or
\`include\` a file.

## Usage

``` r
eng_mai(options)
```

## Arguments

- options:

  Chunk options, supplied by knitr.

## Value

Formatted chunk output, as from \[knitr::engine_output()\].

## Details

Chunk options: the usual \`echo\`, \`eval\`, \`include\`, \`results\`
and \`error\`, plus \`mai.include\` (labels of earlier mai chunks to
prepend) and \`mai.nil\` (keep the trailing \`\<nil\>\`; default
\`FALSE\`).
