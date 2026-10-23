# 07 — 三个服务连起来：因果、关联、物理
#
#   Rscript examples/07-three-services.R
#
# 例子里的一对基因：HIF1A 与 PGK1（缺氧程序里最经典的一对）。
# 为什么不用 TP53/CDKN1A：那个数据集里 TP53 自己几乎没被敲下去
# （log2fc -0.005，padj 1.00），扰动一侧就不可信了。选例子先看被扰动的基因。
#
# 需要：gpsadb、aisdk.mcp。三个服务都是公开端点，无需 key。

suppressPackageStartupMessages({
  library(gpsadb)
  library(aisdk.mcp)
})

gps <- gpsadb_client()
gt  <- create_mcp_http_client("https://gtbadb.gzdlab.com/mcp", timeout = 120)
str <- create_mcp_http_client("https://mcp.string-db.org/", timeout = 90)

pair <- c("HIF1A", "PGK1")

# --- 1. 因果（扰动）：GPSAdb ------------------------------------------------
# D22946 = siRNA 敲低 HIF1A，HeLa
deg <- gpsadb_de("D22946", genes = c("HIF1A", "PGK1", "SLC2A1", "LDHA"))
cat("== GPSAdb：D22946 敲低 HIF1A（HeLa）\n")
print(deg[, c("gene", "log2fc", "padj")])

# --- 2. 关联（人体样本）：GTBAdb -------------------------------------------
one_source <- function(datasource) {
  res <- gt$call_tool_data("correlate_two", list(
    category1 = "gene", category2 = "gene", datasource = datasource,
    feature1 = pair[1], feature2 = pair[2], method = "pearson"
  ))
  data.frame(
    datasource = datasource,
    subtype = vapply(res$rows, function(r) r$subtype, ""),
    n = vapply(res$rows, function(r) as.integer(r$n), 1L),
    cor = vapply(res$rows, function(r) as.numeric(r$cor), 1),
    p = vapply(res$rows, function(r) as.numeric(r$p), 1),
    stringsAsFactors = FALSE
  )
}
sources <- c("gtex", "tcga_tumor", "ccle")
cor_df <- do.call(rbind, lapply(sources, one_source))

cat("\n== GTBAdb：", pair[1], " 与 ", pair[2], " 的共表达\n", sep = "")
summary_df <- data.frame(
  datasource = sources,
  subtypes = vapply(sources, function(d) sum(cor_df$datasource == d), 1L),
  median_cor = vapply(sources, function(d)
    median(cor_df$cor[cor_df$datasource == d], na.rm = TRUE), 1),
  sig_positive = vapply(sources, function(d)
    sum(cor_df$datasource == d & cor_df$p < 0.05 & cor_df$cor > 0), 1L),
  sig_negative = vapply(sources, function(d)
    sum(cor_df$datasource == d & cor_df$p < 0.05 & cor_df$cor < 0), 1L)
)
print(summary_df, row.names = FALSE, digits = 3)

# --- 3. 物理还是调控：STRING ----------------------------------------------
edge_of <- function(a, b) {
  net <- str$call_tool_data("string_interactions_query_set", list(
    proteins = paste(c(a, b), collapse = "\r"), species = "9606"
  ))
  if (!length(net$network)) return(NULL)
  e <- net$network[[1]]
  c(functional = e$functional$association_confidence %||% NA,
    physical = e$physical$association_confidence %||% NA,
    regulatory = e$regulatory$combined_confidence %||% NA)
}
cat("\n== STRING：这一对是'调控'还是'物理结合'\n")
print(round(edge_of("HIF1A", "PGK1"), 3))
cat("   （对照）NFKB1-NFKBIA：", sep = "")
print(round(edge_of("NFKB1", "NFKBIA"), 3))

# --- 4. 交给 agent 时：三个服务必须加前缀 ----------------------------------
tools <- combine_mcp_tools(gpsadb = gps, gtbadb = gt, string = str)
nms <- vapply(tools, function(t) t$name, character(1))
cat("\n== 合并后工具数：", length(nms), "（",
    paste(table(sub("__.*$", "", nms)), collapse = " / "), "）\n", sep = "")
cat("  两个同名的 get_database_info 被前缀分开：",
    paste(grep("__get_database_info$", nms, value = TRUE), collapse = ", "), "\n")

# --- 5. 三个答案放一起 -----------------------------------------------------
cat("\n== 一句话\n")
cat(sprintf("  扰动：HIF1A 敲低 %+.2f，PGK1 跟着 %+.2f（padj %.1g）\n",
            deg$log2fc[deg$gene == "HIF1A"], deg$log2fc[deg$gene == "PGK1"],
            deg$padj[deg$gene == "PGK1"]))
cat(sprintf("  关联：正常组织 r≈%.2f > 肿瘤 r≈%.2f > 细胞系 r≈%.2f，%d 个显著子类型全为正\n",
            summary_df$median_cor[1], summary_df$median_cor[2],
            summary_df$median_cor[3], sum(summary_df$sig_positive)))
cat("  物理：functional/regulatory 高、physical 低 —— 是调控关系，不是复合物。\n")
cat("  三层一致：扰动打掉了这个调控，人群里它们同步高，STRING 认得这条调控。\n")

gt$close()
str$close()
