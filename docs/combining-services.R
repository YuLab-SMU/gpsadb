# 两个 MCP 服务串起来：GPSAdb（扰动转录组）× STRING（蛋白互作）
#
#   Rscript docs/combining-services.R
#
# 需要：gpsadb、aisdk.mcp；可选 uvx（第三层 PDBe 结构，见文末）。
suppressPackageStartupMessages({
  library(gpsadb)
  library(aisdk.mcp)
})

# STRING 收的是回车分隔的字符串，不是 JSON 数组（GPSAdb 正好相反）
sep <- function(x) paste(x, collapse = "\r")

# --- 服务一：GPSAdb（HTTP，公开端点）----------------------------------------
# TP53 敲低，U-2 OS，D20305；两端各 10 个基因。管道把结果直接变成基因列表。
up_genes <- gpsadb_de("D20305", direction = "up", limit = 10) |> gpsadb_genes()
down_genes <- gpsadb_de("D20305", direction = "down", limit = 10) |> gpsadb_genes()
genes <- c(up_genes, down_genes)
cat("上调:", paste(up_genes, collapse = ", "), "\n")
cat("下调:", paste(down_genes, collapse = ", "), "\n\n")

# --- 服务二：STRING（官方远程 MCP）------------------------------------------
string <- create_mcp_http_client("https://mcp.string-db.org/", timeout = 90)

# 1) 这组蛋白是不是比随机更连通
enrichment <- string$call_tool_data("string_ppi_enrichment", list(
  identifiers = sep(genes), species = "9606"
))$results[[1]]
# 注：STRING 客户端用自己的 call_tool_data()，不用 gpsadb_call()——
# 后者会给结果附加 GPSAdb 的溯源信息。

cat(sprintf(
  "PPI 富集：%d 个节点 / %d 条边，随机期望 %.1f 条，p = %.2g；平均度 %.1f，聚类系数 %.2f\n\n",
  enrichment$number_of_nodes, enrichment$number_of_edges,
  enrichment$expected_number_of_edges, enrichment$p_value,
  enrichment$average_node_degree, enrichment$local_clustering_coefficient
))

# 2) 边：谁和谁连，哪一侧
net <- string$call_tool_data("string_interactions_query_set", list(
  proteins = sep(genes), species = "9606", required_score = "400"
))
edge_name <- function(p) p$preferred_name
edges <- do.call(rbind, lapply(net$network, function(e) {
  data.frame(
    a = edge_name(e$proteins[[1]]), b = edge_name(e$proteins[[2]]),
    functional = e$functional$association_confidence %||% NA_real_,
    physical = e$physical$association_confidence %||% NA_real_,
    regulatory = e$regulatory$combined_confidence %||% NA_real_,
    stringsAsFactors = FALSE
  )
}))
edges$side <- ifelse(
  edges$a %in% up_genes & edges$b %in% up_genes, "up-up",
  ifelse(edges$a %in% down_genes & edges$b %in% down_genes, "down-down", "cross")
)
edges <- edges[order(-edges$functional), ]

cat("边的分布：\n"); print(table(edges$side))
cat("\n最强的 8 条：\n")
print(head(edges[, c("a", "b", "side", "functional", "physical")], 8),
      row.names = FALSE, digits = 3)
cat("\n跨两侧的边（桥）：\n")
print(edges[edges$side == "cross", c("a", "b", "functional", "physical")],
      row.names = FALSE, digits = 3)

deg <- sort(table(c(edges$a, edges$b)), decreasing = TRUE)
cat("\n度数最高的节点：\n"); print(head(deg, 6))

# 3) 社区划分（kmeans，STRING 默认）与网络地址
clusters <- string$call_tool_data("string_network_clustering", list(
  proteins = sep(genes), species = "9606", required_score = "400",
  clustering_algorithm = "kmeans"
))
cat("\n社区（簇内基因按 STRING 的顺序）：\n")
for (cluster in clusters$clusters) {
  cat(sprintf("  簇 %d（%s，%d 个）：%s\n", cluster$clusterNumber,
              if (nzchar(cluster$clusterNames)) cluster$clusterNames else "未命名",
              cluster$proteinCount, cluster$preferredNames))
}
cat("\n网络图：", clusters$image_url, "\n")
cat("可交互：", clusters$interactive_network_url, "\n")

string$close()

# --- 可选的第三层：PDBe（结构覆盖度，判断“能不能碰”）----------------------
# 需要 uvx。去掉注释即可跑。
# if (nzchar(Sys.which("uvx"))) {
#   pdbe <- create_mcp_client("uvx", c("pdbe-mcp-server", "--transport", "stdio",
#                                      "--server-type", "pdbe_api_server"))
#   best <- Filter(function(t) startsWith(t$name, "best_soubsu_acc"),
#                  pdbe$list_tools())[[1]]$name
#   # gene -> UniProt 仍需离线映射（见文档第 5 节）
#   pdbe$close()
# }
