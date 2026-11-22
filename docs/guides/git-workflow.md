---
title: "LearnFolio Git 流程讲解"
author: foamshadow
date: 2026-11-13
status: draft
tags: [se-arch, tool-git]
related: [ADR-0003, ADR-0005, ADR-0007, ADR-0009, SPEC-0001]
---

# LearnFolio Git 流程讲解

## 讲给谁 / 前置知识

给所有要在这个仓库里**写代码或改文档**的成员（人类与 agent）。前置只需要两样：会 git 最基础的三个动作——`git add`（把改动放进暂存区）、`git commit`（把暂存区记录成一个提交）、`git push`（把本地提交传到远端 GitHub）；以及不害怕看到 `SPEC-0001-A5` 这样的编号引用（编号体系见 doc-system.md）。

本文**不假设你懂 branch / merge / rebase**——这三个词恰恰是协作流程的主角，会在第一次登场时完整讲解。全文结构：先讲四个 Git 地基概念（一次投入，全文受用），再陪一个任务走完一生，最后是修复、发布与读历史的姿势。规则原文在 AGENTS「分支与版本」「提交纪律」两节，决策链在 ADR-0003 / 0005 / 0007 / 0009；本文与条文冲突时以条文为准，并当教材 bug 报告（真源层级见 doc-system.md 设计七）。

## 核心图景

### 全景：永远只有两条长存分支

```
main ─────────────────────────────  产品库：只进"收口"与"hotfix"，版本 tag 只在此
  \
   dev ────────────────────────────  集成线：日常所有任务的归宿（任务账本）
     \
      feat/spec-0001-t2-xxx ────────  任务分支：干完即删（过程史）
```

| 分支 | 角色 | 谁能直接写 |
| --- | --- | --- |
| `main` | 产品库：每次发布在这里打版本 tag | 没有人——只接受收口 PR 与 hotfix PR |
| `dev` | 集成线：所有任务的合流处 | 没有人——必经 PR |
| `feat/` `fix/` `hotfix/` `backport/` `docs/` 开头 | 各类任务分支 | 该任务的执行者 |

两条长存分支分工明确：**dev 回答"项目现在长什么样"，main 回答"我们发布过什么"**。其余分支都是天级短命分支，生下来就是为了被合并然后删除。

**分支前缀是受管资源**：`main / dev / feat / fix / hotfix / backport / docs` 七个名字的形态都有规则——任务分支必须用带斜杠的两段式（如 `feat/spec-0001-t2-api-healthz`），不能建恰好叫 `feat` 的裸分支。原因是 git 的一个实现细节：分支名存储为 `.git/refs/heads/` 目录下的文件路径，分支 `feat` 会占用文件 `feat`，而分支 `feat/xxx` 需要目录 `feat/`——文件与目录同名冲突，一旦建了裸分支 `feat`，之后所有 `feat/*` 分支全部报错。同理 `main/*`、`dev/*` 被禁止（与长存分支名冲突）。短名段用 ASCII kebab-case（`^[a-z0-9]+(-[a-z0-9]+)*$`：小写字母数字加连字符），保证跨平台与 grep 可搜性。

### Git 地基概念一：提交与历史

git 的每次 commit 做三件事：给整个仓库拍一张**完整快照**、记录**元数据**（作者、时间、提交消息），并持有一个指向**上一次提交**（父提交）的指针。所以历史不是一摞散落的补丁，而是一条链：每个提交都知道自己的父母是谁，顺着父指针能一路走回仓库的第一个提交。

每个提交有一个 40 位十六进制编号叫 **SHA**（如 `128b660...`，日常只用前 7 位）。SHA 由提交内容算出——内容不变则 SHA 不变，所以 **SHA 相同 = 内容与来历完全相同**。这个性质后面会反复用到：为什么 cherry-pick 危险（同一个修复复制出两个不同 SHA）、为什么 squash 后找不到旧分支（SHA 被重写）。

### Git 地基概念二：分支

