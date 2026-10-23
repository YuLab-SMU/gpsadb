# Live checks against the public GPSAdb endpoint. Skipped on CRAN and when
# offline; they assert the *shape* the wrappers rely on, not database content.

skip_live <- function() {
  testthat::skip_on_cran()
  testthat::skip_if_offline()
}

test_that("live: GPSAdb answers and reports its release", {
  skip_live()
  info <- gpsadb_info()

  expect_true(grepl("GPSAdb", info$name, ignore.case = TRUE))
  expect_gt(info$datasets, 0)
  expect_true(length(info$gene_set_libraries) >= 1)
})

test_that("live: dataset search, metadata and differential expression", {
  skip_live()

  hits <- gpsadb_search_datasets(perturbed_gene = "TP53", limit = 3)
  expect_equal(nrow(hits$data), 3L)
  expect_gt(hits$meta$total, 3)
  expect_true(all(c("id", "perturbed_gene", "cell_line") %in% names(hits$data)))

  id <- hits$data$id[1]
  ds <- gpsadb_dataset(id)
  expect_equal(ds$meta$perturbed_gene, "TP53")
  expect_gt(nrow(ds$data), 0)

  de <- gpsadb_de(id, genes = c("MDM2", "CDKN1A"))
  expect_true("gene" %in% names(de$data))
  expect_true(nrow(de$data) >= 1)
})

test_that("live: reverse lookups and signature search", {
  skip_live()

  reverse <- gpsadb_query_gene("CDKN1A", limit = 2)
  expect_equal(nrow(reverse$data), 2L)
  expect_gt(reverse$meta$total, 0)

  sig <- gpsadb_fastgpsa(dataset_id = "D20305", limit = 2)
  expect_equal(nrow(sig$data), 2L)
  expect_true("gscore" %in% names(sig$data))
})

test_that("live: errors from the server surface as mcp_tool_error", {
  skip_live()
  expect_error(gpsadb_dataset("D00000"), class = "mcp_tool_error")
})
