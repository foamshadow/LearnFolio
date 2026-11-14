---
title: "LearnFolio Git 流程讲解"
author: foamshadow
date: 2026-11-13
status: draft
tags: [se-arch, tool-git]
related: [ADR-0003, SPEC-0001]
---

# LearnFolio Git 流程讲解

## 讲给谁 / 前置知识

所有成员（人类与 agent）。前置：会 git 基本操作（branch / commit / merge / rebase）；不需要懂 git-flow 理论——本文按本仓库规则讲，规则的理由都在文中。

## 核心图景

仓库永远只有两条长存分支，其余都是天级短命分支：

```
main ─────────────────────────────  产品库：只进"收口"和"hotfix"，tag 只在此
  \
   dev ────────────────────────────  集成线：日常所有任务的归宿
     \
      feat/spec-0001-t2-xxx ────────  任务分支：干完即删
```

`main / dev / feat / fix / hotfix / backport` 六个前缀名都被占用规则管着——不能建恰好叫 `feat` 的分支（git 目录/文件冲突，之后所有 `feat/*` 报错），也不能建 `main/*`、`dev/*`（与长存分支冲突）；`feat/*` 等带斜杠形式才是任务分支的形态。

## 一个任务的一生（以 t2 为例）

1. **开工**：从 dev 切 `feat/spec-0001-t2-api-healthz`（spec 号 + 任务号 + 短名，从名字反查施工图，不依赖任何外部系统）
2. **开发（agent 自主）**：高频小步提交——每完成一个可验证步骤（编译过 / 测试绿）一 commit，message 可草（`wip:` / `fix:` 前缀）；每任务至少 push 一次。过程提交保留是有意的：bisect 可定位到任务内具体一步，agent 试错轨迹是本项目的学习素材
3. **整理（人类执行）**：PR 开启前 `rebase -i`——fixup 掉 typo 链、保留逻辑步骤；禁止把任务整体 squash 成单提交（那会废掉过程保留；**纯文档 PR 例外**——恰好一个提交，由 GitHub squash 合入）；整理前打 backup 分支；push 用 `--force-with-lease --force-if-includes`（本操作 Phase 0 由人类执行；agent 确认链提案孵化中，见 proposals/）
4. **PR**：标题 = 账本行，五种格式之一（如 `合并 spec-0001-t2 api-healthz：Go 后端最小服务`；五类 merge 变体与 docs 变体、方向矩阵见 AGENTS 分支与版本节）；CI 在 PR 开启时正则校验标题；ci-ok 是必需检查（自 t0 合入起）。合并时 GitHub 会在标题后追加 ` (#N)`——账本行实际形态是 `标题 (#N)`、正文为空（2026-11-14 实测）。**纯文档 PR 例外**：走 `docs/*` 分支，标题直接用 `docs: …`，squash 后账本行就是该提交本身（ADR-0005）
5. **合入 dev**：代码任务用 merge 按钮（settings 只开 merge commit 与 squash，rebase 关闭）→ `--no-ff` 产生 merge 节点；纯文档 PR 用 squash 按钮 → 一条普通提交、无节点（ADR-0005）。为什么代码要节点：git 能快进时会抹平分支不留痕——有的任务成节点、有的消失，账本形状不一致；节点统一后 `git log --first-parent dev` 一任务一行。合并后分支自动删，过程史不丢（merge 节点让提交从 dev 永久可达）
6. **并行**：不要求追平 dev（"up to date" 保护已关——开着会造成 dev 每动一次、全部在飞 PR 被迫改写重审的死锁）；只在真冲突或 ci 红疑基线时 `git rebase dev` 同步
7. **兜底**：dev 每次被合入触发 push CI 全量跑——红 = 两个各自绿的分支合坏了（语义冲突），开 `fix/` 修或 `git revert -m 1` 退回（注意：被 revert 的任务重合入不带回内容，需 revert 那个 revert）

## 修复与 hotfix

| 分支 | 场景 |
| --- | --- |
| `fix/spec-0001-t2-xxx` | 任务还在飞，修自己 |
| `fix/spec-0001-xxx` | 已合入 dev，修该 spec 遗留 |
| `fix/<scope>-xxx` | 无 spec 归属小修（scope 白名单） |
| `hotfix/<scope>-xxx` | 已发布的 main 上有 bug |

