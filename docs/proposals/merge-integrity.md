---
title: "合并完整性与历史修复：快照合并、撤回窗口与 PR 编号守恒"
author: foamshadow
date: 2026-11-16
status: review
tags: [se-arch, tool-git, tool-ci]
related: [ADR-0004, ADR-0005, ADR-0007, ADR-0009, ADR-0010, ADR-0011, SPEC-0001]
adopted-as: ""
---

# 合并完整性与历史修复

## 背景

2026-11-16 PR #22（agent-collaboration 教学版）暴露了一条完整故障链：

1. PR head 的 CI 绿（`ci-ok`）；`REVIEW: PASS` 后，PR 描述被追加了一段评审清单；
2. squash merge 时，GitHub 用**描述**生成落地提交，`Assisted-by` 不再位于正文末尾；
3. dev push 的 attribution 判红——PR 已合并，push CI 是**事后发现**；
4. 先用 revert + redo + 单独 journal PR 补救，dev 出现 revert/redo 节点，PR 号 #22–#25 连续消耗；
5. 最后 force reset dev 回 `1d622c3`，再用 #26 re-land，历史才变干净。

由此得到三个目标，它们彼此冲突：

1. **history 美观**：dev 第一父链只有任务 merge / docs 最终单提交，没有 revert/redo 对；
2. **commit 准确**：落地提交的正文与树，就是被评审、被合并的那一份；
3. **可溯源**：commit → PR → review/CI 能对上；PR 号尽量不浪费，但不以牺牲前两项为代价。

核心矛盾：GitHub 原生只有 revert（+1 提交、+1 PR）；“零补救提交 + 平台可溯源”只能靠受控 rewrite。规则要把 rewrite 关进笼子，而不是临时关保护硬推。

## 提议

### 0. 决策基线（2026-11-17）

- **软约束**（已定，#28 评审协议毕业）：不引入 `review-gate` / merge bot；`required_approving_review_count=0`；PASS 是评论，不是 approval。
- **合并授权**（已定）：人类先授权，agent 再执行合并；脚本是执行工具，不替代授权。
- **docs / code 分路径**（已定）：docs 用 squash + body 快照；code 用 `--no-ff` + title 校验 + 分支提交 trailer。
- **收口后**（ADR-0010 #29 已 accepted）：dev/main/tag 允许 rewrite，但**只允许 message-only（tree 不变）**；内容 rewrite 不允许；docs 单提交已撤销（ADR-0005 `deprecated`）；AGENTS 流程冻结线已同步。

### 0.1 现行依赖（事实）

- **评审协议已毕业**（#28）：PASS 的 `target` / `body-sha256` / `Reviewer` / PASS 后冻结，真源是 `AGENTS.md`「评审协议」+ `docs/guides/review.md`；本 proposal 不再定义评审流程，只消费 PASS。
- **评审署名双轨**（ADR-0011）：PR 状态评论的角色行（BLOCKED/PASS `Reviewer`；REVIEW-FIX `Author`）；commit 级提交前互审写 `Reviewed-by`（opt-in）；`Pi` / `glm-5.3` 已登记（与 `glm-5.3-flash` 区分）；#27–#29 的历史缺口不回填。
- **C6 `pr-meta` 已落地**（#27）：PR 描述末行 trailer、正文无评审状态行（含 `Reviewed-by` 行）；并入 `ci-ok`；不查 docs 提交数、不校验评论层 Reviewer（ADR-0011）。
- **ADR-0010 已 accepted**（#29）：message-only rewrite；docs 单提交撤销；ADR-0005 `deprecated`。
- **未实现 / 未实测**：`scripts/merge.sh` / `retract.sh` 未写；`(#N)` 自定义 subject 未实测；ruleset vs break-glass 未定。

### 1. 合入前：快照合并（P0，硬保证）

> 术语：PASS = 评审者按完整清单发出的 `REVIEW: PASS` 状态评论（不是 GitHub approval；合并授权另按 ADR-0007）。它是 `AGENTS.md`「评审协议」+ `docs/guides/review.md` 的项目级规则（#28 已毕业），不是 GitHub required approval/check；GitHub 侧硬门禁目前只有 `ci-ok`。PASS 评论末行记 `Reviewer: <harness>:<model>`（键表同 `Assisted-by`，人类写 `none`）；同账号下这是声明，不是平台验证。本 proposal 不重新定义评审流程，只规定 PASS 时抓快照；快照脚本是流程级约束，Merge 按钮仍可绕过。

PASS 时抓 `title + body` 快照并记 hash；合并时用快照生成 squash 正文，不读实时描述。

