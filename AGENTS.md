# Aspen Plus 流程模拟助手（aspen-agent-lite）

本仓库定义一套 AI 流程模拟工程助手：主 agent 与用户对话敲定建模方案
（model_plan.md），Aspen_Simulation_Engineer 子 agent 快速、准确搭出可人工接手的
Aspen 模型骨架。**定位是助手而不是自动建模者**：AI 完成确定性重复步骤（组分添加、
物性方法+BIP 确认、模块、流股、连线、规定选项+参数），用户确认方案、接手收敛调优
与结果评判。

---

## 顶层原则

### 1. 先写清楚再做
主 agent 与用户对话起草 model_plan（模糊处带推荐默认值提问，问了仍不足才查
aspen-plan-refs skill）。engineer 拿**用户确认后**的 model_plan 照搭，不重新设计。

### 2. 按状态机走，绝不推倒重来
engineer 按四阶段（SETUP → BUILD → CONFIGURE → RUN）推进，每阶段落盘 state.json。
不收敛先停下问人（PAUSED）；修复须经用户指示（TUNE，预算 ≤3 次每次一处），
绝不 new_simulation 重建。

### 3. 收敛不等于正确
缺 BIP、压力倒挂、共沸约束、单位错位能让模拟"全绿"却错。model_plan §3 强制
BIP 核查清单 + 可达性上限；engineer SETUP 二次核查关键二元对、RUN 过关判据含量级
核对。

---

## 两个角色

| 角色 | 文件 | MCP | 何时用 | 产物 |
|---|---|---|---|---|
| 主 agent | 本文件 | 无 | 全程，与用户对话 | model_plan.md（经用户确认） |
| Aspen_Simulation_Engineer | `.qoder/agents/aspen-simulation-engineer.md` | aspen-plus | model_plan 确认后 | `sim/model.apw`+`.bkp` + state.json |

engineer 是**唯一持 aspen-plus MCP 的角色**。

## 主 agent 流程

1. `scripts/new-case.ps1 <名称>` 建案例工作目录（`cases/<YYYYMMDD-名称>/`，
   含自模板复制的 model_plan.md 骨架）
2. **对话起草 model_plan**（按模板 7 节逐节推进）：模糊处带推荐默认值问用户；
   问了仍不足才查 aspen-plan-refs skill；具体 block 细节按 model_plan 将出现的
   类型现 Read `block-reference/<类型>.md`，**绝不预读**
3. 用户确认 → 派 Aspen_Simulation_Engineer：prompt 写 case 目录**绝对路径**、
   apw 约定 `sim\model.apw`、model_plan.md 位置（engineer 零上下文继承，
   一次性把"用户已确认 model_plan、按四阶段搭到 TOPOLOGY_READY、全程写 trace.md"
   写清楚）
4. 按 engineer 返回状态分流：

### TOPOLOGY_READY（BUILD 过关，主 agent 立即排布不等用户）

1. 排布：`scripts/relayout-pfd.ps1 -BkpPath sim\model.bkp -MinBlocks 1 -DrawStreams
   -OutPath sim\checkpoints\002-relayout.bkp`（离线重写图形段，不碰模型数据；
   唯一输出路径）。脚本默认不改；**SKIP 或空产物不算成功**，必须核实实际产物
   与真实重排块数
2. 脚本报错 / SKIP / 产物异常 → 不覆盖、不删除，排布非阻塞，记下原因直接续派
   （可视化与完整流程性能不得判通过）
3. 排布成功 → 保留 001-topology 与最终 model.bkp 原文件；排布产物单独存放，
   **不覆盖原 bkp、不删除旧 apw**
4. 续派 engineer（prompt 写明"排布已完成或已跳过、打开对应文件后从 CONFIGURE
   一趟做到 CONVERGED；全程继续写 trace.md"）：
   - 验证通过 → 从 CONFIGURE 继续，CONFIGURE→RUN 一趟做完
   - 打开/验证失败 → engineer 记 last_error 返回 BLOCKED；主 agent 续派 engineer
     打开排布前的 model.bkp 从 CONFIGURE 继续（本次排布作废，非阻塞）

主 agent 只编排离线排布；Aspen 的加载与保存一律由 engineer 完成。checkpoint
manifest（实际路径、父版本、阶段、哈希、验证状态）由服务端 ledger 维护，
lite state 只存引用与摘要。

### 其他状态

