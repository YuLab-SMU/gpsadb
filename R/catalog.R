# --- catalog ---------------------------------------------------------------

#' Search perturbation datasets
#'
#' Filters are optional and combined with AND; text filters ignore case and
#' punctuation.
#'
#' @param query Words matched against ID, perturbed gene, cell line, tissue,
#'   accession and data source; every word must match.
#' @param perturbed_gene Gene symbol(s), comma separated, matched exactly
#'   (case-insensitive).
#' @param method Perturbation method: one of `"shRNA"`, `"siRNA"`, `"knockdown"`,
#'   `"knockout"`, `"CRISPRi"`, `"inhibit"`, `"mutation"` (`"knockdown"` means
#'   shRNA or siRNA).
#' @param cell_line Part of the cell line name, e.g. `"HeLa"`, `"MCF7"`.
#' @param tissue Part of the tissue site the cell line came from, e.g.
#'   `"Liver"`.
#' @param oncotree_code OncoTree cancer type code(s), e.g. `"BRCA"`, `"LUAD"`;
#'   comma separated for several.
#' @param reference_only Only datasets in the reference set used by
#'   [gpsadb_biotrigger()] and [gpsadb_fastgpsa()].
#' @param limit Maximum datasets to return (1-200).
#' @param offset Skip this many matches (paging).
#' @param client An MCP client; defaults to [gpsadb_client()].
#' @return A [gpsadb_result]: `gpsadb_data()` has one row per dataset,
#'   `gpsadb_meta(x, "total")` the number of matches overall.
#' @examplesIf interactive()
#' gpsadb_search_datasets(perturbed_gene = "TP53", limit = 5)
#' gpsadb_search_datasets(method = "CRISPRi", cell_line = "HeLa", limit = 5)
#' @export
gpsadb_search_datasets <- function(query = NULL,
                                   perturbed_gene = NULL,
                                   method = NULL,
                                   cell_line = NULL,
                                   tissue = NULL,
                                   oncotree_code = NULL,
                                   reference_only = NULL,
                                   limit = 50,
                                   offset = 0,
                                   client = gpsadb_client()) {
  res <- client$call_tool_data("search_datasets", drop_nulls(list(
    query = query,
    perturbed_gene = perturbed_gene,
    method = method,
    cell_line = cell_line,
    tissue = tissue,
    oncotree_code = oncotree_code,
    reference_only = reference_only,
    limit = limit,
    offset = offset
  )))
  new_gpsadb_result(
    records_to_tibble(res$datasets, cols = c(
      "id", "perturbed_gene", "method", "cell_line", "tissue",
      "oncotree_code", "n_samples", "n_up", "n_down", "in_reference"
    )),
    list(total = res$total, offset = res$offset, returned = res$returned)
  )
}

#' Metadata of one dataset
#'
#' `gpsadb_data()` holds the samples with their group (`control` / `treat`) and
#' phenotype attributes; `gpsadb_meta()` holds the dataset-level fields:
#' perturbed gene, method, cell line and tissue, data source and accession,
#' download links, and the website URL.
#'
#' @param dataset_id Dataset ID, e.g. `"D20305"`.
#' @param client An MCP client; defaults to [gpsadb_client()].
#' @return A `gpsadb_result`.
#' @examplesIf interactive()
#' ds <- gpsadb_dataset("D20305")
#' gpsadb_meta(ds, "title")
#' gpsadb_data(ds)
#' @export
gpsadb_dataset <- function(dataset_id, client = gpsadb_client()) {
  check_dataset_id(dataset_id)
  res <- client$call_tool_data("get_dataset", list(dataset_id = dataset_id))
  samples <- res$samples
  res$samples <- NULL
  new_gpsadb_result(records_to_tibble(samples), res)
}

# --- per-dataset measurements ---------------------------------------------