- PASS 评论按 AGENTS 模板带 `target`、`body-sha256: <sha256(title + "\n" + body)>`、末行 `Reviewer: <harness>:<model>`。
- 合并脚本 `scripts/merge.sh <PR>`：
  1. 取 PR 当前 `title/body`；
  2. 校验末行是 `Assisted-by` trailer、正文无评审状态行（REVIEW / Reviewer / Author / Reviewed-by；**有意与 C6 冗余**：脚本不依赖 CI 时序，C6 只是 PR 时的 backstop）；
  3. 与 PASS 评论的 hash 比对；不一致即作废 PASS，退回重审；同时要求 PASS 评论末行有 `Reviewer:`；
  4. docs 用快照合并：`gh pr merge --squash --subject "<title> (#N)" --body-file <snapshot>`；code 用 `gh pr merge --merge --subject "<title>"`（merge commit 正文为空）。
- 作者在 PASS 后不得编辑 title/body；编辑即作废 PASS。
- 第一次使用前验证 `(#N)` 后缀：自定义 subject 是否被平台重复追加。验收标准固定为“dev 上 subject = `标题 (#N)`、body = 快照”。

#### docs 与 code 分路径

- **docs**：squash；快照 body 生成落地正文；`gh pr merge --squash --subject "<title> (#N)" --body-file <snapshot>`。
- **code**：`--no-ff`；merge commit 正文为空；快照只冻结 title / 描述；脚本用 `gh pr merge --merge --subject "<title>"`（不带 body）；分支提交的 trailer 由 attribution 校验。
- **PASS 后改描述**：作废 PASS，需重新 PASS（新 target/hash）并重新快照。

#### 手动合并警告（零成本兜底）

手动点 GitHub Merge 按钮 = 绕过快照脚本。PASS 评论附以下警告，`docs/guides/merge.md` 同文（待建）：

> [!WARNING]
> 手动合并前逐项确认：
> - [ ] 标题 = 落地主题，且 PASS 后未改
> - [ ] 描述只含最终变更：无评审记录、修正清单、试错过程
> - [ ] 描述最后一行是 `Assisted-by: ...`，其后没有任何内容
> - [ ] 描述与 PASS 一致（`body-sha256` 相同；否则重新 PASS）
> - [ ] `ci-ok` 绿；docs 单意图（提交数不限，ADR-0010 已撤销单提交）；base/head 方向正确
> - [ ] 无 open blocking；PASS 的 target = 当前 head
> - [ ] 合并方式：docs squash；feat/fix `--no-ff`；不手改 message
>
> 合并后立刻检查落地提交的 subject/body；不符合按 P1–P4 处理，不要点 Revert。

注意：警告**不能**放在 PR 正文的 trailer 之后——会随 squash 进入提交正文，正是 #22 的成因；只放 PASS 评论与指南。

出现时机：评审者发 `REVIEW: PASS` 时随评论出现；GitHub 的 Merge 对话框不接受自定义警告文本。已决定只随 PASS 评论，不额外加 bot 评论或 `review-gate` required check（软约束，#28）。

### 2. 合入后：先分类，再选修复阶梯

| 类型 | 判断 | 首选 |
| --- | --- | --- |
| **元数据**（message / trailer / 描述） | 内容正确 | 头部 + 窗口内：**P2b reset + re-land（默认，平台溯源）** 或 P2a amend（省号退路）；否则 P1 接受 + journal，或按 ADR-0010 D1 全量仪式做 message-only（窗口外/非头部，慎用） |
| **内容错误**（非敏感） | 当前树必须改 | P3 revert 或 fix-forward；ADR-0010 不允许内容 rewrite |
| **敏感数据**（密钥 / PII / 法律） | 不可留在任何历史 | 独立事件响应：轮换 + rewrite + 平台清理；**revert 不够** |
| **仅 CI 红** | 平台 / 配置 | fix-forward 或 rerun；不改历史 |

修复阶梯：

