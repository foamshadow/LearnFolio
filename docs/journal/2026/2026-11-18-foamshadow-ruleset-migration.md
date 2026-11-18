---
title: "ruleset 迁移：三规则集、PUT 语义与 dry-run 假象"
date: 2026-11-18
author: foamshadow
tags: [se-arch, tool-git, tool-ci]
related: [SPEC-0001, ADR-0003, ADR-0007, ADR-0010]
---

# ruleset 迁移：三规则集、PUT 语义与 dry-run 假象

> agent 起草、人审定（作者键 = 审定者）。本篇记录 2026-11-18 把 dev / main 的
> classic branch protection 迁到三条 repository ruleset 的完整过程，以及同批落地的
> `scripts/retract.sh` / `task retract`（PR #42）。核心不是“换了配置”，而是把
> **PR 门禁、force 放行、删除保护**拆成三条互不污染的规则集。

## 事件

迁移前 dev / main 是同构的 classic protection：required `ci-ok`（strict=false）、
approvals=0 + dismiss stale、`enforce_admins=true`、禁 force push、禁删除。P2b 的
手工 break-glass 需要临时关保护，保护空窗是整条撤销链里唯一可能静默失守的环节。

实验先回答了三个语义问题：

1. **require-PR 拦一切直推，包括 force**。所以只给 RS-2 加 owner bypass 不够；
2. **单 ruleset + bypass 会连 PR 门禁一起豁免**。owner 获得常设静默直推能力，
   不只是 rewrite；
3. **classic 的 `enforce_admins=false` 是全有或全无**。owner 直推会放行并显示
   “Bypassed rule violations”，没有“只允许 force、不允许普通直推”的部分豁免。

这解释了 #34→#36 的 P2b 之谜：当时只开 `allow_force_pushes` + 关 `enforce_admins`
就能 force，正是因为 classic 的 admin 语义没有中间态。

最终模型：

```text
RS-1 dev-main-pr-gate      require PR + required ci-ok，无 bypass
RS-2 dev-main-history      non_fast_forward，RepositoryRole:5 + always bypass
RS-3 dev-main-undeletable  deletion，无 bypass
```

`retract.sh` 只 disable RS-1（秒级），force 走 RS-2 的 owner bypass，RS-3 全程不动。
RS-2 单独时是惰性的：RS-1 的 require-PR 仍会拦 force。

## B1：deletion 不能挂在 RS-2 上

第一版设计把 `non_fast_forward` + `deletion` 都放在 RS-2，并给 owner bypass。
审查指出这会**净弱化**现状：分支删除不经过 push 路径，RS-1 拦不住；owner 平时就能
直接删 dev/main，而 classic 是 `allow_deletions=false` + `enforce_admins=true`，
谁都删不了。

修法是拆出 RS-3：只装 `deletion`，无 bypass，`retract.sh` 永不触碰。独立实测：

```text
临时 deletion ruleset（无 bypass）→ 删除临时分支
→ remote: error: GH013 ... Cannot delete this branch
```

删除保护与历史改写是两件事，不能共用 bypass。

## 迁移与恢复 payload

迁移前先把 dev/main 的 protection 原始 payload 存档，再删 classic。关键坑：
**GET 的 protection 形状不能直接 PUT 回去**。

- GET 返回 `enforce_admins: {enabled: true, url: ...}` 等包装；
- PUT 要 `enforce_admins: true`、`allow_force_pushes: false` 等布尔值；
- `required_status_checks` 要 `checks: [{context, app_id}]`，且 `restrictions` 要显式给；
- 第一版直接回灌 422：`{"enabled" => false} is not a boolean`。

修正后的 v2 先在 dev/main 做同值 PUT，逐字段比对未变，才执行 `DELETE protection`。
快照、v2 恢复 payload、rulesets 前后 JSON、`rules/branches/*`、`task retract --dry-run`
输出都在 `.tools/ruleset-migration-20261118T141950/`。

迁移结果：

```text
RS-1 id 27526062  active
RS-2 id 27526064  active
RS-3 id 27526066  active
classic dev/main: DELETE 204; GET 404
rules/branches/dev|main: deletion, non_fast_forward, pull_request, required_status_checks
```

## 五条平台 quirk

1. `enforcement` 枚举是 `disabled | active | evaluate`，不是 `enabled`。
2. `pull_request.parameters` 必须整传；部分传 422。全量可传，`allowed_merge_methods`
   可收窄为 `["merge","squash"]`。
3. ruleset 更新端点是 **PUT**，`PATCH /rulesets/{id}` 是 404。
4. 最小 body `PUT {"enforcement":"disabled"}` 是 **merge 语义**：rules / conditions /
   bypass 全部幸存（用 `non_fast_forward` 与 RS-1 形状各测一次）。这条决定了 lib 的
   toggle 实现，不必构造完整净化 body。
5. bypass 推送不出现在 evaluation API；个人仓库也没有 org audit log API。审计主张
   只能降级为：`rules/branches/*` 回显 + git server 消息 + web security log（如可见）
   + 脚本快照 + journal。

## dry-run 假象

`git push --dry-run origin <dummy>:dev` 返回 0，但 dev 完全没变——dry-run 是客户端侧，
服务端规则没有被真实验证。**不能**把它当作“直推被拒”的证据。

生产侧的直接证据链改为：

- `rules/branches/dev|main` 回显 `pull_request` / `required_status_checks` / `deletion` /
  `non_fast_forward`；
- 临时 ruleset 实弹已证明 require-PR 拦直推与 force；
- 下一个 PR 真实验证 required `ci-ok` 与 PR 门禁。

## 执行差异

- 没有为了测试去真实直推 dev；dry-run 的 0 已如实标注为客户端行为，不入证据链。
- Q1 撤回窗口未拍板：`retract.sh` 当前按“bad 在 dev 头部 + age ≤ 24h（`--window-hours`
  可调）”实现，proposal 保留开放。
- P2a 未动：本篇只落 reset 模式，不把 amend 路径写进脚本。
- ruleset 数字 ID 是仓库实例相关的；脚本按名字解析，不硬编码 ID。

## 后续

- `scripts/merge.sh` / `task merge` 仍未写；pilot 0/3。
- 敏感数据桌面演练未做。
- Q1 窗口待人类拍板；Q2/Q4/Q5 已在本篇对应的 docs 写回中结案。
- t3 的 lefthook 钩子脚本将落根 `scripts/`，与 `.github/scripts/check-attribution.sh`
  共享 `Assisted-by` 正则源。

## 关联

- PR #42（`7f3bd44` → `b8f0c48`）；`scripts/lib/rulesets.sh`、`scripts/retract.sh`、
  `scripts/rulesets.expected.json`、`Taskfile.yml`
- `docs/proposals/merge-integrity.md`（Q2/Q4/Q5 结案，Q1 开放）
- `docs/guides/merge.md`（ruleset 窗口与 `task retract`）
- ADR-0003（分支与合并）、ADR-0007（破坏性操作授权）、ADR-0010（message-only rewrite）
