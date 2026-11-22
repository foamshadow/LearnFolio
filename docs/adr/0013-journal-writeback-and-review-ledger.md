---
id: ADR-0013
title: "journal 写回与审查记账：事件边界、二值判定与预先性记录"
status: accepted
date: 2026-11-22
author: foamshadow
tags: [se-review, tool-git]
related: [ADR-0006, ADR-0011, docs/proposals/task-lifecycle-gates.md]
supersedes: ""
superseded-by: ""
---

# ADR-0013：journal 写回与审查记账

## 背景（Context）

journal 是可变层（ADR-0006 六类之一，谁经历谁写），但**写回时机、commit 结构
与审查记账形态**此前无正式规则。task-lifecycle-gates proposal（PR #59）落地
后的三个 docs 任务（#59/#60/#61）实践出完整机制，以规则素材形式封存在其首演
journal。流程冻结线（Phase 0 已收口 v0.1.0）要求决策级规则走 ADR 载体：本
ADR 收**决策级**——事件边界（含二值判定）、预先性记录、journal 写回与审查
记账；操作级（清单执行判据、learning 例外、时点锚）落 AGENTS「文档写回」
条款（docs-writeback proposal 毕业批同批到达）。ADR-0006 不动：本 ADR 为
新增细化，与其无冲突，非取代。

## 决策（Decision）

1. **事件边界决定写回边界**：任务 journal 的写回边界 = 最后一次 push；PASS
   与合并执行属边界外（由 PR 评论层 + PR 状态 + merge.sh 落地核验承载）；
   边界外撞出的新事实 = 新事件、新 journal，从不尾随追加到已封账的事件上。
   docs 写回同构：写回边界 = 合并请求停点（tlg 流程 ⑨ = 停点表 #9「合并
   授权」），边界外发现 = 执行差异唯一通道（AGENTS 窗口条款现行口径）。
2. **二值判定（无尾随通道）**：写回核对只两态——窗口内更新，或记录"无需
   更新"（一句话理由），不存在"登记后续补"第三态。
3. **预先性记录**：状态与完成描述字段随写回窗口增量维护，合并只落终态
   标记——禁止合并后补 docs PR 做完成回填（那属于执行差异）。
4. **journal 写回与审查记账**：
   - 粒度 = 提炼教训 + 评论层索引，不逐轮复述（全程记录在 PR 评论层）；
   - 序列结构不变量：写 journal 的任务序列以 docs 型提交收尾（AGENTS /
     journal 同步），功能提交在前；
   - trailer 严格语义：trailer 只声明"当前树被谁审过"，不跨版本累加旧审查
     者——版本级审查历史由 journal「审查记录」表承载（轮次/版本/审查者/
     层级/结果），格式登记 journal 模板；人类审查者在表内记 `none`、具体
     人名落 PR 评论（ADR-0011 口径的表内延伸）；
   - amend 预检判据：纯文档 commit（`docs:` 前缀 + 仅文档文件）amend →
     不预检、删旧 trailer 转移 PR 级；评审期间 journal 每轮更新 = amend
     末尾 docs commit（搭同一 push，零额外消耗）。**功能提交预检与 fixup
     轻量复核分支未经实弹**，待 task-lifecycle-gates 毕业演练验证，此前
     按保守默认（审 staged → `--amend` 重写 trailer）。

## 被否方案（Alternatives）

| 方案 | 否决理由 | 翻转条件 |
| --- | --- | --- |
| journal 携带至合并后继续追加 | 边界腐蚀——任务 journal 无限生长，事件边界失效，可考古性瓦解 | 出现"边界外事实必须进同一篇"的强审计场景 |
| 尾随 docs PR 合法化（登记后续补） | 四纠缠：窗口侵蚀（逃生舱化）；语义双轨（与执行差异撞车，搅浑过程改进信号）；漂移窗口合法化（登记 ≠ 执行）；"合入后才知道"类别经盘点近乎不存在 | 合入后独有知识成为常态类别 |
| trailer 跨版本累加 reviewer | 语义失真（当前树未必被旧 reviewer 审过）；与 ADR-0011 失效语义冲突；行内无法标注版本 | 无——审查记录表已覆盖版本级需求 |
| PASS 后 force push 回填 journal | 写回窗口外重写；作废 PASS 快照；触发 ADR-0007 人类确认 | 无 |
| 事实 ID 登记簿（事实编号、消费方引用 ID） | 维护成本超出 5 人团队；时点锚以近零成本达到近似可枚举性 | 团队规模或自动化程度显著变化 |

## 后果（Consequences）

- 正面：事件边界清晰（journal 可考古、不无限生长）；评审循环 journal 更新
  零额外消耗（amend 搭同一 push）；版本级审查历史可考古（审查记录表）；
  写回核对机械可执行（时点锚 grep）。
- 负面 / 新约束：边界外事件必须新开 journal（纪律成本）；PASS 后任何描述
  编辑作废快照（缺口回环成本由停点承担）；amend 判据的代码分支尚未实弹，
  依赖 task-lifecycle-gates 毕业演练收口。
