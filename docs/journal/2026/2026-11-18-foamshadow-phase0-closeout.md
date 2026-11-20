---
title: "Phase 0 收口：v0.1.0 的指定依据与检查单实测"
date: 2026-11-18
author: foamshadow
tags: [se-arch, tool-git]
related: [SPEC-0001, ADR-0003]
---

# Phase 0 收口：版本号 Y 的指定与发布检查单预案

> agent 起草、人审定（作者键 = 审定者）。本篇关联收口前置 PR。

## Y 的显式指定

**v0.1.0**。依据 = SPEC-0001 版本节约定「Phase 0 → v0.1.0」：X = 0
（开发期，首次公开上线才置 1.0.0），Y 由收口显式指定（本篇即记录），
Z 无 hotfix 消耗。Phase 1 首次公开上线将置 **v1.0.0**——其 X 由 0 → 1
是定义性跃迁（"首次公开稳定"），并非"出现不兼容变更"语义（AGENTS
版本节原文两分，勿混）。

## 发布检查单实测（收口前完成项）

- 机械守卫：`git diff --quiet origin/dev...origin/main` **为空**——main 仅
  first commit（4a702e7），Phase 0 无 hotfix，三点 diff 预期内干净。
- onboarding 完备性自证（第二成员模拟）：干净 clone `origin/dev`
  （840d471）→ `task setup` 26s → `task ci` 全绿 8s → `cp .env.example .env`
  → `task db:up` 转 healthy → `task db:down` 干净收尾。本机经 go-task
  3.54.0 等价二进制执行（Arch 包二进制名差异，软链指引已随 onboarding
  入库）；严格的"真实第二成员"验收留待首位外部 clone 者，届时差异按
  执行差异补记。
- A5 实测④（同 SHA 双 run 的 required 归属）：观察窗口 = 收口 PR 本身
  （dev head 同时触发 push 与 PR 两侧 run），结果随收口执行补记并回填
  SPEC 变更记录。

## 收口执行序列（guide 五步，顺序敏感）

1. **收口前置 PR**（本批）：A1–A10 全勾 + status → done；README 预写收口
   基线；本 journal（Y 指定 v0.1.0）。
2. **dev→main 收口 PR**：评审对象 = 发布检查单；标题 `合并 Phase 0 收口：
   v0.1.0`（**全角冒号**，title job 正则字面匹配）；A5 实测④在同 SHA 双 run
   上观察，结果**回填 SPEC 变更记录**；--no-ff、message 不手改。
3. **打收口 tag**（人类执行）：annotated 打 `origin/main`，message
   `v0.1.0 — Phase 0 收口：…（覆盖 SPEC-0001）`，显式 `git push origin v0.1.0`。
4. **dev 不追平 main**（分叉是常态，ff 会毁 dev 第一父链的任务账本读法）。
5. **版本号语义已定**（见上节：Y = 1 即 v0.1.0；Phase 1 → v1.0.0，X 跃迁是
   定义性而非不兼容语义）——此步在收口前完成，故列于账面。

## 收尾补记（2026-11-20）

- 上线步骤 3 完成回填：v0.1.0 annotated tag 已推送——tag object `7330e57`
  → deref `03aeab5`（= 收口 merge commit = `origin/main` tip），message 首行
  `v0.1.0 — Phase 0 收口：Phase 0 交付仓库骨架与工程化地基（覆盖 SPEC-0001）`
  与预案一致。已合入的步骤 3 行不改写，本节为账本补记。
