---
title: "#22 合并事故：PR 描述在 PASS 后追加评审清单，squash 正文 trailer 失位"
author: foamshadow
date: 2026-11-16
tags: [se-arch, tool-git]
related: [ADR-0004, ADR-0005, ADR-0009, SPEC-0001]
---

# #22 合并事故：PR 描述在 PASS 后追加评审清单，squash 正文 trailer 失位

## 事件

2026-11-16 15:06:59 CST，PR #22（agent-collaboration 教学版）收到 `REVIEW: PASS`（target 97fcafd）。15:07:22 CST，PR 以 squash 合入 dev，落地 9885c36。随后 dev push CI（run 43821556464）的 attribution job 判红，`ci-ok (push)` 随之红。

根因不在 guide 内容，而在 squash 正文：PR 描述在 PASS 与 merge 之间（约 23 秒）被追加了一段评审清单（已从 PR 描述删除），位置在 `Assisted-by: ZCode:glm-5.3-flash` 之后。docs PR 的 squash 正文取自 PR 描述，于是落地提交的 trailer 不再是消息末尾的 trailer 块；`git interpret-trailers --parse` 解析不到，attribution job 按规则判红。

## 根因

1. **评审清单写进了 PR 描述**：review-protocol §4 与被否方案都明确“评论承载评审状态、PR 描述只放最终变更”；评审清单属于评论或 journal，不属于描述。
2. **PASS 没有冻结语义**：PR 描述不在 head SHA 内，编辑既不触发 CI，也不作废 `REVIEW: PASS`；作者侧在 PASS 后编辑，评审者没有重读。
3. **合入前没有末行检查**：评审者（DSH）在 PASS 后直接执行 squash，没有重新取一次 PR 描述确认 trailer 仍在最后一块；23 秒窗口内的变更未被发现。
4. **squash 通路的边界**：ADR-0005 规定描述即 squash 正文；`git interpret-trailers` 只解析末尾 trailer 块，trailer 后追加任何段落都会使其失位。此前的规则只说了“末尾列 trailer”，没有说“trailer 后不得再追加内容”。

## 影响

- #22 合入后 dev push run 红（attribution / ci-ok (push)）；guide 内容正确，无代码或部署影响。
- 9885c36 的提交正文含评审清单，且 trailer 不在末尾；按 AGENTS 不重写已合入历史，保留为执行差异；当前内容已由 #23 回滚、#24 重做。
- 这是 #13 / #15 同类问题的又一次形态：上次是评审清单直接进 squash 正文，这次是 PASS 后追加；规则已有，缺的是“PASS 冻结 + 合入前末行检查”的执行机制。

## 处置

- **删除描述中的评审清单**：PR #22 描述里的该段已删除；已合入的 9885c36 提交正文无法直接编辑，保留在历史中（不重写）。
- **回滚 + 重做**：按人类决定，#23（d1729b7）回滚 9885c36；#24（5ab011d）用干净描述与提交正文重做 guide。两次合入后 dev push attribution 均通过，最新 push 绿；旧 run 保留为事故证据。
- **规则补丁**：`docs/proposals/review-protocol.md` 增“PR 描述冻结”与“合入前末行检查”：PASS 后标题/描述视为冻结，任何编辑作废 PASS；评审者在合并前必须重读描述，最后一行必须是 `Assisted-by` trailer，trailer 后不得追加段落。
- **CI 候选**：`docs/proposals/ci-gate-optimizations.md` 增 C6 `pr-meta`——校验 PR 描述最后一行 trailer、正文无评审清单段、docs PR 恰好一个提交；作为 C6 的触发事故登记。
- **流程**：PASS 与 merge 应尽量由同一人在同一时刻完成；作者在 PASS 后不再编辑描述；需要补记录时走评论或 journal。

## 复盘

- `REVIEW: PASS` 是冻结线，不是建议：commit、PR 标题、PR 描述都是评审对象，任何一项变更都应作废 PASS。
- “PR 描述只放最终态”已有规则，但规则没有执行点；这次补的是执行点，不是新原则。
- `git interpret-trailers` 的边界要写进教材：trailer 是末尾块，不是“正文里出现过”。
- 评审者也要为“合并前最后一眼”负责：CI 绿只证明 head SHA，不证明描述没变。

## 关联

- PR #22 / #23 / #24；9885c36（回滚）、d1729b7（revert merge）、5ab011d（重做 squash）；dev push run 43821556464
- review-protocol §4（评审状态只放评论、描述只放变更）、被否方案（评审清单不进描述）
- ADR-0004（署名 trailer）、ADR-0005（squash 正文取自描述）、ADR-0009（attribution job）
