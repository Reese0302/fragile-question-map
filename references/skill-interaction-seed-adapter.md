# Skill Interaction Seed Adapter（可选）

本 adapter 只规定从 `fragile-skill-prototype` 的 Final `Skill Interaction Seed` 到通用 Question Map 批次的映射。核心 skill 不读取 Seed 的私有 Markdown 字段，也不把 Seed 直接当成 Question Map。

## 输入门禁

先读取 Seed 的 `seed_id`、`status`、`parent_seed_ref`、`run_mode`、`tested_slice`、`input_brief_ref`、`scope`、`out_of_scope` 和 `user_authorized_generation`。`status=draft` 只能作为待确认材料；`status=final` 才能作为已确认来源。`changed_slice` 必须带 parent seed、Brief、恢复前置和变化切片；缺一项就停止并请求补齐，不冒充 full run。

## 通用批次输出

Adapter 输出与来源格式无关的批次：

```json
{
  "source_lineage": [{
    "source_id": "seed-v02",
    "source_type": "skill_interaction_seed",
    "source_ref": "绝对路径或稳定引用",
    "parent_source_ref": null,
    "run_mode": "full",
    "tested_slice": "完整代表性路径",
    "status": "final",
    "active_region_ref": "N1",
    "brief_ref": "绝对路径或 null",
    "iteration_number": 2
  }],
  "chosen": [],
  "rejected": [],
  "sibling": [],
  "open": [],
  "corrections": [],
  "insights": [],
  "possible_gaps": [],
  "rerun_signals": {
    "parent_seed_ref": "绝对路径或稳定引用",
    "run_mode_recommendation": "full | changed_slice",
    "tested_slice": "本次实际覆盖的切片",
    "starting_checkpoint": "起始 checkpoint",
    "restored_preconditions": "恢复前置",
    "input_brief_ref": "返回 Seed 使用过的 Brief 或 null"
  }
}
```

映射规则：

- `chosen`：带 `explicit_user_decision` provenance 的已确认候选；
- `rejected`：仅用户明确否定或撤销的项；
- `sibling`：未选择但仍然存活的方向，不自动改成 rejected；
- `open`：transcript 中明确未闭合的问题；
- `corrections`：保留 `raw_user_text`、`before`、`after`、受影响 item 和 source turn，交给 Question Map 的 superseded fast path；
- `insights`：保留 raw、来源回合、branch context 和 incorporated 状态；
- `possible_gaps`：只使用 `model_inference`，不升级为 open；
- 所有批次项保留 `source_turn_ids`、`evidence_type` 和 `confidence`。

## 批量运行规则

先对批次按 Intent 聚类、去重和识别依赖，再生成 2–3 个候选区域。用户只选择一个区域进入 Grill；区域内仍一次只问一个主问题。明确 correction 直接进入 superseded + delta，不重新逐条确认旧决定。

## 重跑建议

- `full`：入口、用户 promise、完成标准或主范围改变；重新走代表性路径；
- `changed_slice`：只变更一个已知 checkpoint、前置或局部决策；引用 parent seed，输出局部证据；
- 如果 correction 改变了目标/验收，建议 full；若只补充局部证据，建议 changed slice。

## 重跑输入信号

Adapter 只提取 Seed 已有的 lineage、实际测试切片、checkpoint、恢复前置和既有 Brief 引用，并据此提供 `full` / `changed_slice` 推荐信号。它不创建下一轮 Brief，也不替用户确认运行模式。

只有 Question Map 已形成当前区域 delta 与 Verify evidence goal，且用户确认运行模式后，才由 [Prototype Iteration Handoff](prototype-iteration-handoff.md) 生成独立 Brief。

返回 Seed 进入写回前，把 `input_brief_ref`、`parent_seed_ref`、`run_mode` 和 tested slice 映射到 source lineage，并补上当前 `active_region_ref` 与 `iteration_number`。映射结果必须与 Question Map iteration 对齐；不匹配时停止，不更新 baseline、verification 或 acceptance。
