---
title: "agent 确认链：破坏性操作的分级外部确认"
author: foamshadow
date: 2026-11-13
status: draft
tags: [se-arch]
related: [ADR-0003]
adopted-as: ""
---

# agent 确认链（proposal）

## 背景

项目定位 agent 全栈实践，但 ADR-0003 Phase 0 将破坏性操作（rebase 整理 / force push / tag / 收口 / revert -m）归属人类——与定位冲突且阻塞自治。破坏性操作的本质约束不是"人类才能做"，而是：不可逆 + 判断题 → 需要独立于执行者的确认。确认来源可以是人、责任链上层 agent（OpenRig delegate 关系）或多 harness 交叉审核。本机三 runtime（Claude Code / ZCode / DSH）天然构成异源审核基础。

## 提议

- 分级确认链：L0 agent 自主（commit、push 非 force）；L1 上一层 agent 确认（rebase -i 整理门、force push、git revert -m）；L2 ≥2 个独立确认来源（打 tag、dev→main 收口）；L3 spec 评审归人类核心成员
- 独立性定义写死：独立来源 = 异 harness / 异模型家族 / 人类；同源自审不算（防回声室）
- 人类角色 = 规则制定者 + 链顶确认者（不要求在线）
- 确认留痕进 PR 描述（确认者、harness、意见）——审计链即账本
- 载体渐进：OpenRig 未引入期人类充任 L1/L2（流程同构只换载体）

## 毕业条件

- OpenRig 引入（Phase 1 评估，本提案为其首个真实用例）
- Phase 1 收口作为首次全链 L2 演练通过（≥2 独立来源确认，留痕可审计）
- 演练复盘无致命缺陷 → 提交 review → 毕业为新 ADR（supersedes ADR-0003 的操作归属条款；本文件正文替换为指向新 ADR 的指针——防双真源，见 docs/README.md 毕业制）

## 被否的替代设计

- 完全人类审批（现状）：与定位冲突，人类成自治瓶颈
- 完全无确认：破坏性操作不可逆，agent 单点误判无对冲
- 全部最高智力模型终审：成本失衡；分级才是授权体系
- 同模型多实例互审：同源共享盲点，退化为回声室

## 演进记录

- 2026-11-13 由 ADR-0004 草案降级为 proposal（零次演练，属想法层，不冒充决策）
