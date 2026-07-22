---
name: fragile-question-map
description: 在开始或继续 Grill 前，从一个或多个 Seed、材料或当前对话建立轻量 Question Map；批量聚类问题区域，只选择一个区域进入一次一问，并在形成 delta 后管理有边界的 full/changed-slice 原型重跑、Prototype Run Brief、A/B/C 交接、返回 Seed 写回和显式接受。用于多个问题区域、决策/验证生命周期、明确纠正、跨 Seed 原型迭代或 closure/integration 判断；不用于清晰的单点实现，也不替代 grilling、fragile-skill-prototype、research、wayfinder、to-spec 或 to-tickets。
---

# Fragile Question Map

建立当前 destination 内的问题地图，保存设计与验证关系，并把深度工作交给已有 skills。

核心原则：**批量看全局，一次做一个决定。**

## Core rules

- 能从代码、文档、Seed 或现状查到的事实先查，不问用户。
- 先做 provenance、scope、批量提取、Intent 聚类、去重和依赖识别；进入 `grilling` 后才一次只问一个主问题。
- 默认向用户展示人话：候选区域、影响、推荐选择和下一步；只有用户要求地图结构时才展示 `status`、`resolution`、`verification`、`closure` 等内部字段。
- `possible_gaps` 只保存模型推测的潜在缺口，不自动变成 Question、候选区域或 blocker。
- 不把所有关系都标成 blocker；当前切片能继续时保留为 `informs`、`depends_on` 或 Park。
- 不在共享理解形成前执行方案；不把 Question Map 变成 backlog、路线图或完整跨 Seed 编排系统。
- 不得自动启动 `$fragile-skill-prototype`；只在用户确认运行模式与 A/B/C 交接后提供显式调用入口。

持久 JSON 必须先读 [references/question-map-schema.md](references/question-map-schema.md)，完成后运行 validator；需要摘要时运行只读 `scripts/report-question-map.ps1`。

## Workflow

### 1. 划定范围并导入

先写清 `destination`、当前 `scope`、`out_of_scope` 和来源。输入是 `Skill Interaction Seed` 时，只有在需要时读取 [references/skill-interaction-seed-adapter.md](references/skill-interaction-seed-adapter.md)；核心流程只消费 adapter 产生的通用批次，不依赖某个学习 skill 的私有字段。

批量提取并保留 provenance：

- `chosen`、`rejected`、`sibling`、`open`、`corrections`、`insights`；
- Seed lineage、`full` / `changed_slice`、tested slice 和重跑建议；
- 用户纠正前后的原文、来源回合和受影响 Intent；
- `possible_gaps` 单独保留，不自动导入 Grill。

### 2. 生成候选区域

按 Intent 聚类、去重并识别依赖，向用户展示 2–3 个候选区域。每个区域只说明：要决定什么、已有证据、会影响哪一条范围或验收。把未选区域标为 sibling/later/deferred，保留理由；不要逐条请求确认。

用户选择一个区域后，只有该区域进入当前 `grilling`；其他区域继续留在地图中。

### 3. 分类并一次一问

为每个问题记录稳定 ID、Intent、具体问题、证据要求、类型化关系、`confidence` 和生命周期字段：

| Mode | Route | 默认状态 |
|---|---|---|
| `discuss` | 使用 `grilling`，一次一问 | `open` → `resolved` |
| `verify` | 使用 `prototype` 或有边界 R&D，先写 `evidence_needed` 和 verification plan | `open` / `deferred` |
| `fact` | 查代码、材料、运行状态或高可信资料 | `resolved` |
| `park` | 保存 Intent、来源和暂缓理由，不打断当前 Grill | `deferred` |

`confidence` 表示证据把握，不承担决策完成状态。`resolution` 保存结论、证据、确认时间和 supersession；`verification` 分开保存计划与执行结果。

### 4. 处理明确纠正

如果用户明确纠正已经确认的决定：

1. 保留原 Question、原 Intent 和原证据；
2. 将旧 Question 设为 `status=superseded`，在 `resolution.superseded_by` 指向替代 Question；
3. 为前后变化写一条 `delta`（通常为 `invalidated` 或 `scope_change`），目标可以是旧 Question 或 baseline Node；
4. 只追问纠正后仍有歧义的一个问题，不重新打开已被纠正的整段 Grill。

