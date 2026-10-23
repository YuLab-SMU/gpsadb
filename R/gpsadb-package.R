#' @keywords internal
#' @importFrom tibble tibble as_tibble
#' @importFrom utils head tail
"_PACKAGE"

# Package-level state: one cached MCP client per session.
.gpsadb_env <- new.env(parent = emptyenv())

`%||%` <- function(x, y) if (is.null(x)) y else x

#' Drop NULL arguments before they reach the server
#'
#' GPSAdb tools declare `additionalProperties: false`, so an explicit `null`
#' for an unused optional argument can be rejected.
#' @keywords internal
drop_nulls <- function(x) {
  if (length(x) == 0) return(x)
  keep <- !vapply(x, is.null, logical(1))
  x[keep]
}

#' Mark a vector as a JSON array
#'
#' `jsonlite` with `auto_unbox = TRUE` would serialise a length-one vector as a
#' string, but GPSAdb expects an array for `genes`, `terms`, `up_genes` and
#' `down_genes`. `I()` pins the array shape so single-element input works too.
#' @keywords internal
as_array <- function(x) {
  if (is.null(x)) return(NULL)
  I(as.character(x))
}

# --- argument validation ----------------------------------------------------

#' Check a single non-empty string argument
#' @keywords internal
check_scalar <- function(x, arg) {
  ok <- is.character(x) && length(x) == 1L && !is.na(x) && nzchar(x)
  if (!ok) {
    stop(sprintf("`%s` must be a single non-empty string", arg), call. = FALSE)
  }
  invisible(x)
}

#' Check a dataset ID argument
#' @keywords internal
check_dataset_id <- function(x) {
  check_scalar(x, "dataset_id")
  if (!grepl("^D[0-9]+$", x)) {
    stop(
      "`dataset_id` looks like \"", x, "\"; IDs look like D10001 ",
      "(use `gpsadb_search_datasets()` to find one)",
      call. = FALSE
    )
  }
  invisible(x)
}
