---
title: "合并完整性与历史修复：快照合并、撤回窗口与 PR 编号守恒"
author: foamshadow
date: 2026-11-16
status: adopted
tags: [se-arch, tool-git, tool-ci]
related: [ADR-0004, ADR-0005, ADR-0007, ADR-0009, ADR-0010, ADR-0011, SPEC-0001]
adopted-as: "AGENTS「分支与版本」合并与同步规则（含远端重写对齐）+ docs/guides/merge.md + scripts/merge.sh、scripts/retract.sh（task merge / task retract）+ rulesets RS-1/2/3 + ADR-0010"
---

# 合并完整性与历史修复

## 背景

2026-11-16 PR #22（agent-collaboration 教学版）暴露了一条完整故障链：

1. PR head 的 CI 绿（`ci-ok`）；`REVIEW: PASS` 后，PR 描述被追加了一段评审清单；
2. squash merge 时，GitHub 用**描述**生成落地提交，`Assisted-by` 不再位于正文末尾；
3. dev push 的 attribution 判红——PR 已合并，push CI 是**事后发现**；
4. 先用 revert + redo + 单独 journal PR 补救，dev 出现 revert/redo 节点，PR 号 #22–#25 连续消耗；
5. 最后 force reset dev 回 `1d622c3`，再用 #26 re-land，历史才变干净。

由此得到三个目标，它们彼此冲突：

1. **history 美观**：dev 第一父链只有任务 merge / docs 最终单提交，没有 revert/redo 对；
2. **commit 准确**：落地提交的正文与树，就是被评审、被合并的那一份；
3. **可溯源**：commit → PR → review/CI 能对上；PR 号尽量不浪费，但不以牺牲前两项为代价。

核心矛盾：GitHub 原生只有 revert（+1 提交、+1 PR）；“零补救提交 + 平台可溯源”只能靠受控 rewrite。规则要把 rewrite 关进笼子，而不是临时关保护硬推。

## 提议

### 0. 决策基线（2026-11-17）

- **软约束**（已定，#28 评审协议毕业）：不引入 `review-gate` / merge bot；`required_approving_review_count=0`；PASS 是评论，不是 approval。
- **合并授权**（已定）：人类先授权，agent 再执行合并；脚本是执行工具，不替代授权。
- **docs / code 分路径**（已定）：docs 用 squash + body 快照；code 用 `--no-ff` + title 校验 + 分支提交 trailer。
- **收口后**（ADR-0010 #29 已 accepted）：dev/main/tag 允许 rewrite，但**只允许 message-only（tree 不变）**；内容 rewrite 不允许；docs 单提交已撤销（ADR-0005 `deprecated`）；AGENTS 流程冻结线已同步。

### 0.1 现行依赖（事实）

- **评审协议已毕业**（#28）：PASS 的 `target` / `body-sha256` / `Reviewer` / PASS 后冻结，真源是 `AGENTS.md`「评审协议」+ `docs/guides/review.md`；本 proposal 不再定义评审流程，只消费 PASS。
- **评审署名双轨**（ADR-0011）：PR 状态评论的角色行（BLOCKED/PASS `Reviewer`；REVIEW-FIX `Author`）；commit 级提交前互审写 `Reviewed-by`（opt-in）；`Pi` / `glm-5.3` 已登记（与 `glm-5.3-flash` 区分）；#27–#29 的历史缺口不回填。
- **C6 `pr-meta` 已落地**（#27）：PR 描述末行 trailer、正文无评审状态行（含 `Reviewed-by` 行）；并入 `ci-ok`；不查 docs 提交数、不校验评论层 Reviewer（ADR-0011）。
- **ADR-0010 已 accepted**（#29）：message-only rewrite；docs 单提交撤销；ADR-0005 `deprecated`。
- **已实现 / 已实测**：`scripts/retract.sh` + `task retract` 已随 #42 落地；三 ruleset 迁移已完成（2026-11-18）；`(#N)` 已实测结案（2026-11-17，#33：显式 subject 逐字落地、不重复追加，见演进记录）。
- **已实现 / 已毕业**：`scripts/merge.sh` / `task merge` 已落地（2026-11-18，PR #50）；pilot 3/3 已毕业（2026-11-19，code #50 / docs #51 #52）。Q1 撤回窗口已定稿（三条件，见开放问题 1）。

