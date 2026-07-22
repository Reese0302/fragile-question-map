# Question Map Schema

Question Map v0.3 在 v0.2 决策/验证生命周期上增加 Prototype Iteration Handoff。validator 继续接受 v0.1 legacy map 和 v0.2 map；只有出现 `iteration` 或 `acceptance` 时才启用 v0.3 条件门。

## Contents

- [Artifact shape](#artifact-shape)
- [Question](#question)
- [Relation semantics](#relation-semantics)
- [Source lineage](#source-lineage)
- [Sudden insight](#sudden-insight)
- [Possible gaps](#possible-gaps)
- [Design baseline / MVP seed / Delta / Closure](#design-baseline--mvp-seed--delta--closure)
- [Prototype iteration（v0.3）](#prototype-iterationv03)
- [Acceptance and integration（v0.3）](#acceptance-and-integrationv03)
- [Validator boundary](#validator-boundary)

## Artifact shape

```json
{
  "question_map_id": "qm-example",
  "destination": "当前工作的范围边界",
  "scope": ["当前解决什么"],
  "out_of_scope": ["当前明确不解决什么"],
  "source_lineage": [],
  "questions": [],
  "insights": [],
  "possible_gaps": [],
  "design_baseline": {},
  "mvp_seed": {},
  "delta": {},
  "iteration": {},
  "acceptance": {},
  "closure": {}
}
```

`questions`、`design_baseline` 和 `mvp_seed` 是必需字段；`insights`、`possible_gaps`、`source_lineage`、`delta` 和 `closure` 在 v0.1 可省略，v0.2 应显式提供。

## Question

```json
{
  "id": "Q1",
  "title": "短标题",
  "mode": "discuss",
  "intent": "为什么这个问题重要",
  "question": "需要回答或验证的具体问题",
  "evidence_needed": null,
  "relations": {
    "blocks_decision": [],
    "blocks_verification": [],
    "blocks_build": [],
    "depends_on": [],
    "informs": [],
    "conflicts_with": []
  },
  "confidence": "provisional",
  "status": "open",
  "resolution": {
    "decision": null,
    "evidence": null,
    "confirmed_at": null,
    "superseded_by": null
  },
  "verification": {
    "status": "not_planned",
    "plan": [],
    "evidence": [],
    "last_run_at": null
  }
}
```

Allowed values:

- `mode`: `discuss | verify | fact | park`
- `confidence`: `provisional | supported | uncertain`
- `status`: `open | resolved | superseded | deferred`
- `verification.status`: `not_planned | planned | running | passed | failed | partial`
- `evidence_needed`: verify 必须为非空文本；其他 mode 可为文本或 `null`

`status` 表示当前生命周期；`confidence` 只表示证据把握。`resolution` 的四个键在 v0.2 都保留，值可以为 `null`。`superseded` Question 必须用 `superseded_by` 指向另一个 Question；保留原 Intent，不删除历史。

`verification.plan` 和 `verification.evidence` 都是字符串数组。`planned` 说明计划已经形成，不等于已经执行；`passed`、`failed`、`partial` 需要真实 evidence 才能支撑对应结论。

## Relation semantics

每个关系目标必须存在于 Question ID 或 baseline Node ID 中：

- `blocks_decision`：没有答案就不能作出设计决定；
- `blocks_verification`：没有前置条件就不能运行验证；
- `blocks_build`：设计已清楚，但实现仍有未解决前置；
- `depends_on`：依赖答案，但不自动成为 blocker；
- `informs`：影响下游判断但不阻止探索；
- `conflicts_with`：两个决定或范围可能不兼容，需要整合。

## Source lineage

核心 skill 不依赖特定 Seed 格式；若使用 adapter，可把来源压缩为通用记录：

```json
{
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
}
```

`run_mode` 为 `full | changed_slice`。changed slice 只能追加或更新对应切片，不能冒充完整快照。

## Sudden insight

```json
{
  "id": "IR1",
  "origin": "Q1",
  "raw": "保留用户原始表达",
  "scope_relation": "bubble_up",
  "mode": "discuss",
  "relation": "informs",
  "confidence": "provisional",
  "is_new_intent": true,
  "intent_id": "I2",
  "rationale": "为什么这样路由"
}
```

`scope_relation` 与 `relation` 分工不同：前者描述相对当前范围的位置，后者描述对目标的关系。`build_dependency` 必须搭配 `blocks_build`。`is_new_intent=true` 时，`intent_id` 必须引用 baseline Intent。

## Possible gaps

```json
{
  "id": "PG1",
  "observation": "可能还缺少跨项目泛化证据",
  "source_refs": ["U04"],
  "evidence_type": "model_inference",
  "confidence": "provisional",
  "reason_not_open": "用户没有把它设为当前开放问题"
}
```

`possible_gaps` 不是 `questions` 的别名，不进入当前 Grill，不自动建立 blocker。

## Design baseline / MVP seed / Delta / Closure

`design_baseline`、`mvp_seed` 和 `delta` 保留 v0.1 结构。Delta 的 `target_id` 可以指向 Question 或 baseline Node，以记录明确纠正；`type` 仍为 `clarified | split | linked | invalidated | new_intent | scope_change`。

```json
{
  "closure": {
    "status": "active | design_closed | fully_verified | superseded",
    "rationale": "为什么当前阶段可以结束",
    "remaining_verifications": ["Q8"],
    "next_skill": "to-spec"
  }
}
```

`design_closed` 只表示当前设计切片可交给下游；`fully_verified` 要求当前范围内没有待完成的 Verify。`remaining_verifications` 必须引用 verify Question。

## Prototype iteration（v0.3）

Question Map 只保存最小迭代状态和稳定引用；完整 Brief 保存在独立 Markdown 文件中：

```json
{
  "iteration": {
    "active_region_ref": "N1",
    "state": "ready_for_rerun",
    "current_seed_ref": "F:/seeds/seed-v01-final.md",
    "last_full_seed_ref": "F:/seeds/seed-v01-final.md",
    "parent_seed_ref": "F:/seeds/seed-v01-final.md",
    "brief_ref": null,
    "iteration_number": 2,
    "rerun_count": 0,
    "recommended_run_mode": "changed_slice",
    "selected_run_mode": null,
    "recommendation_rationale": "变化局限于可恢复的入口 checkpoint",
    "recommended_handoff": null,
    "selected_handoff": null
  }
}
```

Allowed values:

- `state`: `exploring | ready_for_rerun | brief_ready | awaiting_seed | evidence_received | stalled | accepted`
- run mode: `full | changed_slice | null`
- handoff: `A | B | C | null`

`ready_for_rerun` 必须已有与 `active_region_ref` 直接对应的 delta，或 delta 的目标 Question 通过 relations 明确关联该区域；还必须有通过 relations 与 `active_region_ref` 关联的 Verify Question/evidence goal，并保留推荐理由。此时还不能有 Brief、用户选择或交接。生成 Brief 后保存稳定 `brief_ref`，validator 会读取真实 Brief 文件，核对区域、parent、run mode 和 iteration。

返回 Seed 写回时，其 `parent_source_ref`、`run_mode`、`active_region_ref`、`brief_ref` 和 `iteration_number` 必须与当前 iteration 对齐。validator 还会读取 `source_ref` 指向的真实 Final Seed，核对 `parent_seed_ref`、`input_brief_ref`、`tested_slice`、`starting_checkpoint` 和 `restored_preconditions` 是否与 Brief 一致。

`rerun_count` 是同一 active region 已完成的原型重跑次数。达到 3 次只产生 WARNING，不是硬停止。

## Acceptance and integration（v0.3）

```json
{
  "acceptance": {
    "status": "pending",
    "decision": null,
    "confirmed_at": null,
    "integration": {
      "status": "not_verified",
      "verification_question_id": "Q8",
      "full_seed_ref": null,
      "last_change_iteration": 2
    }
  }
}
```

- acceptance: `not_requested | pending | accepted_with_unverified_integration | validated`
- integration: `not_verified | planned | running | passed | failed | partial`

`accepted_with_unverified_integration` 必须有用户明确 decision，但不得声称 integration passed 或 `closure=fully_verified`。`validated` 必须同时满足：用户明确接受；integration Verify 为 passed 且有 evidence；`full_seed_ref` 指向最后变化之后的 Final full Seed；`closure=fully_verified`。

“没有新灵感”、Discuss 已 resolved 或 validator PASS 都不能自动写入 acceptance。

Prototype Run Brief 的字段与 A/B/C 交接语义见 [prototype-iteration-handoff.md](prototype-iteration-handoff.md)。

## Validator boundary

运行：

```powershell
pwsh -File scripts/validate-question-map.ps1 -Path <question-map.json>
pwsh -File scripts/validate-prototype-run-brief.ps1 -Path <prototype-run-brief.md>
```

validator 证明 JSON 结构、引用、Verify evidence 门槛、MVP parent、delta target、lifecycle 枚举和 WARNING 条件。它不证明策略正确、候选聚类质量、tracker native edge、真实写回副作用或模型会在每次对话中遵守流程。
