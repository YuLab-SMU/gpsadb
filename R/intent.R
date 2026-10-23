#' Describe a GPSAdb query in words
#'
#' [aisdk.mcp::mcp_intent()] with this session's GPSAdb client already filled in,
#' so one sentence is enough. The code comes back as text and is **not run** —
#' read it, then run the parts you want.
#'
#' @param intent What you want, in one sentence.
#' @param model An aisdk model or id string. `NULL` uses the model configured
#'   with [aisdk::set_model()].
#' @param client An MCP client; defaults to [gpsadb_client()].
#' @return The generated code, as one string.
#' @seealso [aisdk.mcp::mcp_intent()] to mix in another server,
#'   [gpsadb_tool_catalog()] to see the tools it can choose from.
#' @examples
#' \dontrun{
#' gpsadb_intent("哪些扰动会改变 CDKN1A，其中多少在 Hep G2")
#' }
#' @export
gpsadb_intent <- function(intent, model = NULL, client = gpsadb_client()) {
  mcp_intent(
    intent,
    clients = list(gps = client),
    model = model,
    context = gpsadb_verb_context()
  )
}

#' @importFrom aisdk.mcp mcp_intent
#' @export
aisdk.mcp::mcp_intent

#' The instructions that keep generated code on the typed verbs
#'
#' [aisdk.mcp::mcp_intent()] writes raw `mcp_action()` calls by default, which
#' return payload lists whose field names the model can only guess. Hand it this
#' context and the GPSAdb half of the code uses the typed verbs instead: tibbles,
#' no guessed field names.
#'
#' @return A character string for the `context` argument.
#' @seealso [gpsadb_intent()], [aisdk.mcp::mcp_intent()]
#' @examples
#' \dontrun{
#' mcp_intent(
#'   "HIF1A 敲低后谁变了，再拿去 STRING 看互作",
#'   clients = list(gps = gpsadb_client(), string = create_mcp_http_client(
#'     "https://mcp.string-db.org/")),
#'   context = gpsadb_verb_context()
#' )
#' }
#' @export
gpsadb_verb_context <- function() {
  paste(
    "Prefer these typed functions when they fit: they return tibbles and take the",
    "client implicitly. Use mcp_action(gps, ...) only for a tool without one.",
    "",
    "  gpsadb_info()",
    "  gpsadb_search_datasets(query=, perturbed_gene=, method=, cell_line=, tissue=, oncotree_code=, reference_only=, limit=, offset=)",
    "  gpsadb_dataset(dataset_id)",
    "  gpsadb_de(dataset_id, genes=, direction=, padj_lt=, min_abs_log2fc=, sort_by=, limit=)",
    "  gpsadb_gsea(dataset_id, library=, terms=, direction=, padj_lt=, limit=, include_core_genes=)",
    "  gpsadb_query_gene(gene, padj_lt=, direction=, min_abs_log2fc=, sort_by=, limit=, offset=)",
    "  gpsadb_query_gene_set(term, library=, padj_lt=, direction=, sort_by=, limit=, offset=)",
    "  gpsadb_search_gene_sets(query=, library= one of Hallmarks/biocarta/kegg_legacy/kegg_medicus/pid/reactome/wikipathways/Tftargets, contains_gene=, testable_only=, include_genes=, limit=)",
    "  gpsadb_biotrigger(genes, effect=, limit=)",
    "  gpsadb_fastgpsa(up_genes=, down_genes=, ranked_list=, dataset_id=, direction=, limit=)",
    "  gpsadb_test_gene_set(dataset_id, genes)",
    "  gpsadb_downloads(dataset_ids)",
    "  gpsadb_archives(kind=)",
    "",
    "Start the code with library(gpsadb); add library(dplyr) if you use its verbs.",
    "Do not reference variables you did not define.",
    "",
    "A result is NOT a data frame. Access columns with res$gene or",
    "res[, c(\"dataset\", \"log2fc\")]; for dplyr use gpsadb_data(res) first.",
    "gpsadb_genes(res) gives the gene column; gpsadb_meta(res, \"total\") the totals.",
    "",
    "Result columns: search_datasets -> id, perturbed_gene, method, cell_line, tissue;",
    "de -> gene, log2fc, padj; gsea -> term, nes, padj;",
    "query_gene / query_gene_set -> dataset, perturbed_gene, method, cell_line, log2fc or nes, padj;",
    "dataset -> samples (name, group); the id you already have, not a column of that result.",
    "Meta values come from gpsadb_meta(res, \"field\"), not from res$field.",
    "search_gene_sets -> library, term, size, testable.",
    "",
    "Limits: gpsadb_search_datasets() limit <= 200, offset pages it;",
    "gpsadb_query_gene() / gpsadb_query_gene_set() limit <= 500, offset pages them;",
    "gpsadb_de() limit <= 500; gpsadb_gsea() limit <= 200."
  )
}
