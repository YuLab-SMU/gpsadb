# Every tool call goes through here: NULL dropping, error typing, provenance.
# Keeping one funnel means a new wrapper cannot forget any of the three.

#' Call one GPSAdb tool
#'
#' The generic call behind every wrapper, with the client first so it reads well
#' in a pipe. [gpsadb_raw()] is the same call with the client last, which reads
#' better interactively.
#'
#' Arguments are passed as given (except that `NULL`s are dropped), so a tool
#' added to the server can be used before the package wraps it.
#'
#' @param client An MCP client.
#' @param tool Tool name, see [gpsadb_tool_catalog()].
#' @param arguments Named list of arguments.
#' @return The payload (nested lists), with a `provenance` attribute.
#' @seealso [gpsadb_raw()], [gpsadb_provenance()]
#' @examplesIf interactive()
#' info <- gpsadb_client() |> gpsadb_call("get_database_info")
#' info$datasets
#'
#' genes <- gpsadb_client() |>
#'   gpsadb_call("query_gene", list(gene = "CDKN1A", limit = 5))
#' genes$total
#' @export
gpsadb_call <- function(client, tool, arguments = list()) {
  arguments <- drop_nulls(arguments)
  out <- tryCatch(
    client$call_tool_data(tool, arguments),
    mcp_tool_error = function(e) abort_gpsadb(e, tool, arguments)
  )
  attr(out, "provenance") <- new_provenance(client, tool, arguments, out)
  out
}

#' Provenance of a result
#'
#' Every query records where its numbers came from: the tool, the arguments, the
#' data `release`, the server build, the protocol version and the time of the
#' call. A live service moves under your feet (the server's build id changes
#' between requests), so a number quoted in a paper or a report can only be
#' reproduced if the call that produced it is recorded.
#'
#' @param x A [gpsadb_result].
#' @return A named list with `tool`, `arguments`, `release`, `server`,
#'   `server_version`, `protocol_version`, `queried_at` (UTC) and
#'   `gpsadb_version`. `NULL` when the result carries none, which only happens
#'   for results built by hand in tests.
#' @seealso [gpsadb_result]
#' @examplesIf interactive()
#' res <- gpsadb_de("D20305", limit = 5)
#' gpsadb_provenance(res)[c("tool", "release", "queried_at")]
#' @export
gpsadb_provenance <- function(x) {
  check_gpsadb_result(x)
  attr(x, "provenance")
}

#' @keywords internal
new_provenance <- function(client, tool, arguments, payload) {
  release <- payload$release
  if (is.null(release)) release <- gpsadb_release(client)
  list(
    tool = tool,
    arguments = arguments,
    release = release,
    server = attr_or_na(client, "server_info", "name"),
    server_version = attr_or_na(client, "server_info", "version"),
    protocol_version = attr_or_na(client, "protocol_version"),
    queried_at = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
    gpsadb_version = as.character(utils::packageVersion("gpsadb"))
  )
}

#' @keywords internal
attr_or_na <- function(x, field, sub = NULL) {
  value <- tryCatch(if (is.null(sub)) x[[field]] else x[[field]][[sub]],
                    error = function(e) NULL)
  if (is.null(value) || !length(value)) return(NA_character_)
  as.character(value)
}

# The data release is a session-level fact: fetch it once, keep it for the
# provenance of every later call. Errors are swallowed: provenance must never
# be the reason a query fails.
#' @keywords internal
gpsadb_release <- function(client) {
  if (!is.null(.gpsadb_env$release)) return(.gpsadb_env$release)
  release <- tryCatch(
    client$call_tool_data("get_database_info")$release,
    error = function(e) NULL
  )
  if (is.character(release) && length(release) == 1L && nzchar(release)) {
    .gpsadb_env$release <- release
  }
  release %||% NA_character_
}
