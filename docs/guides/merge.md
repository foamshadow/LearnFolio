---
title: "合并讲解：从 PASS 到落地提交，以及落地之后"
author: foamshadow
date: 2026-11-17
status: draft
tags: [se-arch, tool-git]
related: [ADR-0003, ADR-0005, ADR-0007, ADR-0009, ADR-0010, ADR-0011, SPEC-0001]
---

# 合并讲解：从 PASS 到落地提交，以及落地之后

## 讲给谁 / 前置知识

给两类读者：**合并执行者**（人类授权之后真正跑合并命令的人——今天通常是人类自己点合并或跑命令，agent 获授权后也可能执行），以及 **PR 作者**（合并后发现问题，需要知道为什么、有什么修复路径、什么不能做）。前置：读过 `git-workflow.md`（分支七类、PR 方向、docs 走 squash 与 code 走 `--no-ff` 已在那篇讲过）与 `review.md`（PASS 状态机、`target` / `body-sha256` 快照的评审侧语义）。不需要先懂 GitHub 的 merge API——本文就地讲。

本文是教学层，解释 `AGENTS.md`「分支与版本 · 合并与同步」的操作面与评审协议里"合并闸口"之后的事；规则冲突以 AGENTS 为准，本文不新增规则。合并完整性的设计论证、开放问题与毕业条件的真源是 `proposals/merge-integrity.md`（status: review）——本文引用它时**区分"已决"与"未决"**：已决部分（评审协议、C6、ADR-0010/0011）已进正式层；未决部分逐条标注"开放问题 N"，落地前不当作现行规则执行。

## 核心图景

一句话版本：**合并不是"点按钮让 GitHub 收下这个 PR"，而是"把被评审冻结的那份标题与正文，原封不动变成 dev 上的落地提交"；落地之后出了问题，先分类再动手——元数据错不许 revert，内容错不许 rewrite。**

理解它的关键是看见一道缝：**评审和 CI 验证的世界，与最终落地的世界，不是同一个东西**。

```
        评审与 CI 看到的世界                     落地的世界
┌────────────────────────────┐      ┌───────────────────────────────┐
│ PR head 提交（树）           │      │ squash / merge 提交             │
│   └─ ci-ok / attribution 验过│      │   └─ 合并那一刻由平台现场生成     │
│ PR 标题 + 描述               │ ───→ │   subject ← 平台按设置取标题     │
│   └─ PASS 冻结（target+hash）│      │   body    ← squash: 实时描述     │
│                             │      │           ← merge:  留空        │
└────────────────────────────┘      └───────────────────────────────┘
              ↑ 中间这道缝：没有任何人验证过"落地的那份文本"
   快照合并 = 合并时不读实时描述，读 PASS 冻结的副本 —— 缝被关闭
```

PR CI 验证的是 head 提交树；`pr-meta`（C6）验证的是 check 运行那一刻的描述。check 之后、点合并之前，描述仍然可以编辑，而且**编辑描述不触发任何 CI**（body 变了 SHA 不变）。squash 合并时平台拿实时的描述生成落地正文——这段文本从头到尾没有经过任何验证。#22 事故正是从这道缝里掉进去的。快照合并的全部意义：让"被评审的那份"与"落地的那份"重新成为同一份。

## 为什么这样设计

### 事故起点：#22 的 23 秒

PASS 之后、合并之前的窗口里，PR 描述被追加了评审清单，位置在 `Assisted-by` 之后。squash 落地时正文取自描述，trailer 不再位于末尾，dev push 的 attribution 判红——但 PR 已经合了，push CI 只能事后发现。随后 revert + redo + 单独 journal PR 的补救连续消耗 PR 号（连同事故 PR 共 #22–#26 五个），还在 dev 第一父链上留下 revert/redo 对，最后 force reset 回退、新 PR re-land 才收场。完整链条见 `review.md` 事故三与 `journal/2026/2026-11-16-foamshadow-pr22-metadata-incident.md`。

### 先懂技术：三种合入的落地正文从哪来

网页上的 Merge 按钮、`gh pr merge` 命令，本质都是调同一个 merge API，三种合入方式生成落地提交的原料不同：

| 合入方式 | 落地提交 | subject 来源 | body 来源 | 本仓库用法 |
| --- | --- | --- | --- | --- |
| **squash** | 一个新提交（分支提交不进历史） | squash 设置 = PR 标题，平台追加 ` (#N)` | squash 设置 = **PR 描述（实时）** | docs PR 专用 |
| **merge** | 双亲 merge commit（分支提交原样进入） | 设置"Default to PR title" = PR 标题 + ` (#N)` | 设置正文留空 = **空** | code PR 专用（--no-ff） |
| **rebase** | 分支提交逐个重放到 base | 各提交原 message | 原样 | **关闭**（与 --no-ff 互斥，ADR-0005） |

