# The download side of the database: per-dataset files and the bulk archives.
# This is what makes a result reproducible: the raw counts, the ranked list and
# the SHA-256 of every archive are one call away.

#' File links for datasets
#'
#' The files behind one or more datasets: the DESeq2 results, the sample
#' annotation, the raw read count matrix and the ranked gene list used by
#' [gpsadb_biotrigger()] and [gpsadb_fastgpsa()], plus the bulk archives that
#' contain each dataset.
#'
#' `read.csv(url)` works directly on the per-dataset CSVs, which is the shortest
#' path to re-running DESeq2 yourself instead of trusting the precomputed table.
#'
#' @param dataset_ids Dataset IDs, up to 50.
#' @param client An MCP client; defaults to [gpsadb_client()].
#' @return A [gpsadb_result]; `gpsadb_data()` has one row per file with
#'   `dataset_id`, `file`, `content` and `url`. `gpsadb_meta()` has `release`,
#'   `license`, `checksums_url`, `download_command`, the archives per dataset
#'   and the server's notes.
#' @seealso [gpsadb_archives()] for the whole tables and bulk shards.
#' @examplesIf interactive()
#' files <- gpsadb_downloads("D20305")
#' files[, c("file", "url")]
#' @export
gpsadb_downloads <- function(dataset_ids, client = gpsadb_client()) {
  if (!length(dataset_ids)) {
    stop("`dataset_ids` must hold at least one dataset ID", call. = FALSE)
  }
  if (length(dataset_ids) > 50L) {
    stop("`dataset_ids` holds at most 50 IDs per call", call. = FALSE)
  }
  res <- gpsadb_call(client, "get_download_links", list(
    dataset_ids = as_array(dataset_ids)
  ))

  datasets <- res$datasets %||% list()
  rows <- lapply(datasets, function(ds) {
    files <- ds$files %||% list()
    if (!length(files)) return(NULL)
    data.frame(
      dataset_id = rep(ds$dataset_id %||% NA_character_, length(files)),
      file = vapply(files, function(f) f$file %||% NA_character_, character(1)),
      content = vapply(files, function(f) f$content %||% NA_character_, character(1)),
      url = vapply(files, function(f) f$url %||% NA_character_, character(1)),
      stringsAsFactors = FALSE
    )
  })
  rows <- Filter(Negate(is.null), rows)

  new_gpsadb_result(
    if (length(rows)) tibble::as_tibble(do.call(rbind, rows)) else tibble::tibble(),
    pick_meta(res, c("release", "license", "checksums_url", "download_command",
                     "bulk_archives", "notes")),
    provenance = attr(res, "provenance")
  )
}

#' Bulk archives and whole tables
#'
#' The official release archives: the dataset metadata, the cell line and gene
#' annotation tables, and the raw counts sharded into a few hundred datasets per
#' zip, each with its size, SHA-256 and a resumable `curl` command. Call it with
#' no arguments for everything, or with `kind =` for one sort of archive.
#'
#' @param kind `"all"` (default), `"metadata"`, `"counts"` or `"diffresults"`.
#' @param client An MCP client; defaults to [gpsadb_client()].
#' @return A [gpsadb_result]; `gpsadb_data()` has one row per archive with
#'   `name`, `kind`, `release`, `n_datasets`, `first_dataset`, `last_dataset`,
#'   `size_mb`, `sha256` and `url`. `gpsadb_meta()` has the whole tables,
#'   `checksums_url`, `download_command` and the server's notes.
#' @seealso [gpsadb_downloads()]
#' @examplesIf interactive()
#' gpsadb_archives("counts")[, c("name", "size_mb", "sha256")]
#' @export
gpsadb_archives <- function(kind = c("all", "metadata", "counts", "diffresults"),
                            client = gpsadb_client()) {
  kind <- match.arg(kind)
  res <- gpsadb_call(client, "get_download_links", list(kind = kind))
  new_gpsadb_result(
    records_to_tibble(res$bulk_archives, cols = c(
      "name", "kind", "release", "n_datasets", "first_dataset", "last_dataset",
      "size_mb", "sha256", "url"
    )),
    pick_meta(res, c("release", "license", "whole_tables", "checksums_url",
                     "download_command", "notes")),
    provenance = attr(res, "provenance")
  )
}
