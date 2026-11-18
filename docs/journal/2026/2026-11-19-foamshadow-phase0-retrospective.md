---
title: "Phase 0 复盘：从骨架到 v0.1.0，以及被推迟的合并脚本"
date: 2026-11-19
author: foamshadow
tags: [se-arch, se-review, tool-git, tool-ci]
related: [SPEC-0001, ADR-0003, ADR-0005, ADR-0007, ADR-0009, ADR-0010, ADR-0011]
---

# Phase 0 复盘：从骨架到 v0.1.0，以及被推迟的合并脚本

> agent 起草、人审定（作者键 = 审定者）。本篇是 DSH 视角的初稿；另一 agent 将在同一
> 分支补充其详细记忆，评审时合并多视角。只记会影响 Phase 1 的事，不逐条复述 SPEC-0001。

## 事件

Phase 0 以 v0.1.0 收口：从空仓库到「clone 后能按文档搭环境、跑 `task ci`、有契约生成链与本地 PG」的骨架。核心账本：

| 时间 | 事件 | 账本 |
| --- | --- | --- |
| 2026-11-15 | t0 CI 骨架 | PR #9 |
| 2026-11-17 | t1 workspace 重新落地 | PR #36（#34 缺号事故后 re-land） |
| 2026-11-18 | t2 / t3 / t6 | PR #40 / #44 / #46 |
| 2026-11-18 | A10 前置与收口 | PR #47 / #48；main `03aeab5` |
| 2026-11-18 | v0.1.0 annotated tag | tag 对象 `7330e57` → `03aeab5` |
| 2026-11-18 | merge.sh 自合并 | PR #50；dev `792f64f`；pilot code 1/3 |

Phase 0 的 PR 号从 #9 跨到 #50，但号段本身不是指标；#45（Q1 撤回窗口）、#42（retract 脚本）、
#43（ruleset 迁移）等基础设施也在这条线上。真正的交付判据是 A1–A10 与 tag，不是 PR 数量。

## 做对了什么

- **spec / ADR 作为真源**：任务分解、验收条目、变更记录与 ADR 决策分开存放；t1–t6 的施工都
  能回指到 SPEC-0001 的条目。文档写回窗口（PR 创建后、评审通过前）让「实测结果 + PR 号」
  和代码同批落账，减少了收口时的临时补账。
- **门禁分层**：`ci-ok` 是 GitHub 唯一 required check；docs 走 squash、code 走 `--no-ff`；
  PASS 是评论层的评审结论，不是 GitHub approval。三者职责不同，这个分层在 #47–#50 的
  收口里被反复使用。
- **署名与评审链**：`Assisted-by` / `Reviewed-by` 双轨、PR 状态评论的 `Reviewer` / `Author`
  角色行，让多 agent 的参与可追溯；Pi、DSH、ClaudeCode 的分工没有退化成「谁写谁审」。
- **收口顺序**：A10 前置 PR #47 先勾 A1–A10 与 status done，收口 PR #48 只搬 dev 树，
  tag 打 merge commit，dev 不追平 main。A5 ④ 在 #49 用 aa9f2dd / 2602bcb 两轮双 run 证据
  结案；这不是「跑一次 CI」能替代的账。
- **工具吃狗粮**：#50 用刚落地的 `task merge` 自合并，PASS target/body hash 复核、合并后
  subject/body/第二父核验全部通过。merge.sh 的 N1（合并后核验未被 fixture 覆盖）由此实测，
  而不是留到 Phase 1。

## 代价与返工

- **P0 合并脚本被推迟到收口之后**。proposal #30 已把快照合并定为 P0，但 SPEC-0001 的任务
  表止于 t6，merge.sh 没有任务号；#45–#49 仍按手动六步合并。代价是 pilot 在 v0.1.0 时仍
  0/3，收口后还要补一个 `fix/infra-merge-snapshot` PR。根因不是技术难度，而是**P0 硬保证
  没有进入任务表**，被「t6 是最后一个代码任务」的框架挤掉。
