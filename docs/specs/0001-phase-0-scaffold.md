---
id: SPEC-0001
title: "Phase 0：仓库骨架与工程化地基"
status: ready
author: foamshadow
date: 2026-11-12
tags: [infra, se-arch]
source: "策划期《开发流程设计》（Obsidian ED1，2026-11-10 ~ 11-13）"
related: [ADR-0001, ADR-0002, ADR-0003]
---

# SPEC-0001：Phase 0 — 仓库骨架与工程化地基

> 评审注记：本 spec 的评审发生于建仓前策划期（2026-11-10 ~ 11-13），过程记录未随仓库保存（出处见 frontmatter source）。其余核心成员 clone 后在本节下方补 review 意见——补意见不阻塞开工，涉及验收标准变更的按"变更记录"三分法处理。
>
> **例外记录（一次性 bootstrap，不得成为先例）**：本 spec 的 ready 由作者于建仓前自批——仓库尚不存在，无法执行非作者评审。自第二份 spec 起（编号按分配协议于其起草时才确定——first commit 不得预言性引用未分配编号，防静默指错），ready 必须由至少一名**非作者**的核心成员批准，批准记录写入本节。

## 背景与目标

LearnFolio 是学习驱动 + 文档驱动 + agent 全栈开发的实践项目（定位见根 README，选型见 ADR-0001）。Phase 0 交付工程化地基：混合 monorepo 骨架、契约生成链最小闭环、CI 与 git hooks、配置项基线、本地依赖服务定义。**部署载体（双侧 Dockerfile / prod compose / nginx / 根 .dockerignore）不属本 Phase**——无消费方（不预支判据），随首次部署需求于 Phase 1+ 落地。收口标准：第二个成员 clone 后零口头约定即可开发。

> 粒度例外：本 spec 为伞形 spec（10 条验收、7 个任务），超出"一个 spec = 一个可独立验收交付物、验收 ≤ 8"的常规粒度——建仓期一次性例外，后续 spec 不以此为基准。

## 设计考量

- 数据流（本 Phase 唯一关键数据流 = 契约生成链，方向单向）：
  huma handler struct（apps/api）→ `task gen`（串行）→ apps/api/docs/openapi.yaml（提交进 git）→ openapi-typescript → apps/web/shared/api/schema.ts（提交）→ 前端 openapi-fetch 类型化调用
- 模块边界：Node 工具链止于 apps/web 与根 workspace 文件；Go 工具链止于 apps/api；apps/api 是未来唯一碰数据库的地方（本 Phase 仅 compose 定义 PG，业务代码不接）
- 依赖方向：web 对 openapi.yaml 单向只读（生成物）；一切代码合入以 CI 为门——ci.yml 骨架（t0）先于一切代码任务，ci-ok 自 t0 合入后为必需检查（t0 自身 PR 人工把关，bootstrap 例外见 A5），真实 job 随 t1/t2 填充
- 换行确定性是 gen:check 的前提：.gitattributes 已随 first commit 锁 eol=lf（git 不读 .editorconfig）

## 任务分解

<!-- 每任务 = 一个可独立提 PR 的工作单元；分支命名 feat/spec-0001-tM-短名。
     随带交付 = 本任务 PR 一并带入的规则节/文档（规范与实现同 PR 到达）。
     施工自包含：t0/t2 的 AGENTS 规则节素材全文明示于本 spec"附录：随带交付素材"，
     不依赖仓库外文档 -->

