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

给需要在**同一台机器上同时推进多个任务**的人与 agent——典型场景：agent A 在工作树里修 bug，你同时在工作树 B 里起草文档，谁也不挡谁。前置：读过 git-workflow.md 的"地基概念二"（分支 = 可移动指针），会 `git switch` / `git commit`；规范本体在 AGENTS「多工作树（worktree）」节，本篇讲怎么用、为什么、坑在哪，不新增规则。

## 为什么需要工作树

git 有个默认限制：**一个检出目录（工作区）一次只能对准一条分支**。`git switch` 换分支时，整个目录里的文件被整体替换成目标分支的快照。单人串行干活时这不是问题，但两个任务并行时会撞上三堵墙：

- **未提交的改动**：agent A 的半成品还在工作区，你一 switch，这些改动要么跟着你到新分支（污染），要么直接被 git 拒绝切换；
- **运行态**：`node_modules`、dev server 的端口、构建缓存——都是目录级的单份资源，切分支瞬间全部错乱；
- **状态心智**：切来切去后"我现在在哪个分支、哪些改动属于哪个任务"全靠记忆。

`git worktree` 是 git 的官方解法：**让同一个仓库在多个目录里各检出一条分支**。目录之间互不知晓，switch 的三堵墙全部消失。

### 它的本质：共享一个大仓库，各开各的门

理解 worktree 只需要知道 `.git` 目录里有什么：

- `objects/`——**对象库**：仓库的全部历史数据（每个提交、每个版本的每个文件），是个只增的数据库；
- `refs/`——**引用**：分支标签们（地基概念二：分支只是指针）；
- `hooks/`、`config`——钩子脚本与仓库配置。

普通模式下，一个检出目录对应一套完整 `.git`。worktree 模式下：**主目录保留完整 `.git`；每个附加工作树目录里只有一个名为 `.git` 的指针文件（不是目录），内容是一行路径，指向主 `.git/worktrees/<id>/` 这个管理目录**。这棵树的私有物件——`HEAD`（当前对准哪条分支）和 index（暂存区）——就存放在那个管理目录里。也就是说：**对象库、分支引用、hooks、config 全仓库只有一份；每棵工作树私有的只是"我现在在哪、暂存了什么"，且它们也收纳在主 `.git` 的管理目录里**。

由此推出两条铁律：

1. **历史全局共享**：任何工作树里 commit，其他工作树立刻可见（同一批对象）；从任何树里切任何分支都零成本。
2. **一条分支不能双开**：git 在 `.git/worktrees/<id>/` 登记了每棵工作树正检出的分支，`switch` 一条已被别处检出的分支会直接拒绝（`fatal: '<branch>' is already checked out at ...`）。这个报错不是故障，是"一任务一工作树"的物理保证。

## 目录约定与一次完整流程

约定（AGENTS 规则）：任务工作树一律放仓库根的 `.worktrees/<短名段>`（目录已 gitignore）；**主工作树常驻 `dev`**（或 main），并行任务一律进工作树。

```
LearnFolio/                       主工作树，常驻 dev
├── .worktrees/                   已 gitignore，不入库
│   └── guides-git-rewrite/       分支 docs/guides-git-rewrite
└── ...
```

从创建到清理的完整流程（以一个文档任务为例）：

```bash
# 1. 先 fetch——切分支的基线必须来自远端最新状态（远端才是登记簿）
git fetch origin

# 2. 创建工作树：新分支 + 新目录，一步到位
git worktree add --no-track -b docs/worktree-conventions .worktrees/worktree-conventions dev

# 3. 确认 upstream 为空（坑 1 的防线，见下文）
git config --get branch.docs/worktree-conventions.merge || echo "no upstream（正确）"

# 4. 在该工作树内开发、提交（cd 进去，或所有命令用 git -C <路径>）
cd .worktrees/worktree-conventions
git add ... && git commit ...

# 5. 首次推送：-u 建立同名 upstream（之后裸 push 即推对地方）
git push -u origin docs/worktree-conventions

# 6. 开 PR、评审、合入——与普通任务完全相同（见 git-workflow.md 第 4-5 步）

# 7. 合入后清理：先移除工作树，再删本地分支（顺序不能反）
cd ../..
git worktree remove .worktrees/worktree-conventions
git branch -D docs/worktree-conventions   # squash 合入后 -d 会拒绝，用 -D
```

几个参数的拆解：

- `worktree add` 的最后一段 `dev` 是**起点基线**——新分支从 dev 的当前位置切出，所以第 1 步的 fetch 决定了基线新鲜度；
- `-b` 是"创建新分支"（同 `switch -c`）；
- `--no-track` 是**必须项不是可选项**，理由见坑 1——漏掉它 git 会把新分支的 upstream 自动设成 `origin/dev`，后患一串；
- 第 7 步先 `remove` 再删分支：工作树还挂着分支时删分支会被 git 拒绝；`remove` 发现树里有未提交改动时也会拒绝你——这是防丢稿的保护，真要丢弃先自己确认。

## 锁是什么（以及不是什么）

长时任务（比如一个跨多轮会话的 agent 任务，草稿悬在树里）应该给工作树上锁：

```bash
git worktree lock --reason "ZCode/guides-first-batch" .worktrees/guides-first-batch
# 任务结束或 PR 合入后：
git worktree unlock .worktrees/guides-first-batch
```