未明确纠正时，不替用户把新想法解释成 supersession。

### 5. 路由灵感与选择学习切片

单条突发灵感先原样保存 `raw` 和 `origin`，再只问一次：

> 如果完全不处理这个灵感，当前切片能否在不改变目标、验收标准和关键范围的前提下继续？

根据回答路由到 `current`、`bubble_up`、`informs`、`park` 或 `build_dependency`；若形成新设计意图，设置有效 `intent_id`，不要静默压进当前问题。

只有未解决的 Verify 同时直接阻塞决定/构建、且讨论和事实查找不足以回答时，才触发 Learning Prototype。每个 MVP slice 必须引用 baseline parent；MVP 是投影，不覆盖 baseline。

### 6. 管理原型迭代交接

当当前区域同时具备明确 delta 和 evidence goal 时，进入 `ready_for_rerun`。此时读取 [references/prototype-iteration-handoff.md](references/prototype-iteration-handoff.md)，推荐 `full` 或 `changed_slice` 并说明理由，等待用户确认后再生成独立 `Prototype Run Brief`。

保存推荐与用户选择、active region、父 Seed、Brief 引用、iteration number、rerun count 和 A/B/C 交接。返回 Final Seed 必须与 parent、Brief、区域、run mode 和 iteration 对齐后才写回；Draft Seed 只能展示或检查。同一区域第 3 次重跑只发软 WARNING，由用户选择重新定义问题、补充证据、Park 或明确继续。

用户接受与整合验证分开：没有最后变化之后的 full Seed 和通过的 integration Verify 时，只能是 `accepted_with_unverified_integration`；满足两项且用户明确接受时才是 `validated`。

### 7. 回写与关闭

每次 Discuss、Verify、Fact、prototype 或实现结束后更新问题状态、resolution、verification、关系、baseline rationale 和 delta。当前 blocker 只表示现在仍阻塞；历史通过 supersession 和 delta 保留。

`closure` 只描述当前阶段：

- `active`：仍在收敛；
- `design_closed`：当前设计切片可以交给下游，但 remaining verifications 尚未全部通过；
- `fully_verified`：当前范围内的 Verify 已有通过证据；
- `superseded`：当前地图被更高层方向替代。

关闭地图不等于所有 Verify 已通过；`possible_gaps` 也不自动阻止 `design_closed`。

### 8. 委托下游

- 深度对齐：`grilling`
- 高保真未知：`prototype`
- 事实或外部证据：代码检查或 `research`
- 巨大 fog：`wayfinder`
- 对齐后的规格：`to-spec`
- 实现任务：`to-tickets`
- 实施：`implement`
- 跨 session：`handoff`

Question Map 保存设计、验证、来源和回写关系。执行依赖以 tracker 或下游 skill 的真实产物为真源，不用本地 JSON 声称 native edge 或真实副作用已经存在。

## Validation

```powershell
pwsh -File scripts/validate-question-map.ps1 -Path <question-map.json>
pwsh -File scripts/validate-prototype-run-brief.ps1 -Path <prototype-run-brief.md>
pwsh -File scripts/report-question-map.ps1 -Path <question-map.json>
```

validator 的硬错误继续检查关系目标、Verify 证据门槛、MVP parent、delta target 和新 Intent 回挂；WARNING 只提示生命周期、closure、候选依赖或扩展字段风险，不阻断有效退出。报告脚本只读，不修改 JSON。

## Final response

交付时说明：

- 当前 destination、选中的一个切片和候选区域概览；
- 主要问题及其 mode/status；
- 直接 blocker、非阻塞关系和当前 closure；
- active region、rerun count、推荐/选择的运行模式、Brief 与 A/B/C 交接；
- 用户 acceptance 与 integration 状态；
- 被 Park、sibling、rejected 或保留在 MVP 外的 Intent；
- 下一步调用哪个 skill；
- 是否运行 validator/report，以及它们实际证明的边界。
