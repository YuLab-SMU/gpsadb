# 从「哪些基因变了」到「它们是不是一个模块」

把 GPSAdb 和 STRING 两个 MCP 服务接在一起，回答一个转录组单独答不了的问题：
**一个扰动带来的那批变化基因，是一个有组织的模块，还是一堆彼此无关的巧合？**

- 服务一：**GPSAdb**，公开 HTTP 端点，7665 个基因扰动 RNA-seq 实验。它回答
  "变了哪些、往哪个方向变"。
- 服务二：**STRING**，官方远程 MCP（`https://mcp.string-db.org/`），17 个工具。
  它回答"这些蛋白之间有没有关系、构不构成一个复合物"。

一键复现：`Rscript docs/combining-services.R`。

---

## 1. 为什么是 PPI，而不是结构

我最初接的是 PDBe（蛋白结构），能回答"这个蛋白有多少被看见"。但读完数据发现，
它对**机制解读**帮助有限：结构覆盖度说的是"能不能做药"，不是"这些基因是不是
一件事"。

PPI 直接回答后者。而且 STRING 给的东西正好是转录组缺的那一半：

| 问题 | 谁能答 |
|---|---|
| 哪些基因变了、升还是降 | GPSAdb |
| 这些蛋白是不是一个复合物 | STRING（互作 + 富集检验 + 社区划分） |
| 这些蛋白有没有可用的结构 | PDBe（第三层，见第 7 节） |

**方向来自 GPSAdb，关系来自 STRING。** 两者都不单独成立。

## 2. 两条接法

**给 agent。** 两个服务的工具拼起来，前缀由各自的服务器名生成：

```r
gps    <- gpsadb_client()
string <- aisdk.mcp::create_mcp_http_client("https://mcp.string-db.org/")

combined <- aisdk.mcp::combine_mcp_tools(gpsadb = gps, string = string)
length(combined)
#> [1] 29                     # gpsadb 12 + string 17
vapply(combined, function(t) t$name, character(1))[1:2]
#> "gpsadb__get_database_info" "gpsadb__search_datasets"
```

**给脚本。** 可复现的分析写成代码，下面这条链是纯 R 的。

## 3. 用管道串起来

`|>` 在 R 里能不能用，取决于**被管道的对象是不是函数的第一个参数**。这套 API
里三类符号的落点不同，实测如下：

```r
# 结果 -> 访问器：全部成立
res |> gpsadb_data()
res |> gpsadb_meta("total")
res |> gpsadb_report_url()
res |> gpsadb_genes()            # 基因列，直接喂给下一个服务

# 客户端 -> 工具/契约：成立（client 是第一个参数）
gpsadb_client() |> gpsadb_tools(prefix = "gpsadb")
gpsadb_client() |> gpsadb_contract_check()

# 多服务器：成立
list(gpsadb_client(), string_client()) |> combine_mcp_tools()
gpsadb_client() |> combine_mcp_tools(string = string_client())
```

唯一不顺手的是查询函数：它们把数据放在第一位、`client` 放在最后
（`gpsadb_de("D20305", ..., client = )`），这是交互时更好用的顺序——
敲查询的时候不用先写客户端。管道里要用它们，有两种写法：

```r
# 1) 占位符（R >= 4.2），显式但能读
gpsadb_client() |> gpsadb_de("D20305", client = _)

# 2) 通用的管道友好入口，client 在前
gpsadb_client() |> gpsadb_call("get_differential_expression",
                               list(dataset_id = "D20305", limit = 3))
```

`gpsadb_call()` 是 `gpsadb_raw()` 的同一件事，只是参数顺序反过来：
`gpsadb_call(client, tool, args)` 给管道，`gpsadb_raw(tool, args, client)` 给交互。

**跨服务器不共用这个入口。** 每个服务器有自己的调用习惯（下一节会看到 STRING
要回车分隔的字符串），`gpsadb_call()` 还会附加 GPSAdb 的溯源信息，用错地方只会
添乱。跨服务器的管道发生在**组合**这一层（`combine_mcp_tools()`），而不是调用层。

## 4. 一次真实的运行

数据集 D20305（TP53 siRNA 敲低，U-2 OS），取差异表达两端各 10 个基因：

```
上调: TNFAIP3, CSF2, INHBA, CDKN1A, RELB, NFKB1, TNFRSF9, ATF3, NFKBIA, CD83
下调: PIF1, RNF43, DBP, PSRC1, BMP4, AURKA, FZD2, SOX2, FAM83D, ARHGEF39
```

**第一步，这组基因连不连通。** `string_ppi_enrichment`：

```
20 个节点 / 37 条边，随机期望 11.0 条，p = 8.8e-10
平均度 3.7，聚类系数 0.54
```

p 是 8.8e-10。也就是说，**这不是一张随机名单**，它是一个显著连通的模块。
这句话转录组自己说不出来。

**第二步，边落在哪一侧。** `string_interactions_query_set`：

| 边 | 条数 |
|---|---|
| 上调 ↔ 上调 | **25** |
| 下调 ↔ 下调 | 5 |
| 跨两侧（桥） | 7 |

