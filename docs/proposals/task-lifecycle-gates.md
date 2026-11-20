---
title: "任务生命周期控制点：三项配置与贯穿式审查"
author: foamshadow
date: 2026-11-20
status: draft
tags: [se-arch, se-review]
related: [ADR-0003, ADR-0007, ADR-0011, SPEC-0001, docs/proposals/agent-confirmation-chain.md]
adopted-as: ""
---

# 任务生命周期控制点（proposal）

## 背景

任务从"确定"到"merge"的暂停点与审核点目前散落在多份文档——AGENTS「破坏性操作」「提交纪律」「评审协议」与 ADR-0003 / 0007 / 0011——没有一个任务全生命周期的统一控制点视图。Phase 0（SPEC-0001）的实测数据与多 runtime 实践为重新设计提供了依据：

1. **双授权的常态豁免**：ADR-0007 D2 的逐条审批与逐次 push 许可两个档位在实践中基本空转（任务启动时普遍授予 auto-commit / auto-push），实际生效的人工停点收敛为：双授权申请、docs 提交确认、整理门、合并授权、破坏性操作——五个全部以"人在场"为前提。
2. **评审分层已有捕获分布数据**（Phase 0 复盘）：commit 级审查防"格式与低级错"（scope 违白名单、变量清单漏同步），PR 级评审防"口径与账本错"（勾选语义、账本口径、trailer 覆盖）。两级捕获错类不同，均有存在价值。
3. **审查者可以不是人类**：Pi 续接会话做 commit 级 `Reviewed-by`（#44 正例）、DSH 做 PR 级评审（多轮 BLOCKED/PASS 实战）均为已实践路径；herdr 直连对话通道 2026-11-20 会话内实测可用（通道操作记录待 journal）——"指定外部 agent 审查"只差规则化。
4. **控制点配置缺位**：PR 创建是否自动化、开发完成后要不要停一次审查，目前全靠任务内临时沟通，没有任务级配置承载。

与 docs/proposals/agent-confirmation-chain.md 的关系：该 proposal 管**破坏性操作的分级确认载体**（L0–L3，确认来源从人类渐进到上层 agent）；本 proposal 管**任务全生命周期的控制点配置**。正交且互补——本 proposal 停点表中破坏性/授权/审查类人工停点（#3–#10）是该 proposal 载体升级路线（L1/L2）的候选，任务级授权点（#1/#2）待其范围扩展后映射（见 §6）。

## 提议

### 1. 任务启动三项配置

确认任务后、开发前，一次性申请三项**任务级**配置（任务结束失效，可随时撤销；前两项语义与 ADR-0007 D2 一致）：

| 配置 | 档位 | 未授予 | 已授予 |
| --- | --- | --- | --- |
| auto-commit | 有 / 无 | 每次提交前停问（`wip:` 免审） | 提交前告知即可 |
| auto-push | 有 / 无 | 每次推送前停问 | 推后报告 |
| review | 无 / 人工 / 外部 agent | —— | ——（贯穿开发后审查与 PR 评审两环节） |

### 2. review 单配置贯穿两环节

review 是**一个配置**，档内执行者可换（dev 环节用 Pi、PR 环节用 DSH 都属"外部 agent"档）：

- **dev-review**（仅代码分支，见 §5 整理门执行循环）：**审查发生在每个待生成整理提交之前**——break 点上先 `git reset --soft HEAD^` 把该段改动放回 index，审 staged tree（`git diff --cached`，即该段最终内容，#44"暂存树逐棵审"模式制度化）；通过后 `git commit -C HEAD@{1} --trailer "Reviewed-by: <审查者>"` 生成提交——trailer 随生成写入，ADR-0011 时点纪律在机制上成立。审查者 ≠ `Assisted-by` 参与者（互审约束直接适用）。
- **pr-review**：按评审协议状态机（BLOCKED → REVIEW-FIX → PASS）执行。
  - 人工 → 人按协议审、发 PASS；外部 agent → 指定 agent 按协议审、发 PASS。
  - **无"无"档**：PASS 是 merge.sh 快照校验的硬前置，不可跳过。
  - **映射规则：review = 无 → pr-review 固定为人工**（无审查任务的 PR 兜底由人把关）。

