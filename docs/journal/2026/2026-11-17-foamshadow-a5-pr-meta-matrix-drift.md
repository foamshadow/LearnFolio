---
title: "A5 矩阵的 pr-meta 执行差异"
date: 2026-11-17
author: foamshadow
tags: [tool-ci, se-arch]
related: [SPEC-0001, ADR-0009, ADR-0011]
---

# A5 矩阵的 pr-meta 执行差异

> agent 起草、人审定（作者键 = 审定者）。本篇记录 2026-11-17 发现的一笔门禁文档执行差异。

## 事件

C6 `pr-meta` 于 #27 落地并并入 `ci-ok`，但 `SPEC-0001-A5` 的结果矩阵、push 跳过集合与 `needs` 仍停留在 changes / title / attribution 三 job 版本；`aggregate.sh` 的实际矩阵已含 `pr-meta`。差异自 #27 起存在，直到 `fix/ci-review-attribution` PR 修正。

## 处理

- 本 PR 同步 A5 的 PR / push 矩阵与 `needs`，并在 `SPEC-0001` 尾部追加变更记录。
- 不追溯改写 #27 的合并记录；A5 按既有“就地改 + 变更记录”先例处理，验收编号不变。
- 教训：门禁实现（`ci.yml` / `aggregate.sh` / SPEC-A5）必须同 PR 对表；C6 落地时漏了 A5 文本，后续 PR 补记。
