# --- reverse lookups over the whole database -------------------------------

#' Perturbations that change a gene
#'
#' Reverse lookup: which perturbations (in any dataset) significantly change
#' this gene? This scans every dataset, so it answers questions like "what
#' knocks CDKN1A down?" rather than "what does this one experiment show?".
#'
#' @param gene Gene symbol, e.g. `"CDKN1A"`.
#' @param padj_lt Keep hits with adjusted p-value below this.
#' @param direction `"up"` (the gene is higher after the perturbation), `"down"`
#'   or `"both"`.
#' @param min_abs_log2fc Keep hits with at least this absolute log2 fold change.
#' @param sort_by `"padj"` or `"log2fc"`.
#' @param limit Maximum hits to return (1-500).
#' @param client An MCP client; defaults to [gpsadb_client()].
#' @return A `gpsadb_result`; `$data` has `dataset`, `perturbed_gene`, `method`,
#'   `cell_line`, `log2fc`, `padj`, `base_mean`. `$meta` has `total`, `n_up`,
#'   `n_down`.
#' @examplesIf interactive()
#' gpsadb_query_gene("CDKN1A", direction = "up", limit = 10)
#' @export
gpsadb_query_gene <- function(gene,
                              padj_lt = 0.05,
                              direction = c("both", "up", "down"),
                              min_abs_log2fc = 0,
                              sort_by = c("padj", "log2fc"),
                              limit = 50,
                              client = gpsadb_client()) {
  check_scalar(gene, "gene")
  res <- client$call_tool_data("query_gene", list(
    gene = gene,
    padj_lt = padj_lt,
    direction = match.arg(direction),
    min_abs_log2fc = min_abs_log2fc,
    sort_by = match.arg(sort_by),
    limit = limit
  ))
  new_gpsadb_result(
    records_to_tibble(res$hits),
    res[c("gene", "padj_lt", "total", "n_up", "n_down", "returned")]
  )
}

#' Perturbations that change a pathway
#'
#' Reverse lookup over the precomputed GSEA of every dataset: which
#' perturbations activate (`NES > 0`) or inhibit a gene set? Use
#' [gpsadb_search_gene_sets()] first to find the exact term name.
#'
#' @param term Gene set name, e.g. `"HALLMARK_HYPOXIA"`.
#' @param library Library of the term; searched in all libraries when `NULL`.
#' @param padj_lt Keep hits with adjusted p-value below this.
#' @param direction `"up"` (activated by the perturbation), `"down"` or
#'   `"both"`.
#' @param sort_by `"padj"` or `"nes"`.
#' @param limit Maximum hits to return (1-500).
#' @param client An MCP client; defaults to [gpsadb_client()].
#' @return A `gpsadb_result`; `$data` has `dataset`, `perturbed_gene`, `method`,
#'   `cell_line`, `nes`, `padj`. `$meta` has `total`, `n_up`, `n_down`.
#' @examplesIf interactive()
#' gpsadb_query_gene_set("HALLMARK_HYPOXIA", limit = 10)
#' @export
gpsadb_query_gene_set <- function(term,
                                  library = NULL,
                                  padj_lt = 0.05,
                                  direction = c("both", "up", "down"),
                                  sort_by = c("padj", "nes"),
                                  limit = 50,
                                  client = gpsadb_client()) {
  check_scalar(term, "term")
  res <- client$call_tool_data("query_gene_set", drop_nulls(list(
    term = term,
    library = library,
    padj_lt = padj_lt,
    direction = match.arg(direction),
    sort_by = match.arg(sort_by),
    limit = limit
  )))
  new_gpsadb_result(
    records_to_tibble(res$hits),
    res[c("library", "term", "set_size", "padj_lt", "total", "n_up", "n_down",
          "returned")]
  )
}

#' Search gene sets
#'
#' Find the exact term names to use with [gpsadb_query_gene_set()] and
#' [gpsadb_gsea()].
#'
#' @param query Words that must all occur in the term name, e.g.
#'   `"interferon gamma"`.
#' @param library Search one library; all when `NULL`.
#' @param contains_gene Only gene sets containing this gene symbol.
#' @param testable_only Only terms that have GSEA results in at least one
#'   dataset.
#' @param include_genes Include member genes (at most 50 terms).
#' @param limit Maximum terms to return (1-200).
#' @param client An MCP client; defaults to [gpsadb_client()].
#' @return A `gpsadb_result`; `$data` has `library`, `term`, `size`, `testable`
#'   and (optionally) `genes` as a list column.
#' @examplesIf interactive()
#' gpsadb_search_gene_sets(query = "hypoxia", limit = 10)
#' gpsadb_search_gene_sets(contains_gene = "HIF1A", limit = 5)
#' @export
gpsadb_search_gene_sets <- function(query = NULL,
                                    library = NULL,
                                    contains_gene = NULL,
                                    testable_only = FALSE,
                                    include_genes = FALSE,
                                    limit = 25,
                                    client = gpsadb_client()) {
  res <- client$call_tool_data("search_gene_sets", drop_nulls(list(
    query = query,
    library = library,
    contains_gene = contains_gene,
    testable_only = testable_only,
    include_genes = include_genes,
    limit = limit
  )))
  new_gpsadb_result(
    records_to_tibble(res$gene_sets),
    res[c("total", "returned")]
  )
}
