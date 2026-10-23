# 02 — "谁调控我的基因 / 我的通路？"
#
# 全库反查（不用先挑数据集）：
#   query_gene       哪些扰动会改变某个基因
#   query_gene_set   哪些扰动会激活/抑制某条通路
#   search_gene_sets 先把通路名查准
#
#   Rscript examples/02-reverse-lookup.R

library(gpsadb)

# --- 1. 通路名要先查准 -----------------------------------------------------
# 库里 8 个基因集库，条目名各有前缀（HALLMARK_*、REACTOME_*、KEGG_*…）。
terms <- gpsadb_search_gene_sets(
  query         = "hypoxia",
  testable_only = TRUE,      # 只保留至少在一个数据集里算过 GSEA 的条目
  limit         = 10
)
print(terms[, c("library", "term", "size", "testable")])

# --- 2. 哪些扰动会激活缺氧通路 ---------------------------------------------
# "激活" = NES > 0：扰动后该通路在差异表达排序里靠上。
act <- gpsadb_query_gene_set("HALLMARK_HYPOXIA", direction = "up", limit = 500)
cat(sprintf("\nHALLMARK_HYPOXIA：全库 %d 个数据集显著（上调 %d / 下调 %d），本页 %d 条\n",
            gpsadb_meta(act, "total"), gpsadb_meta(act, "n_up"), gpsadb_meta(act, "n_down"), nrow(act)))

# 一条 hit 就是一个数据集，同一个基因可能在多株细胞系里各有一条。
# 先看哪些基因反复出现，再回去看明细——比盯着 padj 排序更有信息。
cat("\n--- 出现在最多数据集里的扰动基因（本页内）---\n")
print(utils::head(sort(table(gpsadb_data(act)$perturbed_gene), decreasing = TRUE), 10))

print(utils::head(act[, c("dataset", "perturbed_gene", "method",
                               "cell_line", "nes", "padj")], 10))

# --- 3. 哪些扰动会改变某个基因 ---------------------------------------------
# "哪些扰动让 CDKN1A 升高" —— 最常见的用法。
up <- gpsadb_query_gene("CDKN1A", direction = "up", limit = 500)
cat(sprintf("\nCDKN1A 显著上调：全库 %d 条命中（上调 %d / 下调 %d），本页 %d 条\n",
            gpsadb_meta(up, "total"), gpsadb_meta(up, "n_up"), gpsadb_meta(up, "n_down"), nrow(up)))

cat("最常见的扰动基因：\n")
print(utils::head(sort(table(gpsadb_data(up)$perturbed_gene), decreasing = TRUE), 10))

# 按细胞系筛：结论会不会只是某一株细胞系带出来的？
hepg2 <- up[grepl("Hep G2", gpsadb_data(up)$cell_line), ]
cat("\n其中 Hep G2 里：", nrow(hepg2), "条\n")
if (nrow(hepg2)) {
  print(utils::head(hepg2[, c("dataset", "perturbed_gene", "log2fc", "padj")], 5))
}

# --- 4. 分页：怎么翻完整个结果集 ------------------------------------------
# 反查类接口每页最多 500 条，用 offset 翻页。命中总数看 meta$total。
cat(sprintf("\nCDKN1A 上调命中 %d 条，每页 500 条\n", gpsadb_meta(up, "total")))

second <- gpsadb_query_gene("CDKN1A", direction = "up", limit = 500, offset = 500)
cat(sprintf("第 2 页：%d 条（meta$offset = %s）\n",
            nrow(second), gpsadb_meta(second, "offset")))

# search_datasets 才是能翻页的那个：71 个 TP53 数据集，按 100 一页翻完
paged <- do.call(rbind, lapply(0:1, function(i) {
  gpsadb_data(gpsadb_search_datasets(perturbed_gene = "TP53", limit = 100, offset = i * 100))
}))
cat(sprintf("\nTP53 数据集翻页收集：%d 条（total = %d）\n",
            nrow(paged), gpsadb_meta(gpsadb_search_datasets(perturbed_gene = "TP53", limit = 1), "total")))
print(table(paged$method))

# --- 5. 反过来问：我的基因属于哪些通路 -------------------------------------
myset <- gpsadb_search_gene_sets(contains_gene = "HIF1A", limit = 5)
print(myset[, c("library", "term", "size")])
