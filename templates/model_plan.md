# model_plan.md

> 单位约定：全文“工程值 + 单位”书写（30 C、10 bar、100 kmol/hr）。engineer 逐条
> 带 unit 参数传入（MCP 原生换算，主 agent 与本文不做任何换算），本文数值即建模输入。
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

## §4 进料流股表（T/P/总流量/各组分分数）
| 流股 | T (C) | P (bar) | 组成基准 | 总量基准 | 总流量 (kmol/hr) | 各组分（摩尔分数，和为 1） |
|---|---|---|---|---|---|---|
| FEED | 30 | 10 | MOLE-FRAC | MOLE-FLOW | 100 | CH4=0.85, C2H6=0.08, C3H8=0.05, N-C4H10=0.02 |

> 组成按“组成基准 + 总量基准”**显式声明**：分数基准（MOLE-FRAC/MASS-FRAC）必须给
> 显式正总流量；流量基准（MOLE-FLOW/MASS-FLOW）给组分流量且总和与总流量一致。
> 组分表列齐已确认组分，零流量组分显式 0，不写隐含默认。engineer 用
> configure_model(manifest) 提交，服务端 receipt 逐 op 核验；未经原生验证的
> 组合服务端会拒绝并停下报告（能力矩阵另记）。

## §5 模块表
| 模块 | 类型 | 规定选项 | 参数（工程值+单位） |
|---|---|---|---|
| COMP1 | Compr | OPT_SPEC=PRES | PRES=30 bar, SEFF=0.75 |
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

## §8 执行预算（默认，复杂案例另议）
- RUN：首跑 1 次，失败即停；TUNE 由用户另行授权、累计 ≤3、总原生提交 ≤4
- 简单案例 deadline=300 秒，自首次派发前起算，跨派发/排布/服务不重置
- manifest 追溯：model_lineage_id / task_id 由服务端持久记账，跨派发/重启不重置；
  agent 不能通过请求字段自增额度