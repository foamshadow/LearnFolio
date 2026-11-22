---
title: "docs-writeback 首演：对账修正、proposal 三 PR 链与规则落地"
date: 2026-11-22
author: foamshadow
tags: [se-arch, se-review, tool-git]
related: [docs/proposals/docs-writeback.md, ADR-0013, PR 62, PR 63]
---

# docs-writeback 首演

> agent 起草、人审定（作者键 = 审定者）。本篇记录 docs-writeback proposal 从
> C4 漂移发现到规则落地的完整事件链（PR #62 对账修正 → #63 proposal 起草 →
> 毕业批），以及清单 1 机制的首次自我适用。

## 事件

ci-gate C4 漂移（#36/#40 落地后 `guides/ci-gate.md` filters 复述静默过期）
暴露"文档写回规则散落、收口无检查项"的系统性问题。同一连续对话内完成：漂移
根因分类 → 触发器散点盘点 → docs-writeback proposal 设计（与作者逐点对拍：
二值判定取代尾随通道、learning 成员自主例外、清单 7→5 精简、分组转正）→
PR #62 对账修正落地 → #63 起草（Pi 两轮：BLOCKED r1 → PASS r2）→ 毕业批
（ADR-0013 + AGENTS「文档写回」节 + 模板×2 + README 决策线行 + guides×2 +
#60 注记）。

## 停点记账（task-lifecycle-gates 流程逐项）

| 停点 | 本次行为 | 备注 |
| --- | --- | --- |
| 三项配置 | auto-commit ✓ / auto-push ✓ / review=Pi:glm-5.3 | AskUserQuestion 一次申请 |
| docs 提交确认 | 文件清单 + 关键点随提交告知（设计决策全程作者对拍） | ADR-0007 D5 |
| PR 创建 | #62 / #63 自动创建（双授权齐全） | |
| pr-review | #62 PASS r1（24min）；#63 BLOCKED r1（3B+4N，9min）→ PASS r2（缩范围，2min） | Pi 首次 BLOCKED→FIX→PASS 全循环 |
| 合并请求 | #62 人工授权（`task merge` 被权限分类器拦截一次后由人执行）；#63 明确授权后 agent 执行 | 授权措辞须字面明确 |
| 合并落地 | #62 → `e6dca55`；#63 → `6eb3597`（快照核验均通过） | |

## 教训

1. **凭记忆引用 = 复述漂移的写作侧实例**：#63 r1 B1——矩阵行轴把
   task-lifecycle-gates 流程编号记岔一格（③整理门/⑥push 误写）、造出"⑨
   合并落地"伪停点。proposal 自己定义的"复述必须核对真源"恰恰被起草者自己
   违反——写作侧的对账纪律（引用编号前开原文核对）与阅读侧同样必要。
2. **设计文档的行轴引用须逐项回开原文**：tlg 停点表 #1–#10 与流程步骤
   ①–⑩ 是两套编号（其 :84 自己注明不一一对应）——引用任何文档的编号体系前
   先确认它内部有几套编号。
3. **PASS 冻结与写入时点的冲突要在设计时排查**：B3——"合并授权时写入自查
   区"与"PASS 后描述冻结"正面冲突；预先性记录原则（窗口内维护、停点只核验）
   是唯一自洽解。

## 审查记录

| 轮 | 版本 | 审查者 | 层级 | 结果 |
| --- | --- | --- | --- | --- |
| #62 初稿 | `159d3e4` | Pi:glm-5.3 | PR 级 | PASS r1（2 条非阻塞 note：filters 侧别、"保留"措辞） |
| #63 初稿 | `e692edb` | Pi:glm-5.3 | PR 级 | BLOCKED r1（3B+4N：行轴错位/边界外写回/PASS 冻结冲突） |
| #63 修正 | `c347f5c` | Pi:glm-5.3 | PR 级复审（缩范围） | PASS r2 |

## 账目与遗留

- dev：#62 → `e6dca55`；#63 → `6eb3597`；毕业批随本 PR 落地。
- 遗留：① task-lifecycle-gates 毕业批（素材 ②⑥ + amend 代码分支——演练
  矩阵后）；② 机器对账六条（演进口，清单跑熟后 ci:docs）；③ 清单 1 首次
  **跨任务**应用（本篇是自我适用，下一代码任务起强制）；④ PR-3 评审结论
  回填审查记录表。
