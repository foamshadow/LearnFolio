---
title: "task-lifecycle-gates 首演：proposal 诞生、三轮评审与流程结构沉淀"
date: 2026-11-20
author: foamshadow
tags: [se-arch, se-review, tool-git]
related: [docs/proposals/task-lifecycle-gates.md, ADR-0007, ADR-0011]
---

# task-lifecycle-gates 首演

> agent 起草、人审定（作者键 = 审定者）。本篇记录 task-lifecycle-gates proposal
> （PR #59，dev `a0b3e4d`）从流程审计讨论到合并的完整事件，以及合并后两轮结构
> 讨论沉淀的规则素材。文末「审查记录」表是新定形态的首个应用实例。

## 事件

Phase 1 spec 暂停期的一次流程审计对话（2026-11-20 起）：全链控制点盘点 →
任务启动三项配置（auto-commit / auto-push / review 单配置贯穿）→ 整理门
条件化 → 当天成稿 PR #59，DSH 三轮评审（BLOCKED ×2 → PASS），人工合并授权
后 `task merge` 落地 dev。合并后讨论延伸出 journal 写回时机与 journal commit
结构的完整设计——结论以规则素材形式列出（见下），待随 proposal 毕业版落档。

## 首演全程（新流程停点逐项记账）

| 停点 | 本次行为 | 备注 |
| --- | --- | --- |
| 三项配置申请 | auto-commit ✓ / auto-push ✓ / review=外部 agent | 新流程第一次申请 |
| docs 提交确认 | 文件清单 + 关键点确认后提交 | ADR-0007 D5 照常 |
| 整理门 | 单提交自动跳过 | 条件化规则的第一个真实用例 |
| PR 创建 | 双授权齐全 → 自动创建 #59 | 自动化规则的第一次实弹 |
| pr-review | DSH 三轮：BLOCKED r1（4B+8N）→ BLOCKED r2 → PASS r3（缩范围复审） | review=外部 agent 档首次实弹 |
| 合并授权 | 人工明确授权 → `task merge -- 59 --yes` | 永远人工，未打折 |

## 三轮评审：B2 的两轮演化（本篇最值钱的部分）

r1 的 B2（dev-review 时点与 ADR-0011 冲突）抓到了设计里最深的一处：审已存在
的提交序列就不能声称带 `Reviewed-by`。r1 修正采用 break+amend 方案；**r2 DSH
证伪了它**——`rebase break` 停在上一条 todo 执行完之后，HEAD 已是该段提交，
amend 补 trailer 的时点仍然晚于生成；且 ADR-0011 的"tree 不变可保留"讲的是
已存在 trailer 的保留，不覆盖事后补写，引用不成立。DSH 在临时仓库实测了 git
序列来验证这个证伪。r3 采纳 reset --soft 路径后 PASS。

教训：① 纸面论证输给一次临时仓库实测——设计的可执行性要用 git 实际时序验证；
② 引用 ADR 条款时"保留语义"与"新增写入"是两个边界，须核对原文；③ proposal
对现行规则的修改点要自己先做全量考证（hotfix 整理条款是用户抓出、DSH 核实的）。

## 合并执行的发现（机械执行层）

- `task merge -- <PR>` 交互确认在非交互 shell 下中止（"confirmation aborted"）；
  `--yes` 跳过——人类授权在前置对话中已明确拿到，`--yes` 合法。此前没人写过
  这个用法。
- squash 合入后 `git branch -d` 拒绝删除本地分支（提交不在 dev 第一父链），
  需 `-D`——内容已落地为 squash 新提交，`-D` 安全。远端分支由 merge.sh 自动删除。
- DSH 的 PASS 附带 3 条非阻塞 note（§5 措辞统一、人工 trailer 值 `none`、
  `git commit --trailer` 需 Git ≥2.32）——PASS 后正文冻结，note 留给毕业前顺路。

## 合并后结构讨论的规则素材（六条，待随毕业版落档）

1. **journal 写回时机（方案甲）**：随任务分支的 journal 边界 = 最后一次 push；
   PASS 与合并执行属边界外（评论层 + PR 状态 + merge.sh 落地核验承载）；合并中
   撞出的新事实走下一个事件的 journal。journal 粒度 = 提炼教训 + 评论层索引，
   不逐轮复述（全程记录在 PR 评论层）。
2. **整理门不强制重组**：进门 = 人审序列，已合规 → 方案"原样"零改动通过；
   不合规才定重组方案。触发条件：≥2 个功能提交或含 wip/fixup 碎片（文档型
   commit 不计入——否则 journal commit 自身触发整理门，死循环）。
3. **序列结构不变量**：功能提交在前（逻辑级，带 Reviewed-by），文档型提交
   （AGENTS 同步 / journal 记账）收尾；写 journal 的任务序列以 docs commit 收尾。
4. **amend 判据按提交类型**：功能提交 amend → 预检为默认（审 staged → `--amend`
   重写 trailer，换审则换行——#47 语义）；纯文档 commit（`docs:` 前缀 + 仅文档
   文件，含 journal/AGENTS）amend → 不预检、删旧 trailer 转移 PR 级；fixup 纯
   噪音 → 原审查者轻量复核后重写；review=无 → 全免。评审期间 journal 每轮更新
   = amend 末尾 docs commit（搭同一 push，零额外消耗）。
5. **trailer 严格语义 + journal 审查记录表**：trailer 只声明"当前树被谁审过"
   （累加会语义失真、与 ADR-0011 失效语义冲突、且行内无法标注版本）；版本级
   审查历史由 journal「审查记录」表承载（见文末首发实例）。
6. **任务分支 force push 降档**：许可档 → auto-push 授权内 + backup 分支前置 +
   告知（依据 merge-integrity P0 阶梯"合入前 amend/force 合法"）；dev/main 不变。

## 审查记录（新形态首发）

| 轮 | 版本 | 审查者 | 层级 | 结果 |
| --- | --- | --- | --- | --- |
| 初稿 | V0（`f0f74d2`，118 行） | —（docs 无 break 审查） | PR 级 | BLOCKED r1（4B+8N）|
| r1 修正 | V1（`12ac2fb`） | DSH:deepseek-v4.1-flash-1017 | PR 级复审 | BLOCKED r2（B2 时点硬伤）|
| r2 修正 | V2（`358a729`） | DSH:deepseek-v4.1-flash-1017 | PR 级复审（缩范围） | PASS r3 |
| 终版锁定 | `a0b3e4d`（squash） | —（body-sha256 密码学比对） | merge.sh | 落地核验通过 |

## 账目与遗留

- dev：`a0b3e4d`；PR #59 已合并、分支已删；proposal status=draft。
- 遗留：① DSH 三条非阻塞 note（毕业前顺路）；② 六条规则素材落档（随毕业版）；
  ③ 毕业演练矩阵（proposal 毕业条件）：≥2 提交代码任务 + review=agent、
  review=无 映射样本、docs 任务、review=人工样本；④ Phase 1 spec 起草（主线，
  编号起草时分配）。
- 下一个真实任务即毕业演练的起点：按新流程走全链，复盘逐停点记"触发/跳过"。