### 1. 合入前：快照合并（P0，硬保证）

> 术语：PASS = 评审者按完整清单发出的 `REVIEW: PASS` 状态评论（不是 GitHub approval；合并授权另按 ADR-0007）。它是 `AGENTS.md`「评审协议」+ `docs/guides/review.md` 的项目级规则（#28 已毕业），不是 GitHub required approval/check；GitHub 侧硬门禁目前只有 `ci-ok`。PASS 评论末行记 `Reviewer: <harness>:<model>`（键表同 `Assisted-by`，人类写 `none`）；同账号下这是声明，不是平台验证。本 proposal 不重新定义评审流程，只规定 PASS 时抓快照；快照脚本是流程级约束，Merge 按钮仍可绕过。

PASS 时抓 `title + body` 快照并记 hash；合并时用快照生成 squash 正文，不读实时描述。

- PASS 评论按 AGENTS 模板带 `target`、`body-sha256: <sha256(title + "\n" + body)>`、末行 `Reviewer: <harness>:<model>`。
- 合并脚本 `scripts/merge.sh <PR>`：
  1. 取 PR 当前 `title/body`；
  2. 校验末行是 `Assisted-by` trailer、正文无评审状态行（REVIEW / Reviewer / Author / Reviewed-by；**有意与 C6 冗余**：脚本不依赖 CI 时序，C6 只是 PR 时的 backstop）；
  3. 与 PASS 评论的 hash 比对；不一致即作废 PASS，退回重审；同时要求 PASS 评论末行有 `Reviewer:`；
  4. docs 用快照合并：`gh pr merge --squash --subject "<title> (#N)" --body-file <snapshot> --match-head-commit <target>`；code 用 `gh pr merge --merge --match-head-commit <target>`（不传 subject/body，默认标题由仓库设置追加 ` (#N)`；merge commit 正文为空）。
- 作者在 PASS 后不得编辑 title/body；编辑即作废 PASS。
- 第一次使用前验证 `(#N)` 后缀：自定义 subject 是否被平台重复追加。验收标准固定为“dev 上 subject = `标题 (#N)`、body = 快照”。已于 #33 首用实测通过：subject 逐字落地（手写的 `(#33)` 无重复追加）、body 与快照逐字节一致。2026-11-18 #41 补记：GitHub squash 会去掉正文末尾换行（1008→1007 bytes）；校验按 `rstrip("\n")` 归一化，内容行一致即通过。

#### docs 与 code 分路径

- **docs**：squash；快照 body 生成落地正文；`gh pr merge --squash --subject "<title> (#N)" --body-file <snapshot> --match-head-commit <target>`。
- **code**：`--no-ff`；merge commit 正文为空；快照只冻结 title / 描述；脚本用 `gh pr merge --merge --match-head-commit <target>`（不传 subject/body，默认标题路径追加 ` (#N)`）；分支提交的 trailer 由 attribution 校验。
- **PASS 后改描述**：作废 PASS，需重新 PASS（新 target/hash）并重新快照。

#### 手动合并警告（零成本兜底）

手动点 GitHub Merge 按钮 = 绕过快照脚本。PASS 评论附以下警告，`docs/guides/merge.md` 已同文落地（#33）：

> [!WARNING]
> 手动合并前逐项确认：
> - [ ] 标题 = 落地主题，且 PASS 后未改
> - [ ] 描述只含最终变更：无评审记录、修正清单、试错过程
> - [ ] 描述最后一行是 `Assisted-by: ...`，其后没有任何内容
> - [ ] 描述与 PASS 一致（`body-sha256` 相同；否则重新 PASS）
> - [ ] `ci-ok` 绿；docs 单意图（提交数不限，ADR-0010 已撤销单提交）；base/head 方向正确
> - [ ] 无 open blocking；PASS 的 target = 当前 head
> - [ ] 合并方式：docs squash；feat/fix `--no-ff`；不手改 message
>
> 合并后立刻检查落地提交的 subject/body；不符合按 P1–P4 处理，不要点 Revert。

