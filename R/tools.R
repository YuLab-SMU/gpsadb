#' GPSAdb tools as aisdk tools
#'
#' The other half of the integration: instead of calling the wrappers yourself,
#' hand GPSAdb to an `aisdk` agent and let the model choose the query. Each tool
#' becomes an `aisdk` tool whose result is the JSON of the GPSAdb payload.
#'
#' The tools come from the `aisdk.mcp` client, so their names and JSON Schemas
#' are exactly what the server advertises — no second copy to keep in sync.
#'
#' @param client An MCP client; defaults to [gpsadb_client()].
#' @return A list of `aisdk` tool objects, ready for the `tools=` argument of
#'   [aisdk::generate_text()].
#' @seealso [gpsadb_tool_catalog()] to inspect the same tools as a tibble.
#' @examplesIf interactive()
#' tools <- gpsadb_tools()
#' length(tools)
#' aisdk::generate_text(
#'   model = "deepseek:deepseek-chat",
#'   prompt = "Which perturbations mimic hypoxia in U-2 OS?",
#'   tools = tools
#' )
#' @export
gpsadb_tools <- function(client = gpsadb_client()) {
  client$as_sdk_tools()
}
