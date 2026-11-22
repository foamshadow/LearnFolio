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
> 讨论沉淀的规则素材。文末「审查记录」表是本次起用的新形态（格式待随毕业版登记）。

## 事件

本篇的事件界定为「首演及后续结构沉淀」——同一连续对话内完成：Phase 1 spec
暂停期的流程审计（2026-11-20）：全链控制点盘点 → 任务启动三项配置（auto-commit /
auto-push / review 单配置贯穿）→ 整理门条件化 → 当天成稿 PR #59，DSH 三轮评审
（BLOCKED ×2 → PASS），人工合并授权后 `task merge` 落地 dev；合并后讨论延伸出
journal 写回时机与 journal commit 结构的完整设计——结论以规则素材形式列出
（见下），待随 proposal 毕业版落档。本篇即该结构讨论的直接产物（下一事件
journal 的角色），故可记录 PASS 与合并（随任务分支的 journal 边界不含这些）。

## 首演全程（新流程停点逐项记账）

| 停点 | 本次行为 | 备注 |
| --- | --- | --- |
| 三项配置申请 | auto-commit ✓ / auto-push ✓ / review=外部 agent | 新流程第一次申请 |
| docs 提交确认 | 文件清单 + 关键点确认后提交 | ADR-0007 D5 照常 |
| 整理门 | docs 载体豁免——不走整理门/dev-review，评审走 PR 状态评论 | proposal §5 载体豁免的实弹；"单提交跳过"仅对代码分支生效，本任务不适用 |
| PR 创建 | 双授权齐全 → 自动创建 #59 | 自动化规则的第一次实弹 |
| pr-review | DSH 三轮：BLOCKED r1（4B+8N）→ BLOCKED r2 → PASS r3（缩范围复审） | review=外部 agent 档首次实弹 |
| 合并授权 | 人工明确授权 → `task merge -- 59 --yes` | 现阶段人工（确认链毕业后按 L2 载体调整） |

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
  `--yes` 跳过——人类授权在前置对话中已明确拿到，`--yes` 合法。`--yes` 用法
  已有文档（merge.sh 头部 Examples、guides/merge.md），本次首次在非交互 shell
  下使用。
- squash 合入后 `git branch -d` 拒绝删除本地分支（分支提交未被 dev 包含——
  squash 生成的是新提交），需 `-D`，安全。远端分支由 GitHub 的
  `delete_branch_on_merge` 仓库设置在合并时自动删除，merge.sh 不负责删除。
- DSH 的 PASS 附带 3 条非阻塞 note（§5 措辞统一、人工 trailer 值 `none`、
  `git commit --trailer` 需 Git ≥2.32）——PASS 后正文冻结，note 留给毕业前顺路。

## 合并后结构讨论的规则素材（六条，待随毕业版落档）

1. **journal 写回时机**：随任务分支的 journal 边界 = 最后一次 push；
   PASS 与合并执行属边界外（评论层 + PR 状态 + merge.sh 落地核验承载）；合并中
   撞出的新事实走下一个事件的 journal。journal 粒度 = 提炼教训 + 评论层索引，
   不逐轮复述（全程记录在 PR 评论层）。（新增规则，消费 doc-system 的 journal 节）
2. **整理门不强制重组（拟改 proposal #59 §5 触发条件）**：进门 = 人审序列，
   已合规 → 方案"原样"零改动通过；不合规才定重组方案。触发条件拟改为：≥2 个
   功能提交或含 wip/fixup 碎片，文档型 commit 不计入（现行 #59 版为"多提交
   一律过门、≥2 即触发"）——避免 journal commit 的存在为任务额外引入整理门停点。
3. **序列结构不变量（细化 proposal §5 机制）**：功能提交在前（逻辑级，带
   Reviewed-by），文档型提交（AGENTS 同步 / journal 记账）收尾；写 journal 的
   任务序列以 docs commit 收尾。
4. **amend 判据按提交类型（流程化 ADR-0011"须重审"）**：功能提交 amend →
   预检为默认（审 staged → `--amend` 重写 trailer，换审则换行——#47 语义）；
   纯文档 commit（`docs:` 前缀 + 仅文档文件，含 journal/AGENTS）amend → 不预检、
   删旧 trailer 转移 PR 级；fixup 纯噪音 → 原审查者轻量复核后重写；review=无 →
   全免。评审期间 journal 每轮更新 = amend 末尾 docs commit（搭同一 push，
   零额外消耗）。
5. **trailer 严格语义 + journal 审查记录表（细化 ADR-0011）**：trailer 只声明
   "当前树被谁审过"——同一棵树的多个 reviewer 并存是 ADR-0011 既有合法形态，
   本条反对的是**跨版本**把旧审查者累加到当前树（语义失真、与失效语义冲突、
   且行内无法标注版本）；版本级审查历史由 journal「审查记录」表承载
   （见文末首发实例）。
6. **任务分支 force push 降档（拟取代 ADR-0007 D1 的"许可"档，需显式提案）**：
   任务分支（未合并、无他人依赖、PR 兜底）force push → auto-push 授权内 +
   backup 分支前置 + 告知；dev/main 保持人类确认不变。论证依据是操作实践
   （合入前 amend/force 是评审循环的常态动作），现行文本无此条款。

## 审查记录（本次起用的表；格式待随毕业版在 journal 模板/guide 登记）

| 轮 | 版本 | 审查者 | 层级 | 结果 |
| --- | --- | --- | --- | --- |
| 初稿 | V0（`f0f74d2`，118 行） | commit 级 —（docs 无 break 审查）；PR 级 DSH:deepseek-v4.1-flash-1017 | PR 级 | BLOCKED r1（4B+8N）|
| r1 修正 | V1（`12ac2fb`） | DSH:deepseek-v4.1-flash-1017 | PR 级复审 | BLOCKED r2（B2 时点硬伤）|
| r2 修正 | V2（`358a729`） | DSH:deepseek-v4.1-flash-1017 | PR 级复审（缩范围） | PASS r3 |
| 终版锁定 | `a0b3e4d`（squash） | —（body-sha256 密码学比对） | merge.sh | 落地核验通过 |

## 账目与遗留

- dev：`a0b3e4d`；PR #59 已合并、分支已删；proposal status=draft。
- 遗留：① DSH 三条非阻塞 note（毕业前顺路）；② 六条规则素材落档（随毕业版）；
  ③ 毕业演练矩阵（proposal 毕业条件）：≥2 提交代码任务 + review=agent、
  review=无 映射样本、docs 任务、review=人工样本；④ Phase 1 spec 起草（主线，
  编号起草时分配）。
- **2026-11-22 遗留处置更新**：① 已随 PR #62 吸收（三篇文档措辞/口径修正）。
  ② 分组转正——素材 ①③⑤ + ④docs 分支随 docs-writeback proposal（PR #63）
  毕业落 **ADR-0013**（操作级清单/learning 例外落 AGENTS 同批）；素材 ②⑥ +
  ④功能提交/fixup 分支**仍随 task-lifecycle-gates 毕业版**（演练矩阵验证后）。
  审查记录表格式已登记 journal 模板（本篇首发样例为范本）。
- Phase 1 spec 的首个真实任务即毕业演练起点（proposal 毕业条件原文口径）：
  按新流程走全链，复盘逐停点记"触发/跳过"。