对 docs PR，squash 的正文就是 PR 描述——描述因此是**落地物本身**，不是附带的说明文字。这是理解一切 docs 描述纪律的钥匙：评审记录、试错过程、警告清单写进去，就会永久落进 dev。

对 code PR，merge commit 正文为空，真正的过程史在分支提交里（`--no-ff` 保留它们），逐提交的 trailer 由 attribution 校验把关——所以描述被改伤不到落地提交，风险只剩 subject 一行。

### docs 与 code 为什么分路径

落地正文的敏感度不同，防线就不同：docs 的正文来自可实时编辑的描述，所以需要快照合并这个硬保证；code 的落地正文为空、trailer 有 CI 兜着，所以只需冻结标题与描述（PASS 已做）+ 合并时不手改 message。一条 proposal、两套命令，不互相套用——把 docs 的 body 快照硬套到 code 上只会制造没人读的 merge commit 正文。

### 快照合并：合入前的硬保证（P0）

已决机制（proposal §1，与 `review.md`「PASS 的冻结与快照」同源）：PASS 评论冻结 `title + body` 并记 `body-sha256: sha256(title + "\n" + body)`；合并时用快照生成落地正文，不读实时描述；hash 对不上 = PASS 作废，退回重审。

快照脚本 `scripts/merge.sh` / `task merge` 已落地（2026-11-18）；下面六步是脚本内部执行的等价手动流程，也是脚本不可用时的兜底：

1. 从 PASS 评论抄下 `target <sha>` 与 `body-sha256`；
2. 核对 `target` 等于 PR 当前 head SHA——被评审的树必须就是将要合并的树，PASS 之后有过新 push 直接作废；
3. 导出 PR 标题与描述，本地计算 `sha256(title + "\n" + body)`，与 PASS 里的值比对；
4. 不一致 = PASS 已失效（描述被改过），**不合并**，退回重审拿新 PASS；
5. 一致后执行合并——
   - docs：把描述存成文件，`gh pr merge <N> --squash --subject "<标题> (#N)" --body-file <快照文件> --match-head-commit <target>`；
   - code：`gh pr merge <N> --merge --match-head-commit <target>`，**不传** `--subject` / `--body`，让仓库设置"Default to PR title、正文留空"生效。默认标题路径由 settings 追加 ` (#N)`（AGENTS 注 2026-11-14 实测；#36 于 2026-11-17 再次实证）。显式 `--subject` 被平台逐字落地、**不追加** ` (#N)`——#34 的事故即照抄旧 proposal §1 命令所致；proposal §1 已同步为默认标题路径；
   - 两条命令都带 `--match-head-commit <target>`：PASS 的 target 钉进合并动作，PASS 后 head 变动会被拒绝；
6. 合并后立刻核对落地提交：`git fetch origin && git log -1 --format="%s%n%b" origin/dev`——subject 与正文逐字对快照。

### 脚本入口：`task merge`

`scripts/merge.sh` / `task merge` 把上述六步封装成一个命令；`--dry-run` 只校验并打印计划，`--yes` 跳过交互确认。**人类授权仍是前置**（ADR-0007）；脚本不替代授权。

```bash
task merge -- <PR> --dry-run    # 校验 PASS / 快照 / mergeState，打印将执行的命令
task merge -- <PR> --yes        # 授权后执行（docs/* => squash + 快照 body；其余 --no-ff）
```

- mode 由 head ref 派生：`docs/*` 走 squash，其余走 `--no-ff` 且不传 `--subject` / `--body`；特殊场景可用 `--mode docs|code` 覆盖。
- 校验：PR 必须 OPEN、非 draft、`MERGEABLE`、`mergeStateStatus=CLEAN`；body 末行 `Assisted-by`、无评审状态行；PASS 的 `target` 必须等于当前 head、`body-sha256` 必须匹配当前 title/body；PASS 末行 `Reviewer:` 必须合法。
- 合并后自动 `git fetch` 核对落地 subject/body（code 还核对 merge commit 第二父 = target）；失败会报错，不自动 revert——按 `merge.md` 的 P1–P4 分类处理。
- 脚本自测：`task test:merge`（fixture，不触网、不合并）。

