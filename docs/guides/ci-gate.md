---
title: "CI 门禁讲解：读懂你的红绿灯"
author: foamshadow
date: 2026-11-15
status: draft
tags: [se-arch, tool-ci]
related: [ADR-0009, SPEC-0001, ADR-0003, ADR-0004]
---

# CI 门禁讲解：读懂你的红绿灯

## 讲给谁 / 前置知识

给所有要**开 PR** 的成员（人类与 agent）——只要你的改动要走 PR 进 dev / main，就绕不开本文描述的这道门。前置：读过 git-workflow.md 的地基概念（知道分支、merge、PR 是什么）；**不假设你用过 GitHub Actions**，CI 领域的全部词汇在下一节就地讲。

实现本体已随 t0 入库：`.github/workflows/ci.yml`（工作流定义）+ `.github/scripts/` 三个脚本（aggregate / check-title / check-attribution）+ PR 描述模板。本文讲门禁的**结构与读法**；行为与本文不符时以实现文件为准、视为本文 bug 同 PR 修正；设计出处是 SPEC-0001-A5 与 ADR-0009（被否方案与翻转条件都在那篇）。

## 核心图景

### CI 地基概念：五个词讲清 GitHub Actions

**workflow（工作流）**：放在 `.github/workflows/` 目录下的一个 YAML 文件，声明"**什么事件发生时，自动执行哪些任务**"。本仓库只有一个：`ci.yml`。

**job（作业）**：workflow 里的一个执行单元。GitHub 会为每个 job 分配一台全新的虚拟机，把仓库检出进去，跑完销毁。`ci.yml` 里定义了六个检查 job + 一个聚合 job（共七个，下节见图）。

**check（检查状态）**：每个 job 跑完，会向它所属的 PR / 分支上报一个状态（官方叫"结论"），这就是 PR 页面上那一个个红绿灯。常见结论有五种：`success`（绿）、`failure`（红）、`cancelled`（红，被取消）、`skipped`（灰，"这个 job 决定不跑"）、`neutral`（灰，"判定为不适用"）——此外还有 `timed_out` 等更少见的结论。

**一个反直觉的官方语义要先记住**：GitHub 认为 `success / skipped / neutral` 都算**成功状态**——也就是说在 GitHub 眼里，"job 跑过且通过"和"job 压根没跑"是**一样绿**的。整个门禁设计的相当一部分，就是在对抗这个默认行为。

**required check（必需检查）**：分支保护（branch protection）的一种配置项——把某个 check 的名字设为"必需"后，**合并按钮在该名字的 check 报成功状态（success / skipped / neutral）之前保持禁用**——注意 skipped 与 neutral 也算"过关"，这正是下一段反直觉语义的用武之地。这就是"门禁"二字的物理含义：不是道德劝阻，是按钮物理点不动。

**run（运行）**：一次事件触发所执行的全部 job 的集合。PR 页面 Checks 标签下的每一行，都来自某次 run 里的某个 job。

### 双触发图景

`ci.yml` 声明了两种触发（`on:` 段），同一套 job 在两种事件下的职责不同：

```
pull_request 事件（对 PR 检查，结果挂 head SHA）      push 事件（dev / main 被推送，全量跑）
├─ changes        改动范围探测                ├─ web / api（不受 changes 裁剪，全量）
├─ web            Node 侧 lint/typecheck/build ├─ attribution（before..after 区间）
├─ api            Go 侧 build/test/lint
├─ title          标题六变体 + 方向矩阵
├─ pr-meta        PR 描述末行 trailer / 无评审段
├─ attribution    逐提交署名 trailer        （changes / title / pr-meta 跳过：
└─ ci-ok          聚合 ← 分支保护唯一必需检查   它们依赖 PR 上下文，push 下必误报）
```

一个实现细节：pull_request 事件下，Actions 实际检出的代码是 PR 的**合并预演**（`refs/pull/N/merge`——把 head 合进 base 的试合并结果），check 结果则挂在 PR head 的 SHA 上。所以"PR 绿"意味着"合并进 base 之后的样子能通过"——这就是 CI 能在合并前验证合并结果的原因；PR 页面上的文本冲突提示则来自 GitHub 自己的 mergeability 计算，与 Actions 无关。

只需要记住三句话：

