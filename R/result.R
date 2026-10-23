#' @title GPSAdb results
#' @description
#' Every `gpsadb_*()` query returns a `gpsadb_result`: `$data` is a tibble with
#' one row per record, `$meta` holds the scalars that describe the table (total
#' number of hits, how many were up/down, the website report URL, ...).
#'
#' Paging is explicit: `$data` only holds the requested page, so compare
#' `$data` row count with `$meta$total` when it matters.
#' @name gpsadb_result
NULL

#' @keywords internal
new_gpsadb_result <- function(data, meta = list()) {
  structure(list(data = data, meta = meta), class = "gpsadb_result")
}

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

#' @param x A `gpsadb_result`.
#' @param row.names,optional Ignored; the data is always a fresh data frame.
#' @param ... Passed on to [base::as.data.frame()].
#' @rdname gpsadb_result
#' @export
as.data.frame.gpsadb_result <- function(x, row.names = NULL, optional = FALSE, ...) {
  as.data.frame(x$data, row.names = row.names, optional = optional, ...)
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
