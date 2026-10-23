#' @title GPSAdb errors
#' @description
#' A tool-level failure on the server (an unknown dataset, an argument the
#' server refuses, a gene that is not in the database) is re-raised as a
#' condition of class `gpsadb_error`, carrying `tool` and `arguments` so a
#' script can react instead of matching free text.
#'
#' Two subclasses narrow the common cases:
#'
#' * `gpsadb_not_found`: the thing you asked for does not exist (unknown dataset
#'   ID, gene not in GPSAdb, no gene of the set is in the database).
#' * `gpsadb_invalid_input`: the server rejected the arguments themselves
#'   (JSON schema violation, wrong argument shape).
#'
#' ```r
#' tryCatch(
#'   gpsadb_de("D00000"),
#'   gpsadb_not_found = function(e) message("no such dataset: ", e$tool)
#' )
#' ```
#' @param ... Unused; the class is constructed by the package.
#' @name gpsadb_error
NULL

#' @keywords internal
abort_gpsadb <- function(parent, tool, arguments) {
  message <- conditionMessage(parent)
  class <- classify_gpsadb_error(message)
  stop(
    structure(
      class = c(class, "gpsadb_error", "error", "condition"),
      list(message = message, call = NULL, tool = tool, arguments = arguments)
    )
  )
}

#' @keywords internal
classify_gpsadb_error <- function(message) {
  if (grepl(
    "not in GPSAdb|unknown dataset|not in the database|none of the .* genes",
    message,
    ignore.case = TRUE
  )) {
    return("gpsadb_not_found")
  }
  if (grepl("invalid arguments|cannot unmarshal", message, ignore.case = TRUE)) {
    return("gpsadb_invalid_input")
  }
  "gpsadb_error"
}