最强的几条：

| 蛋白对 | 侧 | 功能置信度 | 物理证据 |
|---|---|---|---|
| NFKBIA – NFKB1 | up-up | 0.999 | 0.999 |
| RELB – NFKB1 | up-up | 0.999 | 0.999 |
| NFKBIA – RELB | up-up | 0.999 | 0.999 |
| FZD2 – RNF43 | down-down | 0.948 | – |
| AURKA – PSRC1 | down-down | 0.873 | 0.755 |
| **AURKA – NFKB1** | **cross** | **0.868** | **0.818** |

**第三步，社区划分。** `string_network_clustering`（kmeans）：

```
簇 1（Non-canonical NF-kappaB signal transduction，11 个）:
  TNFAIP3, NFKB1, ATF3, CDKN1A, SOX2, BMP4, AURKA, PSRC1, FAM83D, NFKBIA, RELB
簇 2（3 个）: CD83, TNFRSF9, CSF2
簇 3（2 个）: RNF43, FZD2
```

网络图：<https://string-db.org/images/userimages/network.bFTN0UMlESlh.png>

## 5. 读出来三件事

### 一、上调侧是一个复合物，不是一份名单

25 条内部边，核心是 NFKBIA–NFKB1–RELB 三角，三条都到 0.999，而且**物理证据
也是 0.999**（不只是文本共现）。加上 TNFAIP3（NFKBIA 0.895、NFKB1 0.888），
这四五蛋白本来就是同一个 NF-κB 复合物的组成部分。

这和同一数据集的 GSEA 对得上：排第一的通路是
`HALLMARK_TNFA_SIGNALING_VIA_NFKB`（NES 2.12）。转录组说"这条通路被激活"，
PPI 说"这条通路的成员在物理上就是一坨"。

### 二、下调侧根本不是模块

10 个基因之间只有 5 条边，而且基本是成对的（FZD2–RNF43、AURKA–PSRC1）。
**把"下调"当成一个功能单元去解释，是站不住的**：它们是几件互不相干的事
（Wnt 受体、DNA 复制解旋酶、纺锤体激酶、转录因子各干各的）。

这是接上 PPI 之后最容易改变结论的一条。看差异表达表时，"上调 274、下调 237"
对称得像两类，但结构上完全不对称。

### 三、方向与模块不是一回事

kmeans 分出三个社区，其中最大的那个（11 个）**同时包含上调的 NF-κB 成员和
下调的 AURKA、SOX2、BMP4、PSRC1、FAM83D**。

为什么？因为那个簇的连接主要来自 **AURKA**：它是唯一同时连到两侧的节点，
度数 6（NFKB1 11、NFKBIA 8、TNFAIP3 7、AURKA 6），跨侧的边里三条都有它：

```
AURKA – NFKB1    0.868（物理 0.818）
NFKBIA – AURKA   0.624（物理 0.456）
AURKA – TNFAIP3  0.528（物理 0.457）
AURKA – CDKN1A   0.486
```

所以对这个状态的一个可检验的猜测是：**AURKA 是两侧之间的连接点**。它下调了，
而它连着的那一坨 NF-κB 上调了；如果这个连接有功能，动 AURKA 应该能影响
NF-κB 那一侧。

注意措辞：这是**假设**，不是结论。STRING 只说"这两个蛋白有关系"，不说
"谁调控谁"，更不说在这个细胞里成立。

## 6. 这件事的用处

**一、给差异表达结果加一层"是否成模块"的判断。** 20 个基因跑一次富集检验，
就知道该不该当成一个 program 去讲。下调侧那 5 条边，就是不该当 program 讲的证据。

**二、把"通路富集"落到具体蛋白子上。** GSEA 告诉你 NF-κB 排第一，PPI 告诉你
是哪几个蛋白、哪几条边、物理证据多强。写文章时后者才是可引用的细节。

**三、找桥。** 两个模块之间真正值得做实验的，往往不是度数最高的那个（NFKB1），
而是**同时连两侧、度数中等**的那个（AURKA）。这一步单独看表达量永远看不出来。

**四、给 agent 用。** 29 个工具一起交给模型，它可以自己决定"先查富集、再拉
互作、再问社区"，而不用你预先写死流程。

## 7. 第三层（可选）：能不能碰

PPI 回答"是不是一个模块"，结构回答"能不能做药"。加上 PDBe 之后：

| 蛋白 | 结构数 | 最佳覆盖度 |
|---|---|---|
| AURKA | 247 | 0.67 |
| CDKN1A | 36 | **0.33** |
| RELB | 1 | 0.03 |

p21（CDKN1A）有 36 套结构，但没有一套覆盖超过三分之一的序列，因为它本身高度
无序，PDB 里是结合在 CDK2/PCNA 上的短肽。**"36 套结构"和"看清这个蛋白"是两件事**。

