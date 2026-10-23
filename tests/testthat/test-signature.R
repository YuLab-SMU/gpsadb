test_that("gpsadb_biotrigger sends the gene set as an array", {
  client <- fake_client(list(run_biotrigger = fixture_biotrigger()))
  res <- gpsadb_biotrigger("HIF1A", effect = "activated", limit = 1,
                           client = client)

  expect_equal(nrow(res$data), 1L)
  expect_equal(res$data$perturbed_gene, "IRAK4")
  expect_equal(res$data$effect, "Activated")
  expect_equal(res$meta$n_matched, 5L)
  expect_true(grepl("biotrigger", res$meta$url))

  args <- called_args(client)
  expect_true(inherits(args$genes, "AsIs"))
  expect_equal(as.character(args$genes), "HIF1A")
  expect_equal(args$effect, "activated")

  expect_error(gpsadb_biotrigger(character(0), client = client), "at least one gene")
  expect_error(gpsadb_biotrigger("X", effect = "sideways", client = client))
})

test_that("gpsadb_fastgpsa accepts a dataset id as the query", {
  client <- fake_client(list(run_fastgpsa = fixture_fastgpsa()))
  res <- gpsadb_fastgpsa(dataset_id = "D20305", direction = "opposite",
                         limit = 1, client = client)

  expect_equal(res$data$gscore, -2)
  expect_equal(res$meta$source, "dataset")

  args <- called_args(client)
  expect_equal(args$dataset_id, "D20305")
  expect_equal(args$direction, "opposite")
  expect_false("up_genes" %in% names(args))
  expect_false("ranked_list" %in% names(args))
})

test_that("gpsadb_fastgpsa accepts a two-sided signature", {
  client <- fake_client(list(run_fastgpsa = fixture_fastgpsa()))
  gpsadb_fastgpsa(
    up_genes = c("HIF1A", "VEGFA", "SLC2A1", "PDK1", "BNIP3"),
    down_genes = c("TP53", "CDKN1A", "GADD45A", "MDM2", "BAX"),
    client = client
  )
  args <- called_args(client)
  expect_equal(length(as.character(args$up_genes)), 5L)
  expect_false("dataset_id" %in% names(args))
})

test_that("gpsadb_fastgpsa converts a ranked data frame to a two-column list", {
  client <- fake_client(list(run_fastgpsa = fixture_fastgpsa()))
  ranked <- data.frame(
    gene = sprintf("GENE%d", 1:201),
    score = seq(3, -3, length.out = 201)
  )
  gpsadb_fastgpsa(ranked_list = ranked, client = client)

  sent <- called_args(client)$ranked_list
  expect_type(sent, "character")
  lines <- strsplit(sent, "\n", fixed = TRUE)[[1]]
  expect_length(lines, 201L)
  expect_equal(strsplit(lines[1], "\t", fixed = TRUE)[[1]][1], "GENE1")
})

test_that("exactly one fastGPSA input is required", {
  client <- fake_client(list(run_fastgpsa = fixture_fastgpsa()))

  expect_error(gpsadb_fastgpsa(client = client), "exactly one")
  expect_error(
    gpsadb_fastgpsa(
      up_genes = c("A", "B", "C", "D", "E"),
      down_genes = c("F", "G", "H", "I", "J"),
      dataset_id = "D20305",
      client = client
    ),
    "exactly one"
  )
})

test_that("a two-sided signature needs both sides and five genes each", {
  client <- fake_client(list(run_fastgpsa = fixture_fastgpsa()))

  expect_error(
    gpsadb_fastgpsa(up_genes = c("A", "B", "C", "D", "E"), client = client),
    "given together"
  )
  expect_error(
    gpsadb_fastgpsa(
      up_genes = c("A", "B"),
      down_genes = c("C", "D"),
      client = client
    ),
    "at least 5 known genes"
  )
  expect_length(client$calls(), 0L)
})

test_that("short ranked lists are rejected before the round trip", {
  client <- fake_client(list(run_fastgpsa = fixture_fastgpsa()))
  short <- data.frame(gene = sprintf("G%d", 1:200), score = runif(200))

  expect_error(
    gpsadb_fastgpsa(ranked_list = short, client = client),
    "more than 200 genes"
  )
  expect_error(
    gpsadb_fastgpsa(
      ranked_list = data.frame(a = 1:201, b = 1:201, c = 1:201),
      client = client
    ),
    "exactly two columns"
  )
  expect_length(client$calls(), 0L)
})

test_that("a string ranked list is passed through", {
  client <- fake_client(list(run_fastgpsa = fixture_fastgpsa()))
  text <- "gene\tscore\nA\t1.2\nB\t-0.4"
  gpsadb_fastgpsa(ranked_list = text, client = client)
  expect_equal(called_args(client)$ranked_list, text)
})

test_that("metadata only holds the fields the server actually returned", {
  # the two-sided mode does not always come back with hash/url
  no_hash <- fixture_fastgpsa()
  no_hash$hash <- NULL
  no_hash$url <- NULL
  client <- fake_client(list(run_fastgpsa = no_hash))

  res <- gpsadb_fastgpsa(
    up_genes = c("HIF1A", "VEGFA", "SLC2A1", "PDK1", "BNIP3"),
    down_genes = c("TP53", "CDKN1A", "GADD45A", "MDM2", "BAX"),
    client = client
  )

  expect_false(any(is.na(names(res$meta))))
  expect_false("hash" %in% names(res$meta))
  expect_true(is.na(gpsadb_report_url(res)))
  expect_error(gpsadb_meta(res, "hash"), "Available:")
})
