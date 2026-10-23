# 06 — 把一句问题翻成 R 代码
#
#   Rscript examples/06-intent-to-code.R
#
# 需要：aisdk + 一个可用的模型（GSADB_DEMO_MODEL 或 aisdk::set_model() 配的默认）
# 以及对应的 API key。翻出来的是普通 R：print 看一眼，没问题再 eval。

library(gpsadb)

model <- Sys.getenv("GPSADB_DEMO_MODEL", "deepseek:deepseek-chat")

# 一句话 -> 代码。gpsadb_intent() 只把 GPSAdb 这一个 client 填好，
# 并且告诉模型优先用 gpsadb_* 这些返回 tibble 的函数。
q <- gpsadb_intent("HeLa 里哪些扰动把 CDKN1A 压下去？", model = model)

# 先看：用了哪个函数、参数是什么、筛哪一列
cat(q, "\n")

# 生成代码里的 client 变量叫 gps
gps <- gpsadb_client()

# 确认无误再跑。草稿不一定一次就对（模型会挑错函数或超上限），
# 所以这里只提示，不让示例挂掉。
res <- tryCatch(eval(parse(text = q)), error = function(e) e)
if (inherits(res, "error")) {
  cat("\n这份草稿跑不通：", conditionMessage(res), "\n")
  cat("改一改（通常是函数名、参数上限或列名），再跑一次 eval。\n")
} else {
  print(res)
  if (inherits(res, "gpsadb_result")) {
    head(res[, intersect(c("dataset", "perturbed_gene", "cell_line", "log2fc", "padj"),
                         names(res))])
  }
}
