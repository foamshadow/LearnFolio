---
id: ADR-0011
title: "评审署名双轨：PR 状态评论角色行与 commit 级 Reviewed-by"
status: accepted
date: 2026-11-17
author: foamshadow
tags: [se-arch, tool-git, tool-ci]
related: [ADR-0004, ADR-0009, ADR-0010, SPEC-0001]
supersedes: "ADR-0009"
superseded-by: ""
---

# ADR-0011：评审署名双轨

> 部分取代：本 ADR 只取代 ADR-0009 中与 C6 `pr-meta` 相关的三处——D1 的 job 清单、D2 的 push 跳过集合、D3 的结果矩阵。ADR-0009 的其余决策（单 workflow、required 只挂 `ci-ok`、push 事后发现、标题/署名校验、自举等）继续有效；ADR-0009 因此标 `deprecated`（部分条款失效），不代表整篇失效。
>
> 按 `docs/README` 的部分取代约定，ADR-0009 只标 `deprecated`、不填 `superseded-by`（与 ADR-0005 被 ADR-0010 部分取代的先例一致）；反查用 `git grep 'supersedes:.*ADR-0009'`。

## 背景（Context）

- 2026-11-17 核对 `merge-integrity` proposal 时发现：实际评审来自 **Pi:glm-5.3**，但 AGENTS 的 harness 表没有 `Pi`、model 表没有 `glm-5.3`；`glm-5.3` 与 `glm-5.3-flash` 是两个模型，不能互相代替。
- 评审发生在两个不同层次：
  - **PR 级**：提交之后、合并之前的合并审查；状态评论承载事件（BLOCKED / REVIEW-FIX / PASS）。
  - **commit 级**：重要 commit 在**提交之前**由另一评审者（agent 或人类）做文件级互审，检查整个待提交内容；reviewer 审完，commit 才生成。提交之后才发生的审查，不回头改旧 commit，交给下一个 commit 或 PR。
- 当前规则只显式写了 PASS 的 `Reviewer` / REVIEW-FIX 的 `Author`；BLOCKED 的角色行只在模板里，未升为规则。commit 级互审则完全没有署名载体。
- 过去 #27 / #28 / #29 的 PR 级 PASS 评论存在缺席或署名与事实不符；已决定不补历史。
- C6 `pr-meta`（#27）在评审协议之后落地，只校验 PR 描述末行 `Assisted-by` 与“无 `## 评审` 段”；它没有 ADR 记录，ADR-0010 把“C6 对 ADR-0009 的部分取代”列为独立欠账。
- 约束：所有 agent 共用 `foamshadow` GitHub 账号，评论是声明（claim）不是平台证明（proof）；PR 事件 payload 不含评论；docs PR 描述会成为 squash 正文；历史默认不重写；merge commit 由平台生成、无法携带 trailer。

## 决策（Decision）

### D1 双轨：PR 状态评论 + commit 级 Reviewed-by

**PR 级**

- 所有评审状态评论都带角色行：`REVIEW: BLOCKED` / `REVIEW: PASS` 末行 `Reviewer: <harness>:<model>`；`REVIEW-FIX` 末行 `Author: <harness>:<model>`；人类写 `none`。
- 这是协议软要求：该写，但 CI 不校验评论；缺失不阻断合并，只留下“这条状态是谁发的”缺口。
- PR 描述只放最终变更；评审状态只在评论。

**commit 级**

- 重要 commit 在提交前由另一评审者（agent 或人类）审完**整个待提交内容**时，commit trailer 块增 `Reviewed-by: <harness>:<model>`；一个 reviewer 一行，按评审顺序，不表达权重。
- `Reviewed-by` 是 opt-in：不强制要求存在；缺失只表示“没有 commit 级评审声明”，不判违规，也不代表未评审。
- 只审了部分文件时不写 `Reviewed-by`；未覆盖的部分留到下一个 commit 或 PR。`Reviewed-by` 不携带 scope 字段，避免“commit 级声明覆盖未审文件”。
- 提交后再发生的审查不改旧 commit；审查结论走 PR 评论，或等下一个 commit / PR 再按提交前规则记录。
- reviewer 必须与同一 commit 的所有 `Assisted-by` 参与者不同（互审不是自审）；人类评审的 `none` 是角色标记，不参与身份比较；多个 reviewer 不重复。
- 内容变更（amend 改树、冲突 rebase、fixup）使 `Reviewed-by` 失效，必须重审；tree 不变（message-only rewrite / 无冲突 rebase）可保留。
- merge commit 不写 `Reviewed-by`（平台生成，无法携带；PR PASS 已覆盖合并审查）。
- docs squash 的落地提交不保留分支提交上的 `Reviewed-by`（squash 正文来自 PR 描述，C6 禁止评审行）；docs 的评审记录走 PR 状态评论 / journal。
- 人类评审写 `Reviewed-by: none`；同一 commit 有多名人类评审时，trailer 仍为 `none`，具体人名以 PR 评论 / journal 为准。

