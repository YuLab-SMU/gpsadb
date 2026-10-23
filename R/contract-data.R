# Generated from the GPSAdb MCP endpoint. Do not edit by hand:
#   Rscript tools/dev-contract.R
# 2026-10-23  server gpsadb 1eee9bf
gpsadb_contract_expected <- list(
  list(name = "get_database_info", params = character(0), required = character(0)),
  list(name = "search_datasets", params = c("query", "perturbed_gene", "method", "cell_line", "tissue", "oncotree_code", "reference_only", "limit", "offset"), required = character(0)),
  list(name = "get_dataset", params = c("dataset_id"), required = c("dataset_id")),
  list(name = "get_download_links", params = c("dataset_ids", "kind"), required = character(0)),
  list(name = "get_differential_expression", params = c("dataset_id", "genes", "direction", "padj_lt", "min_abs_log2fc", "sort_by", "limit"), required = c("dataset_id")),
  list(name = "get_gsea_results", params = c("dataset_id", "library", "terms", "direction", "padj_lt", "limit", "include_core_genes"), required = c("dataset_id")),
  list(name = "query_gene", params = c("gene", "padj_lt", "direction", "min_abs_log2fc", "sort_by", "limit", "offset"), required = c("gene")),
  list(name = "query_gene_set", params = c("term", "library", "padj_lt", "direction", "sort_by", "limit", "offset"), required = c("term")),
  list(name = "search_gene_sets", params = c("query", "library", "contains_gene", "testable_only", "include_genes", "limit"), required = character(0)),
  list(name = "run_biotrigger", params = c("genes", "effect", "limit"), required = c("genes")),
  list(name = "run_fastgpsa", params = c("up_genes", "down_genes", "ranked_list", "dataset_id", "direction", "limit"), required = character(0)),
  list(name = "test_gene_set_in_dataset", params = c("dataset_id", "genes"), required = c("dataset_id", "genes"))
)