1. **合并按钮只认 `ci-ok` 一个名字**——分支保护只挂这一个 required check；其他任何 job 红了，本质都是经由 ci-ok 的结果矩阵把合并按钮摁住。job 增删不需要改保护配置。
2. **skipped ≠ 通过**——skipped 在页面上是灰的、在 GitHub 语义里算成功，但它是否合法取决于触发上下文（判读表见下节矩阵）。
3. **push 上的绿灯是事后观测，不是合并前保证**——语义冲突可能在合入 dev 之后才暴露（见设计三）。

### 自举注记（已结案的历史）

`ci-ok` 这个名字有个先有鸡还是先有蛋的问题：required check 只能在下拉里选"最近 7 天内成功上报过的 check 名"，而 t0（`ci.yml` 本体）合入前它从未上报过——所以 t0 自己的 PR 只能人工把关，合入之后立刻手工补配置。2026-11-15 已在 dev / main 配置完成（`strict=false`——不要求分支包含最新 base，与 ADR-0003 的整理门一致；`enforce_admins=true`——管理员同样受门禁约束）。这是一次性 bootstrap 例外（ADR-0009 D8，与 SPEC-0001 的自批例外同源），不得成为先例。

## 为什么这样设计

七组设计点。每段结构：**规定是什么 → 它防的是什么事故 → 操作上怎么读**。完整论证与被否方案在 ADR-0009。

### 设计一：单 workflow，required 只挂 ci-ok（D1）

**规定**：所有检查住进一个 `ci.yml`，分支保护只把 `ci-ok` 一个名字设为必需。

**防的事故**：保护配置与 workflow 脱节。required check 按"名字"配置——若六个检查 job 各自设必需，以后每增删一个 job 都要有人记得去改保护设置（忘了就出现"新 job 谁也不管它"或"删掉的 job 让按钮永久禁用"）。聚合后入口唯一：**job 怎么变，门禁入口永远是 `ci-ok` 这一个名字**。

### 设计二：`if: always()` 硬约束 + 结果矩阵（D3）——全篇最重要的一节

**规定**：聚合 job `ci-ok` 声明 `if: always()`，且它的聚合脚本核对的不是"没有失败"，而是一张**结果矩阵**：

| 触发 | 必须 `success` | 允许 `skipped` |
| --- | --- | --- |
| PR | changes / title / pr-meta / attribution | web / api——且仅当 changes 判定"无相关改动" |
| push | web / api / attribution | changes / title / pr-meta（事件无 PR 上下文） |

**防的事故**要拆两层讲。

第一层：为什么必须有 `if: always()`？GitHub 的默认行为是——`ci-ok` 通过 `needs` 声明它依赖其他 job，**任何被依赖的 job 失败时，聚合 job 直接被跳过**。而地基概念里刚说过：skipped 在 GitHub 语义里算成功。所以缺 `always()` 的后果不是"门禁卡住等你修"，而是**静默放行**：web 测试红 → ci-ok 被跳过 → skipped 算成功 → 合并按钮照常点亮。门禁失效时没有任何声音。

第二层：为什么只有 `always()` 还不够？设想聚合脚本写成"所有依赖不是 failure 就算通过"——某个 job 因为作者 `if:` 条件写错而从未运行（skipped），聚合依然全绿。所以脚本核对的是矩阵：**每个触发场景下，哪些 job 必须是 success、哪些 job 允许 skipped、skipped 的条件是什么**。一句话读法：**skipped 不是白名单通行证，必须与触发上下文绑定**——PR 下 title / pr-meta / attribution 被跳过是门禁漏洞（等价于没校验），push 下跳过它们才是设计（它们依赖 PR 上下文，push 事件里必然误报）。

另外 `needs` 必须把 title、pr-meta 与 attribution 也列进去：否则这些违规只产生旁路红灯，聚合看不到它们，合并按钮照样亮。

**操作**（读法）：聚合脚本首行打印**六个被依赖 job** 的结果快照（`event=… changes=… web=… api=… title=… pr_meta=… attribution=…`——另带 event 字段；ci-ok 自己不在 `needs` 里，不会出现在快照中），每处违规以 `::error::` 注解直接显示在 Checks 摘要上——读红灯从这行快照开始，不用逐个 job 翻日志。

### 设计三：push 双触发，定位是"事后发现"（D2）

**规定**：push 到 dev / main 也触发全量检查，但跳过 changes、title、pr-meta。

