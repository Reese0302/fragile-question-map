# Fragile Question Map

> 先看清问题版图，再一次只推进一个决定。

`Fragile Question Map` 是一个轻量的外层编排 Skill：它从 Seed、材料和明确纠正中整理出候选问题区域，帮助你选定一个区域进入深挖，并在需要验证或原型迭代时保留完整的证据与回写关系。

```text
Seed / 材料 / 纠正
        |
        v
候选问题区域 -> 选择一个区域 -> 一次一问的深挖
        |                              |
        +--- 保留 sibling / park <-----+
                                       |
                                       v
                              delta -> 原型交接 -> 回写与关闭
```

它不替代下游 Skill。它的职责是让“现在该决定什么、什么仍待验证、什么先保留”持续可见。

## 一个真实例子：改造 Fragile Learn 的学习交互

一次真实使用中，`fragile-learn` 要同时处理五类反馈：AI 能加速材料处理、但不能替用户学习；问题不能一次抛出三个；阅读和 PDF 不该打断思考；下一攻击点要接上学习记录；后续改造还要保留可验证的证据链。

如果直接进入 Grill，话题会在“AI 的边界”“题目难度”“HTML 界面”和“学习是否真的发生”之间跳转。Question Map 先把它们聚成四个区域：

| 区域 | 这轮要决定什么 | 当时的状态 |
| --- | --- | --- |
| N1：用户认知责任与 AI 协作边界 | AI 能代劳什么，用户必须亲自完成什么判断 | 已收束 |
| N2：一次一问的问题链与难度梯度 | 追问如何只增加一个变量，而不是固定问四轮 | 保留，等待后续验证 |
| N3：阅读优先界面与学习记录导航 | HTML、PDF 与 Agent 窗口各自负责什么 | 保留，等待后续工作 |
| N4：学习深度、证据等级与停止条件 | 到什么深度才算学会；证据够了何时停止 | 选为当前切片 |

这轮只进入 N4。讨论没有改 HTML，也没有开始原型，而是先确定：学习深度由问题主责者需要保留的判断权决定；一次回答可以提供多项证据；追问只针对仍关键且不确定的部分；证据满足就停止。

中途，用户提出“我需要这么细吗？”。地图没有把这句当作普通抱怨，而是记录了一条明确变化：原先的“复述 → 对比 → 改变一个条件 → 真实迁移”固定四级链，改为“先确定目标层，再根据回答补一个必要变量”。这就是 `delta`：保留原判断和证据，同时写清发生了什么改变。

这次对 N4 的讨论已形成共享理解，但整个地图仍是 `active`，因为“先假设再补桥是否有效”“难度梯度是否连续”等验证尚未完成。它因此不会把“讨论完成”伪装成“产品已验证”。

![Question Map 如何保住 Grill 的全局主线](assets/readme/fragile-question-map-three-problems.gif)

## 为什么有它

`grilling` 的纵向深挖很有价值，但在真实的设计过程里，三个问题会反复出现：支线淹没主问题，中途灵感切断前一阶段的思考，一进入 MVP，先前意图就被静默压掉。

这个 Skill 的选择不是改造 Grill，而是在它外面加一张薄地图：先批量梳理全局，再只选择一个区域进入“一次一问”。它来自对反馈、使用指引、`wayfinder` 实验和替代方案的比较，而不是把完整设计基线塞进 Grill 本体。