分支不是"一份代码的拷贝"，而是**一个指向某条提交链末端的可移动标签**——物理上只是 `.git` 目录里一个 41 字节的文本文件，内容就是它指向的提交的 SHA。

于是：新建分支的成本是零（写一个 41 字节文件）；删分支不丢提交（提交在链上，标签没了链还在——直到没有任何引用能走到它们，才会被 git 的垃圾回收清理）；`git switch` 做的事是把**工作区**（你眼前能看到的文件）对准某个分支指向的快照；新提交产生时，当前分支的标签自动前移到新提交上。

理解了"分支 = 指针"，后面一半的规则会变得理所当然。

### Git 地基概念三：merge 的两种结局

把 A 分支的成果并进 B 分支（`git merge A`，在 B 上执行）时，git 先判断 B 有没有属于自己、而 A 没有的新提交：

- **没有**（B 只是落后于 A）→ **fast-forward（快进）**：不产生任何新提交，git 把 B 的指针直接挪到 A 的末端。历史保持一条直线，但**没有任何痕迹表明"曾经存在过一个分支"**——标签挪过去了，分支来过的证据被抹平。
- **有**（两边各有对方没有的提交）→ **真合并**：git 找到两条链的**共同祖先**（最后一个双方共有的提交），做三方合并，产出一个**有两个父提交的合并提交（merge commit）**。历史出现分叉与汇合，画出来是一个"Y"字。

`--no-ff` 的意思就是"禁止快进、强制走真合并"——即使能快进也要留下 merge 节点。为什么本仓库要这样做，是"任务的一生"第 5 步的主角。

还有一个关键细节要记住：**merge commit 的第一个父 = 合并时所在分支的原末端（主线），第二个父 = 被合进来的分支末端（支线）**。两个父的先后是"账本读法"的钥匙。

### Git 地基概念四：first-parent（第一父链）

顺着上面的概念：普通提交只有一个父，merge commit 有两个父。`git log --first-parent` 的意思是"遇到 merge commit 时只沿第一父走"——也就是只走主线、不拐进支线。

本仓库把这条命令当**账本**用：dev 的第一父链上，一个 merge commit = 一个任务，一行 = 一条账目。`main` 的第一父链 + tag = 版本史。这是所有历史规则的落点，"三层历史读法"一节会展开。

### 任务的一生总览

```
① 开工   从 dev 切任务分支，申请双授权
② 开发   WIP 高频小步提交，trailer 署名，锚点可验证
③ 整理   rebase -i 磨成逻辑级提交序列（人类执行）
④ PR     标题即账本行，CI 门禁校验，模板填描述
⑤ 合入   代码 --no-ff 成节点，文档 squash 成单提交
⑥ 并行   不追平 dev，必要时才 rebase
⑦ 兜底   dev push 红 = 语义冲突，fix/ 或 revert
```

下面逐步展开。

## 一个任务的一生（以 t2 为例）

下面用 SPEC-0001 的 t2 任务（Go 后端最小服务）当例子，走完从想法到账本的完整流程。每一步的结构是：**做什么（命令级）→ 背后的 git 技术 → 为什么这么规定**。

### 第 1 步：开工——切任务分支

```bash
git switch dev && git pull     # 对准 dev 并拉到最新（此时是快进，安全）
git switch -c feat/spec-0001-t2-api-healthz
```

`switch -c` 的 c 是 create：建一个新分支标签并让工作区对准它，末尾的 `dev` 指明从哪儿起算——**feat / fix / docs 这类日常任务分支永远从 dev 切出**，因为 dev 是所有任务的归宿，从别处起算会把别人的半成品带进来（两个特殊分支后文讲：hotfix 是唯一从 main 切出的，backport 虽从 dev 切但身份是回流载体）。

**分支名是自解释的施工单**：`feat / spec-0001 / t2 / api-healthz` 四段分别是"类型 / 施工图编号 / 任务号 / 短名"。看到分支名就能反查到 SPEC-0001 任务分解节里的 t2——不依赖任何外部任务系统，账号、看板丢了都不影响定位。这是"文档驱动"在命名上的落地。

