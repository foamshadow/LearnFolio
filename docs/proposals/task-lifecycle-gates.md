---
title: "任务生命周期控制点：三项配置与贯穿式审查"
author: foamshadow
date: 2026-11-20
status: draft
tags: [se-arch, se-review]
related: [ADR-0003, ADR-0007, ADR-0011, SPEC-0001, proposals/agent-confirmation-chain]
adopted-as: ""
---

# 任务生命周期控制点（proposal）

## 背景

任务从"确定"到"merge"的暂停点与审核点目前散落在多份文档——AGENTS「破坏性操作」「提交纪律」「评审协议」与 ADR-0003 / 0007 / 0011——没有一个任务全生命周期的统一控制点视图。Phase 0（SPEC-0001）的实测数据与多 runtime 实践为重新设计提供了依据：

1. **双授权的常态豁免**：ADR-0007 D2 的逐条审批与逐次 push 许可两个档位在实践中基本空转（任务启动时普遍授予 auto-commit / auto-push），实际生效的人工停点收敛为：双授权申请、docs 提交确认、整理门、合并授权、破坏性操作——五个全部以"人在场"为前提。
2. **评审分层已有捕获分布数据**（Phase 0 复盘）：commit 级审查防"格式与低级错"（scope 违白名单、变量清单漏同步），PR 级评审防"口径与账本错"（勾选语义、账本口径、trailer 覆盖）。两级捕获错类不同，均有存在价值。
3. **审查者可以不是人类**：Pi 续接会话做 commit 级 `Reviewed-by`（#44 正例）、DSH 做 PR 级评审、herdr 直连对话通道（2026-11-20 实测）——"指定外部 agent 审查"已是跑通的事实，只差规则化。
4. **控制点配置缺位**：PR 创建是否自动化、开发完成后要不要停一次审查，目前全靠任务内临时沟通，没有任务级配置承载。

与 proposals/agent-confirmation-chain 的关系：该 proposal 管**破坏性操作的分级确认载体**（L0–L3，确认来源从人类渐进到上层 agent）；本 proposal 管**任务全生命周期的控制点配置**。正交且互补——本 proposal 的所有人工停点是该 proposal 载体升级路线（L1/L2）的候选项。

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

- **dev-review**（开发完成后、commit 前）：审查对象为整理后的提交序列。
  - 无 → 跳过；人工 → 停等审查；外部 agent → 指定 agent 自动审查。
  - 审查通过后生成的 commit 带 `Reviewed-by: <审查者>` trailer——用 ADR-0011 现成机制承载审查结果，不新造账本；互审约束（审查者 ≠ `Assisted-by` 参与者）直接适用。
- **pr-review**：按评审协议状态机（BLOCKED → REVIEW-FIX → PASS）执行。
  - 人工 → 人按协议审、发 PASS；外部 agent → 指定 agent 按协议审、发 PASS。
  - **无"无"档**：PASS 是 merge.sh 快照校验的硬前置，不可跳过。
  - **映射规则：review = 无 → pr-review 固定为人工**（无审查任务的 PR 兜底由人把关）。

外部 agent 的两种通道（均为已实测路径）：

- **a. 旧会话续接追问**：复用以前某 agent 的会话追加询问（如 `pi -c` 模式）——有项目上下文积累，注意会话体积寿限（≈200KB 后挂死率升高，Phase 0 复盘实测）。
- **b. 直连自动交流**：herdr 或其他来源的 agent 直接对话（herdr pane send-text / agent prompt 通道）——会话新鲜、可并行。

### 3. 全流程控制点视图

```
① 确认任务 ⏸（人）
   确定任务内容（spec 任务 / fix / docs / hotfix）
   → 申请三项配置（auto-commit / auto-push / review）→ 切分支
② 开发
   feat/fix：wip 提交免审 + 告知照常（无 auto-commit 时非 wip 提交逐条停问）
   docs：提交"确认"档不变（ADR-0007 D5：文件清单 + 关键点，点头才提交）
③ 整理门 ⏸ ——提交序列需要重组时（≥2 个提交或含 wip 碎片），PR 前
   人定 rebase 方案（哪些 commit 合并、哪些内容归为一个 commit）
   → agent 执行 rebase -i（backup 分支照旧）
④ dev-review（commit 前，审整理后的提交序列；按 review 档位，见上）
⑤ commit（修正循环的提交，受 auto-commit 控制；告知照常）
⑥ push（受 auto-push 控制）
⑦ PR 创建：双授权齐全 → 自动创建；否则 ⏸ 询问是否创建
⑧ pr-review（按 review 档位；review=无 → 人工）
⑨ 合并请求 ⏸ 必须人工授权（agent 只执行 task merge 快照合并）
⑩ 收尾：任务结束三项配置失效；文档写回窗口已随 PR 闭合
```