> **与 Matt Pocock's Skills 的关系**
> `Fragile Question Map` 是面向 [`grilling`](https://github.com/mattpocock/skills/blob/main/skills/productivity/grilling/SKILL.md) 工作流的独立扩展：保留“一次一问、用户保留决策权”，并增加并行问题区域、证据与迭代交接的轻量地图。它受 [Matt Pocock's open-source Skills](https://github.com/mattpocock/skills) 启发，并可与其配合使用；并非 Matt Pocock 的官方或关联项目。

目前的结果只是个人使用中的软证据：上述三个痛点有所缓解。一个仍待验证的问题是，`grilling` 的题量变少代表健康聚焦，还是意味着深度被压缩。

## 它解决什么问题

| 你遇到的情况 | Question Map 的处理方式 |
| --- | --- |
| 一个 Seed 同时包含多个决策、事实和未知项 | 按 Intent 聚类为候选区域，先选一个区域推进 |
| 新灵感打断当前深挖 | 保留 `raw` 与来源，再判断它是否真的改变当前切片 |
| 已确认的决定被明确纠正 | 保留旧结论，用 `superseded`、`superseded_by` 和 `delta` 记录变化 |
| 需要跑原型，但不确定应全量还是切片重跑 | 明确 evidence goal 与 delta，生成有边界的 Prototype Run Brief |
| MVP 或原型返回后，难以判断是否真正闭环 | 分开记录设计关闭、验证、用户接受与整合状态 |

## 何时使用

| 适合 | 不适合 |
| --- | --- |
| 开始或继续 Grill 前，需要同时看见多个问题区域 | 问题已清晰、只需直接实现一个单点改动 |
| 有明确纠正、跨 Seed 迭代或原型重跑 | 替代 `grilling` 的一次一问深挖 |
| 需要区分“已决定”“待验证”“暂缓” | 充当 backlog、路线图或项目管理系统 |
| 需要把一个设计切片交给 prototype、research 或实现流程 | 代替 `research`、`wayfinder`、`to-spec`、`to-tickets` 或 `implement` |

## 工作模型

### 1. 导入并划定范围

从一个或多个 Seed、材料、当前对话或明确纠正中提取信息，并记录来源（provenance）。先写清当前 `destination`、`scope` 与 `out_of_scope`；`possible_gaps` 仅作为模型推测保存，不会自动升级为问题或 blocker。

### 2. 批量形成候选区域

按 Intent 聚类、去重并识别依赖，展示 2 到 3 个候选区域。每个区域只回答三件事：要决定什么、已有何种证据、会影响哪个范围或验收。未选区域以 sibling、later 或 deferred 保留，不逐条拉回当前讨论。

### 3. 选一个区域，一次一问

选定区域后，才交给 `grilling` 深挖。每个问题使用稳定 ID，并按性质路由：

| Mode | 含义 | 默认去向 |
| --- | --- | --- |
| `discuss` | 需要共同做设计判断 | `grilling`，一次一问 |
| `verify` | 需要实验或可检验的证据 | `prototype` 或有边界的 R&D |
| `fact` | 可以从现状、代码或材料查证 | 直接检查证据 |
| `park` | 当前不应打断主线 | 保留 Intent、来源与暂缓理由 |

`confidence` 是证据把握；`resolution` 是已经形成的结论；`verification` 是验证计划和执行结果。三者必须分开，不能用高置信度冒充已完成的决定。

### 4. 把变化留在地图上

明确纠正不会覆盖历史：旧问题标记为 `superseded`，替代问题记录在 `superseded_by`，并以 `delta` 描述被推翻或改变的内容。未被明确纠正的新想法，不会被擅自解释为替代关系。

突发灵感会先被原样保存，然后只判断一件事：不处理它时，当前切片能否在不改变目标、验收和关键范围的前提下继续？答案决定它进入当前区域、提供信息、升级为依赖，还是先 Park。

### 5. 有边界地交接原型

只有当前区域同时拥有明确的 `delta` 与 evidence goal，才进入 `ready_for_rerun`。此时 Skill 会推荐 `full` 或 `changed_slice`，说明理由，并等待用户确认后生成独立的 Prototype Run Brief。

MVP 永远是 baseline 的投影，不覆盖 baseline。原型返回时，Final Seed 只有在与 parent、Brief、区域、运行模式和迭代号对齐后才可写回；Draft Seed 只能展示或检查。

### 6. 关闭不是一句“完成”

`closure` 只描述当前阶段：

| Closure | 含义 |
| --- | --- |
| `active` | 仍在收敛 |
| `design_closed` | 当前设计切片可交给下游，但验证未必全部完成 |
| `fully_verified` | 当前范围内的 Verify 已有通过证据 |
| `superseded` | 当前地图被更高层方向替代 |

用户接受和整合验证也分开。最后一次变化后的 full Seed、通过的 integration Verify 与明确接受缺一不可；否则最多是 `accepted_with_unverified_integration`，不能称为 `validated`。

## 安装

### 从 skills 仓库安装

如果你已经有统一的 skills 仓库，克隆后把本目录放到对应宿主的 skills 目录：

```powershell
git clone https://github.com/<你的用户名>/skills.git
Copy-Item -Recurse .\skills\fragile-question-map "$HOME\.claude\skills\fragile-question-map"
```

Codex 用户可将目标路径换成 `$HOME\.codex\skills\fragile-question-map`。如果本地已有 `F:\agents\skills`，也可以直接把其中的 `fragile-question-map` 目录复制到上述位置。

安装后重启宿主，或重新加载 skills 列表，然后使用 `$fragile-question-map` 调用。

## 最短调用方式

在一个多问题、需要维护上下文的设计讨论前调用：

```text
$fragile-question-map
从这些 Seed 和材料建立 Question Map，给出候选区域、推荐选择，
只把我选中的区域交给一次一问的深挖。
```

也可以在已出现明确纠正或原型迭代时调用：

```text
$fragile-question-map
基于这个 parent Seed、这条纠正和当前原型结果，记录 delta，
判断是否 ready_for_rerun，并在我确认后生成 Prototype Run Brief。
```

## 验证地图与交接 Brief

持久化 Question Map 前，先阅读 [Question Map Schema](references/question-map-schema.md)。完成后，在本 Skill 目录运行：

```powershell
pwsh -File scripts/validate-question-map.ps1 -Path <question-map.json>
pwsh -File scripts/validate-prototype-run-brief.ps1 -Path <prototype-run-brief.md>
pwsh -File scripts/report-question-map.ps1 -Path <question-map.json>
```

前两个命令验证结构与交接约束；`report-question-map.ps1` 只读地生成摘要，不修改地图。硬错误涵盖关系目标、Verify 证据门槛、MVP parent、delta target 和新 Intent 回挂；WARNING 不阻止有效退出，但需要人工判断其生命周期或范围风险。

## 与下游 Skill 的边界

| 需求 | 应交给谁 | Question Map 保留什么 |
| --- | --- | --- |
| 深度对齐与设计判断 | `grilling` | 区域、问题、关系和结论 |
| 高保真未知验证 | `prototype` | evidence goal、delta 与交接 |
| 代码、材料或外部事实 | 代码检查或 `research` | 事实来源和验证结果 |
| 范围仍然巨大或模糊 | `wayfinder` | 已识别的区域和边界 |
| 已对齐的规格、任务与实现 | `to-spec`、`to-tickets`、`implement` | 设计与验证的回写关系 |
| 跨 session 延续 | `handoff` | 当前区域、状态和下一步 |

Question Map 不声明下游 tracker 的 native edge，也不把真实执行副作用写成自己已经完成的工作；下游产物始终是对应工具的真源。

## 目录说明

```text
fragile-question-map/
├── SKILL.md                  # 行为与约束的真源
├── references/               # Schema、Seed adapter 与原型交接规范
├── scripts/                  # 校验和只读报告脚本
└── tests/                    # 本地契约测试；发布包不包含 fixtures
```

## 约束

- 不改变或替代 Grill 的“一次一问”模型。
- 不把地图膨胀为 backlog、路线图或完整的项目管理系统。
- 不把 `possible_gaps` 自动升级为 blocker 或问题。
- 不自动启动 `$fragile-skill-prototype`；原型模式与 A/B/C 交接需要用户确认。
- 不把用户接受等同于整合验证。
- 每次讨论、验证、原型或实现结束后，更新来源、关系、结论、验证和 delta，而非静默覆盖历史。
