---
title: "t2 落地：Huma 默认注入、契约确定性与评审双轨"
date: 2026-11-18
author: foamshadow
tags: [se-arch, tool-git, tool-ci]
related: [SPEC-0001, ADR-0004, ADR-0009, ADR-0011]
---

# t2 落地：Huma 默认注入、契约确定性与评审双轨

> agent 起草、人审定（作者键 = 审定者）。t2（apps/api）于 2026-11-18 凌晨经 PR #40
> 合入 dev（`cc3c966`）。本篇不逐条复述 A3 清单，只记四件会影响后续代码与流程的事：
> Huma 默认配置对响应的注入、openapi 生成链的确定性、作者/评审者署名的双轨校正，
> 以及一次 paths-filter 的评审预期偏差。

## 事件

t2 的五个提交从 `f2b6951` 到 `deecfa9`，依次落 Go module 与 `/healthz`、openapi 子命令、
Taskfile 工具链、CI api job、文档写回；PR #40 于 2026-11-18 01:09:58 CST 合并为
`cc3c966`，A3 完成、A4 的 `PORT` 到达、素材 B 并入 AGENTS。合并后 dev push CI
`44133936669` 全绿，A5 的 push 矩阵 api 侧首次有真实 job 的实证。

### 1. Huma 默认配置把 `$schema` 注入协议

`huma.DefaultConfig` 默认装一个 `SchemaLinkTransformer`，做三件事：

- 在 OpenAPI 的 response schema 里加一个 `$schema` 属性；
- 运行期在响应体里填 `$schema`，并加 `Link: <...>; rel="describedBy"` header；
- 用 `SchemasPath`（默认 `/schemas`）注册 schema 路由，并把 `$schema` 指向它。

`$schema` 的值不是配置里的常量，而是从请求的 `X-Forwarded-Host` / `Forwarded` /
`Host` 推导。同一个二进制，从 localhost、容器内地址、反向代理域名访问，返回的 body
会不同；生成物里的 example 在无 servers 时回落到 `https://example.com`。

这与本项目的契约模型冲突：契约真源是 `apps/api/docs/openapi.yaml`，客户端按生成的类型
调用，协议里不应出现一个运行期合成、随部署环境变化的字段。处置是 `newAPIConfig()`
同时清空三个入口：

```go
config := huma.DefaultConfig("LearnFolio API", apiVersion)
config.CreateHooks = nil
config.Transformers = nil
config.SchemasPath = ""
```

三个都要关，因为它们是三条路径：`CreateHooks` 挂 `OnAddOperation`，把 `$schema` 写进
OpenAPI schema；`Transformers` 负责运行期 body 与 header；`SchemasPath` 负责 schema
路由与 URL。只关 `Transformers` 会留下契约里的字段，只设 `SchemasPath=""` 仍会留下
运行期注入。`TestHealthz` 断言响应无 `$schema`，生成的 YAML 也不再含该属性；Huma 自带
的 `/openapi.json`、`/openapi.yaml`、`/docs` 保留，只是不再提供 JSON Schema 发现。

**教训**：框架的 "default config" 不只是默认值，它会把一套可选协议一起装进来。用
code-first 生成契约时，先检查默认 hook / transformer 往协议里写了什么，再决定是否保留。

### 2. openapi 生成链的确定性

生成链的三个决定：

- server 与 `openapi` 子命令共用 `newAPI()`，路由注册留在构造函数内且不依赖 DB；
  生成契约时不需要起服务、连数据库。
- 子命令自带 `--output`，同目录临时文件写成功后 `rename` 原子替换；拒绝 `--output -`。
  这样 shell 重定向不参与编码（PowerShell 的 `>` 会重编 UTF-16），`gen:check` 的字节
  一致性才成立。
- `task gen` 用 `cmds:` 串行，`gen:check` 重新生成后 `git diff --exit-code`。生成物
  89 行、无时间戳、无 servers；双跑 SHA-256 为
  `3f24f3042e16623e504bb1d6414c4f8f537c2b66e6209efff6e444097b1cae0e`。

**为什么值得记**：生成物是提交进 git、要被人 review 的契约。只要输出里有一个时间戳、
一个 map 遍历顺序或一个 host 相关字段，每次 `task gen` 都会产生假 diff，真正的契约
变更就被噪音淹没。确定性不是测试洁癖，是契约可审查的前提。

### 3. 作者与评审者的双轨署名