三个服务各答一个问题：变了吗（GPSAdb）、连在一起吗（STRING）、能碰吗（PDBe）。
PDBe 那条链需要 `uvx`，gene → UniProt 的映射还得离线做一次（见第 8 节第 2 条），
所以放在可选层。

## 8. 三个服务：把因果、关联、物理分开

GPSAdb 给**扰动**（急性、因果），STRING 给**互作**（结构/通路），再插一个
GTBAdb（TCGA / GTEx / CCLE 的基因共表达）把**关联**补齐。三个服务问三个不同的
问题，答案可以互相印证，也可以互相矛盾——两种都有信息量。

例子用 **HIF1A / PGK1**，缺氧程序里最经典的一对：

| 服务 | 问的是 | 这一对的答案 |
|---|---|---|
| GPSAdb | 扰动它之后变了吗 | HIF1A 敲低 **−4.28**（padj 8e-57），PGK1 **−2.17**（2e-46） |
| GTBAdb | 人体样本里它们一起变吗 | 正常组织 r≈**0.77**，肿瘤 ≈**0.56**，细胞系 ≈**0.32**；70 个显著子类型全为正 |
| STRING | 两个蛋白是什么关系 | functional 0.895，regulatory 0.890，**physical 只有 0.35** |

三层读下来是同一件事的三个侧面：

- 扰动把这条调控打掉了：HIF1A 掉了 4 个 log2，它的糖酵解靶基因跟着塌
  （PGK1 −2.17、SLC2A1 −1.20、LDHA −0.71）；
- 人群里它们同步：正常组织里 r≈0.77，而且 70 个显著子类型**没有一个是负的**；
- STRING 区分了关系和结构：**调控 0.89、物理 0.35**——说明这是"转录因子调控
  靶基因"，不是"两个蛋白抱在一起"。对照组 NFKB1–NFKBIA 的 physical 是 0.999，
  那才是一个复合物。

组织梯度也在讲事：**GTEx 0.77 > TCGA 0.56 > CCLE 0.32**。一个常见解释是细胞系
养在常氧（约 21% O2）里，缺氧程序本来就没被充分激活，动态范围小。

### 为什么不用 TP53 / CDKN1A

因为那个数据集里**被扰动的基因自己几乎没动**：TP53 log2fc −0.005、padj 1.00，
而 CDKN1A 却 +1.67。扰动一侧不可信，后面两层就无从解释。**看扰动结果，先看
被扰动的那个基因。**

（顺带说，那一对的三层数字是：GTEx r≈0.61、TCGA ≈0.20、CCLE ≈0.05，
STRING physical 0.999。方向与急性敲低相反——这正是"因果"和"关联"不是一回事的
现成教材，但它不适合当主例子，因为扰动本身失败。）

### 三个服务之后，前缀不是可选的

GPSAdb 和 GTBAdb **都有 `get_database_info`**。合并给 agent 时是 40 个工具
（12 / 11 / 17），两个同名的变成：

```
gpsadb__get_database_info
gtbadb__get_database_info
```

跑法：`Rscript examples/07-three-services.R`。

## 9. 边界与坑（都真实撞到过）

1. **STRING 不知道你敲了谁。** 互作是条件无关的先验：它说这两个蛋白能互作，
   不说在这个细胞、这个时间点、这个扰动下发生了什么。方向必须来自 GPSAdb。
2. **gene symbol 不是标识符。** PDBe 的 `gene_name:` 检索没有物种约束，
   `gene_name:DBP` 命中大鼠 P04296（人 DBP 是 Q10586）；BMP4、ATF3、PSRC1、
   ARHGEF39 则查不到。跨服务的 ID 映射目前没有谁负责，得自己做一次。
3. **列表的传法不统一。** GPSAdb 要 JSON 数组（`I(c("TP53"))`），STRING 要
   **回车分隔的字符串**（`paste(genes, collapse = "\r")`），`species` 还要传字符串
   `"9606"` 而不是数字。同一个协议，参数习惯各不相同。
4. **聚类标签会误导。** 簇 1 被 STRING 命名为 "Non-canonical NF-κB"，但它包含
   AURKA、SOX2 这些和 NF-κB 无关的基因：标签来自簇内的富集结果，不代表簇内
   每个成员都参与该通路。
5. **富集显著 ≠ 共调控。** p = 8.8e-10 只说明"比随机连通"，不说明"被同一个
   因子调控"。
6. **方向依赖数据集。** 这次 CDKN1A 是 +1.67，同一个基因在 iPSCs 的 TP53 敲低
   数据集里是 -5.64。单数据集的方向不能当机制，这也是 `gpsadb_provenance()`
   记录 release 的原因。
7. **STRING 自己提醒：** 它的 MCP 还在测试期（`https://mcp.string-db.org` 会一直
   指向最新版），大规模或要严格复现的分析建议用它的 REST API 或下载全库。

## 10. 一句话

转录组告诉你**变了什么**，PPI 告诉你**这些变化是不是一个整体**。
没有第二层，你会把"上调 274、下调 237"当成对称的两类；
有了它，你会看到一侧是一个 0.999 的复合物，另一侧是五条松散的边。
