# gpsadb

R client for **GPSAdb** — genetic perturbation RNA-seq datasets with
precomputed differential expression and gene set enrichment.

Data comes from the database's public Model Context Protocol (MCP) endpoint
through the [`aisdk.mcp`](https://github.com/YuLab-SMU/aisdk.mcp) client, so
results land in R already tidy: every query returns a `gpsadb_result`, which
indexes like a data frame, hands you the tibble with `gpsadb_data()`, and keeps
the scalars that describe it (total hits, up/down counts, the web report URL)
in `gpsadb_meta()`.

No registration, no API key.

## Installation

```r
# install.packages("remotes")
remotes::install_github("YuLab-SMU/aisdk.mcp")  # transport
remotes::install_github("YuLab-SMU/gpsadb")     # this package
```

## Quick start

```r
library(gpsadb)

gpsadb_info()                    # release, counts, gene-set libraries

# 1. find datasets
tp53 <- gpsadb_search_datasets(perturbed_gene = "TP53", limit = 5)
gpsadb_meta(tp53, "total")       # 71 datasets perturb TP53
tp53[, c("id", "method", "cell_line")]

# 2. inspect one
ds <- gpsadb_dataset("D20305")
gpsadb_meta(ds, "title")         # D20305(Knock_down TP53 in U-2 OS)
gpsadb_data(ds)                  # samples, with group + phenotype

# 3. what the perturbation did
gpsadb_de("D20305", direction = "down", limit = 10)
gpsadb_gsea("D20305", limit = 10, include_core_genes = TRUE)

# 4. reverse lookups across every dataset
gpsadb_query_gene("CDKN1A", direction = "up")      # what raises CDKN1A?
gpsadb_query_gene_set("HALLMARK_HYPOXIA")          # what activates hypoxia?

# 5. signature matching against the reference set
gpsadb_biotrigger(c("HIF1A", "VEGFA", "SLC2A1", "PDK1", "BNIP3"))
gpsadb_fastgpsa(dataset_id = "D20305", direction = "opposite")
```

## Working with a result

Every query returns the same S3 object, so you learn this once:

```r
hits <- gpsadb_search_datasets(perturbed_gene = "TP53")

hits                  # the scalars first, the page below
nrow(hits)            # rows in this page
hits[1:3, ]           # ordinary data-frame indexing
hits[, c("id", "method")]
head(hits)

gpsadb_data(hits)     # the tibble itself, for dplyr
gpsadb_meta(hits)     # the scalars as a list
gpsadb_meta(hits, "total")
gpsadb_report_url(hits)   # the website report, when there is one
```

Indexing returns a plain tibble on purpose: the scalars describe the whole
query, so keeping them on a filtered subset would leave them quietly wrong.
`$data` and `$meta` still work if you prefer them.

## Functions

| Function | Question it answers |
|---|---|
| `gpsadb_info()` | What does the database hold, and what should I cite? |
| `gpsadb_search_datasets()` | Which datasets perturb gene X / use cell line Y? |
| `gpsadb_dataset()` | What is inside dataset D…? |
| `gpsadb_de()` | What changed in this perturbation? (DESeq2) |
| `gpsadb_gsea()` | Which pathways changed? (precomputed GSEA) |
| `gpsadb_test_gene_set()` | Run GSEA of my own gene set in one dataset |
| `gpsadb_query_gene()` | Which perturbations change gene X? (pages 500 at a time) |
| `gpsadb_query_gene_set()` | Which perturbations change pathway Y? |
| `gpsadb_search_gene_sets()` | What is the exact term name? |
| `gpsadb_biotrigger()` | Which perturbations activate/inhibit my gene set? |
| `gpsadb_fastgpsa()` | Which perturbations mimic or reverse my signature? |
| `gpsadb_downloads()` | Where are this dataset's DESeq2 results, counts and gene list? |
| `gpsadb_archives()` | Where are the bulk archives, with SHA-256? |

Lower-level access when a tool is not wrapped yet: `gpsadb_tool_catalog()`,
`gpsadb_raw(tool, arguments)`, `gpsadb_client()$call_tool_data(...)`.

## Bring your own results

`gpsadb_fastgpsa()` accepts a DESeq2-style table directly, so a signature you
computed here can be matched against 7,000+ perturbation datasets:

```r
de <- gpsadb_de("D20305", limit = 500)   # or your own DESeq2 output
gpsadb_fastgpsa(ranked_list = de[, c("gene", "log2fc")])
```

Ranked lists must hold **more than 200 genes** (the server rejects shorter,
p-value-truncated lists on purpose).

## Let an agent drive it

`gpsadb_tools()` returns the server's own tool definitions as `aisdk` tools —
names and JSON Schemas come straight from the endpoint, no second copy to keep
in sync:

```r
aisdk::generate_text(
  model = "deepseek:deepseek-chat",
  prompt = "Which perturbations look like hypoxia in U-2 OS, and in which cell lines?",
  tools = gpsadb_tools()
)
```

Tool names are flat across a whole session, and `query_gene` / `search_datasets`
are common enough to collide. When one agent talks to several MCP servers, give
each server a prefix or merge them with `aisdk.mcp::combine_mcp_tools()`:

```r
tools <- gpsadb_tools(prefix = "gpsadb")   # gpsadb__query_gene, ...
# or let aisdk.mcp merge several servers at once
combined <- aisdk.mcp::combine_mcp_tools(gpsadb = gpsadb_client(), other = other)
```

## From a question to a call

Turn a question into the R code that answers it:

```r
q <- gpsadb_intent("Which perturbations knock CDKN1A down in HeLa?")
q
#> {
#>     hits <- gpsadb_query_gene("CDKN1A", direction = "down", limit = 500)
#>     d <- gpsadb_data(hits)
#>     d[grepl("HeLa", d$cell_line), ]
#> }
```

`gpsadb_intent()` needs a model (`model =`, or
`options(gpsadb.intent_model = ...)`); everything else is offline. The value is
an ordinary R expression or `{ }` block: print it, store it, diff it.

Look at the code first, then run it with `eval()`:

```r
res <- eval(q)
nrow(res)   # 21 HeLa hits among the top 500
```

The wrappers check arguments locally, before any request is sent, so a wrong
value fails fast. Parts of the question that cannot be expressed are returned
as an `unmatched` attribute and printed, rather than turned into an argument
the server would reject.

## Reproducibility

The endpoint is a live service, so a number only means something together with
the call that produced it:

```r
res <- gpsadb_de("D20305", limit = 5)
gpsadb_provenance(res)[c("tool", "arguments", "release", "server_version", "queried_at")]
```

Every result carries the tool, the arguments, the data `release`, the server
build and the call time; `print()` ends with the release and build. To go
further, download the inputs and recompute:

```r
gpsadb_downloads("D20305")[, c("file", "url")]   # counts.csv, diffresults.csv, ...
gpsadb_archives("counts")[, c("name", "size_mb", "sha256")]
```

A worked example that puts a second MCP service next to this one (GPSAdb's
perturbation transcriptomes plus PDBe's experimental structures) is in
[`docs/combining-services.md`](docs/combining-services.md).

The server's tool contract is pinned in the package and checked on connect:
`gpsadb_contract_check()` lists a tool that disappeared, a tool the package does
not wrap yet, or a parameter that moved. Set
`options(gpsadb.check_contract = FALSE)` to silence the warning.

Errors are typed, so a script can react without matching text:
`gpsadb_not_found` (unknown dataset, gene not in GPSAdb),
`gpsadb_invalid_input`, `gpsadb_error`.

## How it connects

```
gpsadb_*()  ->  aisdk.mcp  ->  POST https://gpsadb.gzdlab.com/mcp
```

* The endpoint speaks **Streamable HTTP** (MCP 2025-06-18): one POST endpoint,
  no session, a plain JSON response, and both structured output
  (`structuredContent`) and text content.
* Point it elsewhere with `options(gpsadb.mcp_url = ...)` or `GPSADB_MCP_URL`,
  e.g. a mirror or a local service.
* The session client is cached for the R session (`gpsadb_client()`); call
  `gpsadb_disconnect()` to close it.

## Examples

[`examples/`](examples/) holds six standalone scripts, each answering one
question:

| Script | Question |
|---|---|
| [`01-explore-a-perturbation.R`](examples/01-explore-a-perturbation.R) | What did a perturbation do? |
| [`02-reverse-lookup.R`](examples/02-reverse-lookup.R) | Who changes my gene / pathway? |
| [`03-match-your-own-signature.R`](examples/03-match-your-own-signature.R) | Which perturbation does my signature look like? |
| [`04-batch-across-datasets.R`](examples/04-batch-across-datasets.R) | Is the effect consistent across datasets? |
| [`05-agent-tools.R`](examples/05-agent-tools.R) | Let a model decide what to query |
| [`06-intent-to-code.R`](examples/06-intent-to-code.R) | Turn a question into R code |

```bash
Rscript examples/03-match-your-own-signature.R
```

## Notes

* A result is one page. Compare `nrow(x)` with `gpsadb_meta(x, "total")`.
* `gpsadb_search_datasets()` pages 200 at a time; the reverse lookups
  (`query_gene`, `query_gene_set`) page 500 at a time. The signature searches do
  not page: narrow their filters instead.
* Nested fields (`core_genes`, `genes`, `attributes`) are list columns.
* Gene lists are sent as JSON arrays, so a single gene works as well as a
  vector.

## Citation

If you use the data, cite the database:

* Guo S. *et al.* (2026) GPSAdb 2.0, *Nucleic Acids Research* 54(D1):D1082–D1086.
  <doi:10.1093/nar/gkaf1077>
* Guo S. *et al.* (2022) GPSAdb, *Nucleic Acids Research*.
  <doi:10.1093/nar/gkac1066>

Data license: CC BY 4.0. This package is MIT.