注意：警告**不能**放在 PR 正文的 trailer 之后——会随 squash 进入提交正文，正是 #22 的成因；只放 PASS 评论与指南。

出现时机：评审者发 `REVIEW: PASS` 时随评论出现；GitHub 的 Merge 对话框不接受自定义警告文本。已决定只随 PASS 评论，不额外加 bot 评论或 `review-gate` required check（软约束，#28）。

### 2. 合入后：先分类，再选修复阶梯

| 类型 | 判断 | 首选 |
| --- | --- | --- |
| **元数据**（message / trailer / 描述） | 内容正确 | 头部 + 窗口内：**P2b reset + re-land（默认，平台溯源）** 或 P2a amend（省号退路）；否则 P1 接受 + journal，或按 ADR-0010 D1 全量仪式做 message-only（窗口外/非头部，慎用） |
| **内容错误**（非敏感） | 当前树必须改 | P3 revert 或 fix-forward；ADR-0010 不允许内容 rewrite |
| **敏感数据**（密钥 / PII / 法律） | 不可留在任何历史 | 独立事件响应：轮换 + rewrite + 平台清理；**revert 不够** |
| **仅 CI 红** | 平台 / 配置 | fix-forward 或 rerun；不改历史 |

修复阶梯：

- **P0 合入前**：同分支 amend / force，PR 号复用；坏提交不进 dev。
- **P1 接受 + journal**：元数据、非头部、窗口外，且不走 ADR-0010 D1 全量仪式；0 新提交、0 新号；坏 message 保留，记执行差异。
- **P2a 头部 amend**：坏提交在 dev 头部、窗口内、无人依赖、rewrite 已授权；**只改 message（tree 不变，ADR-0010 不允许内容）**；0 新提交、0 新号；PR 页面仍指旧 SHA，需在 PR 描述里记新 SHA。
- **P2b reset + re-land**：坏提交在头部/窗口内；force reset 丢掉坏提交，再用新 PR 重做**同一内容**（内容不变）；+1 号、clone reset；历史干净，新 PR 页面与平台溯源干净；旧 PR 页面仍指旧 SHA。
- **P3 revert**：内容必须撤、窗口外、有人依赖；+1 提交、+1 号；revert 不清历史，且 diff 可能再次暴露内容。
- **P4 revert + redo**：撤了还必须重做；+2 号；最后手段。
- **双轨边界**：P2a/P2b 是快速通道，只覆盖“dev 头部 + 窗口内”；ADR-0010 D1 的 message-only 全量仪式（备份、区间映射、tag 重打、journal、保护恢复）可用于窗口外/非头部，但不进入本阶梯，也不把窗口变成 ADR-0010 的唯一授权边界。
- **code 路径**：merge commit 正文为空；merge subject 错可 P2a amend merge commit；分支提交 trailer 错要 rebase 分支 + 重建 merge（通常走 P2b reset + re-merge）；P3 revert 只用于内容回滚，不修 trailer；不要把 docs 的 body 快照套到 code。
- **revert 范围**：P3 只在内容必须撤、且 rewrite 不可用时使用；元数据不 revert；revert 应很少使用。

#### 撤回窗口（2026-11-18 定稿）

三条件同时满足才允许 P2a / P2b（Q1；`retract.sh` preflight 校验）：

1. 坏提交在 dev 头部（`origin/dev` 与本地 `HEAD` 都等于 `bad`）；
2. 除 `dev` / `origin/dev` / `backup/*` 外，无分支以 `bad` 为祖先（`git for-each-ref --contains`，含 main 在内一律拦）；
3. 距合入 ≤ 24 小时（`--window-hours` 可调）。

