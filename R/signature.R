# --- signature matching against the reference set ---------------------------

#' BioTrigger: which perturbations activate or inhibit a gene set?
#'
#' Scores your gene set (GSEA enrichment score, ES) on the ranked gene list of
#' every dataset in the reference set and returns the strongest matches.
#'
#' @param genes Gene symbols of the gene set (1-5000).
#' @param effect `"activated"` (ES > 0), `"inhibited"` (ES < 0) or `"both"`.
#' @param limit Maximum datasets to return (1-200).
#' @param client An MCP client; defaults to [gpsadb_client()].
#' @return A [gpsadb_result]; its data has `rank`, `dataset`, `perturbed_gene`,
#'   `method`, `cell_line`, `es`, `effect`, `n_genes_in_dataset`, and
#'   `gpsadb_meta()` holds `n_genes`, `n_matched`, `n_datasets` and the report
#'   URL ([gpsadb_report_url()]).
#' @examplesIf interactive()
#' gpsadb_biotrigger(c("HIF1A", "VEGFA", "SLC2A1", "PDK1", "BNIP3"))
#' @export
gpsadb_biotrigger <- function(genes,
                              effect = c("both", "activated", "inhibited"),
                              limit = 20,
                              client = gpsadb_client()) {
  if (!length(genes)) stop("`genes` must hold at least one gene symbol", call. = FALSE)
  res <- gpsadb_call(client, "run_biotrigger", list(
    genes = as_array(genes),
    effect = match.arg(effect),
    limit = limit
  ))
  new_gpsadb_result(
    records_to_tibble(res$results),
    pick_meta(res, c("hash", "release", "url", "n_genes", "n_matched", "n_datasets",
          "returned"))
  ,
    provenance = attr(res, "provenance"))
}

#' fastGPSA: which perturbations mimic or reverse a signature?
#'
#' Give **exactly one** of three inputs:
#'
#' * `up_genes` + `down_genes` — a two-sided signature (at least 5 genes each;
#'   the server only counts genes it knows).
#' * `ranked_list` — a full ranked list, e.g. a DESeq2 result. Feed at least 201
#'   genes: the server rejects shorter lists (it does not want a list truncated
#'   by p-value), and a data frame is written as `gene<TAB>score` per line.
#' * `dataset_id` — use a GPSAdb dataset's own signature as the query, e.g. to
#'   find other perturbations that resemble it.
#'
#' @param up_genes Genes up-regulated in the signature (use with `down_genes`).
#' @param down_genes Genes down-regulated in the signature (use with
#'   `up_genes`).
#' @param ranked_list A data frame / two-column matrix (`gene`, `score`), or a
#'   string of one `gene score` pair per line (header allowed).
#' @param dataset_id Use this dataset's signature as the query.
#' @param direction `"similar"` (`gscore < 0`), `"opposite"` (`gscore > 0`) or
#'   `"both"`.
#' @param limit Maximum datasets to return (1-200).
#' @param client An MCP client; defaults to [gpsadb_client()].
#' @return A [gpsadb_result]; its data has `rank`, `dataset`, `perturbed_gene`,
#'   `method`, `cell_line`, `gscore`, `up_es`, `down_es`, `effect`, and
#'   `gpsadb_meta()` has `source`, `n_up_genes`, `n_down_genes`, `n_datasets`
#'   and the report URL ([gpsadb_report_url()]).
#' @examplesIf interactive()
#' gpsadb_fastgpsa(dataset_id = "D20305", limit = 10)
#' gpsadb_fastgpsa(
#'   up_genes = c("HIF1A", "VEGFA", "SLC2A1", "PDK1", "BNIP3"),
#'   down_genes = c("TP53", "CDKN1A", "GADD45A", "MDM2", "BAX")
#' )
#' @export
gpsadb_fastgpsa <- function(up_genes = NULL,
                            down_genes = NULL,
                            ranked_list = NULL,
                            dataset_id = NULL,
                            direction = c("both", "similar", "opposite"),
                            limit = 20,
                            client = gpsadb_client()) {
  direction <- match.arg(direction)
  modes <- c(
    two_sided = !is.null(up_genes) || !is.null(down_genes),
    ranked = !is.null(ranked_list),
    dataset = !is.null(dataset_id)
  )
  if (sum(modes) != 1L) {
    stop(
      "Give exactly one of: `up_genes` + `down_genes`, `ranked_list`, or `dataset_id`",
      call. = FALSE
    )
  }

  if (modes[["two_sided"]]) {
    if (is.null(up_genes) || is.null(down_genes)) {
      stop("`up_genes` and `down_genes` must be given together", call. = FALSE)
    }
    if (length(up_genes) < 5L || length(down_genes) < 5L) {
      stop(
        "`up_genes` and `down_genes` each need at least 5 known genes; ",
        "for a single gene set use `gpsadb_biotrigger()`",
        call. = FALSE
      )
    }
    up_genes <- as_array(up_genes)
    down_genes <- as_array(down_genes)
  }

  if (modes[["ranked"]]) {
    if (is.data.frame(ranked_list) || is.matrix(ranked_list)) {
      if (ncol(ranked_list) != 2L) {
        stop("`ranked_list` needs exactly two columns: gene and score", call. = FALSE)
      }
      if (nrow(ranked_list) <= 200L) {
        stop(
          "`ranked_list` needs more than 200 genes; ",
          "the server rejects shorter lists (do not truncate by p-value)",
          call. = FALSE
        )
      }
      ranked_list <- paste(
        as.character(ranked_list[[1]]),
        format(ranked_list[[2]], scientific = FALSE, trim = TRUE),
        sep = "\t",
        collapse = "\n"
      )
    } else {
      ranked_list <- as.character(ranked_list)
    }
  }

  res <- gpsadb_call(client, "run_fastgpsa", drop_nulls(list(
    up_genes = up_genes,
    down_genes = down_genes,
    ranked_list = ranked_list,
    dataset_id = dataset_id,
    direction = direction,
    limit = limit
  )))
  new_gpsadb_result(
    records_to_tibble(res$results),
    pick_meta(res, c("hash", "release", "url", "source", "n_up_genes", "n_down_genes",
          "n_datasets", "returned"))
  ,
    provenance = attr(res, "provenance"))
}