- **A10 的时序悖论**。A10 要求前置 PR 完成「验收逐条勾选 + status done」，但 A10 自身又包含
  「dev→main 合并 + tag」——前置 PR 不可能已完成这些动作。留空 A10 会让 main 快照缺一项；
  勾上则是提前声明。最终选择在前置 PR 勾 A10，把剩余动作写成「人类确认的机械执行」，执行
  记录进 journal；A5 ④ 的回填另走 #49。这个缝被 DSH 评审抓到，说明**收口类验收项要显式
  区分「前置可验证」与「执行后才有证据」**，不能在一个复选框里混两种时点。
- **受限验收被如实记账，但仍是缺口**。A5 ③（edited 重跑取最新 required）继续推迟；A10 的
  onboarding 以「本机干净 clone 模拟」代替真实第二成员，真正的外部 clone 仍待发生。它们
  没有被粉饰，但「A1–A10 全勾」不自动等于「全部独立验证完成」；读账的人必须读变更记录。
- **评审协议的软要求会漏**。#48 / #49 的修正以 PR 描述编辑 + 聊天呈报完成，没有单独留
  `REVIEW-FIX` 评论；#49 的 PR 描述一度写「使 #48 检查单闭合」，与 commit body 的「待新
  head 复核」矛盾，被 DSH 打回。评论层是审计面，不是可省的仪式；PR 描述是 docs squash 的
  落地正文，任何「未来完成时」措辞都会永久落库。
- **工具与环境的摩擦**：Pi CLI `-p` 的请求级挂死需要外层 `timeout`；worktree 里 lefthook 不在
  PATH，本地 commit 钩子实际没跑（消息由人工核对，CI attribution 兜底）；沙箱 pnpm store
  只读，#50 的本地 `task ci` 无法执行，只能以 PR CI 为等价验证面。这些都不是产品代码问题，
  但会改变「本地已验证」的含义，必须在 PR 描述里说清。
- **main / dev 的文档边界**：收口后新增的文档（例如本篇复盘、后续 pilot 记账）只回 dev，
  不会自动进入 main 的 v0.1.0 快照；#49（A5 ④）与 A10 受限例外是在收口前合入的，已在 main。
  下一次收口的前置 PR 应把「必须进 main 的账」一次收完；否则 tag 的文档快照会落后于 dev 的真源。

## 判断

- **merge.sh 已落地，后续合并一律走 `task merge`**；不再把「手动六步」当默认路径。pilot 现在
  1/3（code #50）；本复盘 PR 合入后是 2/3（docs）。第三票 + 敏感数据桌面演练完成后再谈
  merge-integrity 毕业。
- **Phase 1 的硬门仍是 SPEC-0002**：roadmap 的 Phase 1 段落必须毕业为正式 spec，ready 评审
  至少一名非作者核心成员批准。merge-integrity 毕业与 Phase 1 开工可以并行，但不要用「工具
  还没毕业」拖延 spec 起草。
- **A5 ③ / A10 外部 clone / 敏感数据演练**不阻塞 Phase 1 开工，但不能从账本上消失；分别挂在
  A5 ③ 触发条件、A10 执行差异、merge-integrity 毕业条件上。
- **不要回头重写 Phase 0 历史**。A10 的受限例外、A5 ④ 的两轮 head、#50 的本地 CI 缺席，都按
  执行差异记账；Phase 1 用同样的规则向前走。

## 账目与下一步

- main：`03aeab5`；tag：`v0.1.0`（annotated，tag 对象 `7330e57`）；dev：`792f64f`；无 hotfix。
- pilot：1/3（code: PR #50，`task merge` 自合并）；本复盘 PR 合入后 2/3（docs）；第三票与
  敏感数据桌面演练待做。merge-integrity proposal 仍 `review`。
- 下一步：Phase 0 复盘 + learning（本 PR）→ pilot 记账 → SPEC-0002 起草/ready 评审 →
  Phase 1；A5 ③ 与 A10 外部 clone 继续跟踪。

## Pi 视角补充（评审者记忆）

DSH 初稿记的是实现侧；以下补评审侧的四段记忆，都是 Phase 1 还会复用的。

### 审查锚点：从单锚点到双锚点

