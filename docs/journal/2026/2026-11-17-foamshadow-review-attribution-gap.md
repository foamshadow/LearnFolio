---
title: "评审署名缺口：Pi:glm-5.3、评论层 Reviewer 与新 ADR 准备"
date: 2026-11-17
author: foamshadow
tags: [se-arch, tool-git, tool-ci]
related: [ADR-0004, ADR-0009, ADR-0011]
---

# 评审署名缺口

> agent 起草、人审定（作者键 = 审定者）。本篇记录 2026-11-17 的一个规则缺口：
> 当前 `merge-integrity` proposal 的审查来自 **Pi:glm-5.3**，但项目只有评论层的
> `Reviewer:`，没有 commit 层的 review 署名；`glm-5.3` 与 `glm-5.3-flash` 也不是同一个模型。

## 事件

`merge-integrity` proposal 的事实修订由 **Pi:glm-5.3** 审查。核对时发现：

- AGENTS 的 harness 表只有 `DSH` / `ClaudeCode` / `ZCode`，没有 `Pi`；
- model 表只有 `glm-5.3-flash`，没有 `glm-5.3`；两者是不同模型，不能混用；
- 当前规则只在评审评论写 `Reviewer: <harness>:<model>`，commit 只有 `Assisted-by`
  （作者/参与者），**没有 commit 层的 reviewer 署名**；
- 过去 #27 / #28 / #29 的 PASS 评论**缺席或署名与事实不符**（评审主要在会话内完成、未按状态机落评论）；评审协议 #28 刚毕业即连续三个 PR 未按状态机运行；决定不补历史。

## 决策

1. **当前不新增 commit 级 review 署名**，也不改 AGENTS 的 harness/model 表；只在 journal 记录。
2. **不补历史 PASS 评论**：#27 / #28 / #29 的评审在会话内完成，未落 PR 评论。
3. 当前 `merge-integrity` proposal 的 PR **不要求 review 署名**，先按 docs PR 走。
4. 新开一个 ADR 准备项，覆盖：
   - 评论层 `Reviewer` 与 commit 层 `Reviewed-by` 的边界；
   - `Pi` / `glm-5.3` 的登记（与 `glm-5.3-flash` 区分）；
   - `pr-meta`（C6）是否需要/如何校验或记录 reviewer；
   - 历史 PASS 是否补、补到什么程度。
5. 在该 ADR 落地前，`Reviewer:` 只写已登记键；未登记的 runtime 不写入正式规则。

> 修正（同日）：原决策 1 的“不新增 commit 级 review 署名”不成立——重要 commit 有提交前文件级互审；`Reviewed-by` 见 ADR-0011。

## 后续（同日，含修正）

ADR-0011 落地：登记 `Pi` / `glm-5.3`（与 `glm-5.3-flash` 区分）；状态评论角色行（BLOCKED/PASS `Reviewer`；REVIEW-FIX `Author`）补齐；#27–#29 的 PR 级缺口不回填；`pr-meta` 扩为拒绝评审状态行与 `Reviewed-by:` 行；C6 部分取代 ADR-0009。

**修正**：用户指出重要 commit 存在**提交前**的文件级互审，并非只有 PR 级。原决策 1 的“不新增 commit 级 review 署名”作废；ADR-0011 改为双轨，commit 级用 `Reviewed-by`（opt-in，提交前审完整个待提交内容；提交后再审走下一个 commit / PR）。原“只在 journal 记录、不改表”由 ADR-0011 取代。

## 关联

- `docs/proposals/merge-integrity.md`（当前 review）
- PR #27（C6）、#28（评审协议毕业）、#29（ADR-0010）
- ADR-0004（署名）、ADR-0009（CI 门禁）、ADR-0011（评审署名与 pr-meta 边界）
