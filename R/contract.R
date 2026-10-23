# GPSAdb's tool contract is not versioned: the server advertises
# `listChanged: false` and its `version` is a build id that changes between
# requests. So we pin the contract we were written against and compare it on
# connect; drift is reported, never fatal.

#' The GPSAdb tool contract
#'
#' The tool names and parameters this version of `gpsadb` was written against,
#' as a tibble. Useful when the server moves: compare it with
#' [gpsadb_contract_check()].
#'
#' @return A tibble with `tool`, `params` (comma separated, `""` when none) and
#'   `required`.
#' @seealso [gpsadb_contract_check()]
#' @examplesIf interactive()
#' gpsadb_contract()
#' @export
gpsadb_contract <- function() {
  tibble::tibble(
    tool = vapply(gpsadb_contract_expected, `[[`, character(1), "name"),
    params = vapply(gpsadb_contract_expected, function(x) {
      paste(x$params, collapse = ", ")
    }, character(1)),
    required = vapply(gpsadb_contract_expected, function(x) {
      paste(x$required, collapse = ", ")
    }, character(1))
  )
}

#' Compare the live server with the pinned contract
#'
#' Asks the server for its tools and reports every difference from
#' [gpsadb_contract()]: a tool that disappeared (the wrappers would break), a
#' new tool (the package does not wrap it yet), or a parameter that was added,
#' removed or newly required.
#'
#' [gpsadb_connect()] runs this once per session when it connects to the public
#' endpoint and warns if anything moved; set
#' `options(gpsadb.check_contract = FALSE)` to silence it, or `TRUE` to check a
#' mirror too.
#'
#' @param client An MCP client; defaults to [gpsadb_client()].
#' @return A tibble with `tool`, `issue` (`missing`, `new`, `param_added`,
#'   `param_removed`, `required_changed`) and `detail`. No rows means the
#'   contract still matches.
#' @seealso [gpsadb_contract()]
#' @examplesIf interactive()
#' gpsadb_contract_check()
#' @export
gpsadb_contract_check <- function(client = gpsadb_client()) {
  live <- client$list_tools()
  gpsadb_compare_contract(gpsadb_contract_expected, live)
}

#' @keywords internal
gpsadb_compare_contract <- function(expected, live) {
  live_tbl <- lapply(live, function(tool) {
    schema <- tool$inputSchema %||% list()
    list(
      name = tool$name,
      params = as.character(unlist(names(schema$properties %||% list()))),
      required = as.character(unlist(schema$required %||% list()))
    )
  })

  exp_names <- vapply(expected, `[[`, character(1), "name")
  live_names <- vapply(live_tbl, `[[`, character(1), "name")

  rows <- c(
    list(contract_rows(setdiff(exp_names, live_names), "missing",
                       "the server no longer offers this tool")),
    list(contract_rows(setdiff(live_names, exp_names), "new",
                       "the server offers a tool the package does not wrap")),
    list(contract_param_rows(expected, exp_names, live_tbl, live_names))
  )
  rows <- Filter(Negate(is.null), rows)
  if (!length(rows)) {
    return(tibble::tibble(
      tool = character(0), issue = character(0), detail = character(0)
    ))
  }
  do.call(rbind, rows)
}

#' @keywords internal
contract_rows <- function(tool, issue, detail) {
  if (!length(tool)) return(NULL)
  tibble::tibble(
    tool = tool,
    issue = rep(issue, length(tool)),
    detail = rep(detail, length(tool))
  )
}

#' @keywords internal
contract_param_rows <- function(expected, exp_names, live_tbl, live_names) {
  common <- intersect(exp_names, live_names)
  rows <- lapply(common, function(name) {
    exp <- expected[[match(name, exp_names)]]
    got <- live_tbl[[match(name, live_names)]]
    added <- setdiff(got$params, exp$params)
    removed <- setdiff(exp$params, got$params)
    parts <- list(
      if (length(added)) {
        contract_rows(name, "param_added",
                      paste0("new parameter(s): ", paste(added, collapse = ", ")))
      },
      if (length(removed)) {
        contract_rows(name, "param_removed",
                      paste0("dropped parameter(s): ", paste(removed, collapse = ", ")))
      },
      if (!setequal(exp$required, got$required)) {
        contract_rows(
          name, "required_changed",
          sprintf("was [%s], now [%s]",
                  paste(exp$required, collapse = ", "),
                  paste(got$required, collapse = ", "))
        )
      }
    )
    parts <- Filter(Negate(is.null), parts)
    if (!length(parts)) NULL else do.call(rbind, parts)
  })
  rows <- Filter(Negate(is.null), rows)
  if (!length(rows)) NULL else do.call(rbind, rows)
}

#' @keywords internal
contract_check_enabled <- function(client) {
  option <- getOption("gpsadb.check_contract")
  if (!is.null(option)) return(isTRUE(option))
  # Only the canonical endpoint: a mirror may legitimately differ, and test
  # doubles have no url at all.
  identical(tryCatch(client$url, error = function(e) NULL), gpsadb_url())
}

#' @keywords internal
check_contract_on_connect <- function(client) {
  if (isTRUE(.gpsadb_env$contract_checked)) return(invisible(NULL))
  if (!contract_check_enabled(client)) return(invisible(NULL))
  .gpsadb_env$contract_checked <- TRUE
  diffs <- tryCatch(gpsadb_contract_check(client), error = function(e) NULL)
  if (is.null(diffs) || !nrow(diffs)) return(invisible(NULL))
  warning(contract_warning_message(diffs), call. = FALSE)
  invisible(diffs)
}

#' @keywords internal
contract_warning_message <- function(diffs) {
  pick <- function(issues) unique(diffs$tool[diffs$issue %in% issues])
  parts <- c(
    if (length(pick(c("missing")))) {
      paste0("missing tool(s): ", paste(pick("missing"), collapse = ", "))
    },
    if (length(pick(c("new")))) {
      paste0("new tool(s): ", paste(pick("new"), collapse = ", "))
    },
    if (length(pick(c("param_added", "param_removed", "required_changed")))) {
      paste0("changed parameters: ", paste(
        pick(c("param_added", "param_removed", "required_changed")),
        collapse = ", "
      ))
    }
  )
  sprintf(
    "GPSAdb's tool contract differs from gpsadb %s: %s. See gpsadb_contract_check().",
    as.character(utils::packageVersion("gpsadb")),
    paste(parts, collapse = "; ")
  )
}
