test_that("a result records where its numbers came from", {
  client <- fake_client(list(
    search_datasets = function(args) {
      out <- fixture_datasets()
      out$release <- "2026.10.22"
      out
    }
  ))
  res <- gpsadb_search_datasets(perturbed_gene = "TP53", client = client)

  prov <- gpsadb_provenance(res)
  expect_type(prov, "list")
  expect_equal(prov$tool, "search_datasets")
  expect_equal(prov$arguments$perturbed_gene, "TP53")
  expect_equal(prov$release, "2026.10.22")
  expect_match(prov$queried_at, "^\\d{4}-\\d{2}-\\d{2}T\\d{2}:\\d{2}:\\d{2}Z$")
  expect_equal(prov$gpsadb_version, as.character(utils::packageVersion("gpsadb")))
})

test_that("the release falls back to the database metadata, fetched once", {
  clear_client()
  on.exit(clear_client(), add = TRUE)

  client <- fake_client(list(
    search_datasets = fixture_datasets(),
    get_database_info = list(release = "2026.10.22", datasets = 7665L)
  ))
  first <- gpsadb_search_datasets(perturbed_gene = "TP53", client = client)
  second <- gpsadb_search_datasets(perturbed_gene = "TP53", client = client)

  expect_equal(gpsadb_provenance(first)$release, "2026.10.22")
  expect_equal(gpsadb_provenance(second)$release, "2026.10.22")

  tools <- vapply(client$calls(), function(c) c$name, character(1))
  expect_equal(sum(tools == "get_database_info"), 1L)
})

test_that("provenance survives a missing release", {
  client <- fake_client(list(query_gene = fixture_hits()))
  res <- gpsadb_query_gene("CDKN1A", client = client)
  expect_true(is.na(gpsadb_provenance(res)$release))
})

test_that("provenance is only on results, and says so when absent", {
  expect_error(gpsadb_provenance(data.frame(a = 1)), "must be a `gpsadb_result`")

  handmade <- new_gpsadb_result(tibble::tibble(a = 1))
  expect_null(gpsadb_provenance(handmade))
})

test_that("printing shows the release and the server build", {
  client <- fake_client(list(query_gene = fixture_hits()))
  res <- gpsadb_query_gene("CDKN1A", client = client)
  out <- capture.output(print(res))
  expect_true(any(grepl("GPSAdb", out)))
  expect_true(any(grepl("server", out)))
})

test_that("gpsadb_raw records provenance too", {
  client <- fake_client(list(search_datasets = fixture_datasets()))
  out <- gpsadb_raw("search_datasets", list(limit = 1), client = client)
  expect_equal(attr(out, "provenance")$tool, "search_datasets")
  expect_error(gpsadb_raw(character(0), client = client), "single non-empty string")
})
