# 03 — "我的差异表达结果，像哪个基因被扰动？"
#
# 两件工具，输入不同：
#   run_biotrigger  我的"一组基因"（通路/基因集）-> 谁触发它
#   run_fastgpsa    我的"上调 + 下调签名"或"完整排序表" -> 谁复现它 / 谁反转它
#
# 这里拿 GPSAdb 自己一个数据集当"你的数据"的替身；换成你 read.csv() 进来的
# DESeq2 结果表是一样的。
#
#   Rscript examples/03-match-your-own-signature.R

library(gpsadb)

# --- 1. 准备签名 -----------------------------------------------------------
# 假装这是你自己做的一次敲低实验的结果：两列 gene / log2fc 就够。
mine <- gpsadb_de("D20305", direction = "both", sort_by = "log2fc", limit = 500)$data
cat("签名里有多少基因：", nrow(mine), "\n")
print(utils::head(mine[, c("gene", "log2fc", "padj")], 5))

# 最上调 / 最下调各 50 个（服务端要求每边至少 5 个）
up_genes   <- mine$gene[order(-mine$log2fc)][1:50]
down_genes <- mine$gene[order(mine$log2fc)][1:50]

# --- 2. 双侧签名 -> fastGPSA -----------------------------------------------
# gscore = down_es - up_es，在每个参考数据集上算：
#   gscore < 0（effect "Inhibited"）：该扰动复现了你的签名
#   gscore > 0（effect "Activated"）：该扰动反转了你的签名
sig <- gpsadb_fastgpsa(up_genes = up_genes, down_genes = down_genes, limit = 10)
cat("\n--- 复现/反转我这份签名的扰动 ---\n")
print(sig$data[, c("rank", "dataset", "perturbed_gene", "method",
                   "cell_line", "gscore", "effect")])
cat("报告页：", sig$meta$url, "\n")

# 自检：签名是从 D20305 造的，它自己应该排第一、且是"复现"。
# 不硬报错——上游数据更新时这里是提示，不是阻塞。
if (sig$data$dataset[1] == "D20305") {
  cat("自检通过：D20305 排第一（gscore =", round(sig$data$gscore[1], 2), "，",
      sig$data$effect[1], "）\n")
} else {
  warning("D20305 没有排第一，可能服务端 release 变了", call. = FALSE)
}

# 只看反转的（想找"能把我的表型拉回来"的扰动）
opposite <- gpsadb_fastgpsa(up_genes = up_genes, down_genes = down_genes,
                            direction = "opposite", limit = 10)
cat("\n--- 反转我这份签名的扰动 ---\n")
print(opposite$data[, c("dataset", "perturbed_gene", "cell_line", "gscore", "effect")])

# --- 3. 完整排序表 -> fastGPSA（信息量最大）-------------------------------
# 服务端要求 > 200 个基因、且不要按 p 值截断——排名本身就是信息。
ranked <- gpsadb_fastgpsa(ranked_list = mine[, c("gene", "log2fc")], limit = 10)
cat("\n--- 用 500 个基因的完整排序表 ---\n")
print(ranked$data[, c("rank", "dataset", "perturbed_gene", "gscore", "effect")])

# 两种输入给出的 Top 基因重叠多少？（自己写报告时值得写一句）
overlap <- intersect(sig$data$perturbed_gene, ranked$data$perturbed_gene)
cat("双侧签名 vs 排序表，Top 10 的扰动基因重叠：", length(overlap),
    "个（", paste(overlap, collapse = ", "), "）\n", sep = "")

# --- 4. 同一个扰动往往命中多个数据集：按基因归并 ---------------------------
# 多株细胞系/多种方法各算一条，报告时通常一个基因留一条最可信的。
best <- sig$data[order(abs(sig$data$gscore), decreasing = TRUE), ]
best <- best[!duplicated(best$perturbed_gene), ]
cat("\n归并后（每个扰动基因一条）：\n")
print(utils::head(best[, c("dataset", "perturbed_gene", "cell_line", "gscore", "effect")], 8))

# --- 5. 直接用库里某个数据集的签名当查询 -----------------------------------
# 用途：这个数据集表现出的状态，还有哪些扰动能复现？谁和它的表型最像？
self <- gpsadb_fastgpsa(dataset_id = "D20305", direction = "opposite", limit = 10)
cat("\n--- 谁反转了 D20305 的状态 ---\n")
print(self$data[, c("rank", "dataset", "perturbed_gene", "cell_line", "gscore", "effect")])

# --- 6. 对照：单边输入用 BioTrigger ---------------------------------------
# BioTrigger 只收"一组基因"，不区分上下调；它按 ES 给你谁激活/抑制这组基因。
# es > 0（Activated）：这组基因在扰动上调的基因里富集
# es < 0（Inhibited）：在扰动下调的基因里富集；多数扰动是功能缺失，
#                      所以 es < 0 提示被扰动的那个基因本身是这组基因的促进者。
hypoxia_genes <- c("HIF1A", "VEGFA", "SLC2A1", "PDK1", "BNIP3",
                   "LDHA", "PGK1", "ENO1", "ADM", "NDRG1")
bt <- gpsadb_biotrigger(hypoxia_genes, limit = 10)
cat("\n--- 谁触发这组缺氧基因 ---\n")
print(bt$data[, c("rank", "dataset", "perturbed_gene", "method",
                  "cell_line", "es", "effect")])
cat("命中基因数：", bt$meta$n_matched, "/", bt$meta$n_genes,
    "| 参考集数据集数：", bt$meta$n_datasets, "\n")
