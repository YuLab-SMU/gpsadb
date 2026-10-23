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