第 5 步 docs 命令的 ` (#N)` 后缀行为已实测结案（proposal 开放问题 3，2026-11-17 #33 首用）：显式 `--subject "<标题> (#N)"` 被 GitHub 逐字落地、不重复追加，落地 body 与快照逐字节一致。2026-11-18 #41 补记：GitHub squash 会去掉正文末尾换行；校验按 `rstrip("\n")` 归一化，内容行一致即通过。验收标准（dev 上 subject = `标题 (#N)`、body = 快照）已满足；合并后核对落地提交仍是固定动作，只是预期值如今已知。

code 路径也已由 #36 实弹验证（2026-11-17）：不传 `--subject` / `--body` 时，subject = `标题 (#36)`、正文为空；#34 用显式 `--subject` 导致的缺号事故是本条反例。

### 与 C6 pr-meta 的关系：有意冗余

`pr-meta`（C6，PR #27）在 PR 事件时校验描述末行 trailer、拒绝评审状态行；快照校验在合并瞬间做同样的事。两层**时序不同**：C6 是异步 backstop，check 可能 stale（body 编辑不换 SHA、check 之后仍可改）；快照校验是同步硬保证，读的就是即将落地的那份。冗余是设计出来的——CI 时序的洞由脚本补，脚本绕不过的（Merge 按钮）由手动检查单补。

### 手动合并检查单（零成本兜底）

脚本不跑、手动点 GitHub Merge 按钮 = 绕过快照。以下检查单与 proposal §1 的警告文本**同文**（真源 proposal §1）。注意时点：proposal 设计它"随 PASS 评论附"，但这是 proposal 未毕业的部分——评审协议 #28 毕业条款不含此项，现行 PASS 评论尚不随附；毕业前，本指南是这份清单的唯一固定落点：

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

proposal 设计这份文本只出现在两处：PASS 评论（随附警告，毕业前暂未实施）与本指南。**绝不放进 PR 描述**——docs 的描述就是 squash 正文，警告会随正文落库，把 trailer 挤离末尾，正是 #22 的成因。

### 合入后出了问题：先分类，再进阶梯

发现落地提交不对，第一反应不是 revert，是**分类**——不同类型的错误走完全不同的修复路径：

| 类型 | 判断标准 | 首选路径 |
| --- | --- | --- |
| **元数据错误** | 树是对的，message / trailer / 描述不对 | P1 接受记账，或窗口内 P2a / P2b |
| **内容错误**（非敏感） | 当前树必须改 | P3 revert 或 fix-forward；**不允许内容 rewrite**（ADR-0010） |
| **敏感数据** | 密钥 / PII / 法律风险，不可留在任何历史 | 独立事件响应：轮换 + rewrite + 平台清理；**revert 不够**——revert 不删历史，diff 反而再次暴露内容 |
| **仅 CI 红** | 平台 / 配置问题 | fix-forward 或 rerun；不改历史 |

元数据错误的修复阶梯（P1–P4），代价从低到高：

- **P1 接受 + journal**：0 新提交、0 新 PR 号；坏 message 留在账本上，journal 记执行差异。窗口外、非头部的默认选项。
- **P2a 头部 amend**：坏提交在 dev 头部且窗口内，直接 amend 修正 message（**只许 message-only，tree 不变**——ADR-0010 硬约束）；0 新提交、0 新号。代价：已合并 PR 页面指向的旧 SHA 不会更新，需在 PR 描述里补记新 SHA。
- **P2b reset + re-land**：force reset 丢掉坏提交，同内容开新 PR 重落；+1 PR 号。换来的是平台溯源干净：新 PR 页面与落地提交双向点通。**默认推荐**——取舍依据见下。
- **P3 revert**：只用于**内容**必须撤回的场景；+1 提交、+1 号；坏历史仍在。
- **P4 revert + redo**：撤了还必须重做；+2 号；最后手段。

P2a 与 P2b 的取舍建立在"溯源分两层"的认识上：

- **文本级溯源** = subject 里的 ` (#N)`，`git log` 能搜到 PR——amend 保留 subject 就保得住这层；
- **平台级溯源** = 落地提交是某个 PR 的 merge commit，GitHub 页面上 commit ↔ PR 双向点通——**只有 re-land 做得到**，amend 之后旧 PR 页面永远指向旧 SHA。

优先级裁决（proposal §3）：history 美观 + commit 准确 > 平台溯源 > 省号。P2b 多花一个号买回第二层溯源，所以是默认；团队不能 reset 或旧页面可接受时才退到 P2a。旧 PR 标注 `superseded by #N` 留作审计页——标注方式已结案（Q5，2026-11-17 #34）：在旧 PR 评论 `Superseded by #N`，并在下一次 journal 记区间映射 `A..B → A'..B'`（ADR-0010 D1.3 的既定动作）。