开工还有一步**仪式**：说明任务内容，申请 **auto-commit / auto-push** 两项独立授权（ADR-0007）。两个开关管的事不同：auto-commit 管"提交前是否要等人类逐条确认"，auto-push 管"能否把本地提交推到远端"。拆成两个是因为风险不同——提交只发生在本地（可撤可改），推送出了本地（进入他人视野与 CI）。授权任务级生效、随时可撤销；`wip:` 草稿提交免审，因为它本来就是随时可丢弃的草稿。

### 第 2 步：开发——WIP 高频小步提交

开发期的提交纪律与合入期完全不同：**`wip:` 前缀 + 高频小步 + 不要求每次都完美**。WIP 提交免审（草稿免检），但有三条底线：

- **提交前告知**：改了什么、为什么、几个提交。获 auto-commit 授权时告知后即可提交，不必等确认；未获授权则逐条审批。
- **锚点可验证**：每完成一个可验证的步骤（编译通过 / 测试绿），就落一个锚点提交。原因见下文的 bisect。
- **每条提交带 `Assisted-by` trailer**。

trailer 是什么：提交正文**末尾**的机器可解析元数据行，格式 `键: 值`，git 有专门的解析命令（`git interpret-trailers`）。本仓库的署名规则（ADR-0004）：agent 参与的提交写 `Assisted-by: <harness>:<model>`（如 `ZCode:glm-5.3-flash`），纯人类提交写 `Assisted-by: none`——**缺席即违规**。为什么强制缺席也违规（opt-out 而非 opt-in）？因为 opt-in 模式下 CI 只能校验"写了的格式对不对"，校验不了"该写而没写"——漏写永远查不出来。这个洞真实漏过水：2026-11-14 的首提交就缺署名，直接导致删库重建（journal 2026-11-13 篇）。 enforcement 是双层的：本地 `commit-msg` 钩子 fail-closed 拦截（t3 已落地，缺 trailer 直接中止、不代填），CI 逐提交校验兜底——`git commit --no-verify` 能绕过本地钩子，CI 是唯一绕不过的一层（ADR-0009 D6）。`task setup` 会安装钩子并把 `.gitmessage` 设为提交模板（已有模板不覆盖）；`git commit -m` 不经过模板，trailer 仍需手写。信源查证顺序与 harness / model 键表见 AGENTS 提交纪律节·agent 署名。

为什么过程提交要保留而不压掉？两个理由。其一，**bisect**：git 的二分定位工具，在一串提交里用二分法找出"第一个变坏的提交"——它要求每个提交的好坏可判定，这正是锚点可验证的用途；任务出问题时，bisect 能把范围缩到任务内的具体某一步。其二，本项目是学习驱动的：agent 的试错轨迹本身就是学习素材，压掉等于烧掉教材。

### 第 3 步：整理——rebase -i（人类执行）

PR 开启前，把 WIP 长链整理成**逻辑级提交序列**。整理用交互式 rebase：

```bash
git branch backup/feat-spec-0001-t2-20261115-1530   # 先打后路
git rebase -i dev                                    # 以 dev 为基线交互重放
```

先解释 rebase 本身（地基概念三的延伸）：rebase 把一串提交从原位置**摘下来，在新基线上逐个重新应用**——重新应用会产生**全新的 SHA**（哪怕内容一模一样，父提交变了、时间变了，身份就变了）。所以 rebase 是**历史改写**：改写后本地分支与远端分道扬镳，再推送就需要 force push（见下）。

`-i`（interactive）会打开一个编辑器，列出待重放的每个提交，每行前面可以改"动词"：

- `pick`——原样保留这个提交
- `fixup`——把它并进上一个提交，丢弃它的消息（typo 修复链的正确归宿）
- `reword`——保留改动，改写提交消息

