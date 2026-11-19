---
id: ADR-0012
title: "远端重写对齐：backup 提示、AGENTS 条款与 clone 通知的落点"
status: accepted
date: 2026-11-19
author: foamshadow
tags: [se-arch, tool-git, tool-ci]
related: [ADR-0010, ADR-0011, "docs/proposals/merge-integrity.md", "docs/journal/2026/2026-11-19-foamshadow-secret-drill.md"]
supersedes: ""
superseded-by: ""
---

# ADR-0012 远端重写对齐：backup 提示、AGENTS 条款与 clone 通知的落点

## 背景

2026-11-19 敏感数据桌面演练（journal `2026-11-19-foamshadow-secret-drill.md`）中 `retract.sh` 首次生产实弹，暴露撤回链路的最后一环缺口：dev 被重写后，**clone 持有者如何得知并完成本地对齐**。

平台事实：GitHub 不记录、不暴露"谁 clone 了仓库"，force-push 不触发任何 clone 侧通知——全量自动化通知在平台层不可能。已知成员集合（AGENTS 作者键登记表）可经 issue @mention 触达，但所有者裁定**不使用一次性 issue 作为机制**（issue 只到账号，不落 git 对象；受众靠人记忆而非工具链）。

git 事实：未对齐的 clone 无法危害远端——含已撤提交的 push 对重写后的 dev 必然 non-fast-forward 被拒（RS-2 force-block + `--force-with-lease` 是第二层）；其代价仅持有者本地困惑，且假钥演练中无真实泄露。

## 决策

clone 通知与对齐机制为三件套，全部项目内常驻：

1. **retract 输出**（操作者广播）：`retract.sh` 完成时打印 `git fetch origin && git reset --hard origin/dev` 指引（已实现，2026-11-19 生产实测）。
2. **backup 提示 commit**（被动载体）：撤回时在备份分支 tip 之上追加一个空提交（`commit-tree`，tree 不变、不动被保留的坏历史），message 载明重写事实与对齐命令。backup/* 走默认 fetch refspec，任何 clone 的 `git fetch` 都会把它带进本地对象库；生命周期与备份一致（恰好覆盖事故窗口）。**实现随下一个 `fix/infra-…` 任务落地**（scripts 改动须独立验证路径，不入 docs 分支）；落地前由组件 ①③ 承担通知职能。
3. **AGENTS「远端重写对齐」条款**（主动发现与对齐）：agent 会话遇 `git pull --ff-only` 失败 / status diverged / push 被非 fast-forward 拒绝且已知 dev 被重写时——先查 `backup/*` 对齐提示，经**人类确认**后执行 reset 对齐（前置自检：`git log origin/dev..HEAD` 为空且工作树干净）。条款文本见 AGENTS「分支与版本」合并与同步子节（随 merge-integrity 毕业 PR 落地）。

## 后果

- **流程冻结线合规**：Phase 0 收口后的规则变更以本 ADR + PR 承载；AGENTS 条款引用本 ADR，不另设无源规则。
- **演练闭项口径**：merge-integrity 的「clone 通知」以本三件套产品化为闭项依据。未发一次性 issue 为所有者裁定；公开仓库的未知 clone 不可枚举属通知义务的客观上限，其残余风险（仅本地困惑、假钥无真实泄露）由所有者接受并记录于毕业 PR 与 proposal 演进记录。
- **生效时点**：首次真实 rewrite 起 ①③ 立即生效；② 随实现任务补齐。
- **对齐操作的人类确认要求**与 ADR-0007 破坏性操作分级一致：reset 丢弃本地 dev 状态属重操作，agent 只提示、人确认。
