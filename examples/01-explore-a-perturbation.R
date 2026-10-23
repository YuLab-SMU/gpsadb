# 01 — "这株细胞里敲掉 TP53，到底发生了什么？"
#
# 走一遍 GPSAdb 的主线：
#   search_datasets -> get_dataset -> get_differential_expression / get_gsea_results
#
#   Rscript examples/01-explore-a-perturbation.R

library(gpsadb)

# --- 1. 先找到想看的实验 ---------------------------------------------------
# 一个基因往往有几十个数据集（不同细胞系 × 不同方法）。U-2 OS 是骨肉瘤细胞系。
hits <- gpsadb_search_datasets(
  perturbed_gene = "TP53",
  cell_line      = "U-2 OS",
  limit          = 20
)
cat(sprintf("U-2 OS 里扰动 TP53 的数据集：%d / TP53 全集 %d\n",
            nrow(hits), gpsadb_meta(hits, "total")))
print(hits[, c("id", "method", "cell_line", "n_samples", "n_up", "n_down")])

# 只想看能参与 BioTrigger / fastGPSA 的参考集：
ref <- gpsadb_search_datasets(perturbed_gene = "TP53", reference_only = TRUE, limit = 5)
cat("\n参考集里的前几个：", paste(gpsadb_data(ref)$id, collapse = ", "), "\n")

# --- 2. 看看这个数据集是怎么来的 -------------------------------------------
id <- "D20305"                       # siRNA 敲低 TP53，U-2 OS
ds <- gpsadb_dataset(id)

cat("\n", gpsadb_meta(ds, "title"), "\n", sep = "")
cat("方法:", gpsadb_meta(ds, "method_label"), "| 细胞系:", gpsadb_meta(ds, "cell_line"),
    "| 来源:", gpsadb_meta(ds, "data_source"), gpsadb_meta(ds, "accession"), "\n")
cat("样本:", nrow(ds), "（", paste(names(table(gpsadb_data(ds)$group)),
                                       table(gpsadb_data(ds)$group), sep = "=", collapse = ", "),
    "）\n", sep = "")
cat("检验到的基因数:", gpsadb_meta(ds, "n_genes_tested"),
    "| 上调:", gpsadb_meta(ds, "n_up"), "| 下调:", gpsadb_meta(ds, "n_down"), "\n")
cat("原始数据下载:", gpsadb_meta(ds, "downloads")$raw_counts_csv, "\n")

# 每个样本的元数据都在 attributes 这一 list 列里
print(ds[1, c("name", "group")])
str(gpsadb_data(ds)$attributes[[1]], max.level = 1)

# 不想只信预计算的表？原始 counts、样本注释、DESeq2 结果、排序表都在这里
files <- gpsadb_downloads(id)
print(files[, c("file", "content", "url")])

# --- 3. 敲低之后哪些基因动了 -----------------------------------------------
cat("\n--- 下调最显著的 10 个基因 ---\n")
down <- gpsadb_de(id, direction = "down", limit = 10)
print(gpsadb_data(down))

cat("\n--- 上调最显著的 10 个基因 ---\n")
print(gpsadb_de(id, direction = "up", limit = 10))

# 只查自己关心的基因：一次请求，不受 padj / limit 过滤
cat("\n--- 指定的几个基因 ---\n")
print(gpsadb_de(id, genes = c("TP53", "MDM2", "CDKN1A", "GADD45A", "BAX")))

# --- 4. 通路层面 -----------------------------------------------------------
cat("\n--- Hallmarks 里被显著改变的通路 ---\n")
gsea <- gpsadb_gsea(id, library = "Hallmarks", limit = 10)
print(gsea[, c("term", "nes", "padj", "set_size", "n_core_genes")])
cat("显著条目:", gpsadb_meta(gsea, "n_significant"), "/", gpsadb_meta(gsea, "n_terms"), "\n")

# 想看某条通路的 leading-edge 基因：
hypoxia <- gpsadb_gsea(id, terms = "HALLMARK_HYPOXIA", include_core_genes = TRUE)
cat("\nHALLMARK_HYPOXIA: NES =", round(gpsadb_data(hypoxia)$nes, 2),
    "| 核心基因前 10 个:", paste(head(unlist(gpsadb_data(hypoxia)$core_genes[[1]]), 10), collapse = ", "), "\n")

# 换一个库，同样的数据集（KEGG 里条目名不一样）
kegg <- gpsadb_gsea(id, library = "kegg_legacy", limit = 5)
print(kegg[, c("term", "nes", "padj")])

# --- 5. 一句话总结 -------------------------------------------------------
cat(sprintf(
  "\n结论：TP53 敲低后 %s（log2fc = %.2f）下调最明显；%s（NES = %.2f）是上调最强的通路。\n",
  gpsadb_data(down)$gene[1], gpsadb_data(down)$log2fc[1],
  gpsadb_data(gsea)$term[1], gpsadb_data(gsea)$nes[1]
))
