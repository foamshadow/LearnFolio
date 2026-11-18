---
title: "t3 落地：lefthook 钩子、stage_fixed 与 root 陷阱"
date: 2026-11-18
author: foamshadow
tags: [se-arch, tool-git, tool-ci]
related: [SPEC-0001, ADR-0004, ADR-0007, ADR-0009]
---

# t3 落地：lefthook 钩子、stage_fixed 与 root 陷阱

> agent 起草、人审定（作者键 = 审定者）。t3（lefthook + commit-msg 署名钩子）于
> 2026-11-18 在 `feat/spec-0001-t3-lefthook-hooks` 上实现，PR #44 待评审。本篇不逐条
> 复述 A6 清单，只记四件会影响后续钩子维护的事：`root: "."` 在 pre-commit 的文件过滤
> 陷阱、`stage_fixed` 的索引语义、lefthook postinstall 的副作用，以及一次 guides 过期
> 表述的修正。

## 事件

t3 的交付面：

- `lefthook.yml`：`commit-msg` fail-closed 校验 `Assisted-by`；`pre-commit` 按后缀分流
  （Go `gofmt`、web Prettier、shell `bash -n`），修复类 job 带 `stage_fixed: true`；
- `scripts/hooks/commit-msg.sh`：不代填、跳过 merge commit、同时校验 `Reviewed-by` 格式；
- `scripts/lib/attribution.sh`：署名正则单一源，CI 的 `check-attribution.sh` /
  `check-pr-meta.sh` 均改为 source；
- `.gitmessage` + `task setup:hooks`：本地提交模板，只在 `commit.template` 未设置时接线；
- 根 `package.json` 增 `lefthook` / `prettier` 两个 catalog 依赖；`check-catalog.mjs` 纳入
  根 `package.json`（N1 结案）；
- 文档写回：AGENTS 提交纪律节、onboarding、git-workflow、worktree、ci-gate、README、spec
  变更记录；并修正 git-workflow / agent-collaboration 里"docs 恰好一个提交"的过期表述。

## 1. `root: "."` 是 pre-commit 的陷阱

lefthook 的 `root` 不是"命令从哪跑"这么简单：对 `pre-commit` / `pre-push`，它同时参与
**文件集过滤**。实测 v2.2.2：

```yaml
pre-commit:
  jobs:
    - name: gofmt
      root: "."
      glob: "**/*.go"
      run: gofmt -w {staged_files}
```

有暂存的 `apps/api/foo.go` 时，这个 job 直接 `skip (no files for inspection)`——`root: "."`
归一化后把所有路径都滤掉了。改成 `root: "apps/api"` 后正常：CWD 切到 `apps/api`，
`{staged_files}` 变成相对该目录的 `./foo.go`，`gofmt -w` 能跑，`stage_fixed` 也能把结果
add 回索引。

`commit-msg` 没有文件集，`root: "."` 只改 CWD，是安全的；它让手工
`lefthook run commit-msg <file>` 在子目录里也按仓库根解析脚本与消息路径。所以配置纪律是
**按 job 的性质写 root，而不是每个 job 都写 `root: "."`**；AGENTS 已把这条陷阱写进提交纪律。

## 2. `stage_fixed`：没有它，钩子修了等于没修

`prettier --write` / `gofmt -w` 改的是工作区文件，git 的 index 里仍是旧 blob。若 job 只跑
格式化就返回成功，commit 记录下来的仍是未格式化的内容——钩子"通过"，提交却没修。这是
静默假阴性，也正是 A6 把 `stage_fixed: true` 列为不可省的原因。

实测两条修复类 job 都正确：临时分支上先写未格式化的 `.go` / `.ts`，`git add` 后提交，
`git show HEAD:<file>` 看到的是格式化后的内容，且 `git status` 没有留下未暂存的格式差异。

副作用同样要记：`stage_fixed` 改的是 index，不只是工作区。如果后续 `commit-msg` 失败，
格式化后的文件会留在暂存区，下一次提交会带上——这是"钩子替你改代码"的固有代价，不是 bug。