外部 agent 的两种通道：

- **a. 旧会话续接追问**：复用以前某 agent 的会话追加询问（如 `pi -c` 模式）——Phase 0 已实践路径（多轮 PR/commit 评审）；注意会话体积寿限：累计过 ~100KB 后挂死率升高（140–190KB 区间四调三挂），接近 200KB 时主动 fork（Phase 0 复盘实测口径）。
- **b. 直连自动交流**：herdr 或其他来源的 agent 直接对话（herdr pane send-text / agent prompt 通道）——会话新鲜、可并行；2026-11-20 会话内实测可用，通道操作记录待 journal。

### 3. 全流程控制点视图

```
① 确认任务 ⏸（人）
   确定任务类型（spec 任务 / fix / docs / hotfix / backport）
   → 申请三项配置（auto-commit / auto-push / review）→ 切分支
② 开发
   feat/fix/hotfix/backport：wip 提交免审 + 告知照常
     （无 auto-commit 时非 wip 提交逐条停问）
   docs：提交"确认"档不变（ADR-0007 D5：文件清单 + 关键点，点头才提交）
③ 整理门 ⏸ ——仅代码分支，提交序列需要重组时（≥2 提交或含 wip/fixup 碎片），PR 前
   人定 rebase 方案（todo：哪些 wip squash / fixup、整理段如何切分、
   break 插在每个预期整理段的 pick/squash 之后）
   → agent 执行 rebase -i（backup 分支照旧）
④ dev-review ——整理门 break 点上审 staged tree（仅代码分支，按 review 档位）
   break 点：git reset --soft HEAD^（该段改动回 index，HEAD 退回上一段）
   review=人工 → 人审每个 break 点的 staged tree；review=agent → 指定 agent 审
     （可批量审完全部 break 点再依次放行）
   review=无 → 不设 break 点：整理门只执行 rebase 方案，无审查停，
     提交不带 Reviewed-by，评审责任全部由 pr-review 承载
   通过 → git commit -C HEAD@{1} --trailer "Reviewed-by: ..." 生成该段提交
   发现问题 → 改 index 内容 → 重审 → commit
⑤ commit（整理门外的修正提交，受 auto-commit 控制；整理门内提交生成时已带 trailer）
⑥ push（受 auto-push 控制）
⑦ PR 创建：双授权齐全 → 自动创建；否则 ⏸ 询问是否创建
⑧ pr-review（按 review 档位；review=无 → 人工；docs 任务的唯一评审环节）
⑨ 合并请求 ⏸ 现阶段必须人工授权（agent 只执行 task merge 快照合并；
   确认链毕业后按 L2 载体调整）
⑩ 收尾：任务结束三项配置失效；文档写回窗口已随 PR 闭合（非停点）
```

### 4. 停点表

> 注：本表按停点类型独立编号（#1–#10），与流程步骤 ①–⑩ 不一一对应；⑩"收尾"不是停点，不入表。

