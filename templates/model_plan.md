# model_plan.md

> 单位约定：全文工程单位（C / bar / kmol/hr / Watt 系）。engineer 以 METCBAR 单位制 +
> 数值直传（不带 unit，不做任何换算），本文数值即建模输入。
> 本文件由主 agent 与用户对话起草，逐节确认后派发 engineer，不再有单独的需求文档。

## §1 任务目标
一句话 + 关键指标（产量 / 纯度 / 回收率 / 能耗量级）。

## §2 组分表
| 组分 | 数据库ID | 预期标签(≤8字符) | 角色 |
|---|---|---|---|
| 甲烷 | METHANE | METHANE | 主组分 |
| 氮气 | NITROGEN | N2 | 杂质/惰性 |

> 标签 >8 字符会被 Aspen 截断，这里给预期值；杂质/惰性行必含。

## §3 物性方法
- 方法：PENG-ROB（依据一句话，如"轻烃非极性体系"）
- 关键二元对 BIP 核查清单：决定分离结果的二元对逐个列，标"关键 / 待核查"
- 可达性上限：无共沸 | 乙醇-水 ~95.6 wt% 乙醇（超上限的指标须在此标出）

## §4 进料流股表（T/P/总流量/组成基准/各组分）
| 流股 | T (C) | P (bar) | 总流量 (kmol/hr) | 组成基准* | 各组分 |
|---|---|---|---|---|---|
| FEED | 30 | 10 | 100 | MOLE-FRAC | CH4=0.85, C2H6=0.08, C3H8=0.05, N-C4H10=0.02 |

> *组成基准二选一：MOLE-FRAC 或 MOLE-FLOW（流量基准时在"各组分"列给各组分流量值）。

## §5 模块表
| 模块 | 类型 | 规定选项 | 参数（工程值+单位） |
|---|---|---|---|
| COMP1 | Compr | OPT_SPEC=PRES | PD=30 bar, SEFF=0.75 |
| COOL1 | Heater | SPEC_OPT=TP | TEMP=40 C, PRES=30 bar |
| FLASH1 | Flash2 | SPEC_OPT=TP | TEMP=40 C, PRES=30 bar |

> 规定选项与参数值都必须写明（选了选项才算完成）。

## §6 拓扑连线
框线图：
```
FEED → COMP1 → COOL1 → FLASH1 → VAP1 / LIQ1
```
连线清单：FEED→COMP1, COMP1→COOL1, COOL1→FLASH1, FLASH1→VAP1, FLASH1→LIQ1

逐节点压力剖面（防倒挂）：FEED 10 → COMP1 30 → COOL1 30 → FLASH1 30 bar

## §7 （可选）循环 tear 初值
- TEAR1：T=_, P=_, 组成=_