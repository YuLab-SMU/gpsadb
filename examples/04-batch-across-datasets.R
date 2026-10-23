# 04 — 把很多数据集摊成一张表
#
# 典型的用法：一个基因被扰动了几十次（不同细胞系 × 方法），把同一组下游基因
# 的差异表达拉出来并排看，判断哪些结论是稳的、哪些只在某一株细胞系里成立。
#
#   Rscript examples/04-batch-across-datasets.R

library(gpsadb)

genes <- c("TP53", "MDM2", "CDKN1A", "GADD45A", "BAX", "BBC3")

# --- 1. 收集数据集 ---------------------------------------------------------
sets <- gpsadb_search_datasets(perturbed_gene = "TP53", reference_only = TRUE,
                               limit = 200)
cat("参考集里扰动 TP53 的数据集：", nrow(sets), "/", gpsadb_meta(sets, "total"), "\n")
print(table(gpsadb_data(sets)$method))

ids <- gpsadb_data(sets)$id
cat("本次取前 12 个跑：", paste(ids[1:12], collapse = ", "), "\n")

# --- 2. 逐个取这 6 个基因的差异表达 ---------------------------------------
rows <- lapply(ids[1:12], function(id) {
  d <- gpsadb_de(id, genes = genes)
  if (!nrow(d)) return(NULL)
  cbind(dataset = id, d[, c("gene", "log2fc", "padj")])
})
de <- do.call(rbind, rows)

# 拼上数据集元信息（细胞系、方法），这样表能直接拿去报告
meta <- sets[, c("id", "cell_line", "method", "n_samples")]
names(meta)[1] <- "dataset"
de <- merge(de, meta, by = "dataset")
de <- de[order(de$dataset, de$gene), ]
cat("\n--- 长表（可直接 write.csv）---\n")
print(utils::head(de, 8), row.names = FALSE)

# --- 3. 摊成矩阵：行是基因，列是数据集 ------------------------------------
m <- matrix(NA_real_, nrow = length(genes), ncol = length(ids[1:12]),
            dimnames = list(genes, ids[1:12]))
idx <- cbind(match(de$gene, genes), match(de$dataset, ids[1:12]))
m[idx] <- de$log2fc

cat("\n--- log2fc 矩阵（NA = 该数据集没测到这个基因）---\n")
print(round(m, 2))

# 只看符号，一眼看出方向是否一致
sign_chr <- function(x) ifelse(is.na(x), ".", ifelse(x > 0, "+", "-"))
cat("\n--- 符号矩阵（+ 上调 / - 下调 / . 缺失）---\n")
print(apply(m, 2, sign_chr))

# --- 4. 方向一致性：这个结论跨数据集稳不稳 --------------------------------
majority <- function(x) {
  x <- x[!is.na(x)]
  if (!length(x)) return(NA_real_)
  mean(sign(x) == sign(median(x)))
}
conc <- sort(vapply(genes, function(g) majority(m[g, ]), numeric(1)),
             decreasing = TRUE)
cat("\n--- 与各基因中位方向一致的数据集比例 ---\n")
print(round(conc, 2))

# 某个基因的方向在什么条件下翻转？把它和细胞系/方法并排看
cdkn1a <- de[de$gene == "CDKN1A", ]
cat("\n--- CDKN1A 逐个数据集 ---\n")
print(cdkn1a[order(cdkn1a$log2fc), c("dataset", "cell_line", "method",
                                     "log2fc", "padj")], row.names = FALSE)

# --- 5. 落盘 ---------------------------------------------------------------
# 包里不往工作目录写文件；这里写 tempdir()，换成你自己的路径即可。
out <- file.path(tempdir(), "gpsadb_tp53_de.csv")
utils::write.csv(de, out, row.names = FALSE)
cat("\n长表已写出：", out, "\n")

# 矩阵也可以直接交给 heatmap / pheatmap / ComplexHeatmap：
# heatmap(m, scale = "none", na.rm = TRUE)