| # | 停点 | 触发条件 | 豁免条件 |
| --- | --- | --- | --- |
| 1 | 三项配置申请 | 每任务一次 | —— |
| 2 | docs 提交确认 | docs 任务每次提交 | 无（不随 auto-commit 豁免） |
| 3 | 整理门（人定方案） | 代码分支（feat/fix/hotfix/backport）多提交序列（≥2 或含 wip/fixup） | docs 不走门（载体豁免见 §5）；干净单提交跳过 + 声明 |
| 4 | dev-review（break 点审树） | 整理门执行中的每个 break 点，按 review 档位 | review=无 → 不设 break、提交不带 trailer；review=agent → agent 自动过 |
| 5 | 逐条提交审批 | 无 auto-commit | 有 auto-commit；`wip:` 永远免审 |
| 6 | 逐次 push 许可 | 无 auto-push | 有 auto-push |
| 7 | PR 创建询问 | 双授权不齐 | 双授权齐全 → 自动创建（推导理由见 §6） |
| 8 | pr-review 人工 | review = 人工 或 无（映射） | review = agent → agent 自动审 |
| 9 | 合并授权 | 现阶段人工（确认链毕业后按 L2 载体调整） | 无 |
| 10 | 破坏性操作（tag / dev→main / revert -m / force push） | 现阶段人工（确认链毕业后按 L1/L2 载体调整） | 无 |

### 5. 整理门与 dev-review 的机制（对现行规则的实质修改）

现行"PR 开启前 rebase -i 整理"是覆盖所有代码 PR 分支的一般条款（AGENTS 提交纪律节，无分支限定；docs 是唯一显式豁免——squash 合入）。本 proposal 做两处修改：

**其一，适用范围显式化**：整理门与 dev-review 限定**代码分支**（feat / fix / hotfix / backport）。docs 不走门不走 dev-review——这不是"按分支类型豁免"的例外，而是**载体特性豁免**：docs 由 GitHub squash 落地，分支上的多个提交合法（ADR-0010）且不进入历史，`Reviewed-by` trailer 随 squash 丢失（ADR-0011 明文），docs 的评审记录本就走 PR 状态评论 / journal。整理门在代码分支内**统一按序列重组需要触发**，不再按分支类型二次划分（hotfix 多提交与 feat 多提交同门同流程）。

**其二，dev-review 嵌入整理门执行循环**：ADR-0011 时点纪律要求 commit 级评审发生在 commit 生成前（#50 反例：提交后才审，不能带 trailer）。逐命令序列（break 的时点语义 = 停在上一条 todo 执行完之后，HEAD 已是该段提交——因此不能 amend 补 trailer，必须先把改动放回 index 再审）：

1. 人定 rebase 方案：todo 清单（squash / fixup / reword 分组）+ break 位置（每个预期整理段的 pick/squash **之后**插一个 break）；
2. agent 执行 rebase -i，在 break 点暂停（此时 HEAD = 该段提交，工作区/index 干净）；
3. `git reset --soft HEAD^`——该段改动整体回到 index，HEAD 退回上一段；
4. reviewer 按 review 档位审 **staged tree**（`git diff --cached` = 该段相对分支基点的最终内容；agent 审查者可批量审完全部 break 点的 staged tree 再依次放行）；
5. 通过 → `git commit -C HEAD@{1} --trailer "Reviewed-by: <审查者>"` 生成该段提交（message 复用该段原提交，trailer 随生成写入）；
6. 发现问题 → 修改 index 内容（改文件 + `git add`）→ 重审 → commit；
7. `git rebase --continue` 进入下一段。

机制注记：ADR-0011 的"tree 不变（message-only rewrite）可保留"讲的是**已存在** trailer 在重写后的保留，不覆盖"提交后补写新 trailer"——因此本机制不走 break+amend 路径（被否方案表），评审与生成之间以 index 为界，"生成前审"在 git 时序上成立。

**单提交任务的跳过规则**：干净单提交（无 wip / fixup 碎片）自动跳过整理门，但 agent 须在合并请求里附**任务分解依据**（一句话说明该提交即完整任务、非"整个任务压成一个提交"）——"整理不是 squash、禁止整体压一个提交"的现行纪律不因跳过而豁免，合并授权时抽查该声明。多提交一律过门（保守代理：不引入"需要重组"的语义判据，≥2 提交即触发，宁可多一次人定方案的停）。

### 6. 异源纪律、推导理由与演进口