整理的目标不是"越少越好"，而是**一个提交 = 一个完整逻辑单元**（单一意图）：typo 链 fixup 进它修的那个提交，功能步骤各自独立成提交。整理完的序列，每个提交都可编译、可单独理解——bisect 在合入后的漫长岁月里依然可用。

**禁止把整个任务 squash（压）成一个提交**——那会烧掉过程史，与 --no-ff 的设计目的正好相反。唯一的例外是纯文档任务：`docs/*` 分支由 GitHub squash 落地（第 5 步），分支上可以有多个提交（ADR-0010 已撤销"恰好一个"约束）；squash 把它们压成一条普通提交，过程史不进入 dev。

改写历史之后，本地分支与远端（你之前推过的 WIP）分叉了，普通 push 会被拒绝。这时需要 force push，本仓库规定必须带两件保险：

```bash
git push --force-with-lease --force-if-includes
```

- `--force-with-lease`：裸 `--force` 的意思是"用我的版本覆盖远端，别问"。lease 的意思是"**仅当远端还停在我上次看到的位置时才覆盖**"——如果队友（或另一个 agent）在这期间推了新提交，推送会被拒绝，而不是静默覆盖别人的工作。
- `--force-if-includes`：再补一层——如果本地刚刚 fetch 到了远端的新提交但你还没检查过，也拒绝推送。防"我以为没别人的东西，其实 fetch 进来了"。

整理（含 force push）在 Phase 0 由人类执行——agent 的确认链提案还在孵化中（proposals/agent-confirmation-chain）。整理前先打 backup 分支那条命令不是仪式感：rebase 重放撞上解决不了的真实冲突时，`git switch backup/...` 能一秒回到整理前的世界。

### 第 4 步：开 PR——评审与门禁的容器

PR（Pull Request）是 GitHub 上的一个评审单元：一个**来源分支（head）**请求并进一个**目标分支（base）**，附带的还有 diff 预览、评审意见、自动检查（CI）与合并按钮。本仓库的 PR 规矩都围绕一个事实展开——**PR 标题就是账本行**：合并时它会成为 dev 第一父链上那个 merge commit 的主题，**永久留存**。所以标题不是随手的描述，而是要按固定格式来写——五种合并变体（下表前五行）外加纯文档的 docs 变体（第六行）：

| 方向 | 标题格式 | 例 |
| --- | --- | --- |
| feat → dev | `合并 spec-N-tM 短名：一句话` | `合并 spec-0001-t2 api-healthz：Go 后端最小服务` |
| fix → dev | `合并 fix 短名：一句话` | `合并 fix api-healthz 超时重试：加退避` |
| hotfix → main | `合并 hotfix 短名：一句话（发布 vX.Y.Z）` | |
| backport → dev | `合并 hotfix 短名：backport 自 vX.Y.Z` | |
| dev → main | `合并 Phase N 收口：vX.Y.Z` | |
| docs → dev | `docs: 一句话` | `docs: guides 写作标准落地` |

标题由 CI 强制校验（六变体正则），而且**分支方向矩阵**在同 job 校验——dev 只接受 feat / fix / backport / docs，main 只接受 hotfix 与 dev，其余 base×head 组合一律拒绝。只验标题字面拦不住"feat 分支的 PR 开向 main"这类方向错误，所以方向与字面必须同时验。还有个容易踩的细节：`edited` 事件显式在触发列表里——PR 开启后**改标题也会触发重跑**，首次蒙混、随后改标题逃逸的路径是堵死的。

CI 的全貌（六个 job、结果矩阵、skipped 的合法性判读）见 ci-gate.md，这里只记一句：**ci-ok 是唯一必需检查**（2026-11-15 起在 dev / main 配置），它聚合其余所有检查的结果。

PR 描述按模板填四节：变更 / 验证 / 新增依赖（许可证声明）/ 检查单。**描述末尾有一行 `Assisted-by` 占位必须照实填**——纯文档 PR 走 squash 合入时，PR 描述会成为落地提交的正文，这一行就是落地提交的 trailer；漏填则落地提交过不了署名校验。

