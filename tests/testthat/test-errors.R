raise <- function(message) {
  function(...) {
    stop(structure(
      list(message = message, call = NULL),
      class = c("mcp_tool_error", "error", "condition")
    ))
  }
}

test_that("an unknown dataset is typed as not found", {
  client <- fake_client(list(get_dataset = raise('unknown dataset "D99999"; IDs look like D10001')))

  err <- tryCatch(gpsadb_dataset("D99999", client = client), error = function(e) e)
  expect_s3_class(err, "gpsadb_not_found")
  expect_s3_class(err, "gpsadb_error")
  expect_equal(err$tool, "get_dataset")
  expect_equal(err$arguments$dataset_id, "D99999")
  expect_match(conditionMessage(err), "unknown dataset")
})

test_that("a gene outside the database is typed as not found", {
  client <- fake_client(list(query_gene = raise('gene "NOTAGENE" is not in GPSAdb')))
  expect_error(gpsadb_query_gene("NOTAGENE", client = client),
               class = "gpsadb_not_found")
})

test_that("arguments the server refuses are typed as invalid input", {
  client <- fake_client(list(run_biotrigger = raise(
    "invalid arguments: json: cannot unmarshal string into Go struct field"
  )))
  err <- tryCatch(gpsadb_biotrigger("TP53", client = client), error = function(e) e)
  expect_s3_class(err, "gpsadb_invalid_input")
  expect_s3_class(err, "gpsadb_error")
})

test_that("anything else stays a plain gpsadb_error", {
  client <- fake_client(list(get_database_info = raise("the server is on fire")))
  err <- tryCatch(gpsadb_info(client = client), error = function(e) e)
  expect_s3_class(err, "gpsadb_error")
  expect_false(inherits(err, "gpsadb_not_found"))
  expect_false(inherits(err, "gpsadb_invalid_input"))
})

test_that("classify_gpsadb_error covers the messages we have seen", {
  expect_equal(classify_gpsadb_error("unknown dataset \"D1\""), "gpsadb_not_found")
  expect_equal(classify_gpsadb_error("none of the 1 genes is present in the database"),
               "gpsadb_not_found")
  expect_equal(classify_gpsadb_error("invalid arguments: json: cannot unmarshal"),
               "gpsadb_invalid_input")
  expect_equal(classify_gpsadb_error("HTTP 500"), "gpsadb_error")
})