**为什么 push 要跑**：这正是 git-workflow.md 第 6 步讲过的自由换来的义务——仓库关闭了 "Require up to date"（它与 rebase 整理门死锁：dev 每动一次，全部在飞 PR 被迫改写、approval 全部作废）。关闭之后，"PR + 最新 dev 的组合是否完好"没有合并前的保证者，push run 是**唯一的兜底观测面**。

**但要准确理解它补偿的是什么**：push run 只验证 dev / main 自身的新状态，**不验证"待合 PR + 新 base"的组合**——组合冲突要等真正合入 dev 后，由 push run 全量变红才暴露。所以它的定位是**事后发现**：补偿的是可见性，不是拦截力。绿灯 ≠ 合并后一定不坏。

### 设计四：标题与方向在同一 job 校验（D5）

**规定**：`title` job 校验两件事——PR 标题匹配六变体正则之一（五种合并变体 + docs 变体，格式表见 git-workflow.md 第 4 步），且 base×head 方向合法（dev 只收 feat / fix / backport / docs，main 只收 hotfix 与 dev，其余组合一律拒绝）。

**防的事故**：账本行写错。PR 标题在合并后成为 dev / main 历史上永久的提交主题，而合并按钮自己不读标题格式——没有这个 job，错格式的标题会直接落进账本。方向校验与字面校验必须同时做，因为只验字面拦不住"feat 分支的 PR 开向 main"（标题本身可能完全合法）。

两个配套细节：`edited` 事件必须显式订阅——GitHub 默认的 pull_request 触发不含"编辑 PR"，不显式加的话，开启后改标题就能逃逸校验；校验失败时错误信息自带期望样板（"期望形如：合并 spec-0001-t1 短名：一句话"），PR 模板顶部注释也有六行速查——红灯照抄改参即可，不用回文档查。

### 设计五：逐提交署名校验，PR 与 push 双覆盖（D6）

**规定**：`attribution` job 对范围内**每个非 merge 提交**校验 `Assisted-by` trailer（存在性 + 格式正则）；PR 场景取 `base..head` 区间，push 场景取 `before..after` 区间；区间不可用时回退到全史校验（fail-closed——宁可误伤，不放过去）。

**为什么 push 也要查**（本地钩子 t3 落地后理论上已经拦了一道）：三层答案。其一，`git commit --no-verify` 能绕过任何本地钩子，CI 是唯一绕不过的一层；其二，squash 合入的落地提交根本不经过 PR run——它的 trailer 来自 PR 描述末尾的占位行（描述在 squash 时成为提交正文），只有 push 校验能看到它；其三，checkout 需要 `fetch-depth: 0`（完整历史）才能取到提交区间，浅克隆拿不到。跳过 merge 提交的依据不是"它由平台生成"，而是 merge 提交不注入内容、**结构上无法携带 trailer**（ADR-0004）。

### 补充：PR 描述元数据（pr-meta，C6）

**规定**：`pr-meta` 只在 `pull_request` 事件运行，校验 PR 描述最后一行是合法 `Assisted-by` trailer、正文无 `## 评审…` 记录段；并入 `ci-ok`；push 下 skipped，由矩阵放行。

**为什么**：docs PR 的 squash 正文取自 PR 描述。PR run 校验的是分支提交，`title` 只管标题，`attribution` 只管提交——**描述是死角**。`pr-meta` 是合并前的 body backstop。

**边界**：body 编辑不换 head SHA，check 之后仍可改描述，检查可能 stale；它不能替代合并时的快照。docs 单提交不查（ADR-0005 单提交拟撤销；分支可多提交，squash 后仍一个）。

### 设计六：空分端 job 占位（D7）

**规定**：web / api 两个 job 在 t1 / t2 填入真实构建之前，只是各跑一行 `echo`——**该侧有改动**的代码 PR 上，空 job 真运行并报 success；changes 判定该侧无相关改动时（docs-only、单侧改动等）才 skipped。

**为什么占位**：让七个 job 的 `needs` 结构从第一天就稳定，聚合逻辑可以在 t0 就真刀真枪验证。注意这**不是**为了 required 配置不悬空——required 只挂 ci-ok，跟 web / api 是否存在无关。

### 设计七：`ci-ok (push)` 显示名消歧（D4）

**规定**：push 触发时聚合 job 的显示名是 `ci-ok (push)`，PR 触发时是 `ci-ok`；required 只挂 `ci-ok`；job 的 id 始终叫 `ci-ok`（`needs` 引用不受影响）。