合并时 GitHub 会在标题后自动追加 ` (#N)`（N = PR 编号，2026-11-14 实测），所以账本行的最终形态是 `标题 (#N)`。**不要在合并界面手改 message 字段**——手改 = 账本行与 PR 记录脱钩，账本失守。

**纯文档 PR 的例外规则**：走 `docs/*` 分支，标题直接 `docs: …`，用 squash 按钮合入（第 5 步详述）。squash 提交的 author 保留原人、committer 变成 GitHub（平台代为提交），这是平台的固定行为。

**文档写回窗口**：PR 创建后、评审通过前，变更记录、验收勾选、实测结果可以作为**追加提交**推进同一个 PR（代码任务与 docs 分支都允许多提交，ADR-0010）。每次追加都会触发 `synchronize` 全量重跑——代码 PR 里夹的 docs 提交也会重跑两端构建，机制使然，不是配置错误。需要 PR 编号或 CI 实测结果的记账行只能在这个窗口落；合并之后再补，属于执行差异，记 journal 而不是改账本。

### 第 5 步：合入 dev——账本在这里成形

代码任务用 **merge 按钮**（仓库 settings 只开放 merge commit 与 squash 两种合入方式，rebase merge 关闭）。merge 按钮执行的是带 `--no-ff` 语义的真合并——**即使能快进也强制产生 merge 节点**（回看地基概念三：快进会抹平分支来过的痕迹）。

为什么这个节点如此重要？想象没有它：有的任务合入时恰好能快进（留下直线），有的要真合并（留下节点）——账本上"哪些提交是任务"的形状忽隐忽现。节点统一后，`git log --first-parent dev` 的输出**一行就是一个任务**（回看地基概念四），dev 第一父链成为干净的任务账本。这是 ADR-0005 定下的形态。

纯文档 PR 用 **squash 按钮**：GitHub 把 PR 里的所有提交压缩成**一条全新的提交**（注意：新 SHA，旧提交的 SHA 不复存在）落在 dev 上，没有 merge 节点。为什么 docs 例外？因为文档任务的过程史没有代码任务那样的 bisect 价值，压成一条普通提交正好——账本读法依然是干净的一行；分支上仍可保留多个提交（ADR-0010）。代价是：squash 后 `git branch --merged` 认不出这个分支已经合过（SHA 被重写），本地删分支要用 `git branch -D`（journal 2026-11-14 篇记录过这个坑）。

合并后远端会自动删除任务分支。**过程史不丢**：merge 节点让任务的全部过程提交从 dev 沿第二父永久**可达**（可达 = 顺着父指针能走到，git 只清理不可达的提交）——分支标签没了，历史还在。

### 第 6 步：并行——不追平，必要时才 rebase

任务分支不要求时刻包含 dev 的最新提交（GitHub 的 "Require branches to be up to date" 保护是关闭的）。为什么敢关？因为开着会死锁：dev 每被合入一次就前进一格，所有在飞 PR 立刻"过期"，全部被迫 rebase 改写——而改写会作废全部 approval（Dismiss stale approvals 机制），等于每次合入都把其他任务打回评审原点。

代价是 PR 的绿灯只代表"对旧 base 是好的"，与 dev 最新版的组合是未验证的——这正是第 7 步兜底存在的原因。日常只在两种情况 rebase：真实冲突（两边改了同一处），或怀疑 CI 红灯源于基线过期。rebase 后注意两件事：approval 作废需重新评审（机制如此，不是刁难）；任务分支的 upstream 已被刻意 unset（worktree.md 坑 1），**不要用裸 `git pull` 或 `git pull origin dev` 把 dev 合进任务分支**——正确姿势是在本工作树内 `git rebase dev`。

### 第 7 步：兜底——语义冲突的事后发现

