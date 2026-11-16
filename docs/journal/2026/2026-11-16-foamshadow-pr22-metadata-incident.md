---
title: "#22 元数据事故：PASS 后描述编辑、5 个 PR 号与快照合并的由来"
date: 2026-11-16
author: foamshadow
tags: [se-arch, tool-git, tool-ci]
related: [ADR-0004, ADR-0009, ADR-0010]
---

# #22 元数据事故

> agent 起草、人审定（作者键 = 审定者）。本篇记录 2026-11-16 的 #22 事故及其修复链：
> 一条已 PASS 的 docs PR 在合并前被追加评审清单，squash 正文的 `Assisted-by` trailer
> 失位，dev push 的 attribution 判红；随后 revert / redo / journal 消耗了 5 个 PR 号，
> 最终 force reset + #26 re-land 才恢复历史。事故直接催生 C6 `pr-meta`、评审协议的
> PASS 冻结/hash 规则，以及 ADR-0010 的 message-only rewrite。

## 事件

#22 是 `docs/guides/agent-collaboration.md` 的 docs PR。评审完成、PASS 之后，PR 描述被追加
“评审清单”段，位置在 `Assisted-by` trailer 之后。docs PR 以 squash 合入，squash 正文取自
PR 描述，于是落地提交 `9885c36` 的 trailer 不在末尾；dev push 的 attribution 校验失败。

PR head 的 CI 是绿的：attribution 检查的是 PR 分支提交，而未来 squash 提交的正文在合并时
才生成——PR CI 看不到它。这是“PR 绿 ≠ 落地正文绿”的典型缺口。

## 时间线

| 时间（CST） | 事件 |
| --- | --- |
| 11-16 | #22 评审两轮（B1–B3，第二轮 B4）后 PASS；target/标题/描述当时一致 |
| 11-16 | PASS 后描述追加评审清单；squash 合入 `9885c36`；dev push attribution 红 |
| 11-16 | #23 用 revert 回滚，+1 提交/+1 号；坏 message 仍在历史 |
| 11-16 | #24 重新落内容，+1 号；#25 追加 journal，+1 号；历史出现 revert/redo 对 |
| 11-16 | 人类决定不用 revert 链；force reset dev 回 `1d622c3`，保护临时放行后恢复 |
| 11-16 | #26 用新 PR re-land，得到干净的 `56d750d`；#22–#25 成为孤儿 PR 页面 |
| 11-17 | C6 `pr-meta`（PR #27）、评审协议毕业（PR #28）、ADR-0010 定稿 |

## 决策

### 元数据错误不 revert

revert 只回滚当前树，坏 message 仍在历史；它还为“修一条 message”增加提交和 PR 号。
#22 的 5 个号就是这条路径的代价。元数据修复应优先 amend / re-land，或接受 + journal。

### P2a 与 P2b

- P2a：原地 amend，0 新号；但 PR 页面仍指旧 SHA，新 commit 不是任何 PR 的 merge commit，
  平台溯源断；只适合低风险元数据。
- P2b：force reset + re-land，+1 号 + clone reset；新 commit 是真实 PR 的 merge commit，
  平台溯源干净；默认选它。
- 内容错误才走 P3 revert；敏感数据走独立事件响应（轮换 + rewrite + 平台清理），revert 不够。

### PASS 冻结与快照

PASS 必须带 `target`、`body-sha256`、末行 `Reviewer`；PASS 后标题/描述冻结，任何编辑作废
PASS，必须重新 PASS 并重新快照。合并用 PASS 时的快照生成 squash 正文，不读实时描述。
docs 单提交约束随后由 ADR-0010 撤销；squash 最终仍是一条提交。

### C6 与 ADR-0010

- C6 `pr-meta`：PR 描述末行 trailer、正文无评审段；并入 `ci-ok`，push 下 skipped。
  它是 PR 时的 backstop，挡不住 check 之后的描述编辑；硬保证仍是快照。
- ADR-0010：允许 dev/main/tag 的 message-only rewrite（tree 不变，人类批准、备份、journal、
  保护恢复、tag 重打）；内容 rewrite 仍禁止。收口后不再是绝对冻结线。

## 执行差异

- #22 的旧 PR 页面、旧 squash `9885c36` 仍可访问；rewrite 不删除旧对象，也不清理 fork/CI 日志。
- #22–#25 占用的 PR 号不可回收；#26 是干净 re-land，旧页面保留为失败尝试的审计页。
- 本次未重写 #22 本身，只重写了 dev 指向；旧页面与新历史并存，靠 journal 与本篇映射。
