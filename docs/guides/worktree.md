---
title: "多工作树（worktree）操作手册"
author: foamshadow
date: 2026-11-15
status: draft
tags: [tool-git]
related: [ADR-0003, ADR-0007]
---

# 多工作树（worktree）操作手册

## 讲给谁 / 前置知识

给需要在同一台机器上并行跑多个任务的人与 agent。前置：熟悉 `git switch`、`git rebase` 与 PR 流程（见 guides/git-workflow）。规范本体在 AGENTS「多工作树（worktree）」节，本篇只讲怎么用、坑在哪，不新增规则。

## 为什么用工作树

普通做法是 `git switch` 换分支，但一个工作区同一时间只能检出一条分支；两个 agent 同时干活时，切换会把对方未提交的改动、`node_modules`、dev server 状态搅在一起。`git worktree` 让同一个仓库在多个目录里各检出不同分支，共享对象库与 hooks，互不干扰。

代价是它们共享同一个 `.git`：一条分支不能双开，hooks、仓库 config、`gc` 都是全局的。

## 目录与一次完整流程

约定（AGENTS 规则）：任务工作树放仓库根的 `.worktrees/<短名段>`，主工作树常驻 `dev`。

```
LearnFolio/                    主工作树，常驻 dev
├── .worktrees/                已 gitignore
│   └── worktree-conventions/  分支 docs/worktree-conventions
└── ...
```

```bash
# 1. 从最新 dev 创建（--no-track 必须，理由见"坑 1"）
git fetch origin
git worktree add --no-track -b docs/worktree-conventions .worktrees/worktree-conventions dev

# 2. 确认 upstream 为空
git -C .worktrees/worktree-conventions status --short --branch
git config --get branch.docs/worktree-conventions.merge || echo "no upstream（正确）"

# 3. 在该工作树内开发、提交
cd .worktrees/worktree-conventions
git add ... && git commit ...

# 4. 首次推送建立同名 upstream
git push -u origin docs/worktree-conventions

# 5. PR 合入后清理（先移除工作树，再删本地分支）
cd ../..
git worktree remove .worktrees/worktree-conventions
git branch -d docs/worktree-conventions
```

## 锁是什么（以及不是什么）

`git worktree lock --reason "DSH/spec-0001-t1"` 会在 `.git/worktrees/<id>/locked` 写一个标记，`git worktree list` 随后显示 `locked DSH/spec-0001-t1`。

- **它挡的是清理**：`git worktree prune` / `remove` / `move` 会拒绝动这棵树，防止长任务的目录被误删、被 `prune` 当成"失踪"清掉元数据；
- **它不是并发锁**：不阻止任何进程读写文件、提交、rebase、切分支——两个 agent 同时跑 git 不会被它拦住；并发安全靠 AGENTS 的纪律（不进别人工作树、不跑全局 `gc` / 改 hooks）。

长任务加锁、结束 `git worktree unlock` 即可；锁只会被 `prune`/`remove` 之类操作感知，日常开发无感。

## 常见坑

1. **upstream 指向 dev**：从 `origin/dev` 起手（或全局 `branch.autoSetupMerge=always`）且未加 `--no-track` 时，git 会把任务分支的 upstream 设成 `origin/dev`。后果：`git status` 误报 ahead/behind、`git pull` 把 dev 合进任务分支；`push.default=upstream` 时裸 `git push` 会尝试推 dev（默认 `simple` 会因分支名不匹配而拒绝——两种都不是你要的）。补救：`git branch --unset-upstream`，再 `git push -u origin <分支>`。本仓库已出现过一例。
2. **同一分支不能双开**：`fatal: '<branch>' is already checked out at ...`。这正是"一任务一工作树"的由来；不要用 `--force` 绕过。
3. **落后基线**：工作树是独立检出，不会跟着主工作树自动更新。开 PR 前在**本工作树内** `git rebase dev`；不要进别人的工作树 rebase。
4. **hooks 共享**：t3 lefthook 落地后，hooks 装在共享的 `.git/hooks`，任一工作树提交都会跑同一套钩子。钩子命令要按仓库根解析路径，否则在 worktree 里会找不到文件。
5. **清理顺序**：先 `git worktree remove`，再删本地分支；有未提交改动时 remove 会拒绝。别人的活跃工作树不要 `--force`、不要 `prune`。
6. **prune 的语义**：`git worktree prune` 只清理"目录已被删除"的元数据，不会删除任何活跃工作树；执行前先 `git worktree list`。
7. **运行态冲突**：两个工作树同时 `pnpm dev` 会抢端口；用 `.env.local` 或命令行参数错开，`.env` 系列不入库。

## 与多 agent 协作

- 一个工作树 = 一个任务分支 = 一个 agent 座位；不要跨工作树代提交、代推送。
- `auto-commit` / `auto-push` 按工作树各自申请（ADR-0007），不共享、不继承。
- 对其他工作树只读（`status` / `log` / `diff` / `worktree list`）；`checkout`、`rebase`、`branch -D`、`worktree remove` 一律不做。
- 长任务加锁：`git worktree lock --reason "DSH/spec-0001-t1" .worktrees/t1-...`，结束后 `git worktree unlock`。

## 和 CI / 分支保护的关系

工作树只是本地检出，远端仍按分支走：push 到 `origin/<分支>`、开 PR、required `ci-ok`、合并策略都不变。变化的只是"同一时刻本地可以有多条分支在推进"；每条分支的 `synchronize` 触发与 check 记账仍按各自 head SHA 独立计算。
