---
id: ADR-0009
title: "CI 门禁策略：单 workflow、ci-ok 聚合与双触发"
status: deprecated
date: 2026-11-15
author: foamshadow
tags: [se-arch, tool-ci]
related: [ADR-0003, ADR-0004, ADR-0007, SPEC-0001]
supersedes: ""
superseded-by: ""
---

# ADR-0009：CI 门禁策略

> 补记说明：t0 施工前撰写；本篇只定门禁结构，具体 job 实现由 SPEC-0001-A5 与 `ci.yml` 承载。

## 背景（Context）

- "CI 从 day 0" 是项目纪律：在写任何应用代码前先有反馈回路。
- 分支保护只能把**check 名**设为必需；check 名来自 workflow job。
- PR 标题是账本行，写错必须在合并前拦住；合并按钮不会读标题。
- 提交级署名（ADR-0004）需要一层无法用 `--no-verify` 绕过的校验。
- 关闭了 "Require branches to be up to date"（ADR-0003）：base 前进后，PR 上已有的绿色结果**仍然是绿的**，只是对应旧 base / 旧合并上下文。
- t0 自身处于 bootstrap：`ci-ok` 尚未上报过，required check 无法提前配置。

## 决策（Decision）

### D1 单 workflow，多 job

所有检查放一个 `ci.yml`，job 名即 check 名：`changes`、`web`、`api`、`title`、`attribution`、`ci-ok`。
required check 只需挂 `ci-ok` 一个名字；job 增删不改保护配置；聚合逻辑集中一处。

### D2 双触发，push 全量

- `pull_request`：`types: [opened, edited, synchronize, reopened]`——`edited` 必须显式加，否则改标题可逃逸校验；
- `push`：仅 dev / main，**全量跑**，跳过 `changes` 探测与 `title` 校验——两者依赖 PR 上下文，push 下必然误报；
- **定位修正**：push run 不是"合并前补偿"，而是**事后发现**——它只验证新 base 自身，不验证"待合 PR + 新 base"
  的组合；组合冲突要等 PR 合入后由 dev 全量变红才暴露。它补偿的是**可见性**（关闭 up-to-date 后唯一的兜底观测面），
  不是拦截力。要让"合并前保证"，需 merge queue 或恢复 up-to-date（后者与整理门死锁，见 ADR-0003）；
- **不用 `paths:` 过滤**裁剪范围：workflow 因路径 / 分支过滤被跳过时，其 check 停在 Pending 并阻断合并
  （官方明确）；`changes` job 是"始终运行、自己判定"的替代——跳过发生在 job 级才能是绿的（见 D3）。

### D3 ci-ok 聚合：执行保证 + 结果矩阵

- `if: always()` 是**硬约束**：依赖 job 失败时，聚合 job 会被跳过，而 GitHub 把 `skipped` 算作成功状态
  （官方原文：successful check statuses are `success`, `skipped`, `neutral`）。缺 `always()` 的真实后果
  不是"卡住等待"，而是**静默放行**：web 测试红了 → `ci-ok` skipped → 合并按钮照常点亮。
  门禁失效比门禁卡住严重得多，不得以"简化"为由删掉；
- **结果矩阵**（不能实现成"所有 needs 不是 failure 就算过"——那样某个 job 因 `if` 写错被跳过，聚合仍全绿）：

  | 触发 | 必须 `success` | 允许 `skipped` | 判红条件 |
  | --- | --- | --- | --- |
  | PR | `changes`、`title`、`attribution` | `web` / `api`——且仅当 `changes` 对应 output 为 `false` | 任一为 `failure` / `cancelled`；或必需项为 `skipped`；或应跑的分端 skipped |
  | push | `web`、`api`、`attribution` | `changes`、`title`（事件无 PR 上下文） | 任一为 `failure` / `cancelled`；或必需项为 `skipped` |

- 读法：**skipped 不是白名单通行证，必须与触发上下文绑定**。PR 下 `title` / `attribution` 被跳过是门禁漏洞，
  不是省事；push 下跳过它们是设计；
- `needs` 必须包含 `title` 与 `attribution`：否则标题 / 署名违规只是旁路红灯，拦不住合并按钮。

### D4 同名 check 消歧

- `main ← dev` 收口 PR 是**常规**场景而非边角：dev 前进时 push run 在 dev head 上报一次聚合 check，
  以同一 head 开 PR 后 pull_request run 再报一次——同 SHA 同名，required 取哪次依赖平台未明语义；
- 决策：push 侧聚合 job 显示名 = `ci-ok (push)`，PR 侧保持 `ci-ok`；**required 只挂 `ci-ok`**。
  job id 仍是 `ci-ok`（`needs` 引用稳定），仅显示名随 `github.event_name` 变化；
- 其他 job 在两种触发下同名，只影响展示、不参与 required 判定，允许保留；
- `edited` 重跑仍与旧 run 同名（同为 PR 事件），靠"取最新"语义兜底（实测③）；若实测证明旧 run 会阻塞，
  再单独决策更强的消歧手段——本篇不预支（给 `ci-ok` 加 `run_id` / 事件后缀会让 required 永远匹配不上，不可取）。

### D5 标题校验：六变体 + 方向矩阵

- 六条完整 alternation（feat / fix / hotfix 发布 / hotfix backport / Phase 收口 / docs）；
- 同 job 校验 base×head 方向：dev←feat/fix/backport/docs、main←hotfix/dev，其余组合一律拒绝——只验字面拦不住"feat PR 提到 main"；
- **维护类 PR 的归属**：改 `ci.yml`、lefthook、构建脚本、工具链的 PR 按性质归 `feat/` 或 `fix/`，标题用既有变体；
  细分 scope（ci / infra / deps）记在 conventional commit 里，不新增第七变体——避免门禁逼提交者伪造 `feat` / `fix` 标签；