| 任务 | 内容 | 验收 | 随带交付 |
| --- | --- | --- | --- |
| t0 | ci.yml 骨架：changes 探测 + ci-ok 聚合（if: always() + 结果矩阵，见 A5）+ 空分端 job + **.github/PULL_REQUEST_TEMPLATE.md**（许可证声明机制的载体，t1 首批依赖即消费——"伴随第一个消费者"）+ **逐提交署名校验 job**（`Assisted-by` trailer 正则，opt-out——CI 是唯一能挡 `--no-verify` 的一层，见 A5） | A5（骨架） | AGENTS"验证命令"节（素材见本 spec附录·A） |
| t1 | workspace 根 + apps/web init（Nuxt 4 app/ 布局）+ catalog + .env.example 首段（NUXT_PUBLIC_API_BASE，契约见 A4）+ **根 Taskfile.yml（task setup / task ci）** + **docs/guides/onboarding.md 首段**（fnm / pnpm / Task 安装与 `task setup`，A10 的交付点；Go / Docker 段随 t2 / t6 渐进填充）；填充 ci web job | A1、A2、A4 | — |
| t2 | apps/api：go mod init + internal 分层 + huma /healthz（监听 PORT，缺省 8080）+ openapi 子命令 + .golangci.yml + **根 Taskfile 增 gen / gen:check** + .env.example 增 PORT + onboarding.md 增 Go 段；填充 ci api job 与 gen:check | A3 | AGENTS"Go 分层纪律 / 契约与生成物 / 工具版本"节（素材见本 spec 附录·B） |
| t3 | lefthook + merge message 格式模板 + **commit-msg 署名校验钩子**（缺 trailer 即中止，fail-closed，见 A6） | A6 | AGENTS 提交纪律节增 lefthook 配置行（`root:` 与 `stage_fixed: true` 不可省） |
| t4 | 遗产整理：AGENTS 继承条款（harmony / foampray 裁剪，**输入清单见 A9**）+ journal 首篇 | A9 | AGENTS"继承条款"节（agent-confirmation-chain 与 roadmap 已随 first commit 入库） |
| t5 | .vscode 基线（settings + extensions，含 TODO 八标记配色） | A7 | — |
| t6 | infra/docker-compose.yml：PG 活跃 + 健康检查，Redis 注释预留；.env.example 增 POSTGRES_*（DATABASE_URL 注释预留，见 A4）+ onboarding.md 增 Docker / db:up 段（文档就此完整，收口 A10 验收） | A8 | — |

（A10 收口 = dev → main 的 `--no-ff` 合并与 tag，非独立任务。）

## 验收标准

<!-- append-only：只追加、不重排、不复用；废弃划掉留槽。引用格式 SPEC-0001-A3 -->

