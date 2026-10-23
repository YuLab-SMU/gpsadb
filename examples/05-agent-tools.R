# 05 — 把 GPSAdb 交给 agent（工具由服务端提供）
#
# 前面几个 demo 都是你自己决定调哪个函数。这里换一种：把 GPSAdb 的 11 个工具
# 直接交给 aisdk，让模型自己决定查什么、怎么翻。
#
#   Rscript examples/05-agent-tools.R
#
# 需要：aisdk + 一个可用的模型（下面 model 变量）以及对应的 API key。
# 没配 key 时脚本只跑离线部分，并打印怎么配。

library(gpsadb)

# --- 1. 离线：看看交给模型的是什么 -----------------------------------------
# 工具名和 JSON Schema 直接来自 GPSAdb 服务端，不是包内第二份定义。
print(gpsadb_tool_catalog(), n = 20)

tools <- gpsadb_tools()
cat("\n工具数：", length(tools), "\n")
cat("前两个：", tools[[1]]$name, "/", tools[[2]]$name, "\n")
cat("search_datasets 的参数 schema：\n")
spec <- tools[[2]]$to_api_format()
str(spec[["function"]]$parameters, max.level = 2)

# --- 2. 在线：让模型自己调 -------------------------------------------------
# 换成你要用的模型（provider:model）。deepseek 需要 aisdk.providers。
model <- Sys.getenv("GPSADB_DEMO_MODEL", "openai:gpt-4o-mini")

key_env <- switch(
  sub(":.*$", "", model),
  openai     = "OPENAI_API_KEY",
  deepseek   = "DEEPSEEK_API_KEY",
  anthropic  = "ANTHROPIC_API_KEY",
  gemini     = "GEMINI_API_KEY",
  NA_character_
)

if (is.na(key_env) || !nzchar(Sys.getenv(key_env))) {
  cat("\n[跳过在线部分] 没有检测到",
      if (is.na(key_env)) "该 provider 的" else key_env,
      "API key。\n")
  cat("配置后重跑，例如：\n")
  cat("  export OPENAI_API_KEY=...\n")
  cat("  export GPSADB_DEMO_MODEL=openai:gpt-4o-mini\n")
  cat("  # 或 deepseek:deepseek-chat（需 install.packages 里的 aisdk.providers）\n")
  quit(save = "no")
}

# max_steps 控制最多几轮工具调用：这个问题至少要 3 轮
# （列通路 -> 看它们的 leading-edge 基因 -> 做签名匹配）。
result <- aisdk::generate_text(
  model = model,
  prompt = paste(
    "Using GPSAdb tools: for dataset D20305 (TP53 knockdown in U-2 OS),",
    "1) list the top 5 significantly changed Hallmark pathways;",
    "2) take the leading-edge genes of the top one;",
    "3) run a fastGPSA signature search with those genes and list 5 perturbations",
    "   that reproduce that state, with their dataset IDs and cell lines.",
    "Then summarise in 4 bullet points."
  ),
  system = paste(
    "You are a bioinformatics analyst. Use the supplied tools for all facts;",
    "never invent gene names, dataset IDs or statistics."
  ),
  tools = tools,
  max_steps = 6
)

cat("\n--- 模型的回答 ---\n")
cat(result$text, "\n")

# 模型实际调了哪些工具？(字段名随 aisdk 版本可能不同，打印一次看结构)
cat("\n--- 调用轨迹 ---\n")
str(result[setdiff(names(result), "text")], max.level = 1)

# 想复查模型引用的数字，直接用同一个 dataset id 复核：
# gpsadb_gsea("D20305", limit = 5)