#' Differential expression of one dataset
#'
#' DESeq2 results for perturbation versus control: `log2fc > 0` means the gene
#' is higher after the perturbation.
#'
#' @param dataset_id Dataset ID, e.g. `"D20305"`.
#' @param genes Optional gene symbols or Ensembl IDs to look up (at most 500).
#'   When given, the filters below are ignored.
#' @param direction `"up"`, `"down"` or `"both"`.
#' @param padj_lt Keep genes with adjusted p-value below this.
#' @param min_abs_log2fc Keep genes with at least this absolute log2 fold
#'   change.
#' @param sort_by `"padj"` or `"log2fc"` (`log2fc` sorts by fold change in the
#'   chosen direction, by absolute value for `"both"`).
#' @param limit Maximum genes to return (1-500).
#' @param client An MCP client; defaults to [gpsadb_client()].
#' @return A [gpsadb_result]; its data has `gene`, `gene_id`, `log2fc`, `padj`,
#'   `pvalue`, `base_mean`.
#' @examplesIf interactive()
#' gpsadb_de("D20305", direction = "down", limit = 10)
#' gpsadb_de("D20305", genes = c("MDM2", "CDKN1A"))
#' @export
gpsadb_de <- function(dataset_id,
                      genes = NULL,
                      direction = c("both", "up", "down"),
                      padj_lt = 0.05,
                      min_abs_log2fc = 0,
                      sort_by = c("padj", "log2fc"),
                      limit = 25,
                      client = gpsadb_client()) {
  check_dataset_id(dataset_id)
  res <- client$call_tool_data("get_differential_expression", drop_nulls(list(
    dataset_id = dataset_id,
    genes = as_array(genes),
    direction = match.arg(direction),
    padj_lt = padj_lt,
    min_abs_log2fc = min_abs_log2fc,
    sort_by = match.arg(sort_by),
    limit = limit
  )))
  new_gpsadb_result(
    records_to_tibble(res$genes),
    pick_meta(res, c("dataset_id", "title", "n_genes_tested", "padj_lt",
          "n_up", "n_down", "returned", "url"))
  )
}

#' Precomputed gene set enrichment of one dataset
#'
#' GSEA computed by the database (clusterProfiler, genes ranked by log2 fold
#' change). `NES > 0` means the gene set is enriched among genes the
#' perturbation up-regulates.
#'
#' @param dataset_id Dataset ID, e.g. `"D20305"`.
#' @param library Gene-set library: `"Hallmarks"` (default), `"biocarta"`,
#'   `"kegg_legacy"`, `"kegg_medicus"`, `"pid"`, `"reactome"`,
#'   `"wikipathways"`, `"Tftargets"` or `"all"`.
#' @param terms Term names to look up (at most 200). When given, `direction` and
#'   `padj_lt` are ignored.
#' @param direction `"up"` (NES > 0), `"down"` (NES < 0) or `"both"`.
#' @param padj_lt Keep terms with adjusted p-value below this.
#' @param limit Maximum terms to return (1-200).
#' @param include_core_genes Add the leading-edge genes of each term as a list
#'   column.
#' @param client An MCP client; defaults to [gpsadb_client()].
#' @return A [gpsadb_result]; its data has `term`, `nes`, `es`, `padj`,
#'   `pvalue`, `set_size`, `leading_edge`, `n_core_genes` and (optionally)
#'   `core_genes`.
#' @examplesIf interactive()
#' gpsadb_gsea("D20305", limit = 10, include_core_genes = TRUE)
#' @export
gpsadb_gsea <- function(dataset_id,
                        library = "Hallmarks",
                        terms = NULL,
                        direction = c("both", "up", "down"),
                        padj_lt = 0.05,
                        limit = 25,
                        include_core_genes = FALSE,
                        client = gpsadb_client()) {
  check_dataset_id(dataset_id)
  res <- client$call_tool_data("get_gsea_results", drop_nulls(list(
    dataset_id = dataset_id,
    library = library,
    terms = as_array(terms),
    direction = match.arg(direction),
    padj_lt = padj_lt,
    limit = limit,
    include_core_genes = include_core_genes
  )))
  new_gpsadb_result(
    records_to_tibble(res$terms),
    pick_meta(res, c("dataset_id", "title", "library", "n_terms", "padj_lt",
          "n_significant", "returned", "url"))
  )
}

#' Full GSEA of your own gene set in one dataset
#'
#' Unlike [gpsadb_gsea()], which reads the precomputed results, this runs a
#' GSEA (clusterProfiler defaults, 2,000 permutations, fixed seed) of a gene set
#' you supply against the dataset's ranked gene list.
#'
#' @param dataset_id Dataset ID, e.g. `"D20305"`.
#' @param genes Gene symbols of the set (1-5000).
#' @param client An MCP client; defaults to [gpsadb_client()].
#' @return A `gpsadb_result` with a single row: `n_genes`, `n_in_dataset`, `es`,
#'   `nes`, `pvalue`, `padj`, `note` and `url`.
#' @examplesIf interactive()
#' gpsadb_test_gene_set("D20305", c("HIF1A", "VEGFA", "SLC2A1"))
#' @export
gpsadb_test_gene_set <- function(dataset_id, genes, client = gpsadb_client()) {
  check_dataset_id(dataset_id)
  if (!length(genes)) stop("`genes` must hold at least one gene symbol", call. = FALSE)
  res <- client$call_tool_data("test_gene_set_in_dataset", list(
    dataset_id = dataset_id,
    genes = as_array(genes)
  ))
  new_gpsadb_result(records_to_tibble(list(res)))
}
