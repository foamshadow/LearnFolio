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

所有要开 PR 的成员（人类与 agent）。前置：了解本仓库分支模型（见 git-workflow.md）；会打开 GitHub Actions 页面看一次 run。实现已随 t0 入库：`.github/workflows/ci.yml` + `.github/scripts/`（aggregate / check-title / check-attribution 三脚本）+ PR 模板。本文讲门禁的**结构与读法**，实现细节以这些文件为准；设计出处是 SPEC-0001-A5 与 ADR-0009（被否方案与翻转条件）。

## 核心图景

所有检查在**一个 workflow**（`ci.yml`）里，六个 job、一个聚合：

```
pull_request 事件（对 PR head）              push 事件（dev / main，全量跑）
├─ changes        改动范围探测               ├─ web / api（不受 changes 裁剪）
├─ web            Node 侧 lint/typecheck/build ├─ attribution（before..after 区间）
├─ api            Go 侧 build/test/lint
├─ title          标题六变体 + 方向矩阵       （changes / title 跳过：
├─ attribution    逐提交署名 trailer            依赖 PR 上下文，push 下必误报）
└─ ci-ok          聚合 ← 分支保护唯一必需检查
```

只需要记住三件事：

1. **合并按钮只认 `ci-ok` 一个名字**——分支保护只挂这一个 required check；其他任何 job 红了，本质都是通过 ci-ok 的结果矩阵判红。job 增删不改保护配置。
2. **skipped ≠ 通过**——GitHub 把 `success / skipped / neutral` 都算成功状态，但 skipped 是否合法取决于触发上下文（读法见下节矩阵）。
3. **push 上的绿灯是事后观测，不是合并前保证**——语义冲突可能在合入 dev 之后才暴露。

自举注记（已结案）：`ci-ok` 在 t0 合入前从未上报过，required check 无法提前配置（下拉只列最近 7 天内成功过的 check 名）——t0 自身 PR 人工把关，合入后手工补配置；2026-11-15 已在 dev / main 配置完成（strict=false——不要求 up-to-date，与 ADR-0003 一致；enforce_admins=true——管理员同样受门禁约束）。这是一次性 bootstrap 例外（ADR-0009 D8，与 SPEC-0001 自批例外同源），不得成为先例。

## 为什么这样设计

**单 workflow，required 只挂 ci-ok（D1）**：分支保护按 check 名配置。六个检查若各自设 required，job 增删都要改保护设置；聚合后只维护一个名字，门禁的"入口"稳定，聚合逻辑集中一处。

**`if: always()` 是硬约束 + 结果矩阵（D3）**：依赖 job 失败时，聚合 job 会被跳过，而 GitHub 把 skipped 算成功——缺 `always()` 的后果不是"卡住等待"，而是**静默放行**（web 测试红 → ci-ok skipped → 合并按钮照常点亮）。但只有 always() 还不够：某个 job 因 `if` 写错被跳过时，"非 failure 即过"式的聚合仍会全绿。所以聚合脚本实现的是**结果矩阵**：

| 触发 | 必须 `success` | 允许 `skipped` |
| --- | --- | --- |
| PR | changes / title / attribution | web / api——且仅当 changes 判定"无相关改动" |
| push | web / api / attribution | changes / title（事件无 PR 上下文） |

判红条件两侧相同：任一 job `failure` / `cancelled`；或必需项 `skipped`；或应跑的分端 `skipped`。一句话读法：**skipped 不是白名单通行证，必须与触发上下文绑定**——PR 下 title / attribution 被跳过是门禁漏洞，push 下跳过它们才是设计。另外 `needs` 必须含 title 与 attribution：否则标题 / 署名违规只是旁路红灯，拦不住合并按钮。实现锚点：聚合脚本首行打印六个 job 的结果快照（`event=… changes=… web=… …`），每处违规以 `::error::` 注解直接显示在 Checks 摘要上——读红灯从这行快照开始。

**push 双触发的定位是"事后发现"（D2）**：push run 只验证新 base 自身，不验证"待合 PR + 新 base"的组合——组合冲突要等合入 dev 后由 push run 全量变红才暴露。它补偿的是**可见性**（关闭 "Require up to date" 后唯一的兜底观测面），不是拦截力。为什么不恢复 up-to-date？它与 rebase 整理门死锁：dev 每动一次，全部在飞 PR 被迫改写、approval 全部作废（ADR-0003）。

