---
id: ADR-0010
title: "历史修复与 docs 分支：message-only rewrite 与撤销单提交"
status: accepted
date: 2026-11-17
author: foamshadow
tags: [se-arch, tool-git]
related: [ADR-0003, ADR-0004, ADR-0005, ADR-0007, ADR-0009, SPEC-0001]
supersedes: "ADR-0005"
superseded-by: ""
---

# ADR-0010：历史修复与 docs 分支

> 部分取代：本 ADR 只取代 ADR-0005 中“`docs/*` 分支恰好一个提交”的**分支提交数**条款；docs squash、账本行、trailer 等其余决策继续有效（ADR-0005 因此标 `deprecated` = 部分条款失效）。它同时取代 AGENTS「流程冻结线」中“收口后不重写已发布历史”的**绝对禁止**部分：改为受控的 message-only rewrite。
>
> 边界：本 ADR 不取代 ADR-0009。C6 `pr-meta` 对 ADR-0009 门禁矩阵的“部分取代”是独立欠账，另行处理；`related` 中的 ADR-0009 仅表示相关。

## 背景（Context）

- 项目优先级：**history 美观 + commit 准确 > 平台溯源 > PR 号**。PR 号不浪费但不以牺牲前两项为代价；revert 会产生补救提交，只在内容必须撤回时使用。
- #22 事故暴露了“PASS 后描述编辑 → squash 正文 trailer 失位”的元数据错误。修复阶梯里 P2a（原地 amend）能省号，但 PR 页面仍指旧 SHA、新 commit 不是任何 PR 的 merge commit；P2b（reset + re-land）多一个号，换平台溯源干净。
- 现行 AGENTS「流程冻结线」规定 v0.1.0 收口后不重写已发布历史；这条与“收口后仍要保证 commit 描述正确”冲突。人类所有者决定：收口后也允许 rewrite，但**只允许 message-only**。
- 现行 ADR-0005 规定 `docs/*` 分支恰好一个提交。squash 后最终一定是一个 commit；分支提交数是过程纪律，不是落地形状。人类所有者决定撤销该单提交约束。
- 平台限制：merged PR 的 merge SHA 不可编辑；旧 PR 页面不会因 rewrite 消失；PR 号 merge 后不可回收；tag 是发布内容的代表，重写会改变 SHA。
- 安全边界：敏感数据不能靠 rewrite 解决（旧对象、fork、CI 日志仍可能残留）；revert 也不能。敏感数据走独立事件响应：轮换 + rewrite + 平台清理。内容错误不在本 ADR 的 rewrite 范围。
- 术语：P0 = 合入前；P1 = 接受 + journal；P2a = 头部 amend（只改 message）；P2b = reset + re-land（同一内容）；P3 = revert；P4 = revert + redo。完整阶梯见 `merge-integrity` proposal（独立文档，随其 PR 落地）。

## 决策（Decision）

### D1 允许 message-only rewrite（dev / main / tag）

对 dev、main、tag 上已合入的提交，允许做**只改提交消息、不改树**的受控 rewrite。必须同时满足：

1. **tree 不变**：`git diff <old> <new>` 为空；只改 subject/body/trailer 等 message。禁止借 rewrite 改内容。
2. **人类所有者明确批准**；agent 不得自行发起或先斩后奏。
3. **先备份**：分支 / tag 各留备份引用；记录**区间映射**（如 `A..B → A'..B'`，不只单点）与受影响 tag 的 old/new SHA、理由、批准人、scope、clone/tag 通知。
4. **合规通道**：用 ruleset bypass actor 或 break-glass 脚本临时放行 force；推完立刻恢复保护，并验证 `allow_force_pushes=false`、required `ci-ok`、`enforce_admins=true`、`dismiss_stale_reviews=true`。
5. **tag 影响面**：如果被改提交是**任何 tag 的祖先或指向点**（对区间内每个 old commit 跑 `git tag --contains <old>`，取并集），必须逐一重打 annotated tag 并发布通知；tag 的 tree 不变；若 tag 已被外部消费/缓存，先评估再动。不要只看 main 第一父链或 tag 指向点——中段 rewrite 会重写全部后代，hotfix tag 可能指向 merge 第二父而成为孤儿。
6. **收口后仍允许**：本 ADR 生效后，v0.1.0 收口不再是“绝对不 rewrite”的冻结线；但只开 message-only 这一种。
7. **journal 留痕**：每次 rewrite 记 journal（区间映射、受影响 tag、理由、批准人、clone/tag 通知），并与事故/PR 关联。
8. **内容错误不走本 ADR**：P3 revert 或 fix-forward；敏感数据走独立事件响应。P2b re-land 只允许重做**同一内容**；内容变更不属于本 ADR。

