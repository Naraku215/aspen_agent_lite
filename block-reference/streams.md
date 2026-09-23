# 物流 BASIS 属性详解

## 背景

所有组分输入都通过同一路径：

```
\Data\Streams\{name}\Input\FLOW\MIXED\{component}
```

该节点的 **BASIS 属性** 决定值的解释方式。写入只经 `configure_model(manifest)`
批配置或受控契约工具；`set_value` 对 FLOW/TOTAL/TOTFLOW/BASIS* 流股路径已设
守卫（拒绝裸写，必须走显式契约接口）。

## 四种 BASIS 与总量基准

| 组成 BASIS | 含义 | 总量要求 |
|---|---|---|
| `MOLE-FLOW` | 组分摩尔流量 | 组分求和即总流量（单列验证路径） |
| `MASS-FLOW` | 组分质量流量 | 组分求和即总流量（单列验证路径） |
| `MOLE-FRAC` | 组分摩尔分数 | **必须**显式正 total + total_basis |
| `MASS-FRAC` | 组分质量分数 | **必须**显式正 total + total_basis |

组成基准（composition_basis）与总量基准（total_basis ∈ MOLE-FLOW/MASS-FLOW）
**分开声明**；分数闭合容差 1e-6（不自动归一化）；流量模式核分量总和与总量一致
（相对 1e-6 / 绝对 1e-9），不再乘一次总量。

**能力矩阵**：8 种组合（4 组成基准 × 2 总量基准）当前全部 `unverified`（待原生
取证授权后逐格记录通过/失败/未支持/未验证）。未经证明的组合 configure_model
写前返回 unsupported：engineer 收到即停并报告，**不用旧工具或裸路径绕行**；
只读 inspect 可观察未知组合并返回 unknown。

## 写入（manifest feed op）

```
configure_model({
  "schema_version": 1,
  "manifest_id": "...", "task_id": "...", "model_lineage_id": "...",
  "operations": [
    {"op_id": "feed-1", "kind": "feed", "target": "FEED",
     "components": {"ETHANOL": 0.5, "WATER": 0.5},
     "composition_basis": "MOLE-FRAC",
     "total": 100, "total_basis": "MOLE-FLOW",
     "values": {"TEMP": {"type": "number", "value": 25, "unit": "C"},
                "PRES": {"type": "number", "value": 1, "unit": "bar"}}}
  ]
})
```

MOLE-FLOW 组分流量等价写法：components 给流量值、composition_basis 与
total_basis 均为 MOLE-FLOW、组分和与 total 一致。写后以服务端 receipt 的
verify_status 为准（write_status=applied 不证明值正确）。

## 核对

- 核对具体数值用 `get_value(路径, attribute="si")`（SI 值稳定，路径先 explore
  确认）；SI 读取失败服务端返回错误、**不再退回原始 Value**（无单位数字不代表
  物理量）
- `get_stream(name)` 返回 res_temp / res_pres / res_moleflow / res_volflow 及
  mole_frac_liq / mole_frac_vap；均无逐值单位标注，只作量级参考
- `get_stream_composition_info(name)` 只接受流股名、只返回部分元数据，**没有
  basis 参数**
- 写后读回≠最终输入：读回见值 100 不等于运行输入文件里有 100——CONFIGURE 过关
  前用 `generate_input_summary` 导出输入摘要，把进料流量行 Grep 出来对账（重点）；
  服务端将 run_id、起始时间与输入指纹关联，排除旧结果
