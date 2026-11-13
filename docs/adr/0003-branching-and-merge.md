---
id: ADR-0003
title: "分支模型与合并策略：git-flow 简化 + 任务级 --no-ff + 草稿提交纪律"
status: accepted
date: 2026-11-13
author: foamshadow
tags: [se-arch]
related: [ADR-0001, SPEC-0001]
---

# ADR-0003：分支模型与合并策略

> 补记说明：决策发生于建仓前策划期，**主体定于 2026-11-12、增补至 11-13**（含截至 11-13 的七轮外部审查修正与开源调研——主流分支模型、合并策略分布；backport 分支、release tag 打点（收口 = merge commit / hotfix = hotfix tip）、收口批准 1+检查单等为 11-13 增补）；本篇为沉淀归档，入库后正文即不可变。

## 背景（Context）

5 人学习型团队 + AI agent 实现。需求：Phase 级发布节奏（tag 承载版本语义）、任务级并行开发、git 历史作为开发账本（harmony 项目核心遗产：第一父链账本——`git log --first-parent` 一任务一节点一格式）。约束：任务分支为天级短命分支（spec 任务分解的 tM 粒度）、单人或单 agent 现场。

## 决策（Decision）

- **分支模型 = git-flow 简化**：main（产品库，只收 `--no-ff`，tag 只在此打）/ dev（单条集成分支——Phase 串行无需多线）/ `feat/spec-N-tM-短名`（任务分支，从 dev 切 PR 回 dev）/ `fix/短名`（dev 上修复，与 feat 同层同流程——不分贱籍）/ `hotfix/短名`（从 main 切，修已发布基线）/ `backport/短名`（hotfix 回流 dev 的载体：从 dev 切、`git merge <hotfix tag>`、PR 回 dev——dev 必 PR 且禁 bypass，"在 dev 上直接 git merge"不可执行）。fix/hotfix/backport 的命名锚点分级（spec-N-tM / spec-N / scope 三档）以 AGENTS 分支节为准——本文只定类型与流向，入库后不可变，细节演化住 AGENTS
- **合入策略 = 一律 `--no-ff` merge**：feat/fix → dev 与 dev → main 均产生真实 merge 节点；由 repo settings 物理强制（只保留 merge commit 按钮，关闭 squash/rebase/linear history），非人工纪律
- **hotfix 走 merge 不走 cherry-pick；release tag 打在发布内容的代表 commit（收口 = merge commit `origin/main`，hotfix = hotfix tip `origin/main^2`）**：merge 保证 dev 始终包含 main 全部内容（dev→main 永不冲突且 tree 恒等），收口守卫（三点 diff）靠它成立；收口 tag 必须在 main 第一父链上——"main 第一父链 + tag = 版本史"读法与 describe 才成立（describe 仅 main 侧：收口 merge commit 不在 dev 祖先；打 dev tip 则脱离该链，`git log --first-parent main` 一个版本 tag 都装饰不出来）；hotfix tag 必须指向 hotfix 线本身——被删分支的改动靠 tag 留存，backport 的 `git merge <tag>` 也依赖它（指向 merge commit 会把整条 main 线并进 dev）；"dev 包含 main 全部内容"**不是自动成立**——由每个 hotfix 及时 backport 维持，收口前以机械守卫验证（见后果节）；单独改任一条都会崩
- **关闭 "Require branches to be up to date"**：它与 rebase 整理门 + approved 不改写三者过约束死锁（dev 每前进一次，全部在飞 PR 被迫改写重审）；补偿 = ci.yml push 触发覆盖 dev/main + merge queue 被否（见 Alternatives）的权衡记录
- **提交纪律 = 草稿 + 整理门（A+C）**：feat 内 WIP 高频提交（一个可验证步骤一提交，message 放宽）；PR 开启前 `rebase -i` 整理为逻辑级提交序列（fixup 纯噪音、保留逻辑步骤，**禁止把任务整体 squash 成单提交**）；approved 后不再改写，要改退回重审
- **三层历史读法**：main 第一父链 + tag = 版本史（Phase 级）；dev 第一父链 = 任务史（feat merge 节点）；feat 全量提交 = 过程史（逻辑步骤级）

## 被否方案（Alternatives）

| 方案 | 否决理由 | 翻转条件 |
| --- | --- | --- |
| squash merge（任务级，业界主流） | 与本项目冲突：丢过程提交（agent 轨迹 = 学习材料）与并行拓扑；git 默认可 ff 时吞节点 → 账本形状不一致；过程叙述的正当住所虽已是 journal，但 bisect 细粒度需要 git 内过程 | 团队放弃过程保留价值，任务粒度缩小到"PR 即原子" |
| 数字集成分支 `int/0.Y` | 开源无先例：数字分支的主流角色是发布维护线（K8s `release-1.x` / Node `v20.x`，收 backport 补丁），集成线主流是 `develop` 或无集成分支；本项目 Phase 串行，多线并行用不上 | 出现多版本并行维护（已发布 v1 与开发中 v2 并存） |
| wip 子分支垫层（feat 下再开草稿分支 squash 回 feat） | 解决的是"长寿命多人共享 feat 不能 force push"；本项目 feat 天级单人，结构税无收益。长寿命大任务出现时该结构自然涌现，不预设（不预支原则） | 单任务增长到周级、多人/多 agent 共享同一 feat |
| `--no-ff` 且从不整理 | WIP 噪音（typo 链）永久入史，feat 可读性差 | —（整理门是配套而非替代） |
| GitHub merge queue | 能测合并后的假想结果（可补关闭 up-to-date 的缺口），但 queue 生成自己的 merge commit message，账本格式无法保留——主动接受"账本 message > 合并前 CI"的权衡 | 团队放弃账本 message 格式，或 GitHub 支持自定义 queue 的 merge message |