## 3. commit-msg：与 CI 同源，但跳过 merge

钩子用 `git stripspace --strip-comments` 先按 git 的 cleanup 规则去掉注释行，再交给
`git interpret-trailers --parse` 解析末尾 trailer 块，与 CI 读 `git show -s --format=%B`
的口径一致。正文里出现 `Assisted-by` 但不在 trailer 块，判红。

merge commit 必须跳过：本地 `git merge` 也会触发 `commit-msg`，而 AGENTS 规定 merge commit
不记 trailer。用 `git rev-parse -q --verify MERGE_HEAD` 判断即可；实测 `git merge --no-ff -m`
放行、hook 显示 ✓。平台生成的 merge commit 不经过本地钩子，不受影响。

`--no-verify` 可绕过钩子；补位演示不是推一个坏提交到远端，而是在本地复跑 CI 的同一脚本：

```bash
EVENT=push BEFORE=<parent> AFTER=<bypass-head> bash .github/scripts/check-attribution.sh
```

实测该命令对缺 trailer 的提交按 SHA 判红。三个消费方（commit-msg / check-attribution /
check-pr-meta）共用 `scripts/lib/attribution.sh` 的正则，改规则只改一处；`Reviewed-by` 只校
格式、不校存在性，钩子与 CI 同。

首轮 Pi 评审的 B1 抓到了第三份副本：`check-pr-meta.sh` 仍内联同一条 `Assisted-by` 正则，
与“单一源”目标冲突。修复后它同样 source lib，`git grep` 在本仓库**可执行文件**里只剩
`scripts/lib/attribution.sh` 一份字面量（AGENTS / spec 里的正则属规则文档，不参与执行）。
这条也说明单一源不能只改“当前正在改的那个消费方”，要把所有消费者一次找全——`check-attribution`
与 `check-pr-meta` 都是 CI 侧消费者，漏掉任何一个都会留下静默分叉。

## 4. 依赖与安装：为什么 deny lefthook 的 postinstall

`pnpm install` 首次因 `ERR_PNPM_IGNORED_BUILDS` 失败：lefthook 的 postinstall 会执行
`lefthook install`，而仓库的 `allowBuilds` 只放行 esbuild。处置是显式 deny：

```yaml
allowBuilds:
  esbuild: true
  lefthook: false
```

理由：postinstall 在 `pnpm install` 时自动改写 `.git/hooks`，是隐藏副作用；本仓库把安装
钩子收敛到 `task setup:hooks`（`pnpm exec lefthook install` + 条件写 `commit.template`），
路径唯一、可解释。lefthook 的二进制来自 optional dependency，postinstall 只负责 install
hooks，deny 它不影响 `pnpm exec lefthook` 可用性（实测 2.2.2 正常）。

另两个安装期观察：

- `lefthook install` 生成的转发器会嵌安装时解析到的二进制绝对路径；该路径失效时回落到
  `$(git rev-parse --show-toplevel)/node_modules`。工作树共享 `.git/hooks`，所以移除一个
  工作树后，若主工作树提交报找不到 lefthook，在主工作树重跑 `task setup:hooks` 即可；
- `commit.template` 的相对路径按仓库根解析（在 `apps/api` 下用编辑器提交实测能看到根
  `.gitmessage` 的内容），因此 `.gitmessage` 在子目录提交也有效。

## 5. web Prettier：选根 devDep，不选子目录 root

pre-commit 加 web Prettier 有三条路：根 devDep + 仓库根 CWD；`root: apps/web` + 包内
`pnpm exec`；或只做 `--check`。最终选根 devDep：

- CWD 是仓库根，根 `.prettierrc` / `.prettierignore` 解析最直；
- 版本与 `apps/web` 同走 catalog（3.10.1），pnpm 去重，不会漂；
- 代价是根 `package.json` 多一个 devDep、每次 web 提交多约 1 秒（只在该次有 web 文件时）；
- `root: apps/web` 虽省依赖，但 `{staged_files}` 相对路径、ignore 路径、pnpm 布局叠在一起，
  后人不易读；`--check` 只提前报错，收益最小。