**撤回窗口**——P2a / P2b 先过三条件窗口（Q1 已定稿，2026-11-18；`retract.sh` preflight 全量校验）：

1. 坏提交在 dev 头部（`origin/dev` 与本地 `HEAD` 都等于 `bad`）；
2. 除 `dev` / `origin/dev` / `backup/*` 外，无分支以 `bad` 为祖先（`git for-each-ref --contains`，含 main 在内一律拦）；
3. 距合入 ≤ 24 小时（`--window-hours` 可调）。

窗口之外，P2a / P2b 仍须：

4. 人类所有者明确批准（ADR-0007 授权模型：rewrite 属人类确认项）；
5. 先建备份分支；推完恢复分支保护，并通知所有 clone 执行 reset；
6. 在 PR 评论 + 下一次 journal（搭车）留痕，不单独开号。

两条边界必须分清：**窗口只约束 P2a/P2b 快速通道**，它不是 ADR-0010 rewrite 授权的唯一边界——窗口外的元数据错误还有 P1 接受、或按 ADR-0010 D1 的 message-only 全量仪式（备份、区间映射、tag 重打、保护恢复，重流程慎用）；同时 ADR-0010 只放行 message-only，**任何内容修复都不走 rewrite**，这是 P3 revert 存在的理由。

code 路径的特例：merge commit 的 subject 错可 P2a amend；分支提交的 trailer 错 = rebase 分支 + 重建 merge（本质是 P2b）；revert 只用于内容回滚，不修 trailer，也不要把 docs 的 body 快照套过来。

### 合规 rewrite：ruleset 窗口（2026-11-18 起）

dev / main 的 classic branch protection 已迁到三条 ruleset：

- **RS-1 `dev-main-pr-gate`**：require PR + required `ci-ok`，无 bypass；直推和 force 都被拦。
- **RS-2 `dev-main-history`**：`non_fast_forward`，仓库 admin 角色（`actor_id: 5`，`RepositoryRole`，`bypass_mode: always`）可 force。它只服务 P2b 的 force push，单独时是惰性的——RS-1 仍会拦。
- **RS-3 `dev-main-undeletable`**：`deletion`，无 bypass。删除保护不能挂在 RS-2 上：owner bypass 会顺带放开删分支，迁移即净弱化。

P2b 的窗口由 `scripts/retract.sh` 控制：

```text
preflight → 备份本地+远端 → snapshot → disable RS-1（enforcement=disabled，秒级）
→ reset --hard <bad^> → --force-with-lease + --force-if-includes
→ enable RS-1 → 全字段 verify
```

RS-2 / RS-3 全程 active；窗口只暂停 PR 与 `ci-ok`，不暂停 force / deletion 保护。恢复失败 exit 99，打印快照路径与手工恢复命令；`task retract` 是统一入口。

审计口径：个人仓库没有 org audit log；evaluation API 对 bypass 推送返回空数组。证据链 = `rules/branches/*` 回显 + git server 消息 + web security log（如可见）+ 脚本快照 + journal；不主张“平台 bypass 审计”。break-glass 仅作为历史回退（#34→#36 手工版），不再是日常路径。

### 现状速览：哪些已落地，哪些还没有

已落地、可直接依赖的：

- 评审协议（PASS / target / body-sha256 / PASS 后冻结）——#28 毕业，真源 AGENTS「评审协议」+ `review.md`；
- `pr-meta`（C6）PR 描述校验——#27，`ci-gate.md` 有它在门禁里的位置；
- message-only rewrite 的边界——ADR-0010（accepted）；docs 单提交约束已撤销（ADR-0005 deprecated）；
- 评审署名双轨（评论层 `Reviewer` / commit 层 `Reviewed-by`）——ADR-0011；
- ruleset 迁移（2026-11-18）：RS-1 / RS-2 / RS-3 active，classic dev/main protection 已删除；
- `scripts/retract.sh` + `task retract`（#42）——P2b 的 reset / force / 恢复链自动化，production dry-run 已通过；
- `scripts/merge.sh` + `task merge`（2026-11-18）——P0 快照合并：PASS target/hash 校验、docs squash + 快照 body、code `--no-ff`、合并后落地核验；`task test:merge` fixture 自测。

未落地、执行到对应步骤时按上文手动流程 + 逐条留痕的（全部出自 proposal 毕业条件与开放问题）：