窗口外仍须：人类所有者明确批准；先建备份分支、推完恢复分支保护并通知所有 clone reset；在 PR 评论 + 下一次 journal（搭车）留痕，不单独开号。

窗口外：内容走 revert；元数据默认接受 + journal，或按 ADR-0010 D1 全量仪式做 message-only（窗口外/非头部，重流程，慎用）。**本窗口只约束 P2a/P2b 快速通道**；它不是 ADR-0010 D1 的授权边界。非头部 rebase 一串的风险高于收益，不进入 P2a/P2b。

### 3. 平台溯源与 PR 编号

“溯源”分两层，不能混：

- **文本级**：commit subject 里的 `(#N)`，`git log` 可搜到 PR；amend 保留 subject 即可保住这一层。
- **平台级**：commit 是某个 PR 的 merge commit，GitHub 上可双向点通；只有 re-land 能做到，amend 做不到。

已合并 PR 的 merge SHA 不可编辑；旧 PR 页面不会因 rewrite 消失；PR 号 merge 后不可复用。能省的只有“额外 PR”：

- 合入前同号 amend；
- 合入后窗口内：P2a amend 不新开号；P2b re-land 多一个号（买平台溯源）；
- 事故 journal 搭下一次 PR，不单独开号；
- 多个小修复合并到一个 PR。

**amend 与 re-land 的取舍**：按“history 美观 + commit 准确 > 平台溯源 > 省号”的优先级，默认 **P2b：force reset + re-land**——多一个号，换干净权威页；团队不能 reset、或旧页面可接受时，用 P2a amend 省号。旧 PR 标注 `superseded by #N`，保留为失败尝试的审计页；journal 记区间映射 `A..B → A'..B'`（ADR-0010 D1.3）。

### 4. 合规 rewrite 的基础设施

- **ruleset + bypass actor（已落地，2026-11-18）**：dev / main 使用三条 ruleset，classic branch protection 已删除。
  - **RS-1 `dev-main-pr-gate`**：require PR + required `ci-ok`，无 bypass；require-PR 同时拦直推与 force。
  - **RS-2 `dev-main-history`**：`non_fast_forward`，仓库 admin 角色（`actor_id: 5`，`RepositoryRole`，`bypass_mode: always`）可 force。它只服务 P2b 的 force push，且单独时是惰性的——RS-1 仍会拦。
  - **RS-3 `dev-main-undeletable`**：`deletion`，无 bypass。删除保护不能挂在 RS-2 上：RS-2 的 owner bypass 会顺带放开删分支，迁移即净弱化。
- **retract 窗口**：`scripts/retract.sh` 先 `PUT {"enforcement":"disabled"}` 关 RS-1（秒级），force push 后立即恢复 `active`；RS-2 / RS-3 全程 active。窗口内 PR 与 `ci-ok` 同时暂停，窗口外正常。脚本首尾都按 `scripts/rulesets.expected.json` 全字段 verify；恢复失败 exit 99，打印快照路径与手工恢复命令。
- **审计口径（实测降级）**：evaluation API 对 bypass 推送返回空数组；个人仓库没有 org audit log API。证据链 = `rules/branches/*` 回显 + git server 消息 + web security log（如可见）+ 脚本快照 + journal；**不主张**“平台 bypass 审计”。
- **`scripts/retract.sh`**：preflight（头部 / 窗口 / 干净树 / origin 同步）→ 备份（本地 + 远端）→ snapshot → disable RS-1 → `reset --hard <bad^>` → `--force-with-lease` + `--force-if-includes` → enable RS-1 → verify → 输出 clone reset 指引。`scripts/merge.sh` 已落地（2026-11-18），合并路径由 `task merge` 执行；pilot 尚未完成。
- 每次恢复后必须验证：RS-1 active 且全字段匹配 expected；RS-2 / RS-3 active。classic protection 已删除，不应重新出现（迁移后由 ruleset 承担）。
- 当前 `required_approving_review_count=0`；同账号无法 native approve；真独立审批需另一个账号（人类成员），不在本 proposal 首次落地。
- **收口后**：ADR-0010（#29 accepted）允许 dev/main/tag 的 message-only rewrite；内容 rewrite 不允许；AGENTS“流程冻结线”已同步；main/tag 的 tag 重打、发布通知、备份条件由 ADR-0010 D1 规定。