PR #40 的五个提交都带：

```text
Assisted-by: DSH:deepseek-v4.1-flash-1017
Reviewed-by: Pi:glm-5.3
```

PR 描述只保留一条 `Assisted-by`。评审过程中曾出现把评审者也列进 `Assisted-by` 的意见；
按 ADR-0011 校正：`Assisted-by` 只列内容参与者，评审者进 commit 的 `Reviewed-by` 与
PR 评论的 `Reviewer:`，两者记录不同事件，不能为了"看起来完整"重复列。t2 的五个提交
从第一个到最后一个都带 `Reviewed-by`，双轨规则在一个完整任务上从头走到底；五个提交在
提交前逐一评审（C1 设计确认，C2–C5 staged tree 锚定），终态聚合 PASS 锚定 `deecfa9`，
合并用默认标题路径（不传 `--subject` / `--body`），落地 subject 带 ` (#40)`、正文为空。

### 4. 评审校准：paths-filter 看的是 PR 全量文件集

PR #40 的评审中，曾按"最后一个提交是 docs"预期 web / api 会 skipped；实际两个 job
都真跑。原因不是配置错误：`dorny/paths-filter` 在 `pull_request` 事件取的是 PR 的
全量文件列表，不是最后一次 commit 的 diff；只有整个 PR 都是 docs（或都不命中过滤）
才会跳过。这个预期偏差没有造成红绿错误，但说明"最后一个提交改了什么"不能推出"分端
job 会不会跑"。

## 决策

- **路由用标准库 `http.ServeMux` + `humago`，不引 chi**：t2 只有一条 `/healthz`，标准库
  足够；等出现路由组、复杂中间件或参数匹配需求再评估，避免为一条路由引入依赖。
- **`setup` 聚合，`setup:node` 保留为逃生口**：默认 `task setup` = Node + Go；只做 web
  的成员仍可单跑 `setup:node`。Go 版本由 `apps/api/go.mod` 提供，CI 的 `setup-go` 直接
  读它；golangci-lint 版本只在 Taskfile var 里写一次。
- **`PORT` 缺省 8080，非法值 fail fast**：不在启动时静默回退；`dev:api` 读根 `.env`，
  A4 的消费者随本任务到达。
- **CI api job 真跑 `task ci:api`**：不把 `go test` / lint 命令散落在 YAML；`changes.api`
  把 Taskfile 与 workflow 自身也纳入过滤，改工具链会触发 api job。

## 结果

| 项 | 结果 |
| --- | --- |
| 本地 `task setup` / `task ci` | 全绿 |
| `task gen` 双跑 | SHA-256 一致（见上） |
| `PORT` 冒烟 | 缺省 8080 / `18080` / 非法值 fail-fast |
| PR #40 首个 run | 全绿，api 84s（`dbb26b5`） |
| PR #40 终态 run | 全绿，api 25s / web 36s（`deecfa9`） |
| dev push CI | `44133936669` 全绿，`ci-ok (push)` 通过 |

## 执行差异

- 本篇未塞进 PR #40 的代码 PR，而是按 journal 独立成篇的惯例在合并后补记；PR #40 的
  合并账本行不改写。
- PR 描述写"终态 api 约 29s / web 约 40s"，实际 run `44132757158` 的 job 墙钟为
  api 25s / web 36s（started→completed）。两者都是约数、不影响结论，但账本以 run 为准。
- api job 首轮 84s、终态 25s，未达到需要新增 CI 优化候选的量级；两轮全绿，没有为
  "跑得慢" 引入额外的缓存或跳过策略。

## 后续

- t3：lefthook + `commit-msg` fail-closed 署名钩子 + merge message 模板 + AGENTS 最后一行；
  顺带评审注记 N1（PR #40）：根 `package.json` 纳入 catalog 校验。
- A5 实测④（收口 PR 同 SHA 双 run 的 required 取值）留 A10 自然结案。

## 关联

- PR #40（`deecfa9` → `cc3c966`）；`apps/api/cmd/api/main.go`、`internal/handler/health.go`
- `docs/specs/0001-phase-0-scaffold.md`（A3 / A4 / 素材 B）
- ADR-0004（署名）、ADR-0009（CI 门禁）、ADR-0011（`Reviewed-by` 双轨）
- `docs/journal/2026/2026-11-17-foamshadow-review-attribution-gap.md`（双轨规则的来源）
