# gpsadb 0.1.4

* New `gpsadb_intent()`: [aisdk.mcp::mcp_intent()] with the GPSAdb client
  already filled in and the typed verbs spelled out for the model, so a sentence
  is enough and the code it writes returns tibbles. The code is returned as text
  and never run. `mcp_intent()` is re-exported for pipelines that also use
  another server.
* A result also exposes its columns through `$` (`res$gene`), so code written
  against a data frame mostly works; `$data` and `$meta` keep working.
* `gpsadb_query_gene()` and `gpsadb_query_gene_set()` gained `offset`: the server
  now pages reverse lookups 500 at a time, so the old "500 hits, no paging"
  limit is gone. The pinned tool contract was refreshed accordingly (the drift
  warning caught the server change).

# gpsadb 0.1.3

* Pipelines read better. `gpsadb_genes()` takes the gene symbols out of a result
  (it picks `gene`, then `perturbed_gene`, and can be told which column to use),
  and `gpsadb_call()` is now exported: the generic tool call with the client
  first, so `gpsadb_client() |> gpsadb_call("query_gene", list(gene = "CDKN1A"))`
  works. `gpsadb_raw()` remains the same call with the client last, which reads
  better interactively.
* New `gpsadb_intent()` turns a question into the R expression (or `{ }`
  block) that answers it, and reports the parts of the intent it could not
  express instead of inventing arguments. The result is plain R: `print()` it,
  diff it, then `eval()` it.

# gpsadb 0.1.2

* Every result records its provenance. `gpsadb_provenance()` returns the tool,
  the arguments, the data `release`, the server build, the protocol version and
  the time of the call (UTC); printed results end with the release and build.
  A live service moves under your feet, so a number quoted anywhere is only
  reproducible together with the call that produced it.
* `gpsadb_contract()` and `gpsadb_contract_check()` compare the server with the
  tool contract this version was written against, and `gpsadb_connect()` warns
  once per session when they diverge. The server does not announce changes
  (`listChanged: false`) and its `version` is a build id, not a version.
* Errors are typed: a missing dataset or gene raises `gpsadb_not_found`, a
  rejected argument raises `gpsadb_invalid_input`, everything else is a plain
  `gpsadb_error`. All of them carry `tool` and `arguments`.
* New `gpsadb_downloads()` and `gpsadb_archives()` wrap the server's download
  tool: per-dataset files (DESeq2 results, sample annotation, raw counts,
  ranked gene list) and the bulk archives with size, SHA-256 and a resumable
  command.
* `gpsadb_tools(prefix = )` prefixes tool names, for agents that talk to several
  MCP servers at once (`query_gene` is not a rare name).

# gpsadb 0.1.1

* Results are easier to use. `gpsadb_result` now behaves like its table for
  everyday work (`nrow()`, `dim()`, `names()`, `head()`, `tail()`, `x[i, j]`,
  `as_tibble()`), and the new accessors take out one part at a time:
  `gpsadb_data()`, `gpsadb_meta()` (with an optional field name that lists the
  available fields when you guess wrong) and `gpsadb_report_url()`. `$data` and
  `$meta` still work.

# gpsadb 0.1.0

* First release. Wraps the eleven tools of the GPSAdb Model Context Protocol
  endpoint as typed R functions returning `gpsadb_result` objects (tibble data
  plus a meta list): database overview, dataset search and metadata,
  per-dataset differential expression and precomputed GSEA, a full GSEA of a
  custom gene set, reverse lookups of a gene or pathway across every dataset,
  and the BioTrigger / fastGPSA signature searches.
* `gpsadb_fastgpsa()` also accepts a ranked list (e.g. a DESeq2 result), so a
  signature computed in R can be matched against the reference set.
* `gpsadb_tools()` exposes the server's tools as `aisdk` tools for agent use.