- **异源**：审查执行者 ≠ 实现者（ADR-0011 互审约束）；两级审查推荐异 agent——Phase 0 数据表明两级捕获错类不同，异源保留分布价值。
- **PR 创建自动化条件的推导理由**（表 #7）：双授权齐全 = 任务**完全自主模式**的信号——任一缺席则提交/推送仍需停问、任务非自治，PR 创建同停；auto-push 单项（PR 创建只依赖分支已 push）不足以构成自治闭环，此为刻意绑定而非疏漏。
- **人工停点的载体升级（演进口，本次不做）**：agent-confirmation-chain 的 L1/L2 设计目标是**破坏性操作与授权/审查类停点**——本表 #3–#10（整理门、dev-review、逐条审批/逐次许可、pr-review、合并授权、破坏性操作）是其载体升级的候选；#1（配置申请）与 #2（docs 提交确认）属任务级授权点，待确认链范围扩展后可一并映射。现阶段一律人类。
- **auto-rebase（演进口，本次不做）**：仅 auto-pr 场景（双授权齐全）下，agent 按既定方案自主整理——待"人定方案"阶段积累足够样本后再议。

## 毕业条件

- **首次全链演练矩阵**（Phase 1 spec 的首个真实任务起——spec 编号于其起草时按分配协议确定，本文不预言性引用）：
  - ≥1 个 **≥2 提交的代码任务**且 review=外部 agent——覆盖整理门、break 点 agent 审树、带 trailer 提交、双授权齐全的自动 PR、agent 发 PASS；
  - ≥1 个 **review=无 的任务**——覆盖"无 → pr-review 人工"映射路径；
  - ≥1 个 **docs 任务**——验证载体豁免路径（不走整理门/dev-review，评审走 PR 状态评论）；
  - ≥1 个 **review=人工 的代码任务**——验证 dev-review 人工档（后两个样本可在首个任务之后、毕业之前补齐）；
  - 复盘对停点表 #1–#10 **逐停点记"触发 / 跳过"**，跳过须有豁免条件背书——防止"全链"在未验证核心改动的情况下名义通过。
- **复盘无致命缺陷**：演练后 journal 记复盘；停点表若有结构性问题（漏停、重停、映射规则误设计），修订后重演练缺失路径。
- **毕业产物**：评审通过后毕业为 ADR（新编号），frontmatter `supersedes` 列 **ADR-0007（D1 操作分级、D2 双授权——扩展为三项配置）**与 **ADR-0011（D1——`Reviewed-by` 从 opt-in 收紧为 dev-review 配置下必带）**；两旧 ADR 标 `deprecated`、`superseded-by` 留空（部分取代只挂正向链，反查用毕业 ADR 的 supersedes）。**supersedes 多值 schema 决策随毕业 PR 落地**：现行 `docs/README.md` 注明"数组化（多篇合并/分拆）暂不设计"、ADR 模板为字符串——毕业 PR 将把 `supersedes` 扩展为数组（同批更新 README 与模板，正文注明首次使用的范围），一篇毕业 ADR 同时取代两文，不拆分。ADR-0007 未取代条款（D3–D8）与 ADR-0011 未取代条款（格式正则、重写语义、PR 角色行）的继承关系在毕业 ADR 内逐条注明。`docs/guides/agent-collaboration.md` 与 AGENTS 相应章节（提交纪律整理门段、破坏性操作节）同步更新，本文件正文替换为指针（防双真源）。

## 被否的替代设计

