test_that("gpsadb_intent fills in the GPSAdb client", {
  seen <- new.env(parent = emptyenv())
  client <- fake_client()

  local_mocked_bindings(
    mcp_intent = function(intent, clients, model = NULL, context = NULL) {
      seen$intent <- intent
      seen$clients <- clients
      seen$model <- model
      seen$context <- context
      "# generated code"
    },
    .package = "gpsadb"
  )

  code <- gpsadb_intent("哪些扰动改变 CDKN1A", model = "openai:gpt-4o-mini",
                        client = client)

  expect_equal(code, "# generated code")
  expect_equal(seen$intent, "哪些扰动改变 CDKN1A")
  expect_equal(names(seen$clients), "gps")
  expect_identical(seen$clients$gps, client)
  expect_equal(seen$model, "openai:gpt-4o-mini")
  expect_match(seen$context, "gpsadb_query_gene")
})

test_that("mcp_intent is re-exported for multi-server pipelines", {
  expect_true(is.function(mcp_intent))
})

test_that("gpsadb_intent validates the sentence", {
  expect_error(gpsadb_intent(character(0), client = fake_client()), "one sentence")
})
