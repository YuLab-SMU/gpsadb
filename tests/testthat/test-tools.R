test_that("gpsadb_tools hands the server tools to aisdk unchanged", {
  client <- fake_client()
  tools <- gpsadb_tools(client = client)

  expect_type(tools, "list")
  expect_equal(names(tools), c("sdk_tool_one", "sdk_tool_two"))
})

test_that("gpsadb_tool_catalog summarises the advertised tools", {
  client <- fake_client()
  cat_tbl <- gpsadb_tool_catalog(client = client)

  expect_s3_class(cat_tbl, "tbl_df")
  expect_equal(cat_tbl$name, c("get_database_info", "search_datasets"))
  expect_equal(cat_tbl$title, c("Database overview", "Search datasets"))
  # only the first description line is kept
  expect_equal(cat_tbl$description,
               c("Overview of GPSAdb", "Find perturbation datasets"))
})

test_that("gpsadb_info exposes the database metadata", {
  client <- fake_client(list(get_database_info = list(
    name = "GPSAdb", release = "2026.10.22", datasets = 7665L,
    reference_datasets = 7112L, samples = 42235L, perturbed_genes = 2810L
  )))
  info <- gpsadb_info(client = client)

  expect_equal(info$release, "2026.10.22")
  expect_equal(info$datasets, 7665L)
  expect_equal(called_tool(client), "get_database_info")
})
