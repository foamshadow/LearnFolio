---
title: "评审协议讲解：从 BLOCKED 到 PASS，以及 PASS 之后"
author: foamshadow
date: 2026-11-17
status: draft
tags: [se-arch, tool-git]
related: [ADR-0004, ADR-0005, ADR-0007, ADR-0009, SPEC-0001]
---

# 评审协议讲解：从 BLOCKED 到 PASS，以及 PASS 之后

## 讲给谁 / 前置知识

给作者与评审者两类读者：**作者**（人类或 agent，要知道怎么请求评审、怎么修正、什么时候算通过），以及**评审者**（要知道跑什么清单、怎么发状态、通过后怎么合并）。前置：读过 `git-workflow.md`（分支、PR、squash 已在那篇讲过），知道 `AGENTS.md` 提交纪律与 ADR-0007 的授权模型。

本文解释 `AGENTS.md`「评审协议」子节；规则冲突时以 AGENTS 为准。它是教学层，不是新规则。

## 核心图景

### 一句话版本

**评审不是一个“通过/不通过”的按钮，而是一个有状态、有 ID、有证据、有轮次上限的评论状态机；PASS 是它的终态，也是合并前冻结标题与描述的那一刻。**

```
draft ──作者自检──→ ready
                      │
                      ▼
              REVIEW: BLOCKED ──作者一次修完──→ REVIEW-FIX
                      │                         │
                      │                         ▼
                      └──────────────→ REVIEW: PASS ──→ 合并
```

### 三套评论

| 评论 | 谁发 | 作用 |
| --- | --- | --- |
| `REVIEW: BLOCKED` | 评审者 | 第一轮完整清单；列出 B/N/Q，阻塞项必须带证据 |
| `REVIEW-FIX` | 作者 | 一次性修完，逐 ID 报 fixed/deferred/rejected |
| `REVIEW: PASS` | 评审者 | 第二轮闭环 + 回归 + 元数据通过；带 target/hash/Reviewer |

一条评论承载一个状态；行内评论只用于定位，结论回到汇总评论。ID 跨轮稳定：`B` 阻塞、`N` 非阻塞、`Q` 提问。

## 为什么这样设计

### 事故一：PR #13 的三轮评审

第一轮报 3 阻塞 + 3 非阻塞；第二轮修正引入 A9 伪先例与时区错误；第三轮才发现 PR 标题/描述没同步。问题不在单条意见，而在**没有完整清单、没有状态机、没有回归检查**。

### 事故二：#15 / #16 把评审记录写进 squash 正文

初版把 PR 描述当评审账本；docs PR 的描述会成为 squash 正文，于是“评审修正记录”永久进了 dev。修正：**评论承载状态、commit 只写最终态、journal 承载过程**。

### 事故三：#22 PASS 后描述被改

PASS 之后、merge 之前的 23 秒里，PR 描述被追加评审清单，位置在 `Assisted-by` 之后。squash 正文取自描述，落地提交的 trailer 不在末尾，dev push 的 attribution 判红。修正：**PASS 后冻结标题/描述；PASS 带 target + body-sha256；合并用快照，不读实时描述**。

#22 被记为试点失败样本；毕业条件因此写成“失败样本 + 规则补丁 + 无复发”，而不是“从未漏检”。

## 三套模板

### 评审者：阻塞

````text
REVIEW: BLOCKED · target <sha> · round <n>

## 阻塞
B1 `<file>:<line>` — <一句话问题>
- 证据：<文件行 / 命令输出 / 平台数据>
- 要求：<可验证的修正>

## 非阻塞
N1 `<file>:<line>` — <一句话建议>
- 证据：
- 可延后：是 / 否

## 已核验
- 形状：diff 单意图（docs 提交数按现行 ADR-0005）
- 元数据：标题 / 描述 / trailer / 分支方向
- CI：required 全绿；skipped 符合上下文
- 事实：<抽查项>

## 结论
BLOCKED — B1/B2 关闭前不合入。
Reviewer: <harness>:<model>
````

### 作者：修正完成

````text
REVIEW-FIX · target <sha>
| ID | 状态 | 落点 |
| B1 | fixed | `<file>:<line>` |
| B2 | fixed | `<file>:<line>` |
| N1 | deferred | <后续 PR / 理由> |
待复核。
Author: <harness>:<model>
````

### 评审者：通过

````text
REVIEW: PASS · target <sha>
body-sha256: <sha256(title + "\n" + body)>
closed: B1 B2 N1
verified: CI green · title/body/trailer synced（body 仅最终变更）· 单意图 · no open blocking
merge: <squash|--no-ff>
Reviewer: <harness>:<model>
````

`Reviewer` / `Author` 的键表与 `Assisted-by` 相同；人类写 `none`。同账号下这是**声明**，不是 GitHub approval。

## 一次评审的完整清单