### 5. CI 缺口

- PR 的 `ci-ok` 检查的是 PR head 提交；squash 提交在 merge 时生成，PR CI 没看过它。
- push 的 `ci-ok (push)` 是事后发现，不是 required；它拦不住 merge。
- C6 已落地（PR #27）：`pr-meta` job 校验 PR 描述末行 `Assisted-by` trailer、正文无评审清单段；失败并入 `ci-ok`；push 下 skipped；docs 单提交不查（ADR-0010 已撤销）。触发：`pull_request` 的 `opened / edited / synchronize / reopened`（必须含 `edited`，因为 body 编辑不换 SHA）；只跑 PR，不跑 push。价值是**PR 时的 body backstop**；body 在 check 之后仍可改，check 可能 stale，硬保证仍是快照合并。ADR-0009 部分取代已由 ADR-0011 闭合（#31）。
- PASS 是评论约定，不是 CI 检查；当前 required 只有 `ci-ok`。快照脚本读取 PASS 评论，属于流程级约束；Merge 按钮仍可绕过。
- 没有 PASS 之前，只要 `ci-ok` 绿，Merge 按钮就可用；GitHub 不要求 PASS。PASS 只是流程约定，不是 merge 前置条件。
- 不接受“靠 auto-merge / merge queue 解决”：两者仍读实时描述；queue 只验树，不验提交正文。

## 开放问题

以下只列尚未决定、且会改变实现的项；已决项见 §0。

1. ~~撤回窗口：24 小时 + 下一任务分支前（取先到）是否过短/过长？还是只按“下一次 push CI 绿之前”？~~ **已定稿（2026-11-18，三条件）**：① `bad` 仍是 `origin/dev` 头部（硬——等价于“下一合入前”，dev 侧有后代即关窗）；② 无任何分支以 `bad` 为祖先（硬——`git for-each-ref --contains` 在 `refs/heads` + `refs/remotes` 中仅允许 `dev` / `origin/dev` / `backup/*`，其余任何 ref 含 bad 即拦，含 main；同机工作树共享对象库、可见暴露全覆盖，异机 clone 由 ③ 兜底；`retract.sh` preflight 已实现）；③ `age ≤ 24h`（`--window-hours` 可调，纯时间代理）。任一不满足 → revert 或 ADR-0010 D1 全量仪式。否决口径：“下一次 push CI 绿之前”过短且语义错（#34 即 CI 全绿的坏账本，push CI 只验构建不验账本）；“下一任务分支前”方向对但切分支中央不可判定，落为条件②的可执行检查。
2. ~~合规 rewrite：迁 ruleset + bypass actor，还是先用 break-glass 脚本？~~ **已结案（2026-11-18）**：三 ruleset 迁移完成（RS-1 PR+ci 无 bypass / RS-2 force 带 owner bypass / RS-3 deletion 无 bypass），classic protection 已删；`scripts/retract.sh` 走“秒级 disable RS-1 + force + 恢复”。break-glass 不再是日常路径。审计主张按实测降级：个人仓库无 org audit log，evaluation API 对 bypass 推送为空。
3. ~~`gh pr merge --subject` 的 `(#N)` 行为需实测~~ **已结案（2026-11-17，#33）**：自定义 subject 被平台逐字落地、**不重复追加**；docs 命令保持 `--subject "<标题> (#N)"` 现状；code 路径不显式传 subject（见演进记录）。
4. ~~`scripts/` 放根目录还是 `tools/`？随 t1 Taskfile 落地，还是单独 infra 任务？~~ **已结案（2026-11-18）**：根 `scripts/`；`scripts/retract.sh` + `task retract` 已随 #42 落地；`scripts/merge.sh` / `task merge` 已随本任务落地（2026-11-18）。
5. ~~旧 PR 页面标注：只改 title/description，还是另加 journal？~~ **已结案（2026-11-18）**：评论 `superseded by #N` + journal 映射；#34→#36 已实战。