关闭 up-to-date 换来的自由，由 push 触发的 CI 兜底：dev 每次被合入（包括 docs squash）都触发一次全量检查。它的定位是**事后发现**（ADR-0009 D2）：push run 只验证 dev 自身的新状态，"待合 PR + 新 dev"的组合对不对，要等真合进去才见分晓。红 = 两个各自绿了的分支合起来坏了——这叫**语义冲突**：文本层面 git 能无冲突合并（改的行不重叠），语义层面互相破坏。典型例子：任务 A 给某函数改了签名，任务 B 新增了一个按旧签名调用的测试——各自评审时都完美，合到一起测试全红。

处置纪律：dev push 红 = 语义冲突落地，**暂停后续合入**（避免在坏基线上叠更多任务），然后二选一：小问题开 `fix/` 分支修；伤筋动骨的用 `git revert -m 1 <merge commit>` 整体退回那个任务。这里两个细节：revert 不是"删历史"，而是生成一个内容相反的新提交；`-m 1` 指定"把 merge commit 的第一父线（dev 原本的样子）当作撤销的方向基准"——没有 `-m`，git 不知道该退回两个父中的哪一个。还有个反直觉的规则：**被 revert 的任务想重新合入时，不会自动把内容带回来**（revert 提交拦在中间），正确做法是 revert 那个 revert——用一条"撤销撤销"恢复原改动。

## 修复与 hotfix

合入之后发现了问题，按"问题在哪条分支上"选分支：

| 分支 | 场景 |
| --- | --- |
| `fix/spec-0001-t2-xxx` | 任务还在飞（PR 未合），修自己分支上的问题 |
| `fix/spec-0001-xxx` | 任务已合入 dev，修该 spec 的遗留问题 |
| `fix/<scope>-xxx` | 与 spec 无归属关系的小修（scope 取白名单：web / api / infra / ci / docs / deps） |
| `hotfix/<scope>-xxx` | **已发布**的 main 上有 bug——生产事故级，走独立路线 |

### hotfix 路线：本仓库最重要的一条不变量

main 上的 bug 等不及下一次收口，流程是"修 main、发布、回流 dev"三段：

```bash
# ① 从 main 切出修复分支
git switch -c hotfix/api-healthz-timeout main
# ② 修复、提交、PR 回 main（标题：合并 hotfix 短名：一句话（发布 vX.Y.Z））

# ③ 合入后打补丁版本 tag——注意打在 origin/main^2
git fetch origin
git tag -a v0.1.1 origin/main^2 -m "v0.1.1 — hotfix api-healthz-timeout：一句话"
git push origin v0.1.1

# ④ 回流 dev：从 dev 切 backport 分支，merge 那个 tag，PR 回 dev
git switch -c backport/api-healthz-timeout dev
git merge v0.1.1
# PR 回 dev（标题：合并 hotfix 短名：backport 自 v0.1.1）
```

三处"为什么"值得展开：

**为什么 tag 打在 `origin/main^2`？** `^2` 读作"第二个父"——hotfix 的 PR 是真合并，merge commit 第一父是 main 旧 tip，第二父才是 hotfix 分支的 tip（修复本体）。tag 打在第二父上，是为了让"修复 commit 群"有一个永久指向——hotfix 分支合并后会被删除，没有 tag 的话修复内容虽可达但难定位；更重要的是第 ④ 步的 `git merge v0.1.1` 需要这个 tag 指向 hotfix 线本身（指向 merge commit 会把整条 main 历史并进 dev）。另外用 `origin/main` 而不是本地 `main`，是因为**远端引用才是新鲜度可靠的**——本地 main 可能落后而 git 不会报错。

**为什么回流必须用 merge、禁止 cherry-pick？** cherry-pick 的机制是"把某个提交的改动**复制**一份应用到当前分支，产生一个**内容相同但 SHA 不同**的新提交"。如果 hotfix 用 cherry-pick 回 dev，同一个修复就存在两份不同 SHA 的拷贝：main 一份、dev 一份。此后 dev→main 合并时，git 的合并判断基于共同祖先——两份拷贝互不认识，只要它们碰过同一处代码，合并就报冲突，而且**每次收口都会复发**。用 merge 回流则完全不同：修复提交成为 main 与 dev 的**共同祖先**的一部分，git 认得出"这是同一个改动"——同一修复不会变成两份互不相识的重复改动，收口时也就不会因它产生冲突。收口的机械守卫（三点 diff，见下节）正建立在这条不变量上。漏回流不会立刻出事，但会在收口时被守卫拦下。

