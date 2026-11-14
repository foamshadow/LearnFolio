---
id: ADR-0004
title: "agent 署名：提交级 Assisted-by trailer（opt-out）"
status: accepted
date: 2026-11-14
author: foamshadow
tags: [se-arch, tool-git]
related: [ADR-0003]
supersedes: ""
superseded-by: ""
---

# ADR-0004：agent 署名（Assisted-by trailer）

> 补记说明：决策定于 2026-11-14（建仓首提交缺署名的当日），本篇在规则落地 PR 中撰写；提案过程见
> `proposals/agent-attribution`（已毕业，正文为指针）。

## 背景（Context）

项目把 AI agent 当作主要实现者，但提交只记录人类 author：时间线页无法按 agent 维度切分，出问题时
"这是 agent 干的还是人写的"无从查证；规则缺失则错误不会被发现，只会被继承。建仓首提交（20 件）即因此
缺署名，不得不撤回首版重做——这是本决策的直接触发事故。

约束：5 人团队、人人多 harness × 多 model；agent 无法可靠自知精确模型版本；GitHub 没有 agent 账号；
责任不能转移给 agent，来源标签只能做加法。

## 决策（Decision）

**每条提交携带 `Assisted-by: <harness>:<model>` trailer；纯人类提交写 `Assisted-by: none`。**

- opt-out：缺席即违规，CI 可校验存在性（opt-in 下只能校验格式，漏写不可检测）
- `author` / `committer` 恒为人类（审定者与执行者）；标签只记来源，不改变责任归属
- 身份由 agent 自述并配置查证（harness model 配置 > 系统提示 model id > 自省命令），精确不到版本粒度即问人
- 强制：t3 `commit-msg` 钩子 fail-closed（不代填）+ t0 CI 逐提交正则（唯一能挡 `--no-verify` 的一层）
- **merge commit 不记**：平台生成的合并提交不注入内容（与整理执行者同理），审计与 CI 均以非 merge 提交为范围
- harness / model 键闭合登记于 AGENTS 提交纪律节，新值 = 加一行 + PR

## 被否方案（Alternatives）

| 方案 | 否决理由 | 翻转条件 |
| --- | --- | --- |
| opt-in（缺席 = 无 agent） | CI 无法校验存在性，漏写不可检测——首提交事故的直接成因 | — |
| `Co-authored-by:` | GitHub 会尝试关联账号，agent 无账号；语义上把 agent 抬成共同作者，与"agent 起草、人审定"不符 | agent 获得账号体系 |
| author = agent、committer = human | blame / PR 归属指向无账号身份；与 journal"作者键 = 审定者"冲突 | — |
| 只在 PR 描述标注 | 不进 git 历史；分支删除、仓库迁移即丢失 | — |
| 自由文本（"本提交由 AI 辅助"） | 不可机械聚合，时间线页无法按 agent 维度切分 | — |
| 引入 DCO / `Signed-off-by` | 与本决策正交；AGPL 已承载版权声明，再加只增仪式成本 | 需要外部贡献者签署权利声明 |
| 环境变量注入（`LF_HARNESS` / `LF_MODEL`） | 多 harness × 多 model 下 shell 全局变量跨工具链共享、无法跟踪当前会话身份，必错配；配置负担随模型数线性增长 | harness 原生把会话身份注入环境 |
| 让 merge commit 也带 trailer（`merge_commit_message` 设为 PR 正文） | 平台无法直接写 trailer；PR 描述整段灌入账本正文，噪音大于收益 | GitHub 支持自定义 merge message 且可机械校验 |
| 文档层署名（frontmatter 记起草 agent） | 文档质量难以自动核验，溯源价值低于提交层；增加维护面 | 时间线页需要按文档维度切分 |

## 后果（Consequences）

- 每条提交多一行 trailer；纯人类提交需要显式写 `none`（纪律成本，换可判定性）
- 钩子 fail-closed：缺 trailer 时提交中止，agent 必须按信源清单查证后补写；`--no-verify` 可绕过，由 CI 兜底
- 来源是声明非证明：可信度来自查证纪律与评审抽查，不得用于归责或能力认定
- 时间线页可按 trailer 聚合，且分支删除不丢（数据在提交里，不在 PR 里）
- 键表成为规范的一部分：新增 harness / model 需 PR，换取闭合可校验
- merge commit 不携带 trailer（平台生成、不引入内容）；审计查询用 `git log --no-merges --grep='^Assisted-by:'`
