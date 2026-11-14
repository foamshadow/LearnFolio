---
id: ADR-0005
title: "双合并策略：任务 --no-ff、文档 squash"
status: accepted
date: 2026-11-14
author: foamshadow
tags: [se-arch, tool-git]
related: [ADR-0003, ADR-0004]
supersedes: "ADR-0003"
superseded-by: ""
---

# ADR-0005：双合并策略

> 部分取代：本 ADR 只取代 ADR-0003 中"只保留 merge commit、一律 --no-ff"的**合并方式**条款；
> 分支模型、tag 规则、收口守卫等其余决策继续有效（ADR-0003 因此标 `deprecated` = 部分条款失效）。

## 背景（Context）

ADR-0003 为保留过程史与任务拓扑，规定"只留 merge commit"。运行一天后暴露两个新事实：

1. **纯文档 PR 通常只有一个提交**，merge 节点不携带过程信息，只留下"分支效果"；对照鸿蒙项目的实践，
   docs 直接落 dev（无节点）时 `--first-parent` 读法反而更清——"T 级 merge + docs 直推"。
2. **GitHub 的 PR 合并没有真正的 fast-forward**；能产生"单提交、无节点"效果的只有 squash
   （rebase 同样重写 SHA，且多提交时留下线性碎提交）。

同时，ADR-0004 已确认 merge commit 无法携带 `Assisted-by` trailer（平台生成），文档走 squash
也让来源标签回到单提交本身。

## 决策（Decision）

1. **代码任务**（feat / fix 涉码、hotfix、backport）→ 保持 `--no-ff` merge commit，ADR-0003 的决策不变。
2. **纯文档 PR** → `docs/<短名>` 分支，**恰好一个提交**，以 **squash** 合入：落地为一条普通提交，
   不产生 merge 节点。
3. **账本行**：merge 提交 = PR 标题 + ` (#N)`；squash 提交 = 该提交自身消息——文档 PR 的标题即
   `docs: …`，与落地提交主题一致。
4. **来源标签**：squash 提交必须保留原消息体（含 `Assisted-by` trailer）——squash 的标题 / 正文
   取自 PR 标题与描述，描述末尾同列 trailer。
5. **不溯及既往**：本决策生效前已合入的 docs merge 节点保留，不重写历史。
6. **方法由分支前缀编码**：`docs/*` → squash，其余 → merge；误用由评审把关，必要时由 bot 按前缀自动合并。

## 被否方案（Alternatives）

| 方案 | 否决理由 | 翻转条件 |
| --- | --- | --- |
| 全局 squash | 丢代码任务的过程史与任务节点（ADR-0003 的核心价值） | 放弃过程保留与 bisect 价值 |
| 全局 rebase merge | 与 squash 同为重写 SHA，且多提交时留下线性碎提交 | — |
| docs 直推 dev | 需关闭分支保护或开 bypass，等于放弃门禁 | 出现可按路径生效的保护机制 |
| 维持 merge-only + 批次纪律 | 只减少节点数，不改变"文档也长分支"的形状 | 文档量小到节点不构成噪音 |
| 文档 PR 也 squash 成 `合并 docs …` | 落地提交会变成没有合并语义的"合并"主题 | — |

## 后果（Consequences）

- `dev` 第一父链读法变为：**merge 节点 = 任务，普通提交 = 文档**（与鸿蒙一致），`--first-parent` 一眼分清两类。
- squash 产生新 SHA：原提交的 SSH 签名不保留，GitHub 侧签名不可依赖；作者保留，提交者变为 GitHub。
- 两个合并按钮并存：**必须按分支前缀选方法**；误点 squash 会永久丢失代码任务的过程史（不可逆）。
- 文档 PR 必须恰好一个提交；多提交先在本地整理。
- t0 的 PR 标题正则变六变体（新增 `docs: .+`），方向矩阵增 `dev ← docs/*`。
- 规则自本 ADR 起生效，不追溯；流程冻结线（Phase 0 收口后规则只走取代链）在 AGENTS 规范变更节声明。