- **P0 合入前**：同分支 amend / force，PR 号复用；坏提交不进 dev。
- **P1 接受 + journal**：元数据、非头部、窗口外，且不走 ADR-0010 D1 全量仪式；0 新提交、0 新号；坏 message 保留，记执行差异。
- **P2a 头部 amend**：坏提交在 dev 头部、窗口内、无人依赖、rewrite 已授权；**只改 message（tree 不变，ADR-0010 不允许内容）**；0 新提交、0 新号；PR 页面仍指旧 SHA，需在 PR 描述里记新 SHA。
- **P2b reset + re-land**：坏提交在头部/窗口内；force reset 丢掉坏提交，再用新 PR 重做**同一内容**（内容不变）；+1 号、clone reset；历史干净，新 PR 页面与平台溯源干净；旧 PR 页面仍指旧 SHA。
- **P3 revert**：内容必须撤、窗口外、有人依赖；+1 提交、+1 号；revert 不清历史，且 diff 可能再次暴露内容。
- **P4 revert + redo**：撤了还必须重做；+2 号；最后手段。
- **双轨边界**：P2a/P2b 是快速通道，只覆盖“dev 头部 + 窗口内”；ADR-0010 D1 的 message-only 全量仪式（备份、区间映射、tag 重打、journal、保护恢复）可用于窗口外/非头部，但不进入本阶梯，也不把窗口变成 ADR-0010 的唯一授权边界。
- **code 路径**：merge commit 正文为空；merge subject 错可 P2a amend merge commit；分支提交 trailer 错要 rebase 分支 + 重建 merge（通常走 P2b reset + re-merge）；P3 revert 只用于内容回滚，不修 trailer；不要把 docs 的 body 快照套到 code。
- **revert 范围**：P3 只在内容必须撤、且 rewrite 不可用时使用；元数据不 revert；revert 应很少使用。

#### 撤回窗口（建议）

同时满足才允许 P2a / P2b：

1. 坏提交在 dev 头部（或其后只有本次修复提交，可一起 rebase）；
2. 距合入 ≤ 24 小时，且下一个任务分支尚未切出（两者取先到）；
3. 没有其他成员基于该提交工作；有则先通知并取得同意；
4. 人类所有者明确批准；
5. 先建备份分支；推完恢复分支保护，并通知所有 clone reset；
6. 在 PR 评论 + 下一次 journal（搭车）留痕，不单独开号。

窗口外：内容走 revert；元数据默认接受 + journal，或按 ADR-0010 D1 全量仪式做 message-only（窗口外/非头部，重流程，慎用）。**本窗口只约束 P2a/P2b 快速通道**；它不是 ADR-0010 D1 的授权边界。非头部 rebase 一串的风险高于收益，不进入 P2a/P2b。

### 3. 平台溯源与 PR 编号

“溯源”分两层，不能混：

- **文本级**：commit subject 里的 `(#N)`，`git log` 可搜到 PR；amend 保留 subject 即可保住这一层。
- **平台级**：commit 是某个 PR 的 merge commit，GitHub 上可双向点通；只有 re-land 能做到，amend 做不到。

已合并 PR 的 merge SHA 不可编辑；旧 PR 页面不会因 rewrite 消失；PR 号 merge 后不可复用。能省的只有“额外 PR”：

- 合入前同号 amend；
- 合入后窗口内：P2a amend 不新开号；P2b re-land 多一个号（买平台溯源）；
- 事故 journal 搭下一次 PR，不单独开号；
- 多个小修复合并到一个 PR。

**amend 与 re-land 的取舍**：按“history 美观 + commit 准确 > 平台溯源 > 省号”的优先级，默认 **P2b：force reset + re-land**——多一个号，换干净权威页；团队不能 reset、或旧页面可接受时，用 P2a amend 省号。旧 PR 标注 `superseded by #N`，保留为失败尝试的审计页；journal 记区间映射 `A..B → A'..B'`（ADR-0010 D1.3）。

### 4. 合规 rewrite 的基础设施

- **ruleset + bypass actor（推荐）**：把 dev 保护迁到 ruleset，给 owner / 发布经理 bypass；撤回时合法 force，不必临时关保护，审计可见。
- **break-glass 脚本（备选）**：临时关 PR/status 检查 + 开 force，推完恢复并打印审计行；本次手工版容易漏恢复。
- `scripts/retract.sh <sha>`：检查头部 / 窗口 / 备份 → bypass → `rebase --onto` 或 `reset` → `--force-with-lease` → 恢复保护 → 输出需要 reset 的 clone 列表。
- 每次恢复后必须验证：`allow_force_pushes=false`、required `ci-ok`、`enforce_admins=true`、dismiss stale reviews。
- 当前 `required_approving_review_count=0`；同账号无法 native approve；真独立审批需另一个账号（人类成员），不在本 proposal 首次落地。
- **收口后**：ADR-0010（#29 accepted）允许 dev/main/tag 的 message-only rewrite；内容 rewrite 不允许；AGENTS“流程冻结线”已同步；main/tag 的 tag 重打、发布通知、备份条件由 ADR-0010 D1 规定。

### 5. CI 缺口