### D2 登记 Pi 与 glm-5.3；键表闭合

- harness 表新增 `Pi`；model 表新增 `glm-5.3`。`glm-5.3-flash` 保留，二者是两个独立键，不得互相代替。
- `Assisted-by` / `Reviewed-by` / `Reviewer` / `Author` 使用同一闭合键表；人类写 `none`。
- 未登记键不得写入上述任何位置；新 harness / model = AGENTS 表加一行 + PR。
- 本 ADR 随附的 AGENTS 更新是登记生效点；登记后 `Pi:glm-5.3` 才是合法取值。

### D3 pr-meta 是 body backstop，不是 review gate

- `pr-meta` 只校验 PR 描述：最后一行非空行必须是合法 `Assisted-by` trailer；正文不得含评审状态行（`## 评审`、`REVIEW:`、`REVIEW-FIX`、`Reviewer:`、`Author:`、`Reviewed-by:` 开头的行）。
- 不校验评论层 `Reviewer`，也不校验 commit 的 `Reviewed-by`：PR 事件 payload 不含评论，commit trailer 由 attribution job 校验；不新增 review-gate / bot（软约束，#28）。
- 发现描述违规时判红；PASS 后编辑描述仍作废 PASS（协议层）。C6 只是合并前的 body backstop，不能替代 PASS 快照。
- 部分取代 ADR-0009：
  - D1 的 job 清单增 `pr-meta`；
  - D2 的 push 跳过集合增 `pr-meta`（与 `changes` / `title` 同理：依赖 PR 上下文）；
  - D3 的结果矩阵：PR 下 `changes` / `title` / `pr-meta` / `attribution` 必须 success；push 下 `web` / `api` / `attribution` 必须 success，`changes` / `title` / `pr-meta` 允许 skipped；`ci-ok` 的 `needs` 必须包含 `pr-meta`。

### D4 attribution 只校验 Reviewed-by 格式、不校验存在性

- `attribution` job 仍校验每个非 merge 提交的 `Assisted-by` 存在性与格式。
- 若提交带有 `Reviewed-by:` 行，逐行校验格式；没有 `Reviewed-by` 不报错。这样 opt-in 语义不会被 CI 变成事实强制。
- 不校验 reviewer 是否真的审过、是否与 `Assisted-by` 不同——这些是声明层规则，机械校验会把“声明”伪装成“证明”。格式校验只防拼写 / 键表漂移。
- `Reviewed-by` 与 `Assisted-by` 同形正则；merge commit 不参与（`--no-merges`）。
- 实现顺序：本 ADR 先定规则；`check-pr-meta.sh` / `check-attribution.sh` 的收紧随紧随的 fix PR 到达（D6 首个消费者）。
- fix PR 范围：`check-pr-meta.sh`、`check-attribution.sh`、`aggregate.sh` 的矩阵权威注释、`PULL_REQUEST_TEMPLATE.md`；同时补 `SPEC-0001-A5` 的结果矩阵与变更记录（#27 起的存量），脚本落地后移除 `ci-gate.md` 的过渡注记。

### D5 历史缺口不回填

- #27 / #28 / #29 的 PR 级 PASS 评论（缺席或署名与事实不符）不补发、不改写、不追认；合并结果保持不变。
- 历史 commit 若没有 `Reviewed-by`，不追溯补写；规则从本 ADR 起向前生效。
- 缺口以 journal 为准；复盘价值在“记录”，不在“补签”。

### D6 本 ADR 的自举