#42 的 B1 修复复审时，实现者报告的 diff-sha256 与评审者复算不一致（实测 `1fa3de91…` ≠ 声称的 `73fe66dd…`）——tree 哈希逐位一致、diff 哈希却对不上，说明两者口径不同源。结论：**tree 哈希（git 自身的内容寻址）是唯一权威锚点，diff-sha256 只是便利校验和**，且必须约定生成命令（`git diff --cached | sha256sum`）。#43 起改双锚点（tree + diff-sha256 同报同核），此后未再出现口径漂移；PR 级审查同样以「PR head 的树 = commit 级 `Reviewed-by` 覆盖的树」逐位比对收口。评审覆盖的可审计延伸靠 git 对象寻址，不是信任口头声明。

### 「比现状弱」的迁移审查框架

#42 首轮 B1：第一版把 `deletion` 挂在带 owner bypass 的 RS-2 上——分支删除不走 push 路径、RS-1 拦不住，管理员平时就能删 dev/main，**相对 classic（`allow_deletions=false` + `enforce_admins`）是净弱化**。规则迁移类审查的通用问题不是「新方案是否可行」，而是「新方案相对被取代方案的每个维度是否都不弱」。修法（拆 RS-3、无 bypass、`retract.sh` 永不触碰）让删除保护比 classic 更强：owner 也删不了。

### 角色反转与 Q1 三条件的概念拆分（#45）

Q1 三条件落地时 Pi 写代码、DSH 审查——互审约束（reviewer ≠ Assisted-by 参与者）首次在两个方向都得到验证。三条件也不是一次想清的：先发现已实现的「HEAD + 24h」里时间只是不可见扩散的代理，再把原提案「下一任务分支前」从不可执行的意图落成 `for-each-ref --contains` 的可执行检查（同机工作树共享对象库 = 可见暴露全覆盖；异机 clone 由时间兑底）。前置的概念拆分——**RS-1 禁用窗口（秒级）/ 撤回资格窗口（Q1 本体）/ re-land 无窗口**——避免了把三个不同的「窗口」混进一个决策。

### 评审时点与 `Reviewed-by` 的边界（#50）

merge.sh 的两个提交在开 PR 前受了审，但提交已存在——按协议「提交后才发生的审查不回头改旧 commit」，两个提交不带 `Reviewed-by`，评审责任整体转移到 PR 级 PASS。实践结论：**想拿 commit 级互审署名，评审必须发生在 commit 生成前（staged tree 快照）；PR 级 PASS 是兜底，不是替代**。#44 的「4 棵暂存树逐棵审」是正例，#50 是反例教材。

另一条复利链：#43 复审时对 #41 尾换行做了字节级验证（PR body 1008 字节、落地 1007、`rstrip("\n")` 后逐字节一致）→ 归一化口径写入 guide → #50 的 merge.sh 落地核验直接实现该归一化（两边命令替换天然去尾换行）。一次较真的验证，三个 PR 后变成工具的一行正确性。

### 现场反证一则：worktree 里钩子是能跑的

本补充提交在 `.worktrees/phase0-retrospective` 内完成，lefthook 的 `pre-commit`（按后缀分流，本提交无匹配文件全部 skip）与 `commit-msg`（`assisted-by` 校验通过）**两个钩子都真实执行**。初稿「worktree 里 lefthook 不在 PATH，本地 commit 钩子实际没跑」应精确为**特定会话的 PATH 问题**，不是 worktree 的结构性缺陷（t3 的转发器回落机制本就为此设计）；下次遇到应在该会话内 `task setup:hooks` 复装验证，而不是归因于 worktree。

## 参考

- `docs/specs/0001-phase-0-scaffold.md`（A1–A10、变更记录）
- `docs/guides/merge.md`（PASS、快照合并、手动兜底）
- `docs/proposals/merge-integrity.md`（P0 设计、pilot 与毕业条件）
- `docs/journal/2026/2026-11-18-foamshadow-phase0-closeout.md`（收口执行记录）
- `docs/journal/2026/2026-11-18-foamshadow-t3-commit-hooks.md`、`2026-11-18-foamshadow-t2-api-contract.md`