- A1 workspace 根基线：pnpm-workspace.yaml + 根 package.json（private、packageManager 锁 pnpm、engines）+ .nvmrc + **根 Taskfile.yml（task setup / task ci——验证命令节与"提交前 task ci"的载体，随本任务落地）**；干净环境 `pnpm install` 成功，依赖版本经 catalog 统一；Node 侧命名空间 @learnfolio/*
- A2 apps/web：Nuxt 4 脚手架（`app/` srcDir 布局）；`pnpm --filter @learnfolio/web dev` 可启动；同时填充 ci.yml 的 web job（lint + typecheck + build）
- A3 apps/api：go.mod 建立（module github.com/foamshadow/learnfolio）+ cmd/api/main.go + internal 分层随首个代码出现（不建空目录）+ huma 最小 /healthz；openapi 子命令落盘 docs/openapi.yaml 且同代码双跑逐字节一致（陷阱防护：包级 var 用 `=` 赋值；路由注册在构造回调内且不依赖 DB 连接；**自带 `--output` 原子写盘、禁 stdout 重定向**——shell 管道参与编码，PowerShell `>` 重编 UTF-16 即毁 gen:check）；.golangci.yml 随本任务入库——`version: "2"` 顶层键 + 生成代码排除（v2 语法：`linters.exclusions.generated: lax` + `paths: [ent/, migrations/]` 双保险）；根 Taskfile 增 `gen` / `gen:check` 任务（CI 的 gen:check 与"改契约源追加 task gen"消费）；填充 ci.yml 的 api job 与 gen:check
- A4 .env.example **按消费者分阶段到达**（预支判据贯彻到变量级，不一次预写无消费者的变量）：t1 `NUXT_PUBLIC_API_BASE`（web 消费）；t2 `PORT`（api 监听，缺省 8080）；t6 `POSTGRES_USER/PASSWORD/DB`（compose 消费）；Phase 2 `DATABASE_URL`（Go 消费；t6 起以注释形式写明拼装格式）与 `REDIS_ADDR`（注释预留，t6 与 compose 注释服务同批入库）。各阶段入库变量与当期实际消费者一致，验收按阶段核对
- A5 ci.yml 单 workflow，骨架先行：changes 探测 + 分端 job + ci-ok 聚合（`if: always()` 是硬约束——依赖 job 失败时聚合被跳过，而 skipped 被 GitHub 算作成功，缺 always() 是静默放行而非卡住；**结果矩阵**：PR 下 changes / title / attribution 必须 success（skipped 判红）、web / api 允许 skipped 但仅当 changes 对应 output 为 false；push 下 web / api / attribution 必须 success、changes / title 允许 skipped；任一 failure / cancelled 判红——不能实现成"非 failure 即过"，否则某个 job 因 `if` 写错被跳过时聚合仍全绿；**聚合 needs 含标题校验与署名 job**——否则违规只多一个红灯，拦不住合并按钮）；**双触发**：pull_request（对 PR head）+ push（对 dev/main——关闭 up-to-date 后唯一的兜底观测面；它是**事后发现**：只验证新 base 自身，PR + 新 base 的组合冲突要等合入 dev 后全量变红才暴露；**push 事件跳过 changes 探测与标题校验、全量跑**——两者依赖 PR 上下文，push 下必误报红，而"dev push 红 = 语义冲突"信号不可被误报污染）；**PR 标题正则校验 job**（仅 pull_request 事件）六条完整 alternation：`^(合并 spec-\d{4}-t\d+ [a-z0-9-]+：.+|合并 fix [a-z0-9-]+：.+|合并 hotfix [a-z0-9-]+：.+（发布 v\d+\.\d+\.\d+）|合并 hotfix [a-z0-9-]+：backport 自 v\d+\.\d+\.\d+|合并 Phase \d+ 收口：v\d+\.\d+\.\d+|docs: .+)$`（不共用后缀——收口变体无短名段，全角冒号字面匹配）；**ci-ok 自 t0 合入后为必需检查**（2026-11-15 已配置 dev/main，strict=false）——t0 自身 PR 由人工评审把关（一次性 bootstrap：GitHub 设置界面只能下拉选已上报过的 check 名，ci-ok 在 t0 合入前从未上报；API 可写任意名但未实测（见实测⑤）——按"先合入后补配"顺序最稳；例外与 SPEC-0001 自批例外同源，记录于此不得成为先例）；**push 侧聚合 job 显示名 `ci-ok (push)`、PR 侧 `ci-ok`**（job id 不变）——收口 PR 的 dev head 天然同时有 dev push 与 PR 两次 run，同名会让 required 取值依赖平台未明语义；A2/A3 填充真实 job 后 PR 上 lint + build + test 全绿（test 空集也跑），gen:check = 重生成后 `git diff --exit-code`；**t0 同时带入 .github/PULL_REQUEST_TEMPLATE.md**（新增依赖许可证声明栏——ADR-0002 执行机制的载体，t1 首批依赖即消费；模板顶部以 HTML 注释内置**五类标题速查样板**——分支短名用连字符、标题短名是空格，照抄分支名必被正则拦红，样板防照抄错误）；标题校验 job 触发 `pull_request: types: [opened, edited, synchronize, reopened]`（默认 types 不含 edited——首次通过后改标题会逃逸校验）；**分支方向矩阵在同 job 校验**：dev←`feat/*`/`fix/*` 用 feat/fix 变体、dev←`backport/*` 用 backport 变体、dev←`docs/*` 用 docs 变体（`docs: …`）、main←`hotfix/*` 用发布变体、main←`dev` 用收口变体，**其余 base×head 组合一律拒绝**（只验标题字面拦不住"feat PR 提到 main"类方向错误）；**逐提交署名校验 job**（PR 与 push 双场景）：PR 取 `--no-merges base..head`，push 取 `--no-merges before..after`（`github.event.before` 全零或不可达时回退到 `after` 全史，fail-closed；checkout 需 `fetch-depth: 0`）；对**非 merge** 提交（`git rev-list --no-merges`）校验 `Assisted-by` trailer 存在性与格式 `^Assisted-by: (none|[A-Za-z][A-Za-z0-9]*:[a-z0-9][a-z0-9.-]*)$`（opt-out——缺失即违规、列出 SHA；并入 ci-ok；CI 是唯一能挡 `--no-verify` 的一层；规则源 proposals/agent-attribution，键表见其 §4、毕业迁 AGENTS）；**t0 实测四项 GitHub 行为**（①已于 2026-11-14 实测结案：merge commit subject = PR 标题 + ` (#N)`、正文为空，账本读法与后续校验按容忍该后缀处理）：②新 workflow 在首个 PR 上的自举运行（2026-11-15 结案：PR #9 首轮 run 六 job 结论符合预期——docs-only 分端 skipped、title/attribution/ci-ok 绿） ③edited 重跑与旧 run 同名时 required 是否取最新（旧 run 红灯不阻塞修好的标题）④收口 PR 同 SHA 上 `ci-ok` 与 `ci-ok (push)` 并存时 required 只认 PR 侧 ⑤API 预配置未上报过的 required check 名，是否在首个 PR 上自举生效；合并界面手改 message 字段 = 账本失守，禁止（AGENTS 分支与版本节）
- A6 lefthook：`root:` 与 `stage_fixed: true` 配置正确，按文件后缀分流钩子（PR 模板已随 t0 入库，本条不含）；**commit-msg 钩子校验 `Assisted-by` trailer**：缺失即中止提交（fail-closed——静默补 `none` 会把 agent 提交误标成人类提交）；`LF_HARNESS` / `LF_MODEL` 已否决（环境注入见被否方案表）——trailer 由 agent 按署名提案 §5 信源清单查证后自行写入；`--no-verify` 可绕过，由 t0 的 CI 校验补位
- A7 配置项基线：.vscode/settings.json + extensions.json（含 TODO 高亮插件与八标记配色——注释规范的机器分发载体）
- A8 infra/docker-compose.yml：PG 服务定义 + 健康检查，健康检查通过一次（验证成员 Docker 环境）；**唯一命令固定参数**（compose 文件在 infra/ 下，裸 `docker compose up -d` 从根目录找不到配置）：`docker compose --project-directory . --env-file .env -f infra/docker-compose.yml up -d`，down/ps 同参数；封装为根 Taskfile `db:up` / `db:down`（唯一入口）；Redis 以注释形式预留；compose 消费的变量（POSTGRES_USER/PASSWORD/DB）随本任务进 .env.example（与 Go 消费的 DATABASE_URL 双轨，后者注释预留至 Phase 2）
- A9 AGENTS.md "继承条款"节补齐：harmony / foampray 条款逐条裁剪（判据：工具无关 + 对 5 人团队成立，每条注来源），产出继承决策 journal 一篇（docs/journal/ 首篇）。**输入清单**：harmony《软工流程复盘》与 foampray AGENTS.md 为仓库外源文档，由 foamshadow 于 t4 开工时提供全文，裁剪条款逐条注明出处，来源账记入 journal 首篇（"仓库内文档不引用仓库外记录"约束的是文档间链接；施工输入物料经 journal 记账闭合）
- A10 收口：**收口前置 PR**（fix/ 短名 PR 回 dev）完成 SPEC 验收条目逐条勾选与 spec status → done，先于收口 PR 合入（收口 PR head = dev 且 dev 必 PR 禁直推，无法自带文件改动）；发布检查单全过（首项机械守卫 = main 自分叉点以来无 dev 缺失的改动：`git diff --quiet origin/dev...origin/main`，三点 diff——防"hotfix 进了 main 未回流（含漏打 tag）"；命令与陷阱见 ADR-0003）；dev --no-ff 合回 main，`git fetch origin && git tag -a v0.1.0 origin/main -m "v0.1.0 — Phase 0 收口：…（覆盖 SPEC-0001）" && git push origin v0.1.0`（收口 tag 打 merge commit，main 第一父链上——首个基线）；onboarding 完备性：第二个成员 clone 后仅凭仓库内文档（docs/guides/onboarding.md——t1 建首段、t2 / t6 补 Go / Docker 段；.nvmrc / packageManager / go.mod / AGENTS 工具链边界 + `task setup`）可搭建环境并开发，缺失即本条不通过

## 附录：随带交付素材（施工自包含）

> 本 spec 自足原则：任务施工只依赖仓库内文档。t0 / t2 的 AGENTS 规则节素材全文在此明示，
> 对应任务 PR 将其写入 AGENTS.md 后，在本文末"变更记录"追加一行"素材 X 已并入（PR #N）"。
> 并入 AGENTS 时，下列粗体行升为 `##` 节标题。

### 素材 A：AGENTS"验证命令"节（t0 并入）

**验证命令（agent 自证完成的唯一方式；未跑通不得声称完成）**

**生效时点**：工具链随 t1（根 Taskfile）与 t2（Go）落地——此前仓库仅含文档与 CI 骨架，纯文档改动（*.md）无需执行下表任何命令，确认编号 / 链接 / 词表自洽即可（ci:docs 立项前的轻量路径）；**t0 至 t1 之间的空档**（ci.yml 已入库、task 尚不存在）：本地无可跑命令，验证 = PR 上的 GitHub Actions 结果 + YAML 语法人工核对。

| 改动范围 | 必跑 |
| --- | --- |
| apps/api/**/*.go | `cd apps/api && go build ./... && go test ./... && golangci-lint run ./...` |
| apps/api 的 handler / DTO / ent schema | 追加 `task gen && task gen:check` |
| apps/web/**/*.{ts,vue} | `pnpm --filter @learnfolio/web lint && pnpm --filter @learnfolio/web typecheck` |
| 任何改动 | 提交前 `task ci`（CI 管线本地等价物，全绿才推） |

