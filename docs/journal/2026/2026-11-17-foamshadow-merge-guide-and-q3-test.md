---
title: "merge guide 落地与开放问题 3 实测"
date: 2026-11-17
author: foamshadow
tags: [tool-git, tool-ci, se-arch]
related: [ADR-0010, ADR-0011, SPEC-0001]
---

# merge guide 落地与开放问题 3 实测

> agent 起草、人审定（作者键 = 审定者）。本篇记录 `docs/guides/merge.md` 首版落地的完整链路、快照合并首次手动应用，与 merge-integrity 开放问题 3 的实测结案。

## 事件

`merge-integrity` proposal 的毕业产物 `docs/guides/merge.md`（合并讲解指南，187 行）由 ZCode:glm-5.3-flash 起草，经 PR #33 落地 dev（squash，`965a9ce`）。这条链路上有三个"第一次"：

1. **全仓库首条真实 `Reviewed-by`**：commit `a04c2e7` 提交前由 Pi:glm-5.3 完成整内容互审——一轮 BLOCKED（B1 号数事实错误 + N1–N4），REVIEW-FIX 后 PASS，PASS 以文件哈希锚定（`sha256 = fd2b7aa2…`），commit 从该字节状态原样创建；trailer 双轨齐备（`Assisted-by: ZCode:glm-5.3-flash` / `Reviewed-by: Pi:glm-5.3`）。
2. **快照合并首次手动应用**：PR 级两轮状态机闭环（一轮 BLOCKED 仅 N1 描述缺模板三节，补节复跑 CI 后 PASS），PASS 带 `target` / `body-sha256`；合并前校验 `sha256(title + "\n" + body)` 与 PASS 一致，`gh pr merge --squash --subject "<标题> (#33)" --body-file 快照` 执行。
3. **开放问题 3 实测结案**：落地 subject 的手写 ` (#33)` 被 GitHub **逐字落地、无重复追加**；落地 body 与快照文件 `diff` 逐字节一致；dev push CI 一次全绿——0 补救提交、0 额外 PR 号。

## 处理与教训

- ` (#N)` 行为结案：proposal §1 的 docs 命令（显式 subject）保持现状正确；guide 的"已决 / 未决"分层与现状速览同批更新为已结案表述。
- **顺带证伪 proposal §1 的 code 命令**：显式 `--subject "<标题>"` 因平台不追加会丢 ` (#N)`（文本级溯源），而 guide 的 code 路径（不传 subject，走 settings"Default to PR title"默认标题）被证实为正确侧。当初 guide 评审 N1 的"偏离声明"从权宜判断升级为实测结论——merge.sh 定稿时按 guide 路径反向统一 proposal。
- **实操坑**：`gh pr view --jq .body` 经命令替换会剥掉尾部换行，`sha256(title + "\n" + body)` 必须取**含尾部换行**的变体才与评审者计算的哈希一致；快照 body 文件同理需补回该换行。此坑已随 guide 手动六步的实践沉淀。
- 快照合并的时序闭环成立：PASS 冻结（描述补节发生在 PASS 前）→ 合并读快照 → 落地与快照零偏差。#22 的故障模式（PASS 后描述变更污染落地正文）在本次流程中结构性不可复现。

## 关联

- PR #33（落地 `965a9ce`）；`docs/guides/merge.md`；`proposals/merge-integrity.md`（演进记录同批写回）
- ADR-0011（`Reviewed-by` 双轨首用）、ADR-0010（docs squash 单提交撤销后的首例多节描述落地）
- journal 2026-11-16 `pr22-metadata-incident`（故障链源头，本次为其修复方案的首次实战验证）
