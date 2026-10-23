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