- 本 ADR 合并前，`Pi:glm-5.3` 尚未生效；本 PR 由人类评审，PASS 末行写 `Reviewer: none`。
- 合并后 `Pi:glm-5.3` 才可用于后续 PR：首个消费者是紧随的 fix PR（`fix/ci-review-attribution`），t1 是第二个。
- 这是登记生效顺序，不是评审例外；不得把“先写未登记键、后补登记”变成常规路径。

## 被否方案（Alternatives）

| 方案 | 否决理由 | 翻转条件 |
| --- | --- | --- |
| 所有评审都只写 PR 评论 | commit 级提交前互审在合并审查之前发生，且未必有 PR；不写进 commit，分支删除后就不随提交保存 | — |
| 所有评审都写 commit `Reviewed-by` | PR 级评审发生在提交之后，补写要 amend / 额外提交 / 改写；平台 merge commit 也带不了 | 平台支持合并时自动追加 review trailer |
| 只给 PASS 加 `Reviewer` | BLOCKED / REVIEW-FIX 也是独立评审事件；只记 PASS 会让前几轮无主 | — |
| 要求每条评论都带角色行 | 行内评论只用于定位，不承载状态；会制造噪音 | — |
| `Reviewed-by` 强制每条 commit | 多数 commit 没有提交前互审；强制会逼出假声明，CI 也无法验证 | 团队把提交前互审设为所有 commit 的硬门 |
| 部分文件也写 `Reviewed-by` | 一个 trailer 声明覆盖整个 commit，未审文件会被误标；拆 commit / 留到下一个 commit 更诚实 | 引入可机械校验的 scope 字段 |
| 提交后 amend 补 `Reviewed-by` | 改写已提交内容 / 重写历史；违背“提交前审完”的时点语义 | — |
| 把评审记录写进 PR 描述 | #22 已证明：描述 = squash 正文，评审段会把 trailer 挤出末行，且永久落库 | 平台不再用描述生成 squash 正文 |
| CI review-gate 读评论校验 `Reviewer` | 评论不在 payload；同账号下仍是声明；与“不引入 review-gate”的软约束冲突 | 出现独立评审账号或平台可验证的 review 身份 |
| `required_approving_review_count=1` | 所有 agent 共用同一账号，GitHub 只看到一个人；设 1 会死锁 | 有第二个可用的评审账号 |
| 回填 #27–#29 的 PASS / 历史 `Reviewed-by` | 评论时间、target、hash 无法真实还原；补签只会制造假证据 | — |
| 把 `glm-5.3-flash` 当成 `glm-5.3` | 两个模型，能力/版本不同；混用会静默指错 | — |
| 用 `Assisted-by` 兼表评审 | 评审不是内容 authorship；角色混在一起后 `git log` 无法区分“谁写的”和“谁审的” | — |

## 后果（Consequences）

- 评审溯源分成两条：PR 评论看合并审查，commit trailer 看提交前文件互审；`git log --no-merges --grep='^Reviewed-by:'` 可筛出被审 commit。docs squash 的落地提交不保留分支 `Reviewed-by`，这类评审只留在 PR 评论 / journal。
- `Reviewed-by` 是 opt-in，缺失不代表未评审；审计不能把“没有 trailer”当成“没有 review”。
- 提交前审完的模型避免正常路径的 rewrite；提交后再审的内容不会回头改写旧 commit，代价是这类 review 只留在 PR 评论 / journal。
- 内容变更会使 `Reviewed-by` 失效；重审成本由改动者承担，不能用“trailer 跟内容走”自动继承。
- `Reviewed-by` 仍是声明：CI 只校验格式，不证明 reviewer 真的审过；不得用于归责或能力认定。
- `pr-meta` 收紧：PR 描述不得出现评审状态行或 `Reviewed-by:`；引用评审模板的 PR 需改为行内引用或缩进（脚本按行首匹配，不解析 Markdown）。
- ADR-0009 标 `deprecated`（部分）；读者查 C6 相关决策时须同时看 ADR-0011，其余 ADR-0009 条款继续有效。
- 新 harness / model 继续走登记 PR；`glm-5.3` 与 `glm-5.3-flash` 不会因同名前缀被合并。
- 提交消息多一行或几行 trailer；多 reviewer 时行数增加，但仍是 ASCII 可解析块。