**标题与方向在同 job 校验（D5）**：PR 标题是账本行，写错必须在合并前拦住——合并按钮不会读标题。`edited` 事件必须显式订阅（默认 types 不含 edited，否则改标题可逃逸校验）。同 job 还校验 base×head 方向（dev←feat/fix/backport/docs、main←hotfix/dev，其余组合一律拒绝）：只验标题字面拦不住"feat PR 提到 main"这类方向错误。校验对象是 PR 标题而非 merge 提交——后者由平台追加 ` (#N)`。校验失败时错误信息自带期望样板（如"期望形如：合并 spec-0001-t1 短名：一句话"），PR 模板顶部注释也有六行速查——红灯照抄改参即可。

**署名校验 PR 与 push 双覆盖（D6）**：`--no-verify` 能绕过本地钩子，CI 是唯一挡得住的一层；直推、squash 落地提交都不经过 PR run——squash 提交的 trailer 来自 PR 描述**末尾的占位行**（squash 时描述进入提交正文；模板漏填 = squash 提交被判红），所以 push 也查（`before..after` 区间，区间不可达时回退全史，fail-closed）。跳过 merge 提交不是因为"由平台生成"，而是因为 merge 提交不注入内容、无法携带 trailer（ADR-0004）。

**空分端 job 占位（D7）**：web / api 在 t1 / t2 填充前只是 `echo`，但空 job 是**真运行并报 success**（不是 skipped——只有 docs-only 等被 `if` 裁剪时才 skipped）。占位为的是 needs 结构稳定、聚合逻辑可以在 t0 先验证，不是为了 required 配置不悬空。

**`ci-ok (push)` 显示名消歧（D4）**：收口 PR（main←dev）是常规场景：dev 前进时 push run 在 dev head 上报一次聚合，同 head 开 PR 后 pull_request run 再报一次——同 SHA 同名，required 取哪次是平台未明语义。决策：push 侧显示名 `ci-ok (push)`、required 只挂 `ci-ok`；job id 不变，`needs` 引用稳定。

## 常见误区

- **"skipped 了但页面是绿的，过了"**——先对照矩阵：这次触发下它该不该跑？PR 下 title / attribution skipped = 门禁漏洞（等价于没有校验），不是省事。
- **"CI 全绿，合进 dev 一定不坏"**——push 是事后发现。dev push 红 = 语义冲突落地：暂停后续合入，开 `fix/` 修或 `git revert -m 1` 回滚（AGENTS 分支与版本节）。
- **"本地 `--no-verify` 绕过钩子没人知道"**——CI 逐提交校验（PR 与 push 双场景）是唯一绕不过的一层，缺 trailer 的提交按 SHA 列出判红。
- **"改个 PR 标题而已，不用重跑"**——标题是账本行；`edited` 显式在触发列表里，改标题必重跑校验（含 web / api 的重跑成本，已知且接受）。
- **"用 `paths:` 过滤裁剪省资源"**——被路径 / 分支过滤跳过的 workflow，其 check 停在 Pending 并阻断合并（官方行为）；`changes` job 正是它的替代：workflow 始终运行、job 自己判定，跳过发生在 job 级才能是绿的。
- **读红灯的顺序**：先看 ci-ok 日志首行的结果快照与 `::error::` 注解（哪个 job 红 / 被跳过 / 期望什么）→ 对照"这次触发下它该不该 skipped"→ 再进对应 job 日志定位。不要只看列表第一条。特例：changes 本身红（失败而非 skipped）会级联——web / api 随之被跳过、矩阵判红，根因在 changes 的日志，不在分端。
- **"我改了根 Taskfile / tsconfig，怎么 web / api 没跑？"**——已知假阴性：changes 的 filters 只覆盖 apps/web、apps/api、packages 与 workspace 根清单文件（pnpm-lock / pnpm-workspace / package.json），根工具链文件未入表。优化候选已登记（`proposals/ci-gate-optimizations` C4，待 t1 落），不是你的姿势不对。

## 延伸

ADR-0009（门禁全部决策点、被否方案与翻转条件——本文每个设计点的出处）、SPEC-0001-A5（`ci.yml` 实现规格：六变体正则、结果矩阵、实测清单）、proposals/ci-gate-optimizations.md（C1–C5 优化候选与"已接受、不修"清单——动手改门禁前先查它，别重提已否决项）、ADR-0003（push 兜底与 up-to-date 死锁的前因）、ADR-0004（署名规则本体）、AGENTS.md 提交纪律节（trailer 写法与键表）、git-workflow.md（任务流程全景——本文只展开其中 CI 一环）。实现本体 = `.github/workflows/ci.yml` 与 `.github/scripts/`，行为与本文不符时以实现为准、并视为本文 bug 同 PR 修正。
