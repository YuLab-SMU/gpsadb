# Build tool stubs that match the pinned contract, so a test can perturb one
# detail and see what the checker reports.
tools_from <- function(contract = gpsadb_contract_expected) {
  lapply(contract, function(t) {
    props <- as.list(rep(NA_character_, length(t$params)))
    names(props) <- t$params
    list(
      name = t$name,
      inputSchema = list(
        type = "object",
        properties = props,
        required = as.list(t$required)
      )
    )
  })
}

client_with_tools <- function(tools) {
  fake_client(list())
}

test_that("the pinned contract covers the tools the package wraps", {
  contract <- gpsadb_contract()
  expect_s3_class(contract, "tbl_df")
  expect_true(all(c("get_download_links", "run_fastgpsa") %in% contract$tool))
  expect_equal(contract$required[contract$tool == "get_dataset"], "dataset_id")
})

test_that("a matching contract reports nothing", {
  client <- fake_client(list())
  client$list_tools <- function() tools_from()
  diffs <- gpsadb_contract_check(client)
  expect_equal(nrow(diffs), 0L)
})

test_that("a disappeared tool is reported as missing", {
  tools <- tools_from()
  tools <- Filter(function(t) t$name != "run_fastgpsa", tools)
  client <- fake_client(list())
  client$list_tools <- function() tools

  diffs <- gpsadb_contract_check(client)
  expect_equal(diffs$issue, "missing")
  expect_equal(diffs$tool, "run_fastgpsa")
})

test_that("an extra tool is reported as new", {
  tools <- tools_from()
  tools[[length(tools) + 1L]] <- list(
    name = "brand_new_tool",
    inputSchema = list(type = "object", properties = list(), required = list())
  )
  client <- fake_client(list())
  client$list_tools <- function() tools

  diffs <- gpsadb_contract_check(client)
  expect_true("new" %in% diffs$issue)
  expect_true("brand_new_tool" %in% diffs$tool)
})

test_that("parameter drift is reported per tool", {
  tools <- tools_from()
  idx <- which(vapply(tools, function(t) t$name, "") == "run_fastgpsa")
  tools[[idx]]$inputSchema$properties$new_arg <- NA_character_
  client <- fake_client(list())
  client$list_tools <- function() tools

  diffs <- gpsadb_contract_check(client)
  expect_true(any(diffs$issue == "param_added" & diffs$tool == "run_fastgpsa"))
})

test_that("a newly required argument is reported", {
  tools <- tools_from()
  idx <- which(vapply(tools, function(t) t$name, "") == "search_datasets")
  tools[[idx]]$inputSchema$required <- list("query")
  client <- fake_client(list())
  client$list_tools <- function() tools

  diffs <- gpsadb_contract_check(client)
  row <- diffs[diffs$tool == "search_datasets", ]
  expect_equal(row$issue, "required_changed")
  expect_match(row$detail, "now \\[query\\]")
})