**为什么标题有两套变体？** hotfix → main 是"发布"（带 `（发布 vX.Y.Z）`），backport → dev 是"回流"（`backport 自 vX.Y.Z`）——账本读法里这是两种不同性质的事件，一行账各自可见。

## Phase 收口

一个 Phase 的全部任务合入 dev 后，把 dev 合回 main 并打版本 tag，叫**收口**。五步，顺序敏感：

1. **收口前置 PR 先行**（`fix/` 短名 PR 回 dev，先合入）：内容是 SPEC 验收条目逐条勾选 + spec status 改 done。为什么需要它？收口 PR 的 head 就是 dev 本身、而 dev 必经 PR 禁直推——**收口 PR 自己没有承载文件改动的位置**，所以"改验收状态"必须由一个普通 PR 先行完成。顺序反了（收口 PR 开启后才想改 spec）会撞上 Dismiss stale approvals：追加提交作废已得的审批，全部重来。

2. **dev → main 收口 PR**：评审对象是**发布检查单**而不是代码（代码已在各 feat PR 评审过）。首项是机械守卫：**main 自分叉以来没有 dev 缺失的改动**——

   ```bash
   git diff --quiet origin/dev...origin/main   # 退出码 0 = 通过
   ```

   三点语法 `A...B` 的含义：比较"共同祖先到 B"的差异。放在这里就是问"main 上有没有 dev 不知道的东西"——正常应为空；非空 = main 上有没回流 dev 的内容（典型是 hotfix 漏回流），失败时逐 tag 排查。一个著名的陷阱：不能用 `git merge-base --is-ancestor origin/main origin/dev` 替代——收口时刻 main 的 tip（收口 merge commit）只存在于 main 第一父链上，这个判断恒为假、恒误报阻断；tag 遍历也查不出漏打 tag 的 hotfix——三点 diff 两种漏法都能覆盖。

   其余检查项：全部任务已合入 / dev push CI 绿 / 前置 PR 已合入 / 版本号已指定。批准 ≥1 名非作者核心成员 + 检查单逐项勾选。

3. **打收口 tag**：

   ```bash
   git fetch origin
   git tag -a v0.1.0 origin/main -m "v0.1.0 — Phase 0 收口：一句话（覆盖 SPEC-0001）"
   git push origin v0.1.0
   ```

   tag 有两种：轻量 tag（只是一个指针）与 annotated tag（一个完整对象，带说明、作者、日期）。**版本只用 annotated**——发布必须自带说明。收口 tag 打在 merge commit（= `origin/main`）上，让它落在 main 第一父链上——"第一父链 + tag = 版本史"的读法才成立。`git push origin vX.Y.Z` 显式只推 tag：`--follow-tags` 依附普通 push，会连带推当前分支，本地 main 落后时行为不可预期。

4. **dev 不追平 main**：收口后不要把 main 的进展合回 dev（更不要 ff）——main 的版本史节点会污染 dev 的第一父链，任务账本尽毁。**分叉是常态**，两条线各走各的，下次收口再汇合。

5. **版本号**：`vX.Y.Z`——X（主版本）只在出现不兼容变更时 +1（0.x 是开发期，首次公开上线定 1.0.0，其后 X+1 时 Y / Z 归零）；Y 在每次收口时显式指定并记入 journal（Phase 0 → v0.1.0，Phase 1 → v1.0.0，其后 Y+1）；Z 只被 hotfix 消耗。

## 三层历史读法（所有规则服务的目标）