hotfix 路线（本仓库最重要的一条不变量来源）：从 main 切 `hotfix/<scope>-短名` → PR 回 main（标题 `合并 hotfix 短名：一句话（发布 vX.Y.Z）`）→ 合入后 `git fetch origin && git tag -a vX.Y.Z origin/main^2`（hotfix tip = merge 第二父：被删分支靠 tag 留存，backport `git merge <tag>` 也依赖它指向 hotfix 线）并 `git push origin vX.Y.Z` → **回流 dev：从 dev 切 `backport/<短名>`，`git merge <tag>`，PR 回 dev**（标题 `合并 hotfix 短名：backport 自 vX.Y.Z`；禁 cherry-pick）。cherry-pick 会把同一修复复制成两个不同 SHA，下次 dev→main 合并时共同祖先退化、两侧带同一改动，碰过同处即冲突且现场难解；merge 让修复成为两线共同祖先 → **dev→main 永不冲突且 tree 恒等**——收口守卫（三点 diff）靠它成立。漏回流会在收口时被守卫拦下。

## Phase 收口

1. **收口前置 PR**（fix/ 短名 PR 回 dev，先合入）：SPEC 验收条目逐条勾选 + spec status → done——收口 PR head = dev、dev 必 PR 禁直推，收口 PR 自身无法承载文件改动；顺序反了会被 Dismiss stale approvals 作废审批重审
2. dev → main 收口 PR：评审对象是**发布检查单**而非代码（代码已在各 feat PR 审过）——首项机械守卫：**main 自分叉点以来无 dev 缺失的改动**（`git diff --quiet origin/dev...origin/main`，三点 diff 空 = 通过；非空 = main 上有未回流内容，失败时逐 tag 诊断。注意不能用 `--is-ancestor origin/main origin/dev`：其真值与缺失与否不相关——正常收口时刻 main tip（最新收口 merge commit）只在 main 第一父链上，该式恒假恒误阻断；tag 遍历也查不出漏打 tag 的 hotfix——三点 diff 两者都能覆盖）；其余项 = 全部任务合入 / dev push CI 绿 / 确认前置 PR 已合入 / 版本号指定；批准 ≥1 名非作者核心 + 检查单逐项勾选
3. 合并后 `git fetch origin && git tag -a vX.Y.Z origin/main -m "vX.Y.Z — Phase N 收口：…（覆盖 SPEC…）" && git push origin vX.Y.Z`：annotated（有元数据）；**收口 tag 打 merge commit = `origin/main`**——在 main 第一父链上，"第一父链 + tag = 版本史"读法才成立；fetch 后取 origin/ 引用，不依赖本地新鲜度；推 tag 显式指定（`--follow-tags` 依附常规 push 会连带推当前分支，本地 main 落后时行为不可预期）
4. **dev 不追平 main**：ff 追平会把 main 的版本史覆盖进 dev 第一父链，任务账本尽毁
5. Y 收口时显式指定并记 journal：Phase 0 → v0.1.0；Phase 1 首次上线 → v1.0.0；其后 Y+1

## 三层历史读法（所有规则服务的目标）

```
git log --first-parent main + tag   →  版本史（发过什么）
git log --first-parent dev          →  任务史（谁何时合入了什么，含 hotfix 回流）
git log <feat 分支>                  →  过程史（任务内部怎么推进的）
```

（hotfix 的 patch tag 打在 hotfix tip = merge 第二父，不装饰在此链上——查 patch 版本用 `git tag -l` / `git tag --contains`；dev 侧 `git describe` 也解析不到收口 tag，版本号以 main 侧为准。）

## 常见误区

- "分支太乱了不如直接推 dev"——dev 必 PR（分支保护），且直推会绕过账本节点
- "PR 前把所有提交压成一个更干净"——禁止；过程保留是本仓库 `--no-ff` 的目的
- "hotfix 修完 cherry-pick 到 dev 更轻"——禁；见上文后果链
- "hotfix 修完直接在 dev 上 git merge"——也不行：dev 必 PR 且禁 bypass，无人可直推；回流走 backport/ 分支
- "收口后记得把 dev 对齐 main"——不要；分叉是常态

## 延伸

ADR-0003（分支与合并的完整决策链与被否方案）、SPEC-0001 任务分解节（t0-t6 实例）、proposals/（agent 确认链提案，孵化中）。
