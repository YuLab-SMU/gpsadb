test_that("gpsadb_query_gene returns hits with the totals in the meta", {
  client <- fake_client(list(query_gene = fixture_hits()))
  res <- gpsadb_query_gene("CDKN1A", direction = "up", limit = 2, client = client)

  expect_equal(nrow(res$data), 2L)
  expect_equal(res$data$dataset, c("D23745", "D28333"))
  expect_equal(res$data$log2fc, c(6.78, 4.95))
  expect_equal(res$meta$total, 2957L)
  expect_equal(res$meta$n_down, 1565L)

  args <- called_args(client)
  expect_equal(called_tool(client), "query_gene")
  expect_equal(args$gene, "CDKN1A")
  expect_equal(args$direction, "up")
  expect_equal(args$limit, 2)
})

test_that("gene names are validated", {
  client <- fake_client(list(query_gene = fixture_hits()))
  expect_error(gpsadb_query_gene(character(0), client = client), "single non-empty string")
  expect_error(gpsadb_query_gene(NA, client = client), "single non-empty string")
  expect_length(client$calls(), 0L)
})

test_that("gpsadb_query_gene_set omits an unspecified library", {
  client <- fake_client(list(query_gene_set = list(
    library = "Hallmarks", term = "HALLMARK_HYPOXIA", set_size = 200L,
    padj_lt = 0.05, total = 3955L, n_up = 2035L, n_down = 1920L,
    returned = 1L,
    hits = list(list(dataset = "D27689", perturbed_gene = "TRIM28",
                     method = "shRNA", cell_line = "HFF", nes = -3.21,
                     padj = 1.79e-10))
  )))
  res <- gpsadb_query_gene_set(
    "HALLMARK_HYPOXIA", direction = "down", sort_by = "nes",
    limit = 1, client = client
  )

  expect_equal(res$data$perturbed_gene, "TRIM28")
  expect_equal(res$meta$set_size, 200L)

  args <- called_args(client)
  expect_false("library" %in% names(args))
  expect_equal(args$direction, "down")
  expect_equal(args$sort_by, "nes")
})

test_that("gpsadb_search_gene_sets exposes optional member genes", {
  client <- fake_client(list(search_gene_sets = fixture_gene_sets()))
  res <- gpsadb_search_gene_sets(
    query = "hypoxia", include_genes = TRUE, limit = 2, client = client
  )

  expect_equal(nrow(res$data), 2L)
  expect_equal(res$data$term[[1]], "HALLMARK_HYPOXIA")
  expect_equal(res$data$genes[[1]], list("HIF1A", "VEGFA"))
  expect_null(res$data$genes[[2]])
  expect_equal(res$meta$total, 2L)

  args <- called_args(client)
  expect_true(args$include_genes)
  expect_false("contains_gene" %in% names(args))
  expect_false("library" %in% names(args))
})
