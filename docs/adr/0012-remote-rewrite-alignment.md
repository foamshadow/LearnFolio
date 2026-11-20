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

git 事实：未对齐的 clone 无法危害**远端完整性**——含已撤提交的 push 对重写后的 dev 必然 non-fast-forward 被拒（RS-2 force-block + `--force-with-lease` 是第二层）。但对**持有者本地**的代价随数据敏感度分级：真实密钥场景下，未通知 clone **持续持有明文**（数据暴露风险，本地副本不受平台清理影响，且可随新分支/tag 扩散）；假钥演练无此暴露。

## 决策

clone 通知与对齐机制为三件套，全部项目内常驻：

1. **retract 输出**（操作者广播）：`retract.sh` 完成时打印 `git fetch origin && git reset --hard origin/dev` 指引（已实现，2026-11-19 生产实测）。
2. **backup 提示 commit**（被动载体）：撤回时在备份分支 tip 之上追加一个空提交（`commit-tree`，tree 不变、不动被保留的坏历史），message 载明重写事实与对齐命令；提示**仅在重写全链成功后发布**，发布组件全失败路径非致命（WARNING 续跑）。分发面 = **默认 refspec 配置下的 clone**（`--single-branch` / 自定义 refspec 不收）；trailer 经 `RETRACT_ASSISTED_BY` 环境变量声明（AGENTS 同款正则，校验先于任何变更）。生命周期与备份一致（恰好覆盖事故窗口）。**已实现**（PR #56，`fix/infra-retract-hint-commit`，fixture `task test:retract` 六场景）。
3. **AGENTS「远端重写对齐」条款**（主动发现与对齐）：agent 会话遇 `git pull --ff-only` 失败 / status diverged / push 被非 fast-forward 拒绝且已知 dev 被重写时——先查 `backup/*` 对齐提示，经**人类确认**后执行 reset 对齐（前置自检：`git log origin/dev..HEAD` 为空且工作树干净）。条款文本见 AGENTS「分支与版本」合并与同步子节（随 merge-integrity 毕业 PR 落地）。

## 被否方案（Alternatives）

| 方案 | 否决理由 | 翻转条件 |
| --- | --- | --- |
| 一次性 issue @ 已知成员 | 只到 GitHub 账号、不落 git 对象，受众靠人记忆而非工具链 | 平台暴露 clone 集合 API，或所有者改判账号触达优先 |
| 仅 AGENTS 条款、无备份载体 | 组件 ③ 只覆盖 agent 会话主动发现，非 agent 既有 clone 无触达点 | 出现覆盖全量 clone 的分发面 |
| 全量自动化 clone 通知 | GitHub 不记录、不暴露 clone 集合（公开仓库尤甚），平台层不可能 | 平台提供 clone 通知机制 |

## 后果

- **流程冻结线合规**：Phase 0 收口后的规则变更以本 ADR + PR 承载；AGENTS 条款引用本 ADR，不另设无源规则。
- **演练闭项口径**：merge-integrity 的「clone 通知」以本三件套产品化为闭项依据。未发一次性 issue 为所有者裁定；公开仓库的未知 clone 不可枚举属通知义务的客观上限，其残余风险——未知/未通知 clone **可能保留已撤数据**（真实密钥场景 = 数据暴露风险）——由所有者接受并记录于毕业 PR 与 proposal 演进记录；真实事件中由平台清理 + 直接联系已知成员兜底。
- **备份保留窗口**：备份分支（含提示 commit）保留至事件闭项——真实事件口径 = 平台清理完成且已知成员对齐确认；清理由操作者执行并记 journal（2026-11-19 演练先例：演练结束即删）。
- **生效时点**：#56 合并（dev 落地）起三件套全量生效；首次真实 rewrite 即首次行使。
- **对齐操作的人类确认要求**与 ADR-0007 破坏性操作分级一致：reset 丢弃本地 dev 状态属重操作，agent 只提示、人确认。
