# gpsadb 示例

每个脚本都能独立跑（都直接打真实的 GPSAdb 端点，无需 key）。先装包：

```bash
R CMD INSTALL --library=/home/wang/Rlib ../aisdk.mcp
R CMD INSTALL --library=/home/wang/Rlib ../gpsadb
```

然后：

```bash
Rscript examples/01-explore-a-perturbation.R
```

| 脚本 | 回答的问题 | 用到的函数 | 请求数 |
|---|---|---|---|
| `01-explore-a-perturbation.R` | 这株细胞里敲掉某个基因，到底发生了什么？ | `search_datasets` → `dataset` → `de` → `gsea` | ~7 |
| `02-reverse-lookup.R` | 谁调控我的基因 / 我的通路？能翻页吗？ | `search_gene_sets`、`query_gene`、`query_gene_set`、`search_datasets(offset=)` | ~7 |
| `03-match-your-own-signature.R` | 我自己的差异表达结果像哪个基因被扰动？ | `fastgpsa`（双侧签名 / 排序表 / dataset_id 三种输入）、`biotrigger` | ~5 |
| `04-batch-across-datasets.R` | 一个结论跨数据集稳不稳？ | 循环调 `de`，拼长表 / 矩阵 | 13 |
| `05-agent-tools.R` | 让模型自己决定查什么 | `tool_catalog`、`tools()` + `aisdk::generate_text(tools=)` | 1（离线部分） |

几个约定：

- 都从 `library(gpsadb)` 开始，一次调用 = 一次 MCP 请求，单次 0.6–1.1 s。
- `$data` 是 tibble，`$meta` 是标量（`total`、`n_up`、`n_down`、报告页 URL）。
- 反查类接口（`query_gene` / `query_gene_set`）上限 500 条且**没有 offset**；只有
  `search_datasets` 能翻页。命中超过 500 时靠收窄条件（`padj_lt`、`min_abs_log2fc`）。
- 写文件一律写 `tempdir()`，不落在工作目录（`04` 里有例子）。

`03` 里的 `gscore` 语义（来自服务端工具说明）：

```
gscore = down_es - up_es，在每个参考数据集上算
  gscore < 0（effect "Inhibited"）：该扰动复现你的签名
  gscore > 0（effect "Activated"）：该扰动反转你的签名
```

`biotrigger` 的 `es` 语义：
`es > 0` 该基因集在扰动**上调**的基因里富集；`es < 0` 在**下调**的基因里富集。
多数扰动是功能缺失，所以 `es < 0` 提示被扰动的基因本身是这组基因的促进者。
