test_that("gpsadb_url falls back to the public endpoint", {
  old <- options(gpsadb.mcp_url = NULL)
  on.exit(options(old), add = TRUE)
  env <- Sys.getenv("GPSADB_MCP_URL", unset = NA_character_)
  Sys.unsetenv("GPSADB_MCP_URL")
  on.exit(
    if (is.na(env)) Sys.unsetenv("GPSADB_MCP_URL") else Sys.setenv(GPSADB_MCP_URL = env),
    add = TRUE
  )
  expect_equal(gpsadb_url(), "https://gpsadb.gzdlab.com/mcp")
})

test_that("the option overrides the environment variable", {
  old <- options(gpsadb.mcp_url = NULL)
  on.exit(options(old), add = TRUE)
  env <- Sys.getenv("GPSADB_MCP_URL", unset = NA_character_)
  Sys.setenv(GPSADB_MCP_URL = "https://env.invalid/mcp")
  on.exit(
    if (is.na(env)) Sys.unsetenv("GPSADB_MCP_URL") else Sys.setenv(GPSADB_MCP_URL = env),
    add = TRUE
  )

  expect_equal(gpsadb_url(), "https://env.invalid/mcp")
  options(gpsadb.mcp_url = "https://option.invalid/mcp")
  expect_equal(gpsadb_url(), "https://option.invalid/mcp")
})

test_that("the client is connected once and cached for the session", {
  clear_client()
  on.exit(clear_client(), add = TRUE)

  fake <- fake_client()
  connects <- new.env(parent = emptyenv())
  connects$n <- 0L
  local_mocked_bindings(
    new_mcp_client = function(url, headers, timeout) {
      connects$n <- connects$n + 1L
      fake
    },
    .package = "gpsadb"
  )

  first <- gpsadb_client()
  second <- gpsadb_client()
  expect_identical(first, second)
  expect_equal(connects$n, 1L)
})

test_that("a closed client is replaced on next use", {
  clear_client()
  on.exit(clear_client(), add = TRUE)

  dead <- fake_client()
  dead$is_alive <- function() FALSE
  .gpsadb_env$client <- dead

  fresh <- fake_client()
  local_mocked_bindings(
    new_mcp_client = function(url, headers, timeout) fresh,
    .package = "gpsadb"
  )
  expect_identical(gpsadb_client(), fresh)
})

test_that("gpsadb_disconnect closes and forgets the client", {
  clear_client()
  on.exit(clear_client(), add = TRUE)

  closed <- new.env(parent = emptyenv())
  closed$n <- 0L
  client <- fake_client()
  client$close <- function() {
    closed$n <- closed$n + 1L
    invisible(NULL)
  }
  .gpsadb_env$client <- client

  expect_null(gpsadb_disconnect())
  expect_equal(closed$n, 1L)
  expect_null(.gpsadb_env$client)
})

test_that("gpsadb_raw drops NULL arguments", {
  client <- fake_client(list(search_datasets = fixture_datasets()))
  gpsadb_raw(
    "search_datasets",
    list(perturbed_gene = "TP53", query = NULL, limit = 5),
    client = client
  )
  args <- called_args(client)
  expect_equal(args$perturbed_gene, "TP53")
  expect_equal(args$limit, 5)
  expect_false("query" %in% names(args))
})

test_that("gpsadb_raw passes the tool name through", {
  client <- fake_client(list(get_database_info = list(datasets = 7665L)))
  info <- gpsadb_raw("get_database_info", list(), client = client)
  expect_equal(called_tool(client), "get_database_info")
  expect_equal(info$datasets, 7665L)
})

test_that("gpsadb_call is the pipe-friendly form of gpsadb_raw", {
  client <- fake_client(list(search_datasets = fixture_datasets()))

  piped <- client |> gpsadb_call("search_datasets", list(limit = 1))
  expect_equal(piped$total, 71L)
  expect_equal(attr(piped, "provenance")$tool, "search_datasets")

  interactive_form <- gpsadb_raw("search_datasets", list(limit = 1), client = client)
  expect_equal(piped$total, interactive_form$total)
})