## 后果（Consequences）

- feat 过程提交永久保留：bisect 可定位到任务内具体步骤；agent 试错轨迹成为学习材料（与 learning/ 互为源与蒸馏）
- **--no-ff 与 merge message 格式由 repo settings 物理强制**（只留 merge commit 按钮 + 默认取 PR title + CI 校验 PR 标题正则 + 关闭 Require linear history + 开 Dismiss stale pull request approvals——"approved 后不改写"由纪律变机制）——"进 settings 才是机制"原则适用于本 ADR 自身的每条纪律
- **release tag 打在发布内容的代表 commit（见决策节）：收口 = merge commit `origin/main`，hotfix = hotfix tip `origin/main^2`**；tag 一律 annotated，message 列覆盖 SPEC，推送显式 `git push origin vX.Y.Z`（`--follow-tags` 依附常规 push 会连带推当前分支，合并发生在远端时本地 main 落后，行为不可预期）；Y 于收口时显式指定并记录收口 journal（Phase 0 → v0.1.0；Phase 1 首次上线 → v1.0.0；其后 Y+1）
- 关闭 up-to-date 的代价（pull_request 本跑在 GitHub 生成的 merge commit 上、测的正是合并结果，真实缺口是 base 在运行后前进时已有结果过期且不自动重跑）由 push 触发 CI 补偿；dev push CI 红 = 语义冲突落地，处置 fix/ 修复或 `git revert -m 1`（注意 revert merge 的重合入陷阱）
- **破坏性操作 Phase 0 由人类执行或确认**（rebase -i 整理门、force push 一律 `--force-with-lease --force-if-includes`、打 tag、dev→main 合并、git revert -m；agent 限 commit 与非 force push；rebase 前留 backup 分支）。**agent 确认链作为提案孵化于 proposals/**（毕业条件：OpenRig 引入 + 首次全链演练），毕业后以新 ADR 取代本条
- Y 版本语义由 tag 承载，不编码进分支名（对个人全局规则"Y=二级分支"的项目级覆盖；语义化版本与稳定才合并的精神保留）
- conventional commits 只约束合入 dev/main 的内容，feat 内 WIP 豁免（scope 白名单：web / api / infra / ci / docs / deps）；命名约束：main/dev 为长存分支，新建分支不得取六前缀的单段名、不得以 main/ 或 dev/ 为前缀（D/F 冲突，详见 AGENTS 分支与版本节）
- dev→main 收口 PR 的评审对象是**发布检查单**而非代码（代码已在各 feat PR 逐个审过）。**首项 = 机械守卫"main 自分叉点以来无 dev 缺失的改动"**：`git fetch origin --tags && git diff --quiet origin/dev...origin/main || { echo "BLOCKED: main 有 dev 缺失的内容（未回流的 hotfix？）"; for t in $(git tag); do git merge-base --is-ancestor "$t" origin/dev || echo "  未回流 tag: $t"; done; exit 1; }`——三点 diff 为空 = main 相对 merge-base 无内容增量，**覆盖漏打 tag 与漏 backport 的一切 main 侧独有内容**（纯 tag 遍历查不出漏打 tag 的 hotfix；echo 恒返 0 不能阻断 CI，循环仅作诊断，阻断由 diff 非零退出码承担）。**不可用 `--is-ancestor origin/main origin/dev` 替代**：其真值与"main 是否缺失内容"不相关——正常收口时刻 main tip（最新收口 merge commit）只在 main 第一父链上、不在 dev 祖先，该式恒假恒误阻断；唯一变真 = hotfix 经 backport 把旧收口 merge 带入 dev 祖先之后，而那一刻本就无需阻断。守卫适合做成 CI job（按收口 PR 标题正则触发）。**收口的文件写操作走前置 PR**：SPEC 验收条目逐条勾选 + spec status → done 在 fix/ 短名前置 PR 回 dev 完成、先于收口 PR 合入（收口 PR head = dev、dev 必 PR 禁直推，收口 PR 自身无法承载新的文件改动；顺序反了会被 Dismiss stale approvals 作废审批重审），检查单此处只确认前置 PR 已合入。其余项：全部任务合入确认 / dev push CI 绿 / Y 指定与 tag message 草稿附 PR 描述
- 收口批准 = **≥1 名非作者核心成员 + 检查单逐项勾选**（3 核心下 2 approvals = 除作者外全票、可用性单点；hotfix→main 的 PR 同吃 main 保护，紧急场景代价最高。agent 确认链毕业后恢复 ≥2 独立确认源）