- **dev-review / pr-review 双档位独立配置**：配置面翻倍；单配置 + "无→人工"映射已覆盖全部有意义组合（dev 与 pr 的执行者在档内自由更换）。
- **PR 评审设"无"档**：PASS 是 merge.sh 快照校验的硬前置，取消 PR 级审查等于拆掉合并校验的输入。
- **审已生成的整理序列再补 trailer**（先 rebase 出完整序列、审全量 diff、再逐提交补 `Reviewed-by`）：评审时点晚于 commit 生成，补写 trailer 属"提交后才发生的审查不回头改旧 commit"（ADR-0011 / #50 反例）——break 点审树（审在生成前）才是合规路径。
- **break 点 `git commit --amend` 补 trailer**（round 1 修正案，round 2 被否）：rebase break 停在上一条 todo 执行完之后，HEAD 已是该段提交——amend 是对已生成提交的事后补写，评审时点仍晚于生成；且 ADR-0011 的"tree 不变可保留"指已存在 trailer 的保留，不覆盖新增。改为 reset --soft 放回 index、审 staged tree、生成时带 trailer（§5）。
- **reset --soft 后按计划 staged 切片重建提交**（替代 rebase 机制）：可行但放弃"rebase -i 整理"的现行措辞与 todo 表达力，整理与评审的对应关系不如 break 点直白。
- **整理自动化 + 机械守卫**（整理前后 PR diff 总量比对，不一致自动回滚）：技术上可行且不依赖确认链毕业，但本轮保留人工定方案——"哪些内容归为一个 commit"的取舍是提交历史质量的判断题，先积累人定方案的样本再议自动化。
- **整理交独立 agent 确认**（agent-confirmation-chain L1 提前首用）：确认链未毕业不吃第一口；且与 dev-review 功能重叠——break 点审查者天然复核提交序列质量。
- **按分支类型豁免整理门**（如 hotfix 全免）：现行一般条款本就覆盖全部代码 PR 分支；代码分支内按"序列重组需要"统一触发比按分支类型更本质，docs 的豁免来自载体特性（squash）而非分支名。

## 演进记录

- 2026-11-20 起草：Phase 1 spec 暂停期的一次流程审计对话成形——全链控制点矩阵盘点 → 任务启动三项配置 → review 单配置贯穿 → 整理门条件化（hotfix 考证修正：现行一般条款覆盖所有代码 PR 分支，触发条件改为"序列需要重组"）。
- 2026-11-20 round 1 评审修正（PR #59，DSH BLOCKED 4 阻塞 + 8 非阻塞）：B1 毕业路径去下份 spec 的预言性编号引用（改为"Phase 1 spec，编号起草时分配"）；B2 dev-review 初步重定义进整理门 break 循环；B3 整理门/dev-review 限定代码分支、docs 按载体特性豁免；B4 毕业产物写明部分取代链（ADR-0007 D1/D2、ADR-0011 D1 → deprecated，superseded-by 留空）。非阻塞：N1 演练矩阵逐停点记账；N2 "永远"改"现阶段人工"；N3 触发条件保守代理化 + 单提交跳过附分解依据；N4 双授权齐全的推导理由补记（完全自主模式信号）；N5 herdr 口径诚实化与体积阈值改复盘口径；N6 停点表编号注记；N7 补 backport；N8 related 路径统一。
- 2026-11-20 round 2 评审修正（DSH BLOCKED，B2 未闭 + N9–N13）：B2 重做——break+amend 时点仍晚于 commit 生成（break 停在上一条 todo 之后），改为 break 点 `git reset --soft HEAD^` 放回 index → 审 staged tree → `git commit -C HEAD@{1} --trailer` 生成时写入（"生成前审"在 git 时序上成立；ADR-0011"保留"语义不覆盖新增 trailer 的引用一并修正）；N9 补 §6 节（round 1 漏排"异源纪律与演进口"独立节，表 #7 引用悬空）；N10 演进记录去编号字面；N11 演练矩阵补 docs 任务与 review=人工样本；N12 毕业 PR 将扩展 supersedes 为数组（同批改 README/模板），不拆两篇 ADR；N13 确认链映射收窄为"破坏性/授权/审查类停点（#3–#10）"，任务级授权点（#1/#2）待范围扩展。第二轮上限已到，按协议缩范围复审（仅 B2/N9/N12 范围）。
