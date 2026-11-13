---
id: ADR-0002
title: "许可证采用 AGPL-3.0"
status: accepted
date: 2026-11-12
author: foamshadow
tags: [se-arch]
related: [ADR-0001]
---

# ADR-0002：许可证采用 AGPL-3.0

> 补记说明：决策于策划期 2026-11-11（由 MIT 改判），本篇为沉淀归档。

## 背景（Context）

项目包含"后继开源"诉求：网站上线运行后，他人（含我们自己后续接手者）对代码的修改必须继续开源。同时代码与文字内容（learning 笔记、文章）需要区分授权。

## 决策（Decision）

全部代码采用 GNU Affero General Public License v3.0（AGPL-3.0）。文字内容可另行选择 CC 系列授权，与代码区分。

## 被否方案（Alternatives）

| 方案 | 否决理由 | 翻转条件 |
| --- | --- | --- |
| MIT | 宽松许可无 copyleft 义务，无法实现后继开源（那是 GPL 系特征，MIT 没有） | 放弃后继开源诉求 |
| Apache-2.0 | 同 MIT 宽松无 copyleft；专利授权条款与本题无关 | 同上 |
| GPL-3.0 | 有 copyleft 但存在 SaaS 漏洞：修改后仅部署为网络服务、不分发二进制即不触发开源义务 | 程序仅以分发形态交付、永不做网络服务 |

## 后果（Consequences）

- "网络交互"同样触发开源义务——对网站项目是必需特性，AGPL 与 GPL 的本质差异所在
- 免责保留：官方文本第 15/16 节（Disclaimer of Warranty / Limitation of Liability），效力与 MIT 免责等同
- 再授权表述（2026-11-13 收窄）：FoamShadow **就其自有版权部分**不受 AGPL 约束、可自由再授权；其余成员与外部贡献者的权利保留——**整仓**商业双轨需贡献者协议（CLA / 逐人授权确认）或各权利人同意，贡献者权利策略于 Phase 3 前再议
- 第三方依赖引入需查许可证兼容性：MIT / Apache / BSD 可引入；GPL 系需评估传染；禁止引入无许可证代码——**执行机制：新增依赖的 PR 描述必须声明其许可证**（PR 模板含声明栏）