- 校验对象是 PR 标题而非 merge 提交（后者由平台追加 ` (#N)`）。

### D6 署名校验：PR 与 push 都覆盖

- PR：`git rev-list --no-merges base..head`；
- push：`git rev-list --no-merges before..after`；`github.event.before` 全零（首推）或不可达（强推 / 未取到对象）时
  回退到 `after` 全史——fail-closed，宁可误伤不放过；checkout 需 `fetch-depth: 0`，浅克隆拿不到区间；
- 跳过 merge 提交的依据不是"由平台生成"（PR head 里也可能有本地 merge），而是 **merge 提交不注入内容、
  无法携带 trailer**（ADR-0004 B 案）；整理门与 rebase 纪律已尽量消除本地 merge，但规则不依赖"它们不存在"；
- push 也校验的意义：管理员 bypass 直推、squash 落地提交（其正文 trailer 来自 PR 描述）都在 PR 校验之外；
  分支保护只保证"常规路径有 PR"，不保证"所有提交都经过 PR run"。

### D7 空分端 job 先占位

- web / api 先 `echo`，t1 / t2 填 lint / build / test / gen:check；
- 空 job 是真运行并报 `success`（代码 PR 上），不是 `skipped`——只有 docs-only 等被 `if` 裁剪时才 skipped；
- 占位的目的是 `needs` 结构稳定、后续填充有落点、A5 能在 t0 验证聚合逻辑；**不是**为了让 required 配置不悬空
  （required 只挂 `ci-ok`，不依赖 web / api 出现）。

### D8 自举顺序

- t0 自身 PR 由人工把关（`ci-ok` 尚未上报，settings 下拉选不到）；
- t0 合入后**尽快**（7 天时效内）在 main / dev 补 `ci-ok` 必需检查；
- 这是与 SPEC-0001 自批同源的一次性 bootstrap 例外，不得成为先例。

## 被否方案（Alternatives）

| 方案 | 否决理由 | 翻转条件 |
| --- | --- | --- |
| 每个检查单独设为 required | check 名多、增删 job 就要改保护；聚合逻辑分散 | 需要按 job 精准阻断而非整体阻断 |
| 多 workflow（ci / title 分开） | check 名分散、required 难维护；同 SHA 多 run 判定更复杂 | 某类检查需要独立触发或独立权限 |
| 只靠 lefthook 校验署名 | `--no-verify` 可绕过，防不住有意逃避 | 出现不可绕过的服务端钩子 |
| push 跳过署名校验 | 管理员 bypass、直推与平台生成提交形成通道；"常规走 PR"不是保证 | 分支保护能完全禁直推且无 bypass |
| 双 run 同名交给实测再治理 | 收口 PR 是常规场景，不能长期依赖未明语义 | — |
| matrix 后缀 job 名消歧 | 比显示名重；job 名表达式已足够 | 需要按事件区分触发条件或权限 |
| push 也跑标题校验 | push 无 PR 上下文，必误报；污染语义冲突信号 | — |
| 不做 changes 探测、全量跑 | 文档 PR 也跑 Go / Node 构建，浪费且噪音 | 仓库小到全量成本可忽略 |
| 用 `paths:` 过滤代替 `changes` job | 被过滤跳过的 workflow，其 check 停在 Pending、阻断合并 | 检查不需要按改动范围裁剪 |
| 开 "Require up to date" 代替 push 触发 | 与 rebase 整理门 + approved 不改写死锁（ADR-0003） | 放弃整理门 |

## 后果（Consequences）

- 分支保护只挂 `ci-ok` 一个 check；t0 合入后需手工补配置（一次性）。
- required check 候选有 **7 天时效**：check 须在最近 7 天内于本仓库成功过，才会出现在保护设置的下拉中
  （官方明确）。t0 合入后应尽快配置；若间隔过久，先用 Re-run all jobs 重跑最近一次成功的 run（不改 SHA），
  仍不出现则以 API 直接配置兜底（实测⑤）。
- **残留风险（push 事后发现）**：语义冲突可能在合入 dev 后才暴露。处置纪律沿用 AGENTS：dev push 红 =
  语义冲突落地，暂停后续合入，开 `fix/` 修复或 `git revert -m 1` 回滚；合并前保证需 merge queue 或恢复
  up-to-date，作为将来的翻转条件记录于此。
- `edited` 会重跑整个 workflow（含 web / api），成本已知且接受：优化需引入"上一次 run 绿灯"状态，
  复杂度不划算。改名 / 改描述触发重跑属预期行为。
- 同 SHA 双 run 的**展示层**仍有同名现象（`edited` 重跑、其他 job 的 push / PR 同名），不参与 required 判定；
  若实测③证明旧 run 会阻塞，再升级消歧方案。
- 空 job 会一直存在到 t1 / t2 填充；**代码 PR 上它们是 success，docs-only PR 上才是 skipped**。
- 标题正则与方向矩阵写在 job 脚本里，修改需 PR；维护类 PR 按 feat / fix 归属，scope 记提交。
- 聚合脚本是唯一必须保持稳定的部分；后续 job 增删只改 `needs`、矩阵白名单与占位。
- 可选加固（后续）：`ci.yml` 与聚合脚本纳入 CODEOWNERS 或显式要求维护者评审，避免门禁在同一 PR 内被顺手削弱。
