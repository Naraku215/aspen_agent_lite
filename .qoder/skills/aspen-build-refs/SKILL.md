---
name: aspen-build-refs
description: Aspen 建模操作参考（engineer 用）：门槛判据输出读法、规定选项速查、参数语义、MCP 调用依赖参照表、已知坑 TOP 清单。状态机流程在 agent 定义文件里，本 skill 不复述，只提供动手时查的细节。
---

# 建模操作参考

四阶段状态机（SETUP / BUILD / CONFIGURE / RUN）在 aspen-simulation-engineer
agent 定义里，不复述。本 skill 只动手时查：判据读法、规定选项速查、参数语义、
MCP 依赖参照、已知坑。
具体 block 细节按 model_plan 出现的类型现 Read `block-reference/<类型>.md`；
总目录 `block-reference/index.md`、流股 BASIS 语义 `block-reference/streams.md`
需要时现读。**绝不预读。**

## 1. 门槛判据输出读法

### find_incomplete_inputs()
分三组：**Critical** 必须清零；**Mode-irrelevant** 当前模式用不到，忽略；
**Optional** 除非 model_plan 明确要求否则忽略。过关 = Critical 清零。
先跑 `fill_trivial_params()` 再查，能自动填掉一批噪声。

### validate_block(name)
`Engine.Ready` = true → 该块过关；false → 按 missing diagnostics 提示补缺。
GUI 红框 ≈ Engine.Ready=false 的块。

### simulation_warnings()
run 前必调。重点看两类：压力不匹配（对照 model_plan §6 压力剖面）、
断开进料 / 端口未连（回连接步骤补）。

### block_status() / diagnose()
BLKSTAT=0 正常；非零 → `diagnose([块名或错误码])` 定位。只摘块名与错误码
关键词写 state.note，不整段粘。

## 2. 规定选项速查表

| Block 类型 | mode_param | 有效值 | 对应参数 |
|---|---|---|---|
| Flash2 | SPEC_OPT | TP / PD / TEMP / PRES / VFRAC / DUTY | TP: TEMP+PRES; PD: PRES+DUTY |
| Compr | OPT_SPEC | PRES / TEMP / DUTY | PRES: PRES+SEFF; TEMP: TEMP+SEFF |
| Heater | SPEC_OPT | TP / PD / TEMP / PRES / VFRAC | TP: TEMP+PRES; PD: PRES+DUTY |
| RadFrac | （无 mode_param，用 set_column_specs） | — | — |

> **Heater 热负荷模式是 PD 不是 DUTY**（实测：`SPEC_OPT="DUTY"` 被 Aspen 拒绝，
> `"PD"` 有效——压力+热负荷模式，需同时填 PRES 与 DUTY）。

**常见错误**：
- 只填参数值不设规定选项 → Aspen 报"输入不完整"
- 规定选项设错 → Aspen 用错误的参数组合计算，结果全错
- **塔纯度禁固定 D:F**：固定 D:F 会锁死纯度、RR 改动无效果。正解 Design Spec
  （纯度）+ Vary（RR 或 D:F），建行用 `add_table_row` + `set_value`

**速查表外的块**（反应器/Pump/Valve/HeatX/Extract/DSTWU/固体等）：
先 Read `block-reference/<类型>.md`，端口表、输入路径、规定选项有效值、设置步骤
都在里面。

## 3. 参数语义与常见错误

- **规定选项先于参数**：先设 SPEC_OPT / OPT_SPEC，再填 PRES / TEMP / DUTY / SEFF，
  最后 validate_block（顺序不能颠倒）；填了参数不会自动完成"规定"选项
- 塔（RadFrac）顺序不能颠倒：set_column_stages → set_condenser_type +
  set_reboiler_type → set_feed_stage + set_product_stage → set_column_pressure →
  set_column_specs
- 分流器用 `configure_fsplit`；固体 / PSD 场景 set_param 到相应节点，
  节点不确定先 explore 找