## 毕业条件

- **pilot**：`scripts/merge.sh` 落地后，至少 3 个 PR（docs 与代码各至少 1 个）用它合并；0 次“PASS 后描述变更导致落地正文不一致”；`(#N)` 行为验证通过。`merge.sh` 已落地；pilot **3/3，已毕业**（2026-11-19：#50 code 自合并 dev `792f64f`；#51 docs dev `dce0ab0`；#52 docs 自合并 dev `5b6185b`）——0 次「PASS 后描述变更」违例，`(#N)` 四度实证（#33/#50/#51/#52）。
- **撤回演练**：基本完成（#34→#36，2026-11-17，P2b）：历史干净、保护恢复、旧 PR 标注；ruleset 迁移于 2026-11-18 完成，`retract.sh` 的 production dry-run 通过；**生产实弹完成**（2026-11-19 敏感数据演练，retract 全程 54s，journal `2026-11-19-foamshadow-secret-drill.md`）。clone 通知**闭项（2026-11-19）**：操作者外持有者集合为空 → 通知义务空满足；机制 = retract 输出 + AGENTS「远端重写对齐」agent 提示（随本 PR 落地）；git 自保护使未通知 clone 无法回写远端（含已撤提交的 push 必然 non-fast-forward 被拒）——首次外部 clone 后的真实 rewrite 为机制首次真实行使。
- **敏感数据桌面演练**（假密钥）：**完成**（2026-11-19，PR #53/#54 + journal）：轮换（桌面替代）+ rewrite（retract 生产首弹）+ 验证（8 项独立清单）+ 确认 revert 不在流程。
- **毕业产物**：评审协议已毕业（#28，AGENTS + guide）；C6 `pr-meta` 已落地（#27）；`docs/guides/merge.md` 已落地（#33）；ADR-0009 部分取代已闭合（ADR-0011）；`scripts/retract.sh` + `task retract` 已落地（#42）；三 ruleset 迁移已完成（2026-11-18）；Q1 撤回窗口已定稿（2026-11-18，三条件，preflight 守卫随本任务补齐）；`scripts/merge.sh` / `task merge` 已落地（2026-11-18）；pilot 3/3（#50 / #51 / #52）；**已毕业（2026-11-19，见变更记录末条）**。
- **依赖**：t1 根 Taskfile 已就绪；ruleset 迁移已完成（2026-11-18），作为独立 infra 操作记录于迁移 journal。

## 被否方案

- **revert 修元数据**：+1 提交、+1 号，坏 message 还在；#22 的 5 个号就是这样来的。
- **删分支 / 删 dev 重建**：不省号；删 dev 要关保护、可能影响 open PR；与 force update 等价但副作用更多。
- **auto-merge / merge queue 单独用**：仍用实时描述；queue 只验树，不验提交正文。
- **所有情况都 force rewrite**：破坏 clone 与 PR 溯源；窗口外/非头部风险过高。
- **所有情况都接受**：坏 message 永久留账本，审计失真。

## 演进记录