- PR 的 `ci-ok` 检查的是 PR head 提交；squash 提交在 merge 时生成，PR CI 没看过它。
- push 的 `ci-ok (push)` 是事后发现，不是 required；它拦不住 merge。
- C6 已落地（PR #27）：`pr-meta` job 校验 PR 描述末行 `Assisted-by` trailer、正文无评审清单段；失败并入 `ci-ok`；push 下 skipped；docs 单提交不查（ADR-0010 已撤销）。触发：`pull_request` 的 `opened / edited / synchronize / reopened`（必须含 `edited`，因为 body 编辑不换 SHA）；只跑 PR，不跑 push。价值是**PR 时的 body backstop**；body 在 check 之后仍可改，check 可能 stale，硬保证仍是快照合并。ADR-0009 部分取代待补（C6 登记，另行处理）。
- PASS 是评论约定，不是 CI 检查；当前 required 只有 `ci-ok`。快照脚本读取 PASS 评论，属于流程级约束；Merge 按钮仍可绕过。
- 没有 PASS 之前，只要 `ci-ok` 绿，Merge 按钮就可用；GitHub 不要求 PASS。PASS 只是流程约定，不是 merge 前置条件。
- 不接受“靠 auto-merge / merge queue 解决”：两者仍读实时描述；queue 只验树，不验提交正文。

## 开放问题

以下只列尚未决定、且会改变实现的项；已决项见 §0。

1. 撤回窗口：24 小时 + 下一任务分支前（取先到）是否过短/过长？还是只按“下一次 push CI 绿之前”？
2. 合规 rewrite：迁 ruleset + bypass actor，还是先用 break-glass 脚本？前者一劳永逸，但要改仓库保护配置。
3. `gh pr merge --subject` 的 `(#N)` 行为需实测：自定义 subject 是否被平台重复追加；若重复，是否只快照 body、让平台默认 title。
4. `scripts/` 放根目录还是 `tools/`？随 t1 Taskfile 落地，还是单独 infra 任务？
5. 旧 PR 页面标注：只改 title/description，还是另加 journal？merged PR 无法删除，标注是唯一的“软清理”。

## 毕业条件

- **pilot**：`scripts/merge.sh` 落地后，至少 3 个 PR（docs 与代码各至少 1 个）用它合并；0 次“PASS 后描述变更导致落地正文不一致”；`(#N)` 行为验证通过。
- **撤回演练**：一次头部元数据错误走 P2a 或 P2b——历史干净、保护恢复、clone 通知齐全；P2a 验 0 新号，P2b 验新 PR 页面与旧 PR 标注。
- **敏感数据桌面演练**（假密钥）：轮换 + rewrite + 验证；确认 revert 不在流程里。
- **毕业产物**：评审协议已毕业（#28，AGENTS + guide）；C6 `pr-meta` 已落地（#27）；待做 `docs/guides/merge.md`、`scripts/merge.sh` / `retract.sh`、撤回窗口规则、ADR-0009 部分取代（C6 登记）。
- **依赖**：t1 的根 Taskfile（`task merge` / `task retract`）；`(#N)` 实测；ruleset 迁移作为单独 infra 任务，不塞进本 proposal 的首次落地。

## 被否方案

- **revert 修元数据**：+1 提交、+1 号，坏 message 还在；#22 的 5 个号就是这样来的。
- **删分支 / 删 dev 重建**：不省号；删 dev 要关保护、可能影响 open PR；与 force update 等价但副作用更多。
- **auto-merge / merge queue 单独用**：仍用实时描述；queue 只验树，不验提交正文。
- **所有情况都 force rewrite**：破坏 clone 与 PR 溯源；窗口外/非头部风险过高。
- **所有情况都接受**：坏 message 永久留账本，审计失真。

## 演进记录

- 2026-11-16 由 #22 事故讨论起草：5 个 PR 号、revert/redo、force reset + re-land；确立“先分类、元数据不 revert、快照合并、撤回窗口”四个结论。
- 2026-11-16 第一轮决策：PASS 模板归 review-protocol；软约束（不引入 review-gate/merge bot）；人类授权后 agent 执行合并；docs/code 分路径；收口后仍允许 rewrite（当时需同步 AGENTS 冻结线，11-17 已完成）；PASS 模板加 `body-sha256`；`required_approving_review_count` 保持 0；评论靠共识管理，不镜像。
- 2026-11-16 第二轮决策：ADR-0010 方向（dev/main/tag message-only；内容不允许；journal 留痕）；docs 单提交拟撤销；review-protocol 计划先毕业。后续 11-17 已落地（review #28、ADR #29）。
- 2026-11-17 事实对齐：review-protocol #28 毕业（PASS 规则迁 AGENTS/guide）；C6 #27 落地；ADR-0010 #29 accepted（ADR-0005 `deprecated`、docs 单提交撤销）；scripts 未实现、`(#N)` 未实测。
