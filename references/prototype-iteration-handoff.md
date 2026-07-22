# Prototype Iteration Handoff

在当前区域已经形成可验证 delta 后，管理一次有边界的 Question Map → Prototype → Final Seed 回路。不要把本流程扩展成通用编排器。

## 进入门

只有同时满足以下条件才进入 `ready_for_rerun`：

- 当前 active region 已明确；
- delta 说明改什么；
- Verify Question 或 Brief evidence goal 说明验证什么；
- 继续讨论不足以提供所需体验证据。

Draft Seed 只能展示或检查，不得更新 baseline、resolution、verification、iteration、acceptance 或 closure。Final Seed 才能成为确认来源。

## 推荐并确认运行模式

推荐 `full`：用户 promise、调用入口、核心循环、跨轮状态、主要完成标准、关键范围或整体验收发生变化；最后一次局部变化后需要整合验证时也推荐 full。

推荐 `changed_slice`：变化只影响已知 checkpoint/局部分支，恢复前置无歧义，且 coverage limit 能防止局部结果冒充完整快照。

同时保存 `recommended_run_mode`、推荐理由和用户最终 `selected_run_mode`。用户可以覆盖推荐；Question Map 不替用户选择验证强度。

## 生成独立 Brief

用户确认模式后，生成独立 `Prototype Run Brief`，JSON 只保存稳定 `brief_ref`。Brief 固定包含：

- `brief_id`、`status`、`active_region_ref`、`parent_seed_ref`、`run_mode`、`iteration_number`；
- `checkpoint`、`restored_preconditions`、`changed_slice`；
- `evidence_goal`、`completion_criteria`、`appetite`、`coverage_limit`。

运行：

```powershell
pwsh -File scripts/validate-prototype-run-brief.ps1 -Path <prototype-run-brief.md>
```

## A/B/C 交接

- A：用户选择后，在同一对话展示显式 `$fragile-skill-prototype` 调用入口；不得自动切换角色或绕过 user-invoked 边界。
- B：输出 parent Seed 路径、Brief 路径和可复制调用文本，结束当前 Question Map 切片，供用户稍后手动调用。
- C：输出适合干净上下文的交接包，只包含稳定文件引用、active region、run mode、checkpoint、evidence goal、completion criteria 和 coverage limit。

保存 `recommended_handoff` 和用户 `selected_handoff`；A/B/C 都不能暗示原型已经运行。

## 接收返回 Seed

先读取返回 Seed 与 Brief 的真实文件并检查 `status=final`，再核对 parent、Brief、active region、run mode、tested slice、starting checkpoint、restored preconditions 和 iteration number。任一不匹配时停止写回，保留错误证据。

changed slice 只更新当前区域的 Question、verification、baseline rationale 和 delta，不覆盖未重跑区域。full Seed 可以提供整合证据，但仍只能覆盖其声明的 tested slice。

每次成功写回后增加当前区域的 `rerun_count`。达到 3 次时输出 WARNING，并给用户四个出口：

1. 重新定义问题；
2. 补充证据；
3. Park 当前区域；
4. 明确继续。

三次是软 appetite；不得自动停止或自动继续。

## 接受与整合

“没有新增灵感”、所有 Discuss 已 resolved、validator PASS 或局部 Seed 成功，都不等于用户接受。

- 用户明确接受但最后变化之后没有通过的 full run：`accepted_with_unverified_integration`，closure 最高为 `design_closed`。
- 用户明确接受，最后变化之后的 Final full Seed 对齐，integration Verify 为 passed 且有 evidence：`validated`，可以使用 `fully_verified`。

报告时同时展示 closure、acceptance 和 integration；不要让其中一个代替另外两个。
