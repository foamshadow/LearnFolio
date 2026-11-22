---
title: "herdr-collaboration 起草：停点 #1 补触发与评审编排首演"
date: 2026-11-22
author: foamshadow
tags: [se-arch, se-review, tool-herdr]
related: [docs/proposals/herdr-collaboration.md, docs/proposals/task-lifecycle-gates.md, PR 65]
---

# herdr-collaboration 起草任务

> agent 起草、人审定（作者键 = 审定者）。本篇记录 herdr 多 agent 协作评审编排
> proposal（PR #65）起草任务的完整过程，重点是两处执行差异（停点 #1 漏触发、
> docs 提交确认与提交告知的心智混淆）与 task-lifecycle-gates 停点记账的第二次
> 实践（首演见 2026-11-20-foamshadow-task-lifecycle-gates-first-run.md）。

## 事件

同一连续对话内完成：herdr 评审编排设计（互传形态三选一 → 用户定"commit 直达 /
PR 评论+提醒"分级 → 逐项定稿：DSH opt-in 因按量付费、池化 compact 轮换、检测
时机后置）→ proposal 落盘 → **用户质询"当前我们的操作没有按照 task-lifecycle-gates
吗"暴露停点 #1 漏触发** → 补申请三项配置 → 用户再问"commit review 呢"，opt-in
增量显式提议后用户选不加（docs 载体豁免维持）→ push 遇代理节点 TLS 故障阻塞，
用户切换节点后恢复 → PR #65 自动创建（双授权齐全）→ pr-review 外部 agent 首演
（herdr 编排第一次实弹：rv 席位新建 → 指派 → 载荷含回传地址 → 评论+提醒往返）。

## 停点记账（task-lifecycle-gates 停点表逐项）

| 停点 | 本次行为 | 备注 |
| --- | --- | --- |
| #1 三项配置申请 | **漏触发**：切分支、写文件后才补申请（auto-commit ✓ / auto-push ✓ / review=外部 agent，AskUserQuestion） | 执行差异——评审编排提案的任务没走自己的配置 |
| #2 docs 提交确认 | 清单两轮展示后，以"opt-in commit review 加不加"的用户选择计为链批准 | 判定依据：选项选择 = 对含提交链路的批准动作 |
| #3 整理门 | docs 载体豁免（squash） | 跳过 |
| #4 dev-review | docs 载体豁免（tlg §5：trailer 随 squash 丢失，评审记录走 PR/journal）；opt-in 增量用户选不加 | 毕业条件①（commit 直达往返）留给首个代码任务 |
| #7 PR 创建 | 自动（双授权齐全）→ #65 | |
| #8 pr-review | 外部 agent 档——herdr 编排首演（席位寻址、互传分级） | 结果由 PR 评审评论承载（本篇写作时未回） |
| #9 合并授权 | 人工（未到） | |

## 教训

1. **提案者没吃自己的流程**：起草评审编排 proposal 的任务本身漏了停点 #1——规则
   在起草时清晰、执行时失效。说明"任务启动三项配置"缺机制化触发，AGENTS.md 一行
   指针的提醒密度不足以在任务启动时点唤醒；tlg 毕业落点设计要考虑启动时点的强制
   载体（如任务启动 checklist），而非依赖 agent 回忆。
2. **docs 提交确认（#2）与 ADR-0007 提交告知心智同构、地位不同**：两者形式都是
   "文件清单 + 关键点"，但 #2 是不随 auto-commit 豁免的独立硬停点。执行时须在
   消息里显式标停点名（"停在 #2"），靠格式相似推断流程状态会漏。
3. **互传协议设计要双向走查**：载荷初版漏了回传地址字段——评审者回传需要目标
   地址，这是互传的反方向。协议字段设计时正反两个方向各走查一遍（请求方向：
   评审者需要什么；回传方向：作者地址在哪）。
4. **proposal 字面执行暴露初始化空白**：可指派判据（rv 前缀 + idle + 无任务后缀）
   对存量无名 pi pane 不命中，按字面走新建路径（本次为有意选择，攒毕业条件③
   样本）；"存量 pane 转正为席位"是 proposal 未覆盖的初始化场景，记为演进候选。
5. **审查记录表不得预置未发生轮次**（Q1）：首版表写"待评审回传后核对本节"造成
   自我引用——表所在提交先于评审存在，结果行无法在该提交内闭合，PASS 后补填
   又会作废 PASS。正确口径：表只记已发生的审查（边界 = push），PASS 后结论由
   评论承载；同时首版缺版本列（ADR-0013 模板五列未对齐）——首用前对照模板
   逐列核验应成为 journal 审查记录表的固定动作。

## 复述面判定（ADR-0013 清单 1 第 2 项）

判定 = **无需更新**（2026-11-22 grep 实核）：docs/guides/ 全目录无 herdr / rv /
席位 / HERDR 相关复述（review.md 与 agent-collaboration.md 均未触及评审者寻址与
互传层），AGENTS.md 评审协议节的 herdr 编排提醒行为唯一复述面、随本 PR 落地，
无静默过期。

## 审查记录

> 口径（Q1 闭合）：按 ADR-0013，journal 封账边界 = 最后一次 push，评审 PASS 属
> 边界外、结论由 PR 评论承载。本表只记**已 push 时点已发生的审查**，不预置未
> 发生轮次（round 2 及其后的结论均在评论层，不入本表）。

| 轮次 | 版本 | 审查者 | 层级 | 结果 |
| --- | --- | --- | --- | --- |
| 1 | `1ef947b` | Pi:glm-5.3（herdr 编排首演） | PR #65 全量 | REVIEW: PASS（0B+4N+1Q），快照核验通过（target = head，body-sha256 重算一致）；处置①——N1/N3 本 proposal、N2/N4/Q1 本 journal，修复后 round 2 缩范围重审（结论见 PR 评论） |