- ~~` (#N)` 自定义 subject 行为未实测~~ 已实测结案（2026-11-17，#33：显式 subject 逐字落地、不重复追加；见 proposal 演进记录）；
- ~~撤回窗口正式拍板仍待人类确认~~ 已定稿（Q1，2026-11-18，三条件）：bad 在 dev 头部 + 除 `backup/*` 外无分支以 bad 为祖先 + age ≤ 24h（`--window-hours` 可调），`retract.sh` preflight 全量校验；任一不满足走 revert / ADR-0010 D1；
- pilot 仍为 0/3：脚本已落，尚无 PR 用它合并；
- 敏感数据桌面演练未做；
- ~~ruleset 迁移 vs break-glass~~ 已结案（Q2，2026-11-18）：ruleset 三规则集落地，break-glass 仅历史回退；
- ~~脚本落位与 `task merge` / `task retract`~~ 已结案（Q4，2026-11-18）：根 `scripts/`；`retract.sh` + `task retract` 已落，`merge.sh` / `task merge` 已随本任务落地（2026-11-18）；
- ~~旧 PR 页面的标注方式未定~~ 已有实战口径（Q5，2026-11-17 #34：评论 Superseded by #36 + journal 映射；见上文 P2a / P2b 段）。

proposal 的 pilot 毕业门槛：merge.sh 已落地；至少 3 个 PR（docs 与代码各 ≥1）用它合并、0 次"PASS 后描述变更导致落地正文不一致"、` (#N)` 验证通过；外加一次撤回演练与一次敏感数据桌面演练。`retract.sh` 已落地并通过 production dry-run，pilot 仍未开始；pilot 未完成前，手动流程保留为脚本不可用时的兜底，正常路径用 `task merge`。

## 常见误区

- **"revert 能修 message"**：revert 只新增一个提交把树回滚，坏 message 原样留在第一父链上，还多付一个提交一个号。#22 烧掉 5 个号的直接原因就是拿 revert 修元数据。元数据错 → P1 / P2a / P2b；revert 只留给内容。
- **"PASS 后顺手补一下描述"**：任何编辑作废 PASS（新 push 同理）；docs 描述就是落地正文，改了就直接落库。要改 = 退回重审。
- **"CI 绿就能点 Merge"**：required 检查只有 `ci-ok`，GitHub 不要求 PASS。绿灯只说明 head 通过；没有 PASS 的合并绕过了评审与快照，平台不会拦你——拦你的应该是检查单。
- **"合并界面手改一下 message 更准确"**："Default to PR title" 已预填正确值，手改 = 账本行失守（AGENTS 明文禁止）。觉得标题不对，应该去改 PR 标题并重新 PASS。
- **"把确认清单写进 PR 描述，合并时看得清楚"**：docs 描述 = squash 正文，清单会永久落库并把 trailer 挤离末尾——正是 #22 的成因。清单只放 PASS 评论与本指南。
- **"P2a amend 完 PR 页面会自己更新"**：已合并 PR 的 merge SHA 不可编辑，旧页面永远指向旧 SHA；新 SHA 要手动补记进 PR 描述，旧 PR 标注 `superseded by #N`。
- **"窗口过了就只能 revert 了"**：窗口只约束快速通道；窗口外还有 P1 接受 + journal 与 ADR-0010 D1 的 message-only 全量仪式。反过来，"窗口内 = 可以随便 rewrite"也不成立——ADR-0010 只放行 message-only。
- **"force push 一下很快"**：没有备份分支、没有窗口核对、没有恢复保护核验、没有 clone 通知的 force push 不是修复，是第二起事故。

## 延伸

- 规则原文：`AGENTS.md`「分支与版本」（合并与同步、三层历史读法、破坏性操作）、「评审协议」、「commit 级评审署名」。
- 教学层：`review.md`（PASS 与快照的评审侧）、`git-workflow.md`（分支与 PR 方向）、`ci-gate.md`（ci-ok / attribution / pr-meta 的门禁位置）。
- 设计论证与开放问题真源：`proposals/merge-integrity.md`（Q1–Q5 已全部结案；本指南"现状速览"的对账依据）。
- 过程记录：`journal/2026/2026-11-16-foamshadow-pr22-metadata-incident.md`（事故与 force reset 决策）、`2026-11-17-foamshadow-a5-pr-meta-matrix-drift.md`（C6 边界）、`2026-11-18-foamshadow-ruleset-migration.md`（本次迁移与 quirk 清单）。
- 决策链：ADR-0003（分支与合并机理、backport）、ADR-0005（双轨合入策略）、ADR-0007（操作授权与分级）、ADR-0009（CI 门禁策略——required 只挂 `ci-ok`，"CI 绿 ≠ 可合"误区的出处；C6 相关条款已被 ADR-0011 部分取代）、ADR-0010（历史修复边界：message-only）、ADR-0011（评审署名与 pr-meta 边界）。
