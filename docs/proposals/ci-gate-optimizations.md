---
title: "CI 门禁优化候选（等触发条件，不在无构建时预支）"
author: foamshadow
date: 2026-11-15
status: draft
tags: [tool-ci]
related: [ADR-0009, ADR-0011, SPEC-0001]
adopted-as: ""
---

# CI 门禁优化候选

## 背景

t0 落地后（PR #9），CI 的真实形态第一次可测量：PR run 与 push run 各 4 个执行 job、2 个 skipped，整轮墙钟 15 秒、单 job 4–5 秒；仓库为 public，标准 runner 分钟不计费。因此当前的"浪费"不是钱，而是**反馈延迟、PR 页面噪音，以及 t1/t2 真实构建上线后的等待**。

盘点后分两类：

- **平台 / 决策使然，不修**：文档写回触发的第二次 PR run（新提交必换 head SHA）、`edited` 全量重跑（标题校验必须对新事件重跑）；
- **有明确触发条件的优化**：见下表。共同点是"现在做没有收益，且不是改一行"——C1 / C3 动到 ADR 决策，C2 卡在平台语义，因此先登记、到点毕业，不在 Phase 0 预支复杂度。

## 提议

| 编号 | 候选 | 现状 / 成本 | 触发条件 | 方案 | 改动面 / 复杂度 | 状态 |
| --- | --- | --- | --- | --- | --- | --- |
| C1 | push 端 app 变更探测 | docs PR 合并也触发 push 全量；t1/t2 后每次白跑 web + api 构建 | docs 合并耗时 > 2–3 分钟，或两端构建合计 > 5 分钟 | push 加 diff 探测（`before..after`），无 app 改动则跳过 web / api；attribution 照跑（squash 提交的 trailer 靠它） | 新 ADR **部分取代 ADR-0009-D2** + `ci.yml` + `aggregate.sh` + SPEC-A5；**高** | 候选 |
| C2 | 被顶掉的 run 自动取消 | 连续 push 时旧 run 继续跑完，PR 页面留多轮 run | SPEC-A5 实测③结案，且构建变重（单轮 > 3–5 分钟） | `concurrency: cancel-in-progress`，按 PR 号 / ref 分组 | `ci.yml`；风险：同 SHA 的 `edited` 会取消前一轮并留下 cancelled check，可能误伤 required；**中** | 候选（阻塞于③） |
| C3 | attribution 浅取 | 每次 `fetch-depth: 0` 全史 clone；收口 PR 扫整个阶段的提交 | 提交数 > 数千，或 clone 时间 > 30 秒 | 按事件取最小范围（PR 取 base + head、push 取 before..after），取不到再回退全史 | 动 ADR-0009-D6 的 fetch-depth 条款 + 脚本；**中** | 候选 |
| C4 | `changes.filters` 覆盖根工具链 | 改根 Taskfile / tsconfig / .npmrc 等不触发分端构建（假阴性） | t1 引入根 Taskfile 时 | filters 增根路径，分端构建随之触发 | `ci.yml`；**低** | 待 t1 |
| C5 | 门禁文件 CODEOWNERS | `ci.yml` / 聚合脚本可在同一 PR 内被改宽 | 团队扩到非核心贡献者之前 | CODEOWNERS 指定维护者，或 AGENTS 要求门禁改动须维护者评审 | 仓库配置 / AGENTS；**低** | 候选 |
| C6 | PR 描述元数据校验 | #22 事故：PASS 后描述追加评审清单，squash 正文 trailer 失位，dev push attribution 红；PR run 不读描述 | 已触发（#22） | `pr-meta` job：PR 描述末行 `Assisted-by` trailer、正文无评审状态行（REVIEW / Reviewer / Author / Reviewed-by）；并入 `ci-ok`；push 下 skipped；不查 docs 单提交、不校验评论层 Reviewer | `ci.yml` + `aggregate.sh` + `check-pr-meta.sh`；ADR-0011 部分取代 ADR-0009；**中** | adopted（PR #27；ADR-0011） |

**已接受、不修**：

- **文档写回第二次 PR run**：任何新提交都换 head SHA，机制使然；代码 PR 会因此重跑两端构建，属同 PR 写回的成本（策略与窗口见 AGENTS 文档体系）；
- **`edited` 全量重跑**：标题校验必须重跑；body 编辑无法与标题编辑安全区分，取消旧 run 又有同 SHA 风险；
- **每个 job 各自 checkout**：单 job 4–5 秒，合并 job 省不下多少且伤可读性与重跑粒度。

## 毕业条件

- C1 / C3 / C6 毕业时须开**新 ADR 部分取代 ADR-0009** 对应决策（ADR 正文不可变），同 PR 改 `ci.yml`、聚合脚本与 SPEC-A5 验收；C2 还须先完成实测③并把结论记入 SPEC；C6 已先落地（PR #27），ADR-0011 已补部分取代；
- C4 随 t1 的 Taskfile PR 一起落地，不单独开任务；C5 视团队扩张再定；
- 落地后本表对应行改 `adopted` 并链 PR，全部毕业或方案被推翻后整篇归档；
- 新增候选必须带"触发指标 + 改动面"，否则不入表——没有触发条件的 backlog 等于永久 TODO。

## 演进记录

- 2026-11-15 由 t0 落地后的 CI 性能盘点建立（基线：PR #9 run 与 dev push run 各 15 秒，均为 4 job 执行 / 2 job skipped）。
- 2026-11-17 C6 落地（PR #27）：新增 `pr-meta` job，校验 PR 描述末行 trailer、正文无评审段；不查 docs 单提交（ADR-0010 已撤销）；ADR-0009 部分取代待补。
- 2026-11-17 ADR-0011 补记：`pr-meta` 扩为拒绝评审状态行（REVIEW / Reviewer / Author / Reviewed-by）；不校验评论层 Reviewer；ADR-0011 部分取代 ADR-0009，C6 记账闭合。
