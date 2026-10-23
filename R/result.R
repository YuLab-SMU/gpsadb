#' @title GPSAdb results
#' @description
#' Every `gpsadb_*()` query returns a `gpsadb_result`: a small S3 envelope that
#' keeps the table and the scalars that describe it together, so paging
#' (`nrow()` versus the total number of hits) stays visible.
#'
#' You rarely need to touch its internals. A result behaves like its table for
#' the things you do every day, and the accessors pull out one part when you want
#' it:
#'
#' ```r
#' hits <- gpsadb_search_datasets(perturbed_gene = "TP53")
#'
#' hits                    # scalars on top, the page below
#' nrow(hits)              # rows in this page
#' hits[1:3, ]             # ordinary data-frame indexing
#' hits[, c("id", "method")]
#' head(hits)
#'
#' gpsadb_data(hits)       # the tibble itself (hand it to dplyr)
#' gpsadb_meta(hits)       # the scalars as a list
#' gpsadb_meta(hits, "total")
#' gpsadb_report_url(hits) # the website report, when there is one
#' ```
#'
#' `$data` and `$meta` still work; the accessors exist so you do not have to
#' remember them, and so `gpsadb_meta(x, field)` can tell you which fields are
#' available when you guess wrong.
#'
#' Paging is explicit: the table only holds the requested page, so compare
#' `nrow()` with `gpsadb_meta(x, "total")` when it matters.
#'
#' @param x A `gpsadb_result`.
#' @param field Name of one scalar in the result's metadata. When given, that
#'   value is returned instead of the whole list.
#' @param i,j Row and column selectors, as for a data frame. Indexing returns a
#'   plain tibble: the scalars describe the full query, so they are dropped
#'   rather than silently kept and left stale.
#' @param drop Passed on to the tibble's `[`.
#' @param n Number of rows to show.
#' @param row.names,optional Ignored; the data is always a fresh data frame.
#' @param ... Passed on to the underlying method.
#' @return `gpsadb_data()` returns the tibble, `gpsadb_meta()` a list (or one
#'   value when `field` is given), `gpsadb_report_url()` a string or `NA`, and the
#'   indexing methods a tibble.
#' @name gpsadb_result
NULL

#' @keywords internal
new_gpsadb_result <- function(data, meta = list()) {
  structure(list(data = data, meta = meta), class = "gpsadb_result")
}

# Keep only the metadata fields the server actually returned: `x[c(...)]` would
# otherwise leave NULL entries behind, named NA, which then print as "NA: NULL"
# and break `gpsadb_meta(x, "url")` lookups.
#' @keywords internal
pick_meta <- function(x, fields) {
  x[intersect(fields, names(x))]
}

#' @keywords internal
check_gpsadb_result <- function(x) {
  if (!inherits(x, "gpsadb_result")) {
    stop(
      "`x` must be a `gpsadb_result`, i.e. the output of a `gpsadb_*()` query.",
      call. = FALSE
    )
  }
  invisible(x)
}

#' @rdname gpsadb_result
#' @export
gpsadb_data <- function(x) {
  check_gpsadb_result(x)
  x$data
}

#' @rdname gpsadb_result
#' @export
gpsadb_meta <- function(x, field = NULL) {
  check_gpsadb_result(x)
  if (is.null(field)) {
    return(x$meta)
  }
  if (!field %in% names(x$meta)) {
    stop(
      sprintf(
        "`%s` is not in this result's metadata.\nAvailable: %s",
        field,
        if (length(x$meta)) paste(names(x$meta), collapse = ", ") else "<none>"
      ),
      call. = FALSE
    )
  }
  x$meta[[field]]
}

#' @rdname gpsadb_result
#' @export
gpsadb_report_url <- function(x) {
  check_gpsadb_result(x)
  url <- x$meta[["url"]]
  if (is.null(url) || !nzchar(url)) NA_character_ else as.character(url)
}

