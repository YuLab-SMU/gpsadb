# gpsadb

R client for **GPSAdb** — genetic perturbation RNA-seq datasets with
precomputed differential expression and gene set enrichment.

Data comes from the database's public Model Context Protocol (MCP) endpoint
through the [`aisdk.mcp`](https://github.com/YuLab-SMU/aisdk.mcp) client, so
results land in R already tidy: every query returns a `gpsadb_result` whose
`$data` is a tibble and whose `$meta` holds the scalars that describe it
(total hits, up/down counts, the web report URL).

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
tp53$meta$total                  # 71 datasets perturb TP53
tp53$data

# 2. inspect one
ds <- gpsadb_dataset("D20305")
ds$meta$title                    # D20305(Knock_down TP53 in U-2 OS)
ds$data                          # samples, with group + phenotype

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

## Functions

| Function | Question it answers |
|---|---|
| `gpsadb_info()` | What does the database hold, and what should I cite? |
| `gpsadb_search_datasets()` | Which datasets perturb gene X / use cell line Y? |
| `gpsadb_dataset()` | What is inside dataset D…? |
| `gpsadb_de()` | What changed in this perturbation? (DESeq2) |
| `gpsadb_gsea()` | Which pathways changed? (precomputed GSEA) |
| `gpsadb_test_gene_set()` | Run GSEA of my own gene set in one dataset |
| `gpsadb_query_gene()` | Which perturbations change gene X? |
| `gpsadb_query_gene_set()` | Which perturbations change pathway Y? |
| `gpsadb_search_gene_sets()` | What is the exact term name? |
| `gpsadb_biotrigger()` | Which perturbations activate/inhibit my gene set? |
| `gpsadb_fastgpsa()` | Which perturbations mimic or reverse my signature? |

Lower-level access when a tool is not wrapped yet: `gpsadb_tool_catalog()`,
`gpsadb_raw(tool, arguments)`, `gpsadb_client()$call_tool_data(...)`.

## Bring your own results

`gpsadb_fastgpsa()` accepts a DESeq2-style table directly, so a signature you
computed here can be matched against 7,000+ perturbation datasets:

```r
de <- gpsadb_de("D20305", limit = 500)$data   # or your own DESeq2 output
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

[`examples/`](examples/) holds five standalone scripts, each answering one
question:

| Script | Question |
|---|---|
| [`01-explore-a-perturbation.R`](examples/01-explore-a-perturbation.R) | What did a perturbation do? |
| [`02-reverse-lookup.R`](examples/02-reverse-lookup.R) | Who changes my gene / pathway? |
| [`03-match-your-own-signature.R`](examples/03-match-your-own-signature.R) | Which perturbation does my signature look like? |
| [`04-batch-across-datasets.R`](examples/04-batch-across-datasets.R) | Is the effect consistent across datasets? |
| [`05-agent-tools.R`](examples/05-agent-tools.R) | Let a model decide what to query |

```bash
Rscript examples/03-match-your-own-signature.R
```

## Notes

* `$data` is one page. Compare `nrow($data)` with `$meta$total`.
* Only `gpsadb_search_datasets()` pages (`offset=`, 200 per request). The
  reverse lookups (`query_gene`, `query_gene_set`) and the signature searches
  cap at 500 hits with no `offset`, so narrow the filters
  (`padj_lt`, `min_abs_log2fc`) instead of paging.
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
