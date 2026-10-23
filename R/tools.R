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
#' @param prefix Prefix the tool names, e.g. `"gpsadb"` turns `query_gene` into
#'   `gpsadb__query_gene`. Tool names are flat across a whole agent session, so
#'   give every server a prefix when you put several of them in one `tools=`
#'   list; `query_gene` and `search_datasets` are common enough to collide.
#' @return A list of `aisdk` tool objects, ready for the `tools=` argument of
#'   [aisdk::generate_text()].
#' @seealso [gpsadb_tool_catalog()] to inspect the same tools as a tibble, and
#'   `aisdk.mcp::combine_mcp_tools()` to merge several servers at once.
#' @examplesIf interactive()
#' tools <- gpsadb_tools()
#' length(tools)
#' gpsadb_tools(prefix = "gpsadb")[[1]]$name
#' aisdk::generate_text(
#'   model = "deepseek:deepseek-chat",
#'   prompt = "Which perturbations mimic hypoxia in U-2 OS?",
#'   tools = tools
#' )
#' @export
gpsadb_tools <- function(client = gpsadb_client(), prefix = NULL) {
  tools <- client$as_sdk_tools()
  if (is.null(prefix)) {
    return(tools)
  }
  check_scalar(prefix, "prefix")
  if (!grepl("^[A-Za-z][A-Za-z0-9_]*$", prefix)) {
    stop(
      "`prefix` must start with a letter and hold only letters, digits and `_`",
      call. = FALSE
    )
  }
  for (i in seq_along(tools)) {
    tools[[i]]$name <- paste0(prefix, "__", tools[[i]]$name)
  }
  tools
}