### D2 撤销 docs 单提交

1. `docs/*` 分支不再强制“恰好一个提交”；可以多提交，但必须保持**单意图**（一个 PR 只做一件事）。
2. 合入方式不变：GitHub **squash**；最终 dev 仍是一条普通提交，无 merge 节点；PR 标题即落地主题，PR 描述即 squash 正文。
3. 每个 docs 分支提交仍必须带 `Assisted-by` trailer（attribution 逐提交校验）；squash 正文的 trailer 仍来自 PR 描述末行。
4. 任务 PR 的文档写回窗口可以用**追加提交**，不再强制 amend/force；approved 后追加仍会因 Dismiss stale approvals 作废审批，按评审协议重审。
5. 评审清单的“docs 恰好 1”改为“docs 单意图、提交数不限”；C6 `pr-meta` 不查 docs 提交数（2026-11-17 已落地）。
6. 本条只改分支过程纪律，不改变 docs 的最终落地形状，也不改变 dev 第一父链的读法。

## 被否方案（Alternatives）

| 方案 | 否决理由 | 翻转条件 |
| --- | --- | --- |
| 收口后绝对不 rewrite | 与“commit 描述必须正确”冲突；#22 类错误只能永久留账本或 revert | 平台提供不可变 message 修正，或外部合规明确禁止 |
| 允许内容 rewrite | 风险远高于 message：改变发布内容、破坏 tag/审计、影响部署 | 独立安全事件响应流程 + 新 ADR |
| revert 修 metadata | +1 提交、+1 PR；坏 message 还在；#22 的 5 个号就是这样来的 | 永不 |
| 保留 docs 单提交 | squash 最终仍一个 commit，分支提交数只是过程纪律；写回被迫 amend/force | 团队需要强制单提交的评审纪律（可逆） |
| 只允许 dev rewrite | main/tag 的 message 错误仍留账本；收口后无法修正 | 外部合规禁止 main/tag rewrite |

## 后果（Consequences）

- **AGENTS**：删除/改写 docs 单提交条款；把「流程冻结线」改成“收口后允许受控 message-only rewrite”；评审协议、PR 模板、`guides/review.md` 同步。具体：写回窗口（单提交 amend → 可追加）、分支 `docs/*`（恰好一个提交 → 单意图）、合并策略、纯文档例外、评审协议过渡行；L114/276 的“文档单提交”历史读法保持不动（squash 最终仍是一条）。
- **ADR-0005**：标 `deprecated`（部分条款失效）；ADR-0010 为直接取代者，但只取代 docs 单提交条款。
- **落地清单（同 PR）**：`docs/README.md` 决策线表加 ADR-0010 行；ADR-0005 `status: deprecated`；上述 AGENTS 同步面；`docs/guides/review.md` 与 PR 模板的 docs 单提交/过渡行；#22 事故 journal（事故 + 带判据条款 + 关联 PR）。
- **顺序**：`merge-integrity` proposal 以 ADR-0010 编号引用，必须在本 ADR accepted 后（或同 PR）落地；本 ADR 合入时 `status: accepted`。
- **C6 / ADR-0009**：C6 对 ADR-0009 的部分取代另行处理，本 ADR 不接管。
- **merge-integrity**：P2a 只改 message（tree 不变）；P2b 只重做同一内容；内容错误走 P3 revert/fix-forward。P2a 的平台溯源仍断，仅用于低风险元数据。
- **CI**：C6 `pr-meta` 不查 docs 提交数；attribution 逐提交校验；push CI 仍检查 squash 提交的 trailer。
- **审计**：journal 记录区间映射、受影响 tag 与批准人；旧 PR 页面仍指旧 SHA；P2b 的新 PR 页面干净；P2a 只留 subject `(#N)` 文本链。
- **风险**：main/tag rewrite 会改变 SHA/tag；clone 需要 reset；外部消费者可能已缓存；必须备份、通知、验证保护恢复。
- **安全**：敏感数据不在本 ADR 范围内；rewrite/revert 都不足以清除，走轮换 + 平台清理。
