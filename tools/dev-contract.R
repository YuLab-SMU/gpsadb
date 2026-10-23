# Regenerates R/contract-data.R from the live endpoint.
# Run it only when the server's contract legitimately changed, then review the
# diff: a silent tool/parameter change is exactly what the check is for.
suppressPackageStartupMessages(library(aisdk.mcp))

client <- create_mcp_http_client("https://gpsadb.gzdlab.com/mcp", timeout = 60)
on.exit(client$close(), add = TRUE)
tools <- client$list_tools()

lines <- vapply(tools, function(t) {
  schema <- t$inputSchema
  params <- names(schema$properties %||% list())
  required <- unlist(schema$required %||% list(), use.names = FALSE)
  chr <- function(x) if (length(x)) paste0('c(', paste0('"', x, '"', collapse = ", "), ')') else "character(0)"
  sprintf('  list(name = "%s", params = %s, required = %s)',
          t$name, chr(params), chr(as.character(required)))
}, character(1))

header <- c(
  "# Generated from the GPSAdb MCP endpoint. Do not edit by hand:",
  "#   Rscript tools/dev-contract.R",
  sprintf('# %s  server %s %s', format(Sys.time(), "%Y-%m-%d"), client$server_info$name,
          client$server_info$version),
  "gpsadb_contract_expected <- list("
)
writeLines(c(header, paste0(lines, collapse = ",\n"), ")"), "R/contract-data.R")
cat("wrote R/contract-data.R with", length(tools), "tools\n")