| # | 停点 | 触发条件 | 豁免条件 |
| --- | --- | --- | --- |
| 1 | 三项配置申请 | 每任务一次 | —— |
| 2 | docs 提交确认 | docs 任务每次提交 | 无（不随 auto-commit 豁免） |
| 3 | 整理门 | 提交序列需要重组（≥2 提交或含 wip 碎片） | 单提交任务自动跳过（agent 在合并请求声明） |
| 4 | dev-review | review = 人工 | review = 无 或 agent（agent 自动过） |
| 5 | 逐条提交审批 | 无 auto-commit | 有 auto-commit；`wip:` 永远免审 |
| 6 | 逐次 push 许可 | 无 auto-push | 有 auto-push |
| 7 | PR 创建询问 | 双授权不齐 | 双授权齐全 → 自动创建 |
| 8 | pr-review 人工 | review = 人工 或 无（映射） | review = agent → agent 自动审 |
| 9 | 合并授权 | **永远**（现阶段不可自动化） | 无 |
| 10 | 破坏性操作（tag / dev→main / revert -m / force push） | 永远（Phase 0 规则） | agent-confirmation-chain 毕业后按 L1/L2 载体调整 |

### 4. 整理门的条件化（对现行规则的唯一实质修改）

现行"PR 开启前 rebase -i 整理"是覆盖所有代码 PR 分支的一般条款（AGENTS 提交纪律节，无分支限定；docs 是唯一显式豁免——squash 合入）。本 proposal 不按分支类型划豁免，而按**是否真的需要重组**触发：

- 触发条件：分支提交序列需要重组（≥2 个提交，或含 wip 碎片）。
- 单提交 hotfix（常态）与单提交 feat/fix 小任务自动跳过——agent 在合并请求里声明"单提交无需整理"，合并授权时顺带确认，零新增停点。
- 多提交任务走完整门：人定方案、agent 执行。方案确认本身就是提交历史质量的把关点。
- 整理在 dev-review **之前**——ADR-0011 语义"内容变更（fixup / 改树 rebase）使 `Reviewed-by` 失效"，先审后整理等于白审。

### 5. 异源纪律与演进口

- **异源**：审查执行者 ≠ 实现者（ADR-0011 互审约束）；两级审查推荐异 agent——Phase 0 数据表明两级捕获错类不同，异源保留分布价值。
- **人工停点的载体升级（演进口，本次不做）**：停点表中所有人工项（①③④⑧⑨）在 OpenRig 等多 agent 体系完善后，可由上级 agent 确认替代而非绝对人类——即 agent-confirmation-chain 的载体渐进路线（现阶段人类充任 L1/L2，成熟后换载体，流程同构）。
- **auto-rebase（演进口，本次不做）**：仅 auto-pr 场景（双授权齐全）下，agent 按既定方案自主整理——待"人定方案"阶段积累足够样本后再议。

## 毕业条件

- **首次全链演练**：SPEC-0002 的首个真实任务按本流程走完全链（三项配置申请 → 整理门 → dev-review → commit/push → PR → pr-review → 合并授权），各停点行为与本文一致。
- **复盘无致命缺陷**：演练后 journal 记复盘；停点表若有结构性问题（漏停、重停、映射规则误设计），修订后重演练。
- **毕业产物**：评审通过后毕业为 ADR（补强 ADR-0007：D2 双授权扩展为三配置、D1 分级表纳入 review 档位；整理门条件化条款落入分支与提交纪律），`docs/guides/agent-collaboration.md` 与 AGENTS 相应章节同步更新，本文件正文替换为指针（防双真源）。

## 被否的替代设计

- **dev-review / pr-review 双档位独立配置**：配置面翻倍；单配置 + "无→人工"映射已覆盖全部有意义组合（dev 与 pr 的执行者在档内自由更换）。
- **PR 评审设"无"档**：PASS 是 merge.sh 快照校验的硬前置，取消 PR 级审查等于拆掉合并校验的输入。
- **整理自动化 + 机械守卫**（整理前后 PR diff 总量比对，不一致自动回滚）：技术上可行且不依赖确认链毕业，但本轮保留人工定方案——"哪些内容归为一个 commit"的取舍是提交历史质量的判断题，先积累人定方案的样本再议自动化。
- **整理交独立 agent 确认**（agent-confirmation-chain L1 提前首用）：确认链未毕业不吃第一口；且与 dev-review 功能重叠——审查者天然复核提交序列质量。
- **按分支类型豁免整理门**（如 hotfix 全免）：现行一般条款本就覆盖 hotfix；按"是否需要重组"触发比按分支类型更本质，且副产品是单提交 feat/fix 同样免掉平凡人停。

## 演进记录

- 2026-11-20 起草：Phase 1 spec 暂停期的一次流程审计对话成形——全链控制点矩阵盘点 → 任务启动三项配置 → review 单配置贯穿 → 整理门条件化（hotfix 考证修正：现行一般条款覆盖所有代码 PR 分支，触发条件改为"序列需要重组"）。