- 生成物报错时禁止改生成物：回源头（Go struct / ent schema）改，再 task gen
- 禁止跨 app import：apps/web 不引用 apps/api 的任何文件，唯一通道是生成的 schema.ts
- 新增 Node 依赖一律走 pnpm-workspace.yaml 的 catalog:，不在 app 的 package.json 写死版本

### 素材 B：AGENTS"Go 分层纪律 / 契约与生成物 / 工具版本"节（t2 并入）

**Go 分层纪律**

- 依赖单向：handler → service → repository；repository 是唯一碰 DB 的层
- internal/handler 放 HTTP 层与 request/response DTO（可带 huma 注解）
- internal/model 放领域/持久化实体：零 huma 注解，永不出现在 OpenAPI spec
- ent 生成代码入库（Phase 2 起）：apps/api/ent/ 提交，仅 ent/schema/ 是手写源（clone 即 build；查询必须对照生成的强类型 API 写）
- 预定目录 config/ store/ httpx/ telemetry/ 随首个代码出现，禁止提前建空目录
- 第二个 cmd/* 二进制出现当天，wire() 组装从 main.go 提入 internal/app/

**契约与生成物**

- 生成物不手改：apps/web/shared/api/schema.ts、ent 生成代码、apps/api/docs/openapi.yaml 一律改源头后重新生成
- 契约产物显式导入：schema.ts 位于 shared/api/（不进 shared/types、shared/utils 自动导入目录），引用一律 #shared/api/schema
- task gen 必须串行（Taskfile 用 cmds: 链式，不用并行执行的 deps:）；migrate:diff 独立任务（需 Docker），不进 gen:check
- openapi 子命令自带写盘（--output，内部临时文件成功后原子替换），禁止 stdout 重定向：shell 管道参与编码，Windows PowerShell 的 `>` 按字符串重编出 UTF-16，gen:check 字节一致性即毁
- 换行纪律：.gitattributes 锁 eol=lf——git 不读 .editorconfig，换行漂移会让 gen:check 永久红；生成物已标 linguist-generated
- SQL 安全（Phase 2 生效）：绕过 ORM 的 raw 查询必须占位符参数绑定；禁止 fmt.Sprintf / 拼接 / f-string 组装 SQL
- 错误响应统一 huma 内建 RFC 9457 problem+json（huma.Error*），不手搓错误信封

**工具版本**

- 生成器 CLI（ent codegen / atlas）用 go.mod 的 tool 指令锁定（Go 1.24+，Phase 2 首个工具落地时启用）；禁止 CI 中 go install ...@latest
- golangci-lint 版本单一源：Taskfile var；CI action 与 task setup 共同消费同一数字（不进 go tool，避免污染 module graph；.golangci.yml 顶层 version 键兜底防 v1/v2 跨界）
- Node / pnpm 版本由 packageManager 字段与 .nvmrc 锁定

## 变更记录

- 2026-11-12 首版 ready（评审 = 策划期 ED1 过程，随 first commit 入库）
- 2026-11-13 任务分解表增"随带交付"列（规范与实现同 PR 到达）；related 增 ADR-0003
- 2026-11-13 第五轮外部审查落地：标题五变体（补 hotfix→main `（发布 vX.Y.Z）`）与正则入 A5；ci-ok 必需检查改"t0 合入后"（GitHub required check 自举，例外记于 A5）；backport/ 分支类型（ADR-0003）；收口守卫与 tag 取法 `origin/main^2` 入 A10；根 Taskfile 归属 t1/t2（A1/A3）；roadmap 提前进 first commit（19 件）
- 2026-11-13 第六轮外部审查落地：**施工自包含**——t0/t2 规则节素材全文移入本 spec"附录：随带交付素材"（任务表指针改仓库内，删除对 LearnFolio-first-commit.md 的仓库外引用）；agent-confirmation-chain 提前随 first commit 入库（20 件）；PR 模板自 t3 移 t0（许可证声明机制须伴随首批依赖，ADR-0002）；A4 改按消费者分阶段（t1 NUXT_PUBLIC_API_BASE / t2 PORT / t6 POSTGRES_* / Phase 2 DATABASE_URL+REDIS 注释）；A5 增 edited 触发、分支方向矩阵、t0 实测 merge subject；A8 增 compose 显式命令与 Taskfile db:up 封装；A9 增输入清单
- 2026-11-13 第七轮外部审查落地：收口写操作改**前置 PR**（"验收勾选 / status→done 在收口 PR 内改"机制不可执行——收口 PR head = dev 且 dev 必 PR 禁直推，文件改动无落点；改 fix/ 短名前置 PR 回 dev 先行合入，收口 PR 自动携带，A10 与 ADR-0003/guides 同步）；**收口 tag 改打 merge commit `origin/main`**（dev tip 不在 main 第一父链，"第一父链 + tag = 版本史"读不出 tag；hotfix tag 仍打 hotfix tip——backport `git merge <tag>` 依赖其指向 hotfix 线）；例外记录"自 SPEC-0002 起"改"自第二份 spec 起"（编号起草时才分配，first commit 引用未分配号会静默指错）；A5 实测清单扩至四项（新增同 SHA 双 run 同名 ci-ok 判定、API 预配置 required check）且预配置措辞软化为"设置界面限制非硬约束"；PR 模板增五类标题速查样板（分支名连字符 vs 标题空格，照抄必红）；素材 A 生效时点守卫补 t0→t1 空档；A4 REDIS_ADDR 注释入库时点钉 t6（原"t1"笔误）；A10 增 onboarding 完备性条款
- 2026-11-13 第七轮收尾补丁：**onboarding 挂交付点**——A10 的环境搭建验收原无任务生产其文档，改 t1 创建 docs/guides/onboarding.md 首段（fnm / pnpm / Task 安装与 task setup）、t2 / t6 渐进补 Go / Docker 段，收口 A10 验收完整性（消除"收口时临时补文档再走一个 PR"）；AGENTS 三层历史读法注 hotfix patch tag 例外（与 guides 同口径）；AGENTS tag 规则注 describe 仅 main 侧（收口 merge commit 不在 dev 祖先，dev 侧 describe 解析不到收口 tag——Phase 1 部署勿在 dev 构建用 describe 取版本号）；X+1 时 Y / Z 归零补写
- 2026-11-13 第九轮小审：A3 增"openapi 子命令自带 `--output` 原子写盘、禁 stdout 重定向"（shell 管道参与编码，Windows PowerShell 的 `>` 按字符串重编 UTF-16，会击穿 gen:check 的字节一致性；规则不依赖成员 shell 配置）；素材 B"契约与生成物"同步该条。审查过程记于 ED1 修订注记（第九轮小审）
- 2026-11-14 v2.4 agent 署名规则（opt-out）落地：任务表 t0 增**逐提交署名校验 job**（`Assisted-by` trailer 正则，并入 ci-ok，A5）；t3 增 lefthook **commit-msg 钩子**（fail-closed + `LF_HARNESS` / `LF_MODEL` 自动补〔已被同日二次转向作废，见下条——钩子不代填〕，A6）；proposals/agent-attribution 随 first commit 入库（第 21 件）；规则本体待建仓后"规则 PR"落 AGENTS 提交纪律节并立 ADR（提案毕业路径 step 2）
- 2026-11-14 二次转向（同日）：**环境变量注入被否**（多 harness × 多 model 下 shell 全局变量必错配、配置负担随模型数线性涨）——t3 钩子只 fail-closed 校验、不代填，trailer 由 agent 按署名提案 §5 信源清单（harness 配置 → 系统提示 → 问人）查证后自行写入，上条"LF_HARNESS / LF_MODEL 自动补"随之作废；model 键粒度目标 = 详细版本（快照 id 照抄）
- 2026-11-14 规则落地（首个合并 PR 后）：A5 实测①结案——`Default to PR title` 的 merge commit subject = PR 标题 + ` (#N)`、正文为空，实测清单四项减为三项；agent 署名规则毕业——AGENTS 提交纪律节增 opt-out 细则与 harness / model 键表、立 ADR-0004、proposals/agent-attribution 状态改 adopted 且正文改指针
- 2026-11-14 双合并策略（ADR-0005）：纯文档改动改 `docs/*` 分支 + squash（无 merge 节点），标题正则扩为六变体、方向矩阵增 dev←docs/*；署名 job 明确只看**非 merge** 提交；ADR-0003 相应转 deprecated（部分条款失效）
- 2026-11-14 t4 提前执行：继承条款与裁剪判据落 AGENTS（ADR-0008：直接 6 条 + 改写 2 条 + 不取 5 条）；提交 / 推送授权模型落 AGENTS（ADR-0007：双授权、告知义务、WIP 免审与可编译边界）；A9 的裁剪要求提前满足，继承决策 journal 并入 2026-11-14 事件篇
- 2026-11-15 外部审查修订（ADR-0009 定稿前）：ci-ok 改**结果矩阵**（skipped 不再一律放行——PR 下 title / attribution 被跳过判红，web / api 的 skipped 须与 changes output 对照）；push 聚合更名 `ci-ok (push)` 消歧（main←dev 收口 PR 的同 SHA 双 run 是常规场景）；署名校验扩至 push（before..after，首推 / 强推回退全史，fetch-depth: 0）；push 兜底定位由"补偿网"改为"事后发现"；修正空 job 表述（代码 PR 上 success，非 skipped）；维护类 PR 归 feat / fix（scope 记提交）；实测清单重排为四项（edited 取最新、双名并存）
- 2026-11-15 t0 落地与门禁启用（PR #9）：CI 骨架以 --no-ff 合入 dev（merge 4b4925a），dev/main 配置 required `ci-ok`（strict=false、enforce_admins=true）；**素材 A 已并入 AGENTS（PR #9）**。实测②结案：首个 PR 自举成功——docs-only 变更 changes 判 web/api=false，分端 skipped、title/attribution/ci-ok 绿，聚合日志 `event=pull_request` 判定通过；push 路径实测 changes/title skipped、web/api/attribution 跑、聚合名 `ci-ok (push)`。实测③④待后续；⑤未测——另记 required 配置坑：状态检查未启用时 `PUT/PATCH /protection/required_status_checks` 返回 404，须整体 `PUT /branches/{b}/protection` 才能打开
