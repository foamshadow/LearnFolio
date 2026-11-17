---
title: "t1 合并 subject 缺 PR 号与 P2b re-land：从 b42eee2 到 d071f24"
date: 2026-11-17
author: foamshadow
tags: [se-arch, tool-git, tool-ci]
related: [ADR-0010, SPEC-0001]
---

# t1 合并 subject 缺 PR 号与 P2b re-land

> agent 起草、人审定（作者键 = 审定者）。本篇记录 2026-11-17 t1 合并时 merge subject
> 缺 ` (#34)` 的事故，以及第一次 P2b（reset + re-land）实弹：旧 merge `b42eee2` 被
> reset，内容经 PR #36 重落为 `d071f24`。这是 merge-integrity proposal 毕业条件里
> “撤回演练”的真实替代，不是桌面推演。

## 事件

PR #34（t1 workspace + Nuxt 4 基线）通过 Pi 的 PR 级 `REVIEW: PASS` 后，于
2026-11-17 20:26 CST 合并。执行命令显式传了：

```bash
gh pr merge 34 --merge --subject "<PR 标题>" --body ""
```

GitHub 将 `--subject` **逐字**用作 merge commit subject，没有追加 ` (#34)`：

```text
合并 spec-0001-t1 workspace-scaffold：建立 pnpm workspace 与 Nuxt 4 应用骨架
```

正文为空、树与 parents 都正确，只有 subject 缺 PR 号。按 AGENTS 的 merge message
规则，这属于账本元数据缺陷，不是内容错误。

## 时间线（CST）

| 时间 | 事件 |
| --- | --- |
| 20:26 | #34 合并为 `b42eee2`；立即发现 subject 缺 ` (#34)` |
| 20:30–20:36 | 比较 P2a（head amend）与 P2b（reset + re-land）；P2a 会切断 PR 页面与 dev 的双向溯源，决定走 P2b |
| 20:37 | 备份 `b42eee2`；保护快照；临时放开 dev 的 force push / admin enforcement |
| 20:37–20:44 | dev reset 到 `94580a8`；恢复并核验保护 |
| 20:44 | 从同一 head `6f882e1` 开 PR #36；补 docs 提交把 C4/SPEC 的 `#34` 改为 `#36` |
| 20:47 | PR #36 CI 全绿；Pi 发 `REVIEW: PASS`（target `2c3213e`） |
| 20:49 | #36 用默认标题路径合并为 `d071f24`；subject = `… (#36)`，正文为空 |
| 20:50 | dev push CI `44086781687` success；worktree / 分支清理 |

## 成因链

1. **命令语义**：`gh pr merge --subject` 是显式值，GitHub 不对其追加 ` (#N)`；默认
   标题路径（不传 `--subject`/`--body`）才会由仓库设置生成 `标题 (#N)` 并留空正文。
2. **规则文本滞后**：merge-integrity proposal §1 的 code 命令仍是
   `gh pr merge --merge --subject "<title>"`；`docs/guides/merge.md` 已经明确写了
   “code 不传 `--subject` / `--body`”，并注明 proposal 要在 merge.sh 定稿时反向统一。
3. **证伪未传播**：2026-11-17 #35 的实测已经证伪了 proposal §1 的 code 命令，Pi 在
   #34 的 PASS 评论里也写了“不传 `--subject`”，但执行者仍按 proposal 旧文执行。
   被证伪的规则文本本身就是 hazard，不能等 merge.sh 毕业再改。

## 为什么选 P2b 而不是 P2a

P2a 只改 merge commit message，保留 PR 号且不新增评审；但改写后的 merge SHA 不属于
任何 PR 页面，#34 页面仍指向 `b42eee2`，dev 上却是另一个 SHA——平台级双向溯源断链。
P2b 多消耗一个 PR 号、多一次评审，但 #36 的 merge commit 真实落在 dev 上，硬溯源成立。
这次选择按“平台溯源 > 省号”的优先级，而不是按“改动最小”。

## P2b 执行

- **备份**：`backup/dev-b42eee2-20261117`，本地与远端都指向 `b42eee2`；
- **保护快照**：`allow_force_pushes=false`、`enforce_admins=true`、required `ci-ok`、
  reviews=0、strict=false、dismiss=true；
- **break-glass**：用完整 protection payload 的 `PUT` 临时打开
  `allow_force_pushes=true` / `enforce_admins=false`（分项 endpoint 在本次 API 上返回
  404，未采用）；
- **reset**：`--force-with-lease --force-if-includes` 把 dev 推到 `94580a8`；
- **恢复**：立即用备份 payload 恢复并逐项核验，最终六项与快照一致；
- **re-land**：PR #36 的 head 仍是原九提交 + 一条 docs 提交（C4/SPEC 的 PR 引用
  `#34` → `#36`）；CI 全绿后 PASS；
- **merge**：不传 `--subject`/`--body`，加 `--match-head-commit` 锚定 PASS target；
  落地 `d071f24`，subject 带 ` (#36)`、正文为空；
- **旧页面**：#34 仍 MERGED，评论 `Superseded by #36`；`b42eee2` 由备份分支保留。

## 结果与执行差异

- dev 最终历史：`94580a8 → d071f24`；`b42eee2` 不再在 dev，但对象仍可由
  `backup/dev-b42eee2-20261117` 与 PR #34 页面找到；
- PR #34 的 merge SHA 仍指向 `b42eee2`，与 dev 断链；这是 P2b 的预期代价，靠评论、
  备份分支与本文映射闭合；
- 其他成员的 clone 需要重新对齐到 `d071f24`；本地主树已 fast-forward，工作树已删除；
- 保护开关是人工 break-glass 操作，尚无脚本；ruleset + bypass actor 仍是待定项。

## 教训与后续

- **固定动作**：code 合并一律 `gh pr merge <N> --merge --match-head-commit <target>`，
  不传 subject/body；`--match-head-commit` 把 PASS target 钉进合并命令，PASS 后 head
  移动会直接拒绝。
- **文档同步**：本次同 PR 修正 proposal §1 的 code 命令，并在 merge guide 的手动六步
  补 `--match-head-commit`；不再等 merge.sh 毕业。
- **演练记账**：P2b 条件（备份、窗口、头部、保护恢复、旧 PR 标注、journal）全部走通；
  merge-integrity 的“撤回演练”毕业条件由本次真实事故覆盖。
- **未完成**：merge.sh / retract.sh 仍未实现；ruleset 迁移未做；其他 clone 的 reset
  通知需由团队渠道完成。
