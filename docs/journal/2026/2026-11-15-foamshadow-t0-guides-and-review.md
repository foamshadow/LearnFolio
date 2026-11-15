---
title: "t0 门禁落地与 guides 教学化：三轮评审、记录落点与 A9 补账"
date: 2026-11-15
author: foamshadow
tags: [se-arch, tool-ci, tool-git]
related: [ADR-0004, ADR-0005, ADR-0006, ADR-0009, SPEC-0001]
---

# t0 门禁落地与 guides 教学化

> agent 起草、人审定（作者键 = 审定者）。本篇记录 2026-11-15 的两条主线：
> t0 的 CI 门禁从骨架变成真实 required check；guides 四篇按「学习者读者」标准回炉。
> 两条线在评审环节交汇，撞出两类记录落点错误：评审过程进了 squash 正文，A9 来源账缺位。

## 事件

t0 的 CI 骨架合入 dev（PR #9），`ci-ok` 随后成为 dev / main 的唯一 required check；
t0 文档写回、worktree 规范、guides 首批、doc-system 与 git-workflow / worktree / ci-gate
教学化依次落地。评审协议 proposal 从 PR #13 的三轮评审中长出来（PR #14），又在
PR #15 / #16 的实践中被修正：评论承载评审状态，commit / PR 描述只写最终变更（PR #17）。

## 时间线

| 时间（CST） | 事件 |
| --- | --- |
| 15:2x | t0 CI 骨架合入 dev（PR #9，merge `4b4925a`）；required `ci-ok` 补配（strict=false、enforce_admins=true） |
| 16:3x | t0 文档写回、CI 优化候选与写回窗口规则（PR #10，`c296c50`） |
| 17:1x | 多工作树协作规范与操作手册（PR #11，`3b6379e`） |
| 17:5x | guides 首批：git-workflow 对齐 + ci-gate 新增（PR #12，`3cd846e`） |
| 20:0x | doc-system 按写作标准重写（PR #13，`128b660`）；三轮评审收口 |
| 20:2x | PR 评审协议 proposal（PR #14，`6b83d19`） |
| 20:3x | git-workflow / worktree 按写作标准重写（PR #15，`ae9e313`） |
| 21:2x | 评审协议 proposal 记录落点修正（PR #17，`5b7dbff`） |
| 21:2x | ci-gate 按写作标准重写（PR #16，`314473d`）；PR 描述清理后 squash |
| 21:3x | 另一 agent 开 `docs/t5-advance`（PR #18）；主工作树被切离 dev |

## 决策

### t0 门禁：单 workflow + 唯一 required `ci-ok`

按 ADR-0009：全部检查住在一个 `ci.yml`，分支保护只挂 `ci-ok`；PR 侧 `ci-ok`、push 侧
`ci-ok (push)` 显示名消歧；title / attribution 进 `needs`，否则违规只是旁路红灯。
t0 自身 PR 人工把关，合入后补配 required——`ci-ok` 在合入前从未上报过，设置界面下拉
选不到，只能先合后配（一次性 bootstrap 例外，D8）。

### guides：默认读者是学习者

PR #13 把「详尽优先于简洁、术语就地解释、机制配实例、讲相关技术本身」写进
`guides/_template.md`，并在 docs/README 地图登记。随后四篇回炉：doc-system 193 行、
git-workflow 301 行、worktree 140 行、ci-gate 158 行。规则仍是 AGENTS / ADR 的真源，
guides 只解释；这条在执行中反复用来判定「教材 bug vs 规则 bug」。

### 评审协议：评论是状态机，commit 只写最终态

PR #13 三轮评审的根因不是单条意见，而是评审缺清单、修正缺回归、评论无 ID / 状态。
PR #14 起草协议：`REVIEW: BLOCKED` / `REVIEW-FIX` / `REVIEW: PASS`，B/N/Q 编号，
一次评审跑完整清单，两轮封顶。

PR #15 / #16 又暴露第二层问题：把「评审修正记录」写进 PR 描述。docs PR 的描述会作为
squash 正文进入 dev，于是 #13 / #15 的 commit 正文带上了 comment 回复；而 commit 的职责
只是记录最终改了什么、为什么。PR #17 因此把协议修正为：

- 评审 ID、轮次、谁提了什么只出现在评论；
- PR 描述按最终 commit message 写（变更 / 验证 / 依赖 / 检查单）；
- commit 不写「因评审改为 X」——X 本身就是这次提交该写的内容；
- 需要留存的复盘进 journal，不进 commit。

PR #16 合入前按此清理了 PR 描述（删除“评审修正记录”整节），并在 squash 正文保留
ZCode / DSH 两行 `Assisted-by`；dev 历史中的 #13 / #15 不重写，作为执行差异记在下面。