- **先连端口再填参数**：连接错了，参数校验结果无意义
- 先设单位制再加组分，加完组分 reinit，否则部分模块节点不生成
- 组分标签 > 8 字符被截断，用 list_components 核对实际标签
- **物流组成 BASIS 三条**：分数基准（MOLE-FRAC / MASS-FRAC）必须同时给 total_flow；
  改 BASIS 只改变解释、不换算已有值；读流量用
  `get_stream_composition_info(..., basis="MOLEFLOW")`，读分数用 `basis="MOLEFRAC"`
- `set_param` 只能设模块参数，物流参数必须用 `set_stream_param`
- `set_tear_estimate` 的 temp 与 pres **分两次调**（一个 unit 只对一个物理量）

## 4. MCP 调用依赖参照表（并行前对照）

### 可并行（无依赖）
- SETUP：add_component × N（多组分互相独立）
- SETUP reinit 后：explore(BIP) + get_property_method（都是读）
- BUILD：**add_block × N**（模块互相独立）
- BUILD：**add_stream × N**（流股互相独立）
- BUILD：**connect / connect_port × N**（显式 stream_name，避免 auto-create
  竞争；connect_port 依赖 list_block_ports 输出，先读后写）
- RUN 后：status + block_status + get_stream × N（都是读）

### 必须串行（有依赖或高频出错）
- new_simulation → 一切（必须先建模拟）
- set_unit_set → get_unit_set（写后验证）
- add_component → list_components → reinit（加后验证，验后重建）
- set_property_method → reinit（设后重建）
- reinit → explore(BIP)（BIP 节点结构在 reinit 后稳定）
- **CONFIGURE 每块串行**：规定选项 → set_param(TEMP) → set_param(PRES) →
  set_stream_param(TEMP) → set_stream_param(PRES) → set_stream_param(FLOW) →
  set_stream_composition_batch → fill_trivial_params → validate_block
  （参数设置高频出错，逐个执行确保正确）
- reinit_and_run → 读取结果（跑后才能读）

## 5. 已知坑 TOP 清单

- **BIP 静默取 0**：也能"收敛"但结果全错——SETUP 的 BIP 核查必须做
- **save() 挂起止损**：带路径 save 底层是 SaveAs，目标已存在会弹覆盖对话框模态
  阻塞 COM。超 1 分钟无返回即判挂起：停止一切 COM 重试，落盘 state.json 返回 PAUSED
- **COM 错误分级自愈**："服务器出现异常情况"→ close_file + open_file 自愈重跑；
  "发生意外"→ 操作型错误，直接重试；"远程过程调用失败"→ Aspen 未运行，提示用户
  查进程；"对象没有连接到服务器"→ MCP 会话失效，记 last_error 返回 BLOCKED
- **删块先于拔流**：先 remove_block（连接自动断裂）再 disconnect 清孤儿物流；
  反过来块孤立后内部校验不过，COM 服务器崩溃不可恢复
- **多 AspenPlus 进程干扰**：多实例并存会让 COM 调用挂起/超时；操作前确认单实例，
  不确定先 open_file 绑定正确文档再操作
- **.rep 只 Grep**：数 MB，整份 Read 会爆上下文
- **run_script 不可用**：输出不可捕获、脚本静默失败；批量操作用单条消息并行多个
  MCP 调用替代
- **set_param 静默失败**：写后必须读回验证（尤其反应体系计量表 COEF，见下）
- **反应体系三条**：add_reaction 写 COEF/COEF1 计量表有时静默失败，写后必须读回
  验证、空则用 set_value 手动补填；RXN_ID 表先清空已有行再加行，不支持 SetLabel，
  直接用 `#0`/`#1` 索引路径赋值；RPlug 温度模式用 `T-SPEC`
- **BLKSTAT=1 + MASS IMBALANCE 可能是 tear 残差假警报**：先按流股加和验证是否
  真不平衡，再判定不收敛，别一看到 MASS IMBALANCE 就报不收敛
- **单位约定**：METCBAR 下不带 unit 直传工程值；不带 unit 的值按 SI 处理
  （K/Pa/kmol/s/W）——绝不把工程值当 SI 裸传；罕见单位手工换算 SI 留痕