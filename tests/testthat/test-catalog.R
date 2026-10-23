test_that("gpsadb_search_datasets returns a tibble with the paging meta", {
  client <- fake_client(list(search_datasets = fixture_datasets()))
  res <- gpsadb_search_datasets(
    perturbed_gene = "TP53", limit = 2, offset = 0,
    client = client
  )

  expect_s3_class(res, "gpsadb_result")
  expect_equal(nrow(res$data), 2L)
  expect_true(all(c("id", "perturbed_gene", "cell_line", "in_reference") %in%
                    names(res$data)))
  expect_equal(res$data$id, c("D20287", "D20305"))
  expect_equal(res$meta$total, 71L)

  args <- called_args(client)
  expect_equal(called_tool(client), "search_datasets")
  expect_equal(args$perturbed_gene, "TP53")
  expect_equal(args$limit, 2)
  # unused filters are not sent at all
  expect_false("query" %in% names(args))
  expect_false("method" %in% names(args))
})

test_that("gpsadb_dataset splits samples from the dataset metadata", {
  client <- fake_client(list(get_dataset = fixture_dataset()))
  res <- gpsadb_dataset("D20305", client = client)

  expect_equal(nrow(res$data), 2L)
  expect_equal(res$data$group, c("control", "treat"))
  expect_true(is.list(res$data$attributes))
  expect_equal(res$meta$title, "D20305(Knock_down TP53 in U-2 OS)")
  expect_equal(res$meta$downloads$differential_expression_csv,
               "https://example.org/de.csv")
  expect_null(res$meta$samples)
})

test_that("dataset IDs are validated before a request is made", {
  client <- fake_client()
  expect_error(gpsadb_dataset("TP53", client = client), "IDs look like D10001")
  expect_error(gpsadb_dataset(c("D1", "D2"), client = client), "single non-empty string")
  expect_error(gpsadb_dataset(NA_character_, client = client), "single non-empty string")
  expect_length(client$calls(), 0L)
})

test_that("gpsadb_de maps filters onto the tool arguments", {
  client <- fake_client(list(get_differential_expression = fixture_de()))
  res <- gpsadb_de(
    "D20305", direction = "down", sort_by = "log2fc",
    padj_lt = 0.01, min_abs_log2fc = 1, limit = 10,
    client = client
  )

  expect_equal(nrow(res$data), 2L)
  expect_equal(res$data$gene, c("CDKN1A", "GADD45A"))
  expect_type(res$data$padj, "double")
  expect_equal(res$meta$n_up, 274L)

  args <- called_args(client)
  expect_equal(args$direction, "down")
  expect_equal(args$sort_by, "log2fc")
  expect_equal(args$padj_lt, 0.01)
  expect_equal(args$min_abs_log2fc, 1)
  expect_false("genes" %in% names(args))
})

test_that("a single gene is still sent as a JSON array", {
  client <- fake_client(list(get_differential_expression = fixture_de()))
  gpsadb_de("D20305", genes = "TP53", client = client)

  genes <- called_args(client)$genes
  expect_true(inherits(genes, "AsIs"))
  expect_equal(as.character(genes), "TP53")
})

test_that("invalid directions are rejected", {
  client <- fake_client(list(get_differential_expression = fixture_de()))
  expect_error(gpsadb_de("D20305", direction = "sideways", client = client))
  expect_error(gpsadb_de("D20305", sort_by = "es", client = client))
})

test_that("gpsadb_gsea keeps core genes as a list column", {
  client <- fake_client(list(get_gsea_results = fixture_gsea()))
  res <- gpsadb_gsea(
    "D20305", limit = 2, include_core_genes = TRUE, client = client
  )

  expect_equal(nrow(res$data), 2L)
  expect_equal(res$data$term[[1]], "HALLMARK_TNFA_SIGNALING_VIA_NFKB")
  expect_true(is.list(res$data$core_genes))
  expect_equal(res$data$core_genes[[1]], list("NFKB1", "NFKB2"))
  # GSEA terms do not all carry core genes
  expect_null(res$data$core_genes[[2]])
  expect_equal(res$meta$n_significant, 21L)

  args <- called_args(client)
  expect_equal(args$library, "Hallmarks")
  expect_true(args$include_core_genes)
  expect_false("terms" %in% names(args))
})

test_that("gpsadb_test_gene_set returns a one-row result", {
  client <- fake_client(list(test_gene_set_in_dataset = list(
    dataset_id = "D20305", title = "D20305", n_genes = 3L, n_in_dataset = 3L,
    es = -0.45, nes = NULL, pvalue = NULL, padj = NULL,
    note = "3 genes tested", url = "https://gpsadb.gzdlab.com/dataset/D20305"
  )))
  res <- gpsadb_test_gene_set("D20305", c("HIF1A", "VEGFA", "SLC2A1"),
                              client = client)
  expect_equal(nrow(res$data), 1L)
  expect_equal(res$data$n_in_dataset, 3L)
  expect_equal(res$data$es, -0.45)
  expect_equal(called_args(client)$genes, I(c("HIF1A", "VEGFA", "SLC2A1")))

  expect_error(
    gpsadb_test_gene_set("D20305", character(0), client = client),
    "at least one gene"
  )
})

test_that("tool-level errors propagate with their message", {
  # aisdk.mcp raises conditions of class mcp_tool_error for `isError` results
  client <- fake_client(list(
    get_dataset = function(...) {
      stop(structure(
        list(message = "unknown dataset \"D99999\"", call = NULL),
        class = c("mcp_tool_error", "error", "condition")
      ))
    }
  ))
  expect_error(gpsadb_dataset("D99999", client = client),
               "unknown dataset", class = "gpsadb_not_found")
})