`lock` 会在 `.git/worktrees/<id>/locked` 写一个标记文件，`--reason` 的值（惯例格式 `<harness>/<任务>`，如 `DSH/spec-0001-t1`）会显示在 `git worktree list` 里。对锁的准确预期：

- **它挡的是清理操作**：`git worktree prune` / `remove` / `move` 遇到锁定的树会拒绝执行——防止长任务的目录被同事误删、或被 `prune` 当成"目录失踪的孤儿"清掉元数据；
- **它不是并发锁**：不阻止任何进程读写树里的文件、提交、rebase、切分支。两个 agent 同时跑 git 命令，锁管不着——并发安全靠下文的纪律，不靠锁。

一句话：锁是"别动我的座位"的牌子，不是"座位反锁"的门。

## 常见坑

每条按"现象 → 机理 → 解法"展开。

1. **upstream 指向 dev**（本仓库真实发生过，也正是 `--no-track` 强制的原因）
   现象：新分支的 upstream 变成了 `origin/dev`——`git status` 显示莫名的 ahead/behind，`git pull` 会把 dev 合进你的任务分支，某些 `push.default` 配置下裸 `git push` 甚至试图推 dev。
   机理：git 的自动跟踪规则——从一个远端追踪分支（如 `origin/dev`）创建新分支时，会自动把新分支的 upstream 设为那个远端分支；全局配置 `branch.autoSetupMerge=always` 时即使从本地 dev 切也会发生。
   解法：`git branch --unset-upstream <分支>`，首次推送时用 `git push -u origin <分支>` 重建同名 upstream。

2. **同一分支不能双开**：`fatal: '<branch>' is already checked out at ...`
   这正是"一任务一工作树"的物理保证（每个任务分支只能在一个座位上被检出），不是需要绕过的故障——**不要用 `--force` 绕过**。想清楚你要的是"把这个任务的工作树切到别的分支"，还是"新开一个任务"。

3. **落后基线**：工作树是独立检出，**不会跟着主工作树或远端自动更新**。昨天切的分支，今天 dev 已经前进了三格。开 PR 前在**本工作树内** `git fetch origin && git rebase dev`；绝不进别人的工作树代为 rebase（纪律见下节）。

4. **hooks 共享**：lefthook 已落地（t3），钩子装在共享的 `.git/hooks`——任何工作树里的提交都会跑同一套钩子。`lefthook install` 生成的转发器会嵌一个安装时解析到的二进制绝对路径；该路径失效时回落到 `$(git rev-parse --show-toplevel)/node_modules`。所以任务工作树里 `pnpm install` 后跑一次 `task setup:hooks`；移除工作树后若主工作树提交报 "Can't find lefthook in PATH"，在主工作树重跑 `task setup:hooks` 即可。job 的 `root:` 按**当前提交所在的树**解析（脚本拿到的工作目录是那棵树的根），脚本路径一律按仓库根写。

5. **清理顺序**：先 `git worktree remove`（有未提交改动时它会拒绝——先确认丢弃或提交），再删本地分支。squash 合入后 `git branch -d` 会因"找不到合并证据"拒绝（SHA 被重写，git-workflow.md 第 5 步讲过），按 journal 先例用 `-D`。**别人的活跃工作树不要 `--force`、不要 `prune`。**

6. **prune 的语义**：`git worktree prune` 只清理"目录已经被手动删掉、但 git 元数据还留着"的孤儿记录，**不会删除任何还存在的活跃工作树**。执行前先 `git worktree list` 扫一眼是纪律：知道有哪些树、哪些上着锁，再动手。

7. **运行态冲突**：两个工作树同时起 dev server 会抢同一个端口（端口是全机共享的，git 管不着）。用 `.env.local` 或命令行参数错开端口；`.env` 系列文件不入库（已在 gitignore）。

## 与多 agent 协作

工作树是多 agent 并行的座位系统：**一个工作树 = 一个任务分支 = 一个 agent 座位**。

- 不要跨座位代操作：不进入别人的工作树执行 commit / rebase / checkout / 删分支；对其他工作树只做只读命令（`status` / `log` / `diff` / `worktree list`）。
- `auto-commit` / `auto-push` 授权**按工作树各自申请**（ADR-0007），不共享、不继承——A 树拿到的授权到了 B 树等于零。
- 长任务加锁（见上），结束或合入后解锁再清理。
- 共享资源（`.git` 整体）面前人人平等：跑 `git gc --prune=now`、改 hooks、改仓库级 config 之前，先 `git worktree list` 确认没有其他活跃工作树——这些操作是全局的。

## 和 CI / 分支保护的关系

工作树是**纯本地概念**：远端 GitHub 只看见分支与提交。push 到 `origin/<分支>`、开 PR、required `ci-ok`、合并策略——全部与单工作树时代一致。变化的只有一件事：同一时刻本地可以有多条分支在推进。每条分支的 `synchronize` 触发与 CI check 记账仍按各自的 head SHA 独立计算，互不干扰。

## 延伸

AGENTS「多工作树（worktree）」节（规范本体）、git-workflow.md（分支模型与任务流程——本篇的前提）、ADR-0003（工作树没有改变它定的任何规则）、ADR-0007（授权按工作树各自申请的出处）、ci-gate.md（push 出去之后发生什么）。