- 2026-11-16 由 #22 事故讨论起草：5 个 PR 号、revert/redo、force reset + re-land；确立“先分类、元数据不 revert、快照合并、撤回窗口”四个结论。
- 2026-11-16 第一轮决策：PASS 模板归 review-protocol；软约束（不引入 review-gate/merge bot）；人类授权后 agent 执行合并；docs/code 分路径；收口后仍允许 rewrite（当时需同步 AGENTS 冻结线，11-17 已完成）；PASS 模板加 `body-sha256`；`required_approving_review_count` 保持 0；评论靠共识管理，不镜像。
- 2026-11-16 第二轮决策：ADR-0010 方向（dev/main/tag message-only；内容不允许；journal 留痕）；docs 单提交拟撤销；review-protocol 计划先毕业。后续 11-17 已落地（review #28、ADR #29）。
- 2026-11-17 事实对齐：review-protocol #28 毕业（PASS 规则迁 AGENTS/guide）；C6 #27 落地；ADR-0010 #29 accepted（ADR-0005 `deprecated`、docs 单提交撤销）；scripts 未实现、`(#N)` 未实测。
- 2026-11-17 开放问题 3 实测结案（#33）：`docs/guides/merge.md` 首版落地，按快照合并手动六步合并——PASS `target` / `body-sha256` 校验通过；落地 subject 的手写 `(#33)` **逐字落地、无重复追加**；落地 body 与快照逐字节一致；dev push CI 一次全绿（0 补救提交、0 额外号）。顺带证伪 proposal §1 的 code 命令：显式 `--subject "<标题>"` 因平台不追加会丢 `(#N)`，merge.sh 定稿时按 guide 的默认标题路径反向统一；同批修正两处过时记账（ADR-0009 部分取代已由 ADR-0011 闭合、`(#N)` 移出未实测清单）。
- 2026-11-17 P2b 首次实弹（#34 → #36）：#34 按旧 §1 命令显式 `--subject` 合并，subject 缺 ` (#34)`；备份 `b42eee2`、dev reset 至 `94580a8`、旧 PR 标 superseded、#36 以默认标题路径重落 `d071f24`；保护开关与 dev push CI 均核验。§1 的 code 命令已在本条后同步修正。
- 2026-11-17 t1 收尾对齐：同文“待建”改已落地（#33）；未实现行 / 开放问题 2 / 撤回演练补 P2b 事实；开放问题 5 增实战口径。
- 2026-11-18 ruleset 迁移与 `retract.sh` 落地（#42）：classic protection 删除；RS-1/2/3 三规则集不对称模型；`scripts/retract.sh` + `task retract` 落地；Q2/Q4/Q5 结案，Q1 保留开放。PUT 最小体 merge 语义、恢复 payload 形状坑、dry-run 局限、B1 删除保护拆分见 journal `2026-11-18-foamshadow-ruleset-migration.md`。
- 2026-11-18 快照合并脚本落地（PR #50）：`scripts/merge.sh` + `task merge`（PASS target/hash、docs squash 快照 body、code `--no-ff`、合并后落地核验；`task test:merge` fixture）；pilot 自此可开始。
- 2026-11-18 merge.sh 首次实弹（PR #50，pilot code 1/3）：`task merge` 自合并；PASS target/body hash 复核、合并后 subject/body/第二父核验通过，N1 路径实测。
- 2026-11-18 Q1 定稿（三条件撤回窗口，`fix/infra-retract-window-guard`）：bad 在 dev 头部 + 无分支以 bad 为祖先 + age ≤ 24h；retract preflight 补 `for-each-ref --contains` 守卫（`dev` / `origin/dev` / `backup/*` 白名单，其余含 bad 的 ref 即拦，含 main；同机可见暴露全覆盖，异机 clone 由时间兜底）；同批补 ADR-0007 D5 理由（ADR-0010 撤销其机制前提，规则不变、理由改为真源传播成本）。
- 2026-11-19 pilot 2/3（docs: PR #51）：`task merge` docs 路径首次实弹，squash 落 dev `dce0ab0`；PASS 快照 body-sha256（`a5eb7c37`）与落地正文密码学比对一致，“0 次 PASS 后描述变更导致落地正文不一致”违例保持 0；N1 docs 路径实测闭合。
- 2026-11-19 **毕业**（本 PR）：pilot 3/3（#50 code / #51 #52 docs，全程 `task merge`，0 次「PASS 后描述变更」，`(#N)` 四度实证）；撤回演练闭项（生产实弹 + clone 通知空满足论证 + AGENTS「远端重写对齐」agent 提示落地）；敏感数据桌面演练完成（retract 生产首弹 54s、四条发现，journal `2026-11-19-foamshadow-secret-drill.md`）；status → adopted。手动流程保留为脚本不可用时的兜底。
