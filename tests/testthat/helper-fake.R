# A stand-in for the aisdk.mcp client: the wrappers only ever call
# `call_tool_data()`, so a list of closures is enough and the tests never
# touch the network.

fake_client <- function(responses = list()) {
  calls <- new.env(parent = emptyenv())
  calls$list <- list()

  record <- function(name, arguments) {
    calls$list[[length(calls$list) + 1L]] <- list(name = name, arguments = arguments)
  }

  list(
    call_tool_data = function(name, arguments = list()) {
      record(name, arguments)
      answer <- responses[[name]]
      if (is.null(answer)) {
        stop("fake client: no canned response for tool '", name, "'", call. = FALSE)
      }
      if (is.function(answer)) answer <- answer(arguments)
      answer
    },
    call_tool = function(name, arguments = list()) {
      record(name, arguments)
      list(structuredContent = responses[[name]])
    },
    list_tools = function() {
      list(
        list(name = "get_database_info", title = "Database overview",
             description = "Overview of GPSAdb\nsecond line"),
        list(name = "search_datasets", title = "Search datasets",
             description = "Find perturbation datasets")
      )
    },
    as_sdk_tools = function() list(sdk_tool_one = "a", sdk_tool_two = "b"),
    is_alive = function() TRUE,
    close = function() invisible(NULL),
    calls = function() calls$list
  )
}

# The arguments recorded for the n-th tool call.
called_args <- function(client, n = 1L) {
  client$calls()[[n]]$arguments
}

called_tool <- function(client, n = 1L) {
  client$calls()[[n]]$name
}

clear_client <- function() {
  .gpsadb_env$client <- NULL
  invisible(NULL)
}

# Canned payloads shaped like the real GPSAdb structured output.
fixture_datasets <- function() {
  list(
    total = 71L,
    offset = 0L,
    returned = 2L,
    datasets = list(
      list(id = "D20287", perturbed_gene = "TP53", method = "shRNA",
           cell_line = "iPSCs", tissue = "Fibroblast", n_samples = 4L,
           n_up = 2996L, n_down = 3556L, in_reference = TRUE),
      list(id = "D20305", perturbed_gene = "TP53", method = "siRNA",
           cell_line = "U-2 OS", tissue = "Bone", oncotree_code = "OS",
           n_samples = 6L, n_up = 274L, n_down = 237L, in_reference = TRUE)
    ),
    dataset_url_template = "https://gpsadb.gzdlab.com/dataset/{id}"
  )
}

fixture_dataset <- function() {
  list(
    id = "D20305",
    title = "D20305(Knock_down TP53 in U-2 OS)",
    perturbed_gene = "TP53",
    method = "siRNA",
    cell_line = "U-2 OS",
    n_samples = 2L,
    in_reference = TRUE,
    url = "https://gpsadb.gzdlab.com/dataset/D20305",
    downloads = list(differential_expression_csv = "https://example.org/de.csv"),
    samples = list(
      list(name = "GSM1", group = "control", attributes = list(source = "x")),
      list(name = "GSM2", group = "treat", attributes = list(source = "y"))
    )
  )
}

fixture_de <- function() {
  list(
    dataset_id = "D20305",
    title = "D20305(Knock_down TP53 in U-2 OS)",
    n_genes_tested = 34657L,
    padj_lt = 0.05,
    n_up = 274L,
    n_down = 237L,
    returned = 2L,
    genes = list(
      list(gene = "CDKN1A", gene_id = "ENSG00000124762", log2fc = 1.66837,
           padj = 1.86282e-16, pvalue = 7.51439e-20, base_mean = 6295.86),
      list(gene = "GADD45A", gene_id = "ENSG00000116717", log2fc = 1.15126,
           padj = 1.03417e-06, pvalue = 3.38952e-09, base_mean = 6202.81)
    ),
    url = "https://gpsadb.gzdlab.com/dataset/D20305"
  )
}

fixture_gsea <- function() {
  list(
    dataset_id = "D20305",
    library = "Hallmarks",
    n_terms = 50L,
    n_significant = 21L,
    returned = 2L,
    terms = list(
      list(term = "HALLMARK_TNFA_SIGNALING_VIA_NFKB", nes = 2.12, es = 0.95,
           padj = 1.67e-09, pvalue = 1e-10, set_size = 196L,
           leading_edge = "tags=58%", n_core_genes = 114L,
           core_genes = list("NFKB1", "NFKB2")),
      list(term = "HALLMARK_HYPOXIA", nes = 1.9, es = 0.87, padj = 3.2e-08,
           pvalue = 3.2e-09, set_size = 200L, leading_edge = "tags=15%",
           n_core_genes = 23L)
    ),
    url = "https://gpsadb.gzdlab.com/dataset/D20305"
  )
}

fixture_hits <- function() {
  list(
    gene = "CDKN1A",
    padj_lt = 0.05,
    total = 2957L,
    n_up = 2957L,
    n_down = 1565L,
    returned = 2L,
    hits = list(
      list(dataset = "D23745", perturbed_gene = "RNF187", method = "siRNA",
           cell_line = "MCF7", log2fc = 6.78, padj = 0, base_mean = 165909),
      list(dataset = "D28333", perturbed_gene = "OGDHL", method = "knockout",
           cell_line = "Ch-CRPC", log2fc = 4.95, padj = 0, base_mean = 112487)
    )
  )
}

fixture_gene_sets <- function() {
  list(
    total = 2L,
    returned = 2L,
    gene_sets = list(
      list(library = "Hallmarks", term = "HALLMARK_HYPOXIA", size = 200L,
           testable = TRUE, genes = list("HIF1A", "VEGFA")),
      list(library = "biocarta", term = "BIOCARTA_P53HYPOXIA_PATHWAY",
           size = 21L, testable = TRUE)
    )
  )
}

fixture_biotrigger <- function() {
  list(
    hash = "c8c7d78c", release = "2026.10.22",
    url = "https://gpsadb.gzdlab.com/biotrigger/c8c7d78c",
    n_genes = 5L, n_matched = 5L, n_datasets = 7112L, returned = 1L,
    results = list(
      list(rank = 1L, dataset = "D22257", perturbed_gene = "IRAK4",
           method = "inhibit", cell_line = "SEM", es = 0.995926,
           effect = "Activated", n_genes_in_dataset = 5L)
    )
  )
}

fixture_fastgpsa <- function() {
  list(
    hash = "8cb4728c", release = "2026.10.22",
    url = "https://gpsadb.gzdlab.com/fastgpsa/8cb4728c",
    source = "dataset", n_up_genes = 500L, n_down_genes = 500L,
    n_datasets = 7112L, returned = 1L,
    results = list(
      list(rank = 1L, dataset = "D20305", perturbed_gene = "TP53",
           method = "siRNA", cell_line = "U-2 OS", gscore = -2, up_es = 1,
           down_es = -1, effect = "Inhibited")
    )
  )
}