### A9 来源账：补记而不是重写旧 journal

SPEC-0001-A9 要求遗产裁剪的外部来源账记入 journal 首篇。实际 11-13 / 11-14 两篇都没有
逐条来源账，条款级来源注记落在 AGENTS「继承条款」节。本篇补记来源账（见下），并把它记
为执行差异；旧 journal 不追改。

## A9 来源账（补记）

| 外部来源 | 形态 | 提供 | 落地 |
| --- | --- | --- | --- |
| harmony-wechat | AGENTS.md + 《软工流程复盘》 | foamshadow 于 t4 开工时提供全文 | AGENTS 继承条款节逐条注来源；ADR-0008 记录裁剪判据 |
| foampray | AGENTS.md | 同上 | 同上 |

这是晚于「首篇」的补记：A9 的字面要求未按原位置执行，但来源、提供者与落点现在都在
仓库内可追溯；后续若需要严格回填 11-13 首篇，journal 可变层允许追加。

## 执行差异

| 原计划 / 预期 | 实际 |
| --- | --- |
| A9 来源账记入 journal 首篇 | 首篇未落；本篇补记，位置晚于要求，旧 journal 不改 |
| PR 描述只承载变更 | #13 / #15 带“评审修正记录”，随 squash 进入 dev；#17 修正规则，#16 合入前清理，旧历史不重写 |
| PR 描述里的 trailer 只是占位 | #16 清理后保留 ZCode + DSH 两行 trailer；attribution push run 校验通过 |
| 主工作树常驻 dev | 收尾时另一 agent 把主树切到 `docs/t5-advance`（PR #18）；未干预，改用独立 worktree 写本篇 |
| #16 评审记录只涉及内容 | 实际上还涉及 PR 描述 / commit 正文的落点；这一层在合入前才被清除 |

## 异常

- **PR #13 三轮评审**：第一轮 3 阻塞 + 3 非阻塞；第二轮修正引入 A9 伪先例与时区错误；
  第三轮才发现 PR 标题 / 描述未同步。根因是评审没有「落地物元数据」与「修正回归」两项清单。
- **PR #15 的绝对化表述**：`dev→main 永不冲突` / `收口必冲突` 被收敛，但 `每次收口都会复发`
  仍偏绝对；作为非阻塞措辞备注放行，不影响规则本身。
- **PR #16 的评审记录回流**：PR 描述带“三轮 8 条”修正记录；合入前删除整节并按
  `Assisted-by` 双行署名，squash 正文干净。`docs/guides-ci-gate-rewrite` 分支（当时）提交正文仍留旧段，
  但 squash 不消费它；该分支已随合入清理，dev 账本不受影响。
- **主工作树并发**：`docs/t5-advance` 在主工作树检出并开 PR #18，主树因此不在 dev；
  按「主树优先常驻 dev、并行任务进 worktree」的规则，这是一次并发纪律偏差，未被用来提交本篇。
- **#16 行数统计**：PR 描述与落地提交写 156 行，实际 `wc -l` 为 158；差 2 行，以文件为准——描述里的数字也要按落盘文件核对。

## 遗留

- 评审协议 proposal（#14 + #17）仍是 draft；试点目标 3 个 PR（docs 与代码各至少 1），
  之后迁 AGENTS + `docs/guides/review.md` + PR 模板「自检」节；不设「评审结论」节。
- A9 来源账已补记，但不在首篇；是否回填 11-13 首篇留待后续文档决定。
- t5 由另一 agent 推进（PR #18，写作时开放）；主工作树切回 dev 的时机归其收尾。
- ZCode 的 ci-gate 工作树与远端分支已在合入后清理；本地分支随工作树删除，不影响 dev。
- t1 未开工；下一任务是 t1 的 workspace / Nuxt 基线，需任务级授权。

## 复盘

一天里两次同类错误：**把过程记录放进了不该放的载体**。第一次是评审 comment 进了
squash 正文；第二次是 A9 的来源账没进它指定的 journal。两次都不是内容难，而是「哪种
记录该落在哪一层」没有先定。沉淀出的判据是：

- commit / PR 描述（docs squash 正文）= 最终态与理由；
- 评论 = 评审状态机，可编辑、可消失，不作为账本；
- journal = 过程、事故、执行差异、来源账；
- AGENTS / ADR / spec = 规则与决策，正文不可变或受控追加。

另一条：**评审要一次跑完清单**。#13 的三轮不是三次独立思考，而是每轮只看见上一轮视野；
把「落地物元数据」与「修正回归」写进清单，才能把轮次压到两轮以内。