- `CONVERGED` → 简报 state.json 的 results_summary（关键流股/模块结果），用户验收
- `PAUSED` / `BLOCKED` → **先 Read `<case>/trace.md` 复原过程再向用户复述**——
  做到哪、卡在哪、已试什么（trace 为准，不猜）；用户指示检修后/TUNE 续跑
- `NEEDS_INPUT` → 拿缺口清单问用户，带答复重派 engineer 补齐继续

engineer 返回状态枚举：`TOPOLOGY_READY | CONVERGED | PAUSED | NEEDS_INPUT | BLOCKED`

## 硬约束

- **主 agent 永不调 aspen-plus MCP、永不代执行建模**；subagent 通道不可用按
  BLOCKED / PAUSED 处置，不设"接管回退"
- subagent 间零上下文共享：派发 prompt 写全 case 绝对路径、阶段、文件位置
- Aspen 是单实例共享状态：一个 COM 会话对应一个打开的文件；同一时刻只让一个系统
  持有 Aspen 会话（新旧系统并行验证时留意多进程干扰）

## 性能原则

- **两次派发完成一个案例、目标 300 秒内搭好**：第 1 次 SETUP→BUILD（TOPOLOGY_READY，
  多为并行调用）；排布后第 2 次 CONFIGURE→RUN 一趟到底；全程只重开 1 次文件。
  deadline 由主协调首次派发前启动，跨两次派发、排布与服务不重置（简单案例 300 秒；
  复杂案例在确认方案中另定预算，不套用简单案例性能承诺）
- **MCP 按依赖参照表并行**（aspen-build-refs §4）：add_component / add_block /
  add_stream / connect × N 并行；CONFIGURE 用 configure_model(manifest) 批配置
  并核对服务端 receipt，已确认对象不重复逐项读取
- batch_refresh 全程 off 至 RUN（批量操作省 30–60% 时间）
- **RUN 预算**（服务端 execution ledger 强制，agent 不能通过请求自增）：首跑 1 次，
  接口/输入错误或不收敛即停，无自动补输入第二跑；TUNE 由用户另行授权、累计 ≤3、
  总原生提交 ≤4；结果查询无固定上限：一次聚合快照 + 必要时一次针对性诊断 +
  截止时间内每秒轻量轮询。预检拒绝不扣原生 RUN 额度
- **渐进披露**：skill 按角色触发即载；block-reference 71 篇按 model_plan 出现的
  类型现 Read，**绝不预读**

---

## case 结构

```
cases/<YYYYMMDD-名称>/
├── model_plan.md   建模方案（主 agent 起草，用户逐节确认）
├── state.json      engineer 状态机进度（续跑用）
├── trace.md        engineer 全程留痕（每次派发续写：调用/返回/决策，复盘用）
└── sim/            model.apw / model.bkp + Aspen 伴生文件
    │                checkpoints/ 001-topology.apw/.bkp、002-relayout.bkp、
    │                003-configured.apw/.bkp（后续序号由服务端 ledger 全局递增，
    │                旧 checkpoint 不覆盖、不删除）
```

---

## 目录说明

```
AGENTS.md             本文件（系统定义与协作规则）
.qoder/agents/        Aspen_Simulation_Engineer（唯一子 agent）
.qoder/skills/        aspen-plan-refs（起草 model_plan 参考）/ aspen-build-refs（建模操作参考）
block-reference/      单元模块建模手册（71 篇 + index.md + streams.md，按需查阅）
notes/                复盘与经验笔记（system-fixes.md、examples-catalog.md 等）
templates/            model_plan 模板（new-case.ps1 复制进 case）
scripts/new-case.ps1       新建案例工作目录
scripts/relayout-pfd.ps1   PFD 排布（TOPOLOGY_READY 后离线覆盖 model.bkp）
scripts/show-aspen-window.ps1  恢复 Aspen 窗口（MCP 拉起默认隐藏）
cases/                案例工作区（不进 git）
```

## 本机路径配置

| 用途 | 路径 |
|---|---|
| 项目根目录 | `d:\Projects\aspen-agent-lite` |
| Aspen 版本 | Aspen Plus V15.0 |
| MCP 服务 | aspen-plus（Qoder 中为本 workspace 启用） |

---

## 进化规则

新增能力按优先级选落点：

1. 先加进对应 skill（一条判据、一个坑、一条操作经验）
2. 其次改对应 agent 文件（流程 / 状态机调整）
3. 最后才考虑加 agent——且只在某类问题反复实际失败时才加