**防的事故**：收口 PR（main ← dev）是**常规**场景而非边角——dev 前进时 push run 在 dev head 上报一次聚合，同一 head 开 PR 后 pull_request run 再报一次：同 SHA、同 check 名，required 取哪次是平台未明确文档化的语义。给 push 侧显示名加后缀，让 required 认的 `ci-ok` 在收口场景下只会有一份，判定不再依赖未明行为。

## 常见误区

每条按"场景 → 为什么 → 正确姿势"展开。

- **"有几个灰色的 skipped，但页面算我过了"**
  skipped 在 GitHub 语义里就是成功，但它是否**合法**取决于触发上下文——回看设计二矩阵：这次触发下，这个 job 该不该跑？PR 下 title / pr-meta / attribution 被跳过 = 门禁漏洞（等价于没校验），不是省事。**正确姿势**：先对矩阵判"该不该 skipped"，再决定要不要管它。

- **"CI 全绿，合进 dev 一定没问题"**
  push 是事后发现（设计三）：它验证的是 base 自身，"PR + 新 base"的组合要等合入后才见分晓。dev push 红 = 语义冲突落地。**正确姿势**：绿灯后照常合并，但合并后扫一眼 dev 的 push run；红了立即暂停后续合入，开 `fix/` 修或 `git revert -m 1` 回滚。

- **"本地 `--no-verify` 绕过钩子，没人知道"**
  本地钩子（t3 起）确实被绕过了，但 CI 逐提交校验（PR 与 push 双场景）是唯一绕不过的一层——缺 trailer 的提交会按 SHA 逐个列出判红。**正确姿势**：trailer 写进提交习惯；补 trailer 用 `git commit --amend`（未推送时）。

- **"改个 PR 标题而已，不用重跑吧"**
  标题是账本行，`edited` 显式在触发列表里——改标题必重跑整个 workflow（有相关改动的 PR 还会重跑 web / api 构建；docs-only 下它们仍 skipped。成本已知且接受，见 ADR-0009 后果节）。**正确姿势**：开 PR 前照模板速查写好标题，减少 edited 重跑。

- **"在 `on:` 里加 `paths:` 过滤，docs 改动就不跑构建了，省资源"**
  被路径 / 分支过滤跳过的 workflow，其 check 会停在 Pending 状态并**阻断合并**（官方行为）——省了资源，堵了门。**正确姿势**：保持 workflow 始终运行，让 `changes` job 自己判定要不要跑分端——跳过发生在 job 级才是绿的。

- **读红灯的顺序**
  ① 看 ci-ok 日志首行的结果快照（`event=… changes=… …`）与 `::error::` 注解——哪个 job 红 / 被跳过 / 期望什么，一眼可得；② 对照矩阵判"这次触发下它该不该 skipped"；③ 再进对应 job 日志定位。不要从 Checks 列表第一条往下翻。**特例**：changes 本身红（失败而非 skipped）会级联——web / api 随之被跳过、矩阵判红，此时根因在 changes 的日志，不在分端。

- **"我改了根目录的 Taskfile / tsconfig，怎么 web / api 没跑？"**
  已知假阴性：changes 的 filters 只覆盖 apps/web、apps/api、packages 与 workspace 根清单文件（pnpm-lock / pnpm-workspace / package.json），根工具链文件尚未入表。优化候选已登记（`proposals/ci-gate-optimizations` C4，触发条件 = t1 引入根 Taskfile），不是你的姿势不对——**正确姿势**：改根工具链时顺手全量自查，或等 C4 落地。

## 延伸

按需求取用：

- **要看为什么**（每个设计点的完整论证、被否方案表与翻转条件）：ADR-0009
- **要看实现规格**（六变体正则全文、矩阵细则、实测清单）：SPEC-0001-A5
- **要动手改门禁前**：proposals/ci-gate-optimizations.md——C1–C5 优化候选与"已接受、不修"清单，别重提已否决项
- **要看门禁为什么长这样**（push 兜底与 up-to-date 死锁的前因）：ADR-0003
- **要看署名规则本体**（trailer 格式、键表、信源查证）：ADR-0004 + AGENTS 提交纪律节
- **要看任务全流程**：git-workflow.md（本文只展开其中 CI 一环）
- **实现本体**：`.github/workflows/ci.yml` 与 `.github/scripts/`——行为与本文不符时以实现为准，并视为本文 bug 同 PR 修正
