#' GPSAdb MCP endpoint
#'
#' The public endpoint needs no registration and no API key. Override it with
#' `options(gpsadb.mcp_url = ...)` or the `GPSADB_MCP_URL` environment variable
#' (the option wins).
#' @return A single URL.
#' @export
gpsadb_url <- function() {
  getOption(
    "gpsadb.mcp_url",
    Sys.getenv("GPSADB_MCP_URL", "https://gpsadb.gzdlab.com/mcp")
  )
}

#' Connect to GPSAdb
#'
#' Opens a Model Context Protocol session against the GPSAdb endpoint and caches
#' it for the rest of the R session. Every `gpsadb_*()` query uses that cached
#' client unless you pass `client =` explicitly.
#'
#' @param url MCP endpoint; defaults to [gpsadb_url()].
#' @param headers Extra HTTP headers.
#' @param timeout Seconds allowed per request.
#' @return The connected `aisdk.mcp` client, visibly. It exposes `list_tools()`,
#'   `call_tool()` and `call_tool_data()` if you want to go below the wrappers.
#' @seealso [gpsadb_client()], [gpsadb_disconnect()]
#' @examplesIf interactive()
#' client <- gpsadb_connect()
#' client$server_info$name
#' @export
gpsadb_connect <- function(url = gpsadb_url(),
                           headers = list(),
                           timeout = getOption("gpsadb.timeout", 120)) {
  client <- new_mcp_client(url, headers = headers, timeout = timeout)
  .gpsadb_env$client <- client
  .gpsadb_env$release <- NULL
  .gpsadb_env$contract_checked <- FALSE
  check_contract_on_connect(client)
  client
}

# The single place that touches aisdk.mcp; a seam so tests can run offline.
new_mcp_client <- function(url, headers, timeout) {
  aisdk.mcp::create_mcp_http_client(url, headers = headers, timeout = timeout)
}

#' The active GPSAdb client
#'
#' Returns the cached client, connecting on first use. A closed client is
#' replaced automatically, so a stale session never breaks a query.
#'
#' @return An `aisdk.mcp` MCP client.
#' @seealso [gpsadb_connect()]
#' @examplesIf interactive()
#' gpsadb_client()$server_info
#' @export
gpsadb_client <- function() {
  client <- .gpsadb_env$client
  if (is.null(client) || !isTRUE(client$is_alive())) {
    return(gpsadb_connect())
  }
  client
}

#' Close the GPSAdb connection
#'
#' Closes the cached client and forgets it. The next query reconnects.
#'
#' @return `NULL`, invisibly.
#' @export
#' @examplesIf interactive()
#' gpsadb_disconnect()
gpsadb_disconnect <- function() {
  client <- .gpsadb_env$client
  if (!is.null(client)) client$close()
  .gpsadb_env$client <- NULL
  .gpsadb_env$release <- NULL
  .gpsadb_env$contract_checked <- FALSE
  invisible(NULL)
}

#' Database overview
#'
#' Release date, counts of datasets / samples / perturbed genes and cell lines,
#' the gene-set libraries with how many of their terms are testable, and the
#' citations to use.
#'
#' @param client An MCP client; defaults to [gpsadb_client()].
#' @return A list of database metadata.
#' @examplesIf interactive()
#' info <- gpsadb_info()
#' info$datasets
#' @export
gpsadb_info <- function(client = gpsadb_client()) {
  gpsadb_call(client, "get_database_info")
}

#' Tools offered by the GPSAdb server
#'
#' A catalog of the underlying MCP tools: name, title and first line of the
#' description. Useful when the server adds tools before this package wraps
#' them — pair it with [gpsadb_raw()].
#'
#' @param client An MCP client; defaults to [gpsadb_client()].
#' @return A tibble with columns `name`, `title`, `description`.
#' @examplesIf interactive()
#' gpsadb_tool_catalog()
#' @export
gpsadb_tool_catalog <- function(client = gpsadb_client()) {
  tools <- client$list_tools()
  tibble::tibble(
    name = vapply(tools, function(t) t$name %||% NA_character_, character(1)),
    title = vapply(tools, function(t) t$title %||% NA_character_, character(1)),
    description = vapply(tools, function(t) {
      d <- t$description %||% ""
      strsplit(d, "\n", fixed = TRUE)[[1]][1]
    }, character(1))
  )
}

#' Call a GPSAdb tool directly
#'
#' An escape hatch for tools the wrappers do not cover yet, and for debugging
#' what the wrappers send. Arguments are passed through as given, except that
#' `NULL`s are dropped.
#'
#' @param tool Tool name, see [gpsadb_tool_catalog()].
#' @param arguments Named list of tool arguments.
#' @param client An MCP client; defaults to [gpsadb_client()].
#' @return The tool payload as nested lists.
#' @seealso [gpsadb_call()] for the pipe-friendly form (client first).
#' @examplesIf interactive()
#' gpsadb_raw("search_datasets", list(perturbed_gene = "TP53", limit = 2))
#' @export
gpsadb_raw <- function(tool, arguments = list(), client = gpsadb_client()) {
  check_scalar(tool, "tool")
  gpsadb_call(client, tool, arguments)
}