三个层次对应一条总纲：**git 历史美观是首要目标，作用域 = 入账层**（main / dev 第一父链
+ PR 整理后的提交序列）——commit 量精简、分支结构明确、内容合规完善、无意义分支及时
清理（合并后删本地分支，squash 落地用 `-D`）；feat 过程史不受此限（WIP 草稿文化，
过程保留正是 --no-ff 的目的）。完整条款见 AGENTS「提交纪律」历史美观总纲。

```
git log --first-parent main + tag   →  版本史：我们发布过什么
git log --first-parent dev          →  任务史：谁在何时合入了什么（含 hotfix 回流）
git log <feat 分支>                  →  过程史：任务内部怎么推进的
```

回看地基概念四：`--first-parent` 让 log 遇到 merge commit 只走主线。于是 main 第一父链上只剩收口与 hotfix 的 merge（+ tag 点缀版本），dev 第一父链上一任务一行，任务分支的完整链是过程。三个问题三秒钟找到答案。

两个例外要记：hotfix 的补丁 tag 打在 merge 第二父上（见 hotfix 一节），不装饰在这三层里——查补丁版本用 `git tag -l` 或 `git tag --contains <sha>`；dev 侧跑 `git describe` 解析不到收口 tag（收口 merge commit 不在 dev 的祖先里），**版本号一律以 main 侧为准**，Phase 1 之后的部署脚本勿在 dev 构建里用 describe 取版本。

## 常见误区

每条：场景 → 为什么错 → 正确姿势。

- **"分支太乱了，直接推 dev 最快"**
  错：dev 受分支保护必经 PR，直推物理上不可能；绕过 PR = 绕过账本节点与门禁。**正确姿势**：走任务分支与 PR，"慢"的评审与 CI 正是账本可信的来源。

- **"PR 前把所有提交压成一个，多干净"**
  错：过程保留是 --no-ff 设计的目的（bisect + 学习素材），整体 squash 等于烧教材。**正确姿势**：rebase -i 磨成逻辑级序列——少而精，但不止一个。

- **"hotfix 修完 cherry-pick 到 dev，多轻"**
  错：复制出第二份 SHA，共同祖先退化——同一修复变成两份互不相识的改动，碰过同一处就会在收口时冲突（见 hotfix 一节的完整后果链）。**正确姿势**：backport/ 分支 + `git merge <tag>`。

- **"hotfix 合回 main 后，顺手在 dev 上 git merge 一下"**
  错：dev 必经 PR 且禁 bypass，无人可直推——这是机制不是习惯。**正确姿势**：backport/ 分支走 PR。

- **"收口后记得把 dev 对齐 main"**
  错：main 的版本史节点会污染 dev 第一父链。**正确姿势**：什么都不做，分叉是常态。

- **"任务分支落后 dev 了，git pull 同步一下"**
  错：pull = fetch + merge，会把 dev 的提交 merge 进任务分支——制造一个本地 merge 节点，dev 的历史整段混进 PR 的提交列表（PR 的 diff 本身因三点比较不会变脏，但历史与评审视图已乱）。**正确姿势**：本工作树内 `git rebase dev`（改写是任务分支的特权，它还没合入）；并记得 rebase 作废 approval。

- **"force push 太危险了，能不推就不推"**
  部分对：裸 `--force` 确实危险。**正确姿势**：本仓库规定的 `--force-with-lease --force-if-includes` 带双保险——lease 拒绝覆盖他人新推的提交，if-includes 拒绝推送未经检查的 fetch 结果。危险的是裸力，不是带保险的推。

## 延伸

按需取用：ADR-0003（分支与合并的完整决策链与被否方案）、ADR-0005（双合并策略：任务 --no-ff、文档 squash）、ADR-0007（提交 / 推送授权模型）、ADR-0009（CI 门禁）、ci-gate.md（门禁结构与读法详解）、worktree.md（多工作树并行——一台机器同时推多个任务的标准姿势）、proposals/ci-gate-optimizations.md（门禁优化候选与"已接受、不修"清单）、SPEC-0001 任务分解节（t0-t6 实例）、proposals/（agent 确认链提案，孵化中）。想在文档目录里写东西，先读 doc-system.md。