#' @rdname gpsadb_result
#' @export
print.gpsadb_result <- function(x, ...) {
  flat <- x$meta[vapply(
    x$meta,
    function(v) is.atomic(v) && length(v) == 1L,
    logical(1)
  )]
  if (length(flat)) {
    cat(paste0(
      "  ", names(flat), ": ",
      vapply(flat, function(v) paste0(v), character(1)),
      collapse = "\n"
    ), "\n", sep = "")
  }
  if (nrow(x$data)) {
    print(x$data, ...)
  } else {
    cat("  <no rows>\n")
  }
  invisible(x)
}

#' @rdname gpsadb_result
#' @export
as.data.frame.gpsadb_result <- function(x, row.names = NULL, optional = FALSE, ...) {
  as.data.frame(gpsadb_data(x), row.names = row.names, optional = optional, ...)
}

#' @rdname gpsadb_result
#' @export
as_tibble.gpsadb_result <- function(x, ...) {
  tibble::as_tibble(gpsadb_data(x), ...)
}

#' @rdname gpsadb_result
#' @export
dim.gpsadb_result <- function(x) {
  dim(gpsadb_data(x))
}

#' @rdname gpsadb_result
#' @export
names.gpsadb_result <- function(x) {
  names(gpsadb_data(x))
}

#' @rdname gpsadb_result
#' @export
`[.gpsadb_result` <- function(x, i, j, ..., drop = FALSE) {
  data <- gpsadb_data(x)
  # nargs() < 3 means one index (`x[i]`, column selection) rather than two
  # (`x[i, ]`, row selection) — the same trick `[.data.frame` uses.
  n_arg <- nargs() - !missing(drop)
  if (n_arg < 3L) {
    if (missing(i)) return(data[])
    return(data[i])
  }
  if (missing(i) && missing(j)) return(data[])
  if (missing(j)) return(data[i, , ..., drop = drop])
  if (missing(i)) return(data[, j, ..., drop = drop])
  data[i, j, ..., drop = drop]
}

#' @rdname gpsadb_result
#' @export
head.gpsadb_result <- function(x, n = 6L, ...) {
  utils::head(gpsadb_data(x), n, ...)
}

#' @rdname gpsadb_result
#' @export
tail.gpsadb_result <- function(x, n = 6L, ...) {
  utils::tail(gpsadb_data(x), n, ...)
}

# --- records -> tibble ------------------------------------------------------

#' Turn a list of records into a tibble
#'
#' GPSAdb structured output arrives as one named list per record. Scalar fields
#' become columns, nested objects and arrays become list columns, and missing
#' fields become `NA` so ragged records still line up.
#' @param records A list of named lists.
#' @param cols Optional preferred column order; unknown names are ignored and
#'   extra columns are appended.
#' @return A tibble (`0` rows when `records` is empty).
#' @keywords internal
records_to_tibble <- function(records, cols = NULL) {
  if (is.null(records) || length(records) == 0) return(tibble::tibble())
  records <- Filter(is.list, records)
  if (length(records) == 0) return(tibble::tibble())
  keys <- unique(unlist(lapply(records, names), use.names = FALSE))
  if (!is.null(cols)) {
    keys <- c(intersect(cols, keys), setdiff(keys, cols))
  }
  columns <- lapply(keys, function(k) column_of(records, k))
  names(columns) <- keys
  tibble::as_tibble(columns)
}

#' @keywords internal
column_of <- function(records, key) {
  vals <- lapply(records, function(r) r[[key]])
  flat <- all(vapply(
    vals,
    function(v) is.null(v) || (is.atomic(v) && length(v) == 1L),
    logical(1)
  ))
  if (!flat) return(vals)
  vals <- lapply(vals, function(v) if (is.null(v)) NA else v)
  out <- do.call(c, vals)
  # JSON `0` parses as integer while `0.05` parses as double, so the same column
  # could arrive as int in one query and dbl in the next; normalise to double.
  if (is.numeric(out)) out <- as.numeric(out)
  out
}
