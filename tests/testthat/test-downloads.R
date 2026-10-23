fixture_downloads <- function() {
  list(
    release = "2026.10.22",
    license = "CC BY 4.0",
    datasets = list(
      list(
        dataset_id = "D20305",
        title = "D20305(Knock_down TP53 in U-2 OS)",
        n_samples = 6L,
        files = list(
          list(file = "D20305_diffresults.csv", content = "DESeq2 results",
               url = "https://example.org/v1/datasets/D20305/files/diffresults.csv"),
          list(file = "D20305_expression.csv", content = "Raw read counts",
               url = "https://example.org/v1/datasets/D20305/files/counts.csv")
        ),
        in_archives = list("GPSAdb-2026.10.22-counts-D10820-D20381.zip")
      )
    ),
    bulk_archives = list(
      list(name = "GPSAdb-2026.10.22-counts-D10820-D20381.zip", kind = "counts",
           release = "2026.10.22", n_datasets = 400L, first_dataset = "D10820",
           last_dataset = "D20381", size_mb = 127, sha256 = "9f0784",
           url = "https://example.org/bulk/counts.zip")
    ),
    checksums_url = "https://example.org/bulk/SHA256SUMS",
    download_command = "curl -fC - -O https://example.org/bulk/counts.zip",
    notes = list("counts are raw reads", "cite GPSAdb")
  )
}

test_that("gpsadb_downloads flattens the files of each dataset", {
  client <- fake_client(list(get_download_links = fixture_downloads()))
  res <- gpsadb_downloads("D20305", client = client)

  expect_equal(nrow(res$data), 2L)
  expect_equal(res$data$dataset_id, c("D20305", "D20305"))
  expect_equal(res$data$file[1], "D20305_diffresults.csv")
  expect_true(all(grepl("^https://", res$data$url)))
  expect_equal(gpsadb_meta(res, "release"), "2026.10.22")
  expect_true(nzchar(gpsadb_meta(res, "checksums_url")))

  args <- called_args(client)
  expect_true(inherits(args$dataset_ids, "AsIs"))
  expect_equal(as.character(args$dataset_ids), "D20305")
})

test_that("gpsadb_downloads validates its input", {
  client <- fake_client(list(get_download_links = fixture_downloads()))
  expect_error(gpsadb_downloads(character(0), client = client), "at least one dataset ID")
  expect_error(gpsadb_downloads(sprintf("D%05d", 1:51), client = client), "at most 50")
  expect_length(client$calls(), 0L)
})

test_that("gpsadb_archives tabulates the bulk shards", {
  client <- fake_client(list(get_download_links = fixture_downloads()))
  res <- gpsadb_archives(kind = "counts", client = client)

  expect_equal(nrow(res$data), 1L)
  expect_equal(res$data$kind, "counts")
  expect_equal(res$data$n_datasets, 400L)
  expect_equal(res$data$sha256, "9f0784")
  expect_true(is.list(gpsadb_meta(res)))

  args <- called_args(client)
  expect_equal(args$kind, "counts")
  expect_false("dataset_ids" %in% names(args))
})

test_that("gpsadb_archives only accepts the documented kinds", {
  client <- fake_client(list(get_download_links = fixture_downloads()))
  expect_error(gpsadb_archives(kind = "everything", client = client))
})