| # | 检查 | 方法 |
| --- | --- | --- |
| 1 | 形状 | base/head、diff 是否单意图、有无无关文件；docs 提交数按现行 ADR-0005 |
| 2 | 落地物元数据 | PR 标题（squash / merge 主题）、PR 描述（docs 的 squash 正文；code 不入提交）、末尾 trailer、分支方向 |
| 3 | CI | required 全绿；skipped 是否符合触发上下文（docs-only / push） |
| 4 | 事实 | 日期、编号、PR 号、链接、命令、数字逐条对仓库或平台数据；真实先例必须在仓库里存在 |
| 5 | 规则一致性 | AGENTS / README / ADR / spec 对表；guides 不得新增规则 |
| 6 | 回归 | 修正 diff 是否引入新表述、新数字、新先例；上一轮 ID 是否全关 |
| 7 | 合并闸口 | 标题/描述已同步且描述只含最终变更；docs 用 body 快照，code 校验 title + merge commit 空正文；trailer、CI、无 open blocking |

## 两轮上限与时间盒

- 第一轮：完整清单，一次发全；没有 blocking 就直接 PASS。
- 作者修正：一次 amend / push 修完全部 ID；发一条 `REVIEW-FIX`。
- 第二轮：只验闭环 + 回归 + 元数据；通过即 PASS。
- 两轮上限：第二轮仍 BLOCKED，禁止开第三轮；拆 PR、缩范围或升级给人决策，并记录原因。
- 时间盒：ready 到 PASS 超过 2 轮或 24 小时，触发同上。

## 角色、授权与同账号

- **作者**：请求评审前自检；修完全部 B 后发 `REVIEW-FIX`。
- **评审者**：跑完整清单、发一条状态评论、复核、在授权范围内合并；不进入作者分支改代码。
- **评论不是审批**：`REVIEW: PASS` 是评审结论，不是 GitHub approval；同账号自审的合法路径 = `COMMENTED` + `REVIEW: PASS` + 人类明确合并授权。
- **`required_approving_review_count=0`**：所有 agent 共用 `foamshadow` 账号，GitHub 只看到一个人；自批不可能，设 1 会死锁。真独立审批需要另一个账号（其他人类成员）。
- **合并动作**：人类先授权，agent 再执行合并（跑脚本）；未授权不得 merge。
- **`Reviewer` 是声明**：GitHub 不能证明评论是哪个 runtime 发的；它让人知道该看哪份结论，不构成平台证明。

## PASS 的冻结与快照

- PASS 评论带 `target <sha>`、`body-sha256: sha256(title + "\n" + body)`、末行 `Reviewer`。
- PASS 后 PR 标题/描述**冻结**；任何编辑都作废 PASS，必须重新 PASS 并重新快照。
- docs：合并用 PASS 快照生成 squash 正文，不读实时描述。code：merge commit 正文为空；快照只冻结 title / 描述，分支提交 trailer 由 attribution 校验。
- 手动合并 = 绕过快照：必须逐项确认标题、描述末行 trailer、body hash、CI、方向、合并方式；合并后立刻检查落地提交。
- `pr-meta`（C6）是 PR 时的 body backstop：查末行 trailer、无评审记录段；它**不能**保证 PASS 之后描述没变，硬保证仍是快照合并。

## docs 与 code 的落地物

| | docs | code |
| --- | --- | --- |
| 合入 | squash | `--no-ff` |
| 落地正文 | PR 描述（快照） | merge commit 正文为空 |
| 提交数 | 现行 ADR-0005 恰好 1；拟立的新 ADR 部分取代撤销 | 多提交；每个非 merge 提交带 trailer |
| 元数据风险 | 描述 = 落地正文，最敏感 | merge subject / 分支 trailer |

## 常见误区

- **“PASS 就是 GitHub approval”**：不是；required approval 数为 0；评论不计入。
- **“PASS 后改个描述没关系”**：作废 PASS；落地提交不跟着变，且可能 trailer 失位。
- **“CI 绿就能 merge”**：`ci-ok` 绿只说明 PR head 通过；没有 PASS 时仍能点 Merge，但绕过了评审与快照。
- **“revert 能修元数据”**：revert 只回滚当前树；坏 message 还在，且多一个提交/PR。
- **“评审记录写进 PR 描述方便”**：docs 描述会成为 squash 正文，永久落库；评审记录只进评论/journal。
- **“同账号多 agent 等于独立审批”**：GitHub 只看到一个人；独立性在 runtime/模型层，不是平台身份。
- **“pr-meta 能保证描述不变”**：不能；body 编辑不换 SHA，check 可能 stale。

## 延伸

- 规则原文：`AGENTS.md`「评审协议」子节；`docs/guides/git-workflow.md` 第 4 步。
- 修复与撤回：`merge-integrity` proposal（评审中；快照合并、P2a/P2b、撤回窗口、拟立的历史修复 ADR）。
- CI 门禁：`docs/guides/ci-gate.md`（pr-meta/C6 的位置与结果矩阵）。
- 来源：ADR-0004（署名）、ADR-0005（squash）、ADR-0007（授权）、ADR-0009（CI 门禁）。