未来风险已记：`apps/web/shared/api/schema.ts` 是契约生成物，出现后 Prettier 钩子会把它当
普通文件格式化。届时要二选一：在 `.prettierignore` 排除，或保证生成器输出与 Prettier 一致。
当前 `shared/` 尚未生成，A6 不阻塞。

## 6. 验证记录

| 项 | 结果 |
| --- | --- |
| `task ci`（catalog + web + api） | 全绿 |
| `pnpm exec lefthook validate` | All good |
| commit-msg 直接跑 7 条路径 | good / reviewed-ok / 已填模板样例 为 0；missing / 未替换占位符 / body-only / reviewed-bad 为 1 |
| 真实 `git commit` 缺 trailer | 中止，HEAD 不动 |
| `gofmt` / Prettier 的 `stage_fixed` | 提交内容为格式化后版本，无未暂存残留 |
| `bash -n` 拦截 | 语法错误脚本使提交中止，HEAD 不动 |
| `--no-verify` 绕过 | 提交成功；CI 脚本对同一区间判红 |
| 本地 merge commit | 无 trailer 放行（`MERGE_HEAD` 跳过） |

测试用的临时分支与文件已在工作树内删除，未进入任务分支。

## 7. 执行差异与遗留

- **guides 过期表述**：git-workflow 里"docs 分支恰好一个提交"及其写回窗口的 amend + force
  表述、agent-collaboration 里同一机制的两处解释，都与 ADR-0010 冲突（ADR-0010 已撤销单
  提交约束）。本次随 t3 修正五处（git-workflow 3 + agent-collaboration 2），并在 spec 变更
  记录记一行；规则本体不变（docs 提交仍始终要确认），只把"无整理机会"的过期机制说明改掉。
  这不是 t3 的新规则，是把文档拉回既有决策。
- **Go gofmt 没有 CI 补位**：`golangci-lint` v2 默认 linters 不含 gofmt，`task ci:api` 也不
  单独跑 `gofmt -l`。因此 `--no-verify` 绕过后，Go 格式只能靠本地钩子；web 格式有
  `format:check` 兜底，shell 语法也没有 CI job。ci-gate 的误区条目已按事实写，不夸大成
  "CI 全能补位"。
- **merge message 模板不复制**：六变体已在 t0 的 PR 模板 + `check-title.sh` + AGENTS 表格，
  t3 只补本地提交模板 `.gitmessage`；spec 变更记录已说明口径，避免第四份漂移源。
- **ADR-0007 D5 的理由待决策层补记**：其"docs 无整理机会（恰好一个提交）"的机制前提已被
  ADR-0010 撤销；本次只在 guides 改了说明，ADR 正文不可变，D5 的新理由（docs 是可直接引用
  的真源）需要后续 ADR / 变更记录补一笔，否则理由的真源悬空。

## 8. 后续

- t6：`infra/docker-compose.yml`、PG 健康检查、Redis 注释预留、`.env.example` 的
  `POSTGRES_*`、onboarding 的 Docker / `db:up` 段。
- 可评估：把 `gofmt -l` 加进 `task ci:api`（或启用 golangci-lint 的 formatter），给 Go 格式
  一道 CI 兜底；以及 `shared/api/schema.ts` 出现时同步 `.prettierignore`。
- `scripts/merge.sh` / `task merge` 仍未写；Q1 撤回窗口仍待人类拍板。

## 关联

- PR #44（`feat/spec-0001-t3-lefthook-hooks` → `dev`）
- `SPEC-0001` A6 / 任务分解 t3；`lefthook.yml`、`scripts/hooks/commit-msg.sh`、
  `scripts/lib/attribution.sh`、`.gitmessage`、`Taskfile.yml`
- ADR-0004（署名）、ADR-0007（授权）、ADR-0009（CI 门禁）
- `docs/guides/onboarding.md`、`git-workflow.md`、`worktree.md`、`ci-gate.md`
- `docs/journal/2026/2026-11-18-foamshadow-t2-api-contract.md`（N1 的来源）
