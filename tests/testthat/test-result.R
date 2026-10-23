test_that("records_to_tibble turns records into columns", {
  records <- list(
    list(a = 1, b = "x"),
    list(b = "y", c = TRUE)
  )
  out <- records_to_tibble(records)
  expect_s3_class(out, "tbl_df")
  expect_equal(nrow(out), 2L)
  expect_true(all(c("a", "b", "c") %in% names(out)))
  expect_equal(out$a, c(1, NA))
  expect_equal(out$b, c("x", "y"))
  expect_equal(out$c, c(NA, TRUE))
})

test_that("records_to_tibble keeps nested fields as list columns", {
  records <- list(
    list(term = "A", genes = list("X", "Y")),
    list(term = "B")
  )
  out <- records_to_tibble(records)
  expect_true(is.list(out$genes))
  expect_equal(out$genes[[1]], list("X", "Y"))
  expect_null(out$genes[[2]])
})

test_that("records_to_tibble normalises mixed integer/double columns", {
  # JSON `0` parses as integer, `0.05` as double; one column must not switch
  # type between queries.
  out <- records_to_tibble(list(list(padj = 0L), list(padj = 0.05)))
  expect_type(out$padj, "double")
  expect_equal(out$padj, c(0, 0.05))
})

test_that("records_to_tibble honours a preferred column order", {
  out <- records_to_tibble(
    list(list(a = 1, b = 2, c = 3)),
    cols = c("c", "a")
  )
  expect_equal(names(out), c("c", "a", "b"))
})

test_that("records_to_tibble handles empty input", {
  expect_equal(nrow(records_to_tibble(NULL)), 0L)
  expect_equal(nrow(records_to_tibble(list())), 0L)
})

test_that("gpsadb_result prints meta above the data", {
  res <- new_gpsadb_result(
    tibble::tibble(gene = "CDKN1A"),
    list(total = 2957, returned = 1)
  )
  out <- capture.output(print(res))
  expect_true(any(grepl("total: 2957", out)))
  expect_true(any(grepl("CDKN1A", out)))
})

test_that("an empty result still prints", {
  res <- new_gpsadb_result(tibble::tibble())
  out <- capture.output(print(res))
  expect_true(any(grepl("no rows", out)))
})

test_that("as.data.frame unwraps the data", {
  res <- new_gpsadb_result(tibble::tibble(gene = c("A", "B")))
  df <- as.data.frame(res)
  expect_s3_class(df, "data.frame")
  expect_equal(df$gene, c("A", "B"))
})

test_that("accessors pull out the parts of a result", {
  res <- new_gpsadb_result(
    tibble::tibble(gene = c("A", "B"), log2fc = c(1.5, -0.5)),
    list(total = 2, url = "https://example.org/r/1")
  )

  expect_equal(gpsadb_data(res), tibble::tibble(gene = c("A", "B"), log2fc = c(1.5, -0.5)))
  expect_type(gpsadb_meta(res), "list")
  expect_equal(gpsadb_meta(res, "total"), 2)
  expect_equal(gpsadb_report_url(res), "https://example.org/r/1")
})

test_that("a missing metadata field lists what is there", {
  res <- new_gpsadb_result(tibble::tibble(gene = "A"), list(total = 1, returned = 1))
  expect_error(gpsadb_meta(res, "nope"), "Available: total, returned")
})

test_that("gpsadb_report_url returns NA when there is no report", {
  res <- new_gpsadb_result(tibble::tibble(gene = "A"), list(total = 1))
  expect_true(is.na(gpsadb_report_url(res)))
})

test_that("accessors reject objects that are not results", {
  expect_error(gpsadb_data(data.frame(a = 1)), "must be a `gpsadb_result`")
  expect_error(gpsadb_meta(list(a = 1)), "must be a `gpsadb_result`")
})

test_that("indexing behaves like the underlying table", {
  res <- new_gpsadb_result(
    tibble::tibble(gene = c("A", "B", "C"), log2fc = c(1, 2, 3)),
    list(total = 3)
  )

  expect_equal(nrow(res), 3L)
  expect_equal(ncol(res), 2L)
  expect_equal(dim(res), c(3L, 2L))
  expect_equal(names(res), c("gene", "log2fc"))

  expect_equal(res[1:2, ], tibble::tibble(gene = c("A", "B"), log2fc = c(1, 2)))
  expect_equal(res[, "gene"], tibble::tibble(gene = c("A", "B", "C")))
  expect_equal(res["log2fc"], tibble::tibble(log2fc = c(1, 2, 3)))
  expect_s3_class(res[1, ], "tbl_df")

  expect_equal(head(res, 1)$gene, "A")
  expect_equal(tail(res, 1)$gene, "C")
  expect_s3_class(as_tibble(res), "tbl_df")
})

test_that("gpsadb_result prints the scalars above the page", {
  res <- new_gpsadb_result(
    tibble::tibble(gene = "A"),
    list(total = 71L, returned = 1L)
  )
  out <- capture.output(print(res))
  expect_true(any(grepl("total: 71", out)))
  expect_true(any(grepl("gene", out)))
})

test_that("gpsadb_genes pulls the gene column out of a result", {
  de <- new_gpsadb_result(
    tibble::tibble(gene = c("CDKN1A", "GADD45A"), log2fc = c(1.7, 1.2)),
    list(n_up = 2)
  )
  expect_equal(gpsadb_genes(de), c("CDKN1A", "GADD45A"))

  hits <- new_gpsadb_result(
    tibble::tibble(perturbed_gene = c("TP53", "TP53", "MDM2")),
    list(total = 3)
  )
  expect_equal(gpsadb_genes(hits), c("TP53", "MDM2"))
  expect_equal(gpsadb_genes(hits, unique = FALSE), c("TP53", "TP53", "MDM2"))
})

test_that("gpsadb_genes needs an explicit column when there is none", {
  gsea <- new_gpsadb_result(
    tibble::tibble(term = c("HALLMARK_HYPOXIA", "HALLMARK_TNFA_SIGNALING_VIA_NFKB")),
    list(n_terms = 2)
  )
  expect_error(gpsadb_genes(gsea), "pass `column =`")
  expect_equal(gpsadb_genes(gsea, column = "term")[1], "HALLMARK_HYPOXIA")
  expect_error(gpsadb_genes(gsea, column = "nope"), "no column `nope`")
  expect_error(gpsadb_genes(data.frame(gene = "A")), "must be a `gpsadb_result`")
})

test_that("gpsadb_genes drops blanks", {
  res <- new_gpsadb_result(tibble::tibble(gene = c("A", NA, "", "B")))
  expect_equal(gpsadb_genes(res), c("A", "B"))
})

test_that("$ reaches columns and still finds the envelope", {
  res <- new_gpsadb_result(
    tibble::tibble(gene = c("A", "B"), log2fc = c(1, 2)),
    list(total = 71)
  )
  expect_equal(res$gene, c("A", "B"))
  expect_equal(res$log2fc, c(1, 2))
  expect_equal(nrow(res$data), 2L)
  expect_equal(res$meta$total, 71)
  expect_null(res$not_a_column)
})
