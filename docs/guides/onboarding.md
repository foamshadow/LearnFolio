---
title: "本地环境上手：从 clone 到 task ci"
author: foamshadow
date: 2026-11-17
status: draft
tags: [tool-node, tool-go, tool-git, se-arch]
related: [SPEC-0001, ADR-0007]
---

# 本地环境上手：从 clone 到 task ci

## 讲给谁 / 前置知识

给第一次 clone 仓库、要把 `apps/web` 与 `apps/api` 跑起来的成员（人类或 agent）。前置只需要会三件事：`git clone`、`git commit`、`git push`，以及使用终端。不需要先懂 Nuxt、pnpm workspace、Go 或 Task——本文会把每个工具第一次出现时的作用讲清楚。

本文覆盖 **Node + Go 侧**（`apps/web`、`apps/api` 与 workspace 根）与**本地依赖服务**（第 9 步，Docker Compose）。规则真源仍是 `AGENTS.md` 与 `SPEC-0001`，本文只解释怎么把环境搭起来，不新增规则。

## 核心图景

本地环境由七层组成，每层只认一个版本真源（第七层是可选项——Phase 0 业务代码不连数据库，不起服务可跳过）：

| 层 | 真源 | 谁消费 |
| --- | --- | --- |
| Node | `.nvmrc`（`24.20.0`） | 本机 `fnm`；CI 的 `setup-node` |
| pnpm | 根 `package.json` 的 `packageManager`（`pnpm@12.19.0`） | 本机 corepack；CI 的 `pnpm/action-setup` |
| npm 依赖版本 | `pnpm-workspace.yaml` 的 `catalog:` | `pnpm install` |
| Go | `apps/api/go.mod` 的 `go` 指令（`1.27.4`） | 本机 `go`；CI 的 `setup-go` |
| Go 工具 | `Taskfile.yml` 的 `GOLANGCI_LINT_VERSION`（`v2.15.0`） | `task setup:go`；CI 的同一命令 |
| 命令 | 根 `Taskfile.yml` | 本地 `task`；CI 的 `task` |
| 本地依赖服务 | `infra/docker-compose.yml` 的镜像 tag（`postgres:17.12`） | `task db:up`；容器健康检查 |

搭好之后，日常只记五条命令：

```text
fnm use --install-if-missing     # 切到 .nvmrc 指定的 Node
task setup                       # setup:node + setup:hooks + setup:go（第一次 / 依赖变更后）
task dev:web                     # 起 Nuxt（默认 http://localhost:3000）
task dev:api                     # 起 Go API（默认 http://localhost:8080）
task ci                          # 提交前的本地 CI 等价物
```

第一次的完整链路是：

```text
fnm（读 .nvmrc）
  └─ Node 24.20.0
       └─ corepack（读 packageManager）
            └─ pnpm 12.19.0
                 └─ task setup
                      ├─ setup:node
                      │    └─ pnpm install（按 catalog 解析版本）
                      │         └─ apps/web postinstall: nuxt prepare
                      ├─ setup:hooks
                      │    ├─ lefthook install（写共享 .git/hooks）
                      │    └─ commit.template=.gitmessage（未设置时）
                      └─ setup:go
                           ├─ go mod download（apps/api）
                           └─ go install golangci-lint@v2.15.0
                                └─ task dev:web / dev:api / gen / ci
```

## 第一天上手

### 1. 安装 fnm 与 Node

fnm 是 Node 版本管理器；它读仓库根的 `.nvmrc`，保证每个人用同一个 Node。

```bash
# macOS
brew install fnm

# Arch Linux
sudo pacman -S fnm

# Windows（PowerShell）
winget install Schniz.fnm

# 其他系统：按 https://github.com/Schniz/fnm 的安装说明
```

把 fnm 接进 shell（只做一次）：

```bash
# bash / zsh：写进 ~/.bashrc 或 ~/.zshrc
eval "$(fnm env --use-on-cd)"
```

```powershell
# PowerShell：写进 $PROFILE
fnm env --use-on-cd | Out-String | Invoke-Expression
```

进入仓库后：

```bash
cd LearnFolio
fnm use --install-if-missing
node --version   # 应输出 v24.20.0
```

`--install-if-missing` 会在本机没有 24.20.0 时先安装；版本来自 `.nvmrc`，不要手写别的版本。

### 2. 安装 pnpm

Node 24 自带 corepack。corepack 会读根 `package.json` 的 `packageManager`，按需下载并使用 `pnpm@12.19.0`：

```bash
corepack enable
pnpm --version   # 应输出 12.19.0（首次可能先下载）
```

Windows 上如果 `corepack enable` 提示权限不足，用管理员终端执行一次。  
如果环境里确实没有 corepack（例如自行换了 Node 发行版），用精确版本回退，不要装 latest：

```bash
npm install -g pnpm@12.19.0
```

### 3. 安装 Task

Task（go-task）是跨语言任务运行器。仓库根只有一份 `Taskfile.yml`，Node、Go 与 Docker 命令都从它进入。

```bash
# macOS
brew install go-task

# Arch Linux
sudo pacman -S go-task
# 注意：Arch 包的二进制名是 go-task（不是 task）。做个软链与本文档其余部分保持一致：
sudo ln -sf /usr/bin/go-task /usr/local/bin/task

# Debian / Ubuntu：注意 apt 里的 task 包是 taskwarrior（撞名，不是本仓库要的
# go-task），不要 apt install task——用官方安装脚本，-b 指定安装目录
# （脚本默认装到当前目录 ./bin，PATH 找不到，后续 task 命令会全部落空）：
curl -fsSL https://taskfile.dev/install.sh | sh -s -- -b "$HOME/.local/bin"
# 确认 $HOME/.local/bin 在 PATH；装系统级则改用：sudo sh -s -- -b /usr/local/bin

# Windows（PowerShell）
winget install Task.Task

# 其他系统：按 https://taskfile.dev/installation/ 安装
task --version   # 应为 3.54.x
```

CI 固定使用 3.54.0；本地 3.54.x 即可。版本差太多可能不认 Taskfile 的 schema。

### 4. clone 与可选的环境文件

```bash
git clone git@github.com:foamshadow/LearnFolio.git
cd LearnFolio
```

根 `.env` 是可选的本地覆盖层，模板在 `.env.example`：

```bash
cp .env.example .env
```

当前有两组变量：

- Web / API：`NUXT_PUBLIC_API_BASE`（Web 请求的 API 地址，默认 `http://localhost:8080`）、`PORT`（API 监听端口，默认 `8080`）；
- 本地数据库：`POSTGRES_USER` / `POSTGRES_PASSWORD` / `POSTGRES_DB` / `POSTGRES_PORT`（缺省值见 `.env.example`；消费者是 `task db:up`，见第 9 步）。

没有 `.env` 也能启动 Web 与 API：Nuxt 走 `nuxt.config.ts` 的硬编码缺省，Go 走代码里的 `8080` 缺省。需要改端口或指向别的 API 时再建。唯一例外是本地数据库（第 9 步）：`task db:up` 必须先有 `.env`——compose 从它读 `POSTGRES_*`，缺文件直接报错，不会静默跳过。

`.env` 已 gitignore，不要提交；`.env.example` 才是入库模板。

### 5. 安装 Go

Go 侧只碰 `apps/api`；仓库根的 `go.mod` 不存在，所以不要指望在根目录跑 `go build`。

```bash
# macOS
brew install go

# Arch Linux
sudo pacman -S go

# Windows（PowerShell）
winget install GoLang.Go

# 其他系统：按 https://go.dev/dl/ 安装
go version   # 应不低于 go1.27.4
```

`apps/api/go.mod` 的 `go 1.27.4` 是最低版本；`GOTOOLCHAIN=auto`（Go 1.21+ 默认）会在本机版本不够时自动下载对应工具链。团队以 1.27.4 为基线，CI 用 `setup-go` 读同一个 `go.mod`。

**把 `GOPATH/bin` 加进 PATH**。`task setup:go` 会把 `golangci-lint` 装到 `$(go env GOPATH)/bin`，这个目录默认不在 PATH 上；不加，`task ci` 会报 `golangci-lint: command not found`。

```bash
# bash / zsh：写进 ~/.bashrc 或 ~/.zshrc
export PATH="$(go env GOPATH)/bin:$PATH"
```

```powershell
# PowerShell：写进 $PROFILE
$env:Path = "$(go env GOPATH)\bin;$env:Path"
```

验证：

```bash
go env GOPATH
echo "$PATH" | tr ':' '\n' | grep "$(go env GOPATH)/bin"
```

### 6. 安装依赖与工具

```bash
task setup
```

`task setup` 是聚合任务，按顺序执行：

1. `setup:node`：`pnpm install`，由 workspace 根安装 `apps/*` 与 `packages/*` 的依赖；`apps/web` 的 `postinstall` 会跑 `nuxt prepare`，生成 `.nuxt/` 下的类型与 ESLint 配置；
2. `setup:hooks`：`pnpm exec lefthook install` 安装 `commit-msg` / `pre-commit` 钩子（写入共享的 `.git/hooks`）；若 `commit.template` 尚未设置，则写入 `.gitmessage`（已有设置不覆盖）；
3. `setup:go`：在 `apps/api` 下 `go mod download`，再 `go install` 固定版本 `golangci-lint`（版本来自 `Taskfile.yml` 的 `GOLANGCI_LINT_VERSION`）。

钩子装好后，每次提交先跑 `pre-commit`（Go `gofmt`、web Prettier、shell `bash -n`，按后缀分流），再由 `commit-msg` 校验末尾的 `Assisted-by` trailer——缺失即中止，不代填。`git commit --no-verify` 可以绕过本地钩子，但 CI 的 attribution job 会逐提交判红，所以 trailer 不能省。`.gitmessage` 只在 `git commit` 打开编辑器时出现；`git commit -m` 不走模板，trailer 仍须手写。

第一次会下载依赖，之后通常很快。如果只做 Web，可以用 `task setup:node` 跳过 Go 工具；如果只改 API，可以用 `task setup:go`。但 A10 的“clone 后一条命令就绪”主路径是 `task setup`。

如果这一步报 Node / pnpm / Go 版本不对，先回到前面的安装步骤；不要用“先把依赖装上再说”绕过。

### 7. 起 Web 开发服务器

```bash
task dev:web
```

浏览器打开 <http://localhost:3000>，应看到 LearnFolio 页面和当前 API base。`Ctrl+C` 停止。

`task dev:web` 会用 Task 的 `dotenv` 读根 `.env`，再启动 Nuxt；Nuxt 自己只读 `apps/web/.env`，所以根 `.env` 必须由 Task 注入。没有 `.env` 时 Task 静默跳过，页面显示默认的 `http://localhost:8080`。

### 8. 起 API 开发服务器与生成契约

```bash
task dev:api
```

它会在 `apps/api` 下启动 `go run ./cmd/api`，并用 `dotenv` 读根 `.env`（任务目录是 `apps/api`，所以 Taskfile 里写的是 `../../.env`）。默认监听 `:8080`；在 `.env` 里改 `PORT` 即可换端口。

```bash
curl http://localhost:8080/healthz
# {"status":"ok"}
```

`/healthz` 是 liveness 探针，只表示进程可服务，不检查数据库；readiness 等有依赖后再加。

契约生成：

```bash
task gen        # 重新生成 apps/api/docs/openapi.yaml
task gen:check  # 重新生成后 git diff --exit-code，校验无漂移
```

改了 handler / DTO 后先 `task gen`，把 Go 源码和 `apps/api/docs/openapi.yaml` 一起提交。**不要手改生成物**；`gen:check` 会在 CI 里抓漂移。也不要从仓库根跑 `go run ./cmd/api openapi`——根目录没有 `go.mod`；用 `task gen`，它已经设好 `dir: apps/api`。

只查 API：

```bash
task ci:api
```

它执行 `go build ./...`、`go test ./...`、`golangci-lint run ./...`、`task gen:check`。

### 9. 起本地数据库（可选）

Phase 0 的业务代码不连数据库，这一步可以跳过；想提前把依赖服务跑起来（或为 Phase 2 做准备）时再执行。前提是 Docker：

```bash
# macOS / Windows：Docker Desktop，按 https://docs.docker.com/get-started/get-docker/ 安装
# Arch Linux
sudo pacman -S docker docker-compose   # compose 子命令由独立的 docker-compose 包提供，缺它 db:up 会报 not a docker command
sudo systemctl enable --now docker
sudo usermod -aG docker "$USER"        # 免 sudo 跑 docker；重新登录或 newgrp docker 生效
# 其他系统：按 https://docs.docker.com/engine/install/ 安装

docker info              # 能输出 Server Version 即可用
docker compose version   # compose 插件就绪（task db:up 依赖它）
```

起 / 停：

```bash
cp .env.example .env   # db:up 的前置：compose 从根 .env 读 POSTGRES_*（第 4 步建过就跳过）
task db:up             # 启动 PG，后台运行
task db:down           # 停止；数据保留在命名卷里，下次 db:up 还在
```

确认健康（`STATUS` 列从 `health: starting` 变 `healthy`）：

```bash
docker compose --project-directory . --env-file .env -f infra/docker-compose.yml ps
```

几个设计决定：

- PG 的端口、用户、库名都来自根 `.env`（缺省见 `.env.example`）；`POSTGRES_PORT` 与本机已有 PG 或其他工作树冲突时改它错开，容器内恒 5432。
- compose 的 project 名取 `--project-directory` 的目录名，所以主仓库与各 `.worktrees/` 工作树的数据库互不共享（容器与数据卷各自一套）。
- Redis 服务已在 `infra/docker-compose.yml` 注释预留，Phase 2 启用；Go 的连接串 `DATABASE_URL` 同批（`.env.example` 里有拼装格式注释）。

> `docker compose ... down -v` 会连数据卷一起删（本地库清零）。Phase 0 无业务数据，误删无碍；Phase 2 起这条命令等于删开发库，慎用。

### 10. 提交前跑 CI 等价物

```bash
task ci
```

它按顺序执行：

1. `task check:catalog`：检查 `apps/*`、`packages/*` 的直接依赖是否都写成 `catalog:` 或 `workspace:`；
2. `pnpm --filter @learnfolio/web lint`；
3. `pnpm --filter @learnfolio/web format:check`（Prettier）；
4. `pnpm --filter @learnfolio/web typecheck`（`nuxt typecheck` + `vue-tsc`）；
5. `pnpm --filter @learnfolio/web build`；
6. `cd apps/api && go build ./...`；
7. `cd apps/api && go test ./...`；
8. `cd apps/api && golangci-lint run ./...`；
9. `task gen:check`。

全绿再 push。CI 的 web job 调 `task check:catalog` + `task ci:web`；api job 调 `task setup:go` + `task ci:api`，不是另一套手写清单。

commit / push 的授权模型见 `AGENTS.md`「破坏性操作」与 [ADR-0007](../adr/0007-collaboration-authorization.md)；能跑通不等于能直接推。

需要手动格式化时：

```bash
task format
```

它只对 `apps/web` 跑 Prettier；编辑器保存时也会先走 Prettier，再由 ESLint 修可自动修复的规则。Go 侧用 `gofmt`。两者都已进 `pre-commit`（自动修并 `stage_fixed` 进暂存区），`task format` 现在主要给编辑器之外的批量整理用；`golangci-lint` 的 formatter 配置仍暂未启用。

### 常用命令速查

| 场景 | 命令 |
| --- | --- |
| 第一次、依赖变更后 | `task setup` |
| 只装 Node 依赖 | `task setup:node` |
| 只装 git hooks / 提交模板 | `task setup:hooks` |
| 只装 Go 工具 | `task setup:go` |
| Web 日常开发 | `task dev:web` |
| API 日常开发 | `task dev:api` |
| 起本地数据库 | `task db:up` |
| 停本地数据库 | `task db:down` |
| 提交前 | `task ci` |
| 只跑 API 检查 | `task ci:api` |
| 生成契约 | `task gen` |
| 校验契约无漂移 | `task gen:check` |
| 格式化 Web | `task format` |
| 只查依赖是否走 catalog | `task check:catalog` |

### Windows 备注

- 用 PowerShell 时，复制文件是 `Copy-Item .env.example .env`，不是 `cp`。
- `corepack enable` 可能需要管理员权限；`winget install Task.Task` / `winget install GoLang.Go` 不需要。
- 仓库的 `.gitattributes` 已把文本行尾锁为 LF；不要把编辑器全局的 CRLF 设置带进来。
- `fnm` 的 shell hook 写进 PowerShell `$PROFILE`，否则新终端不会自动切 Node。
- Go 的 `GOPATH\bin` 也要写进 `$PROFILE` 的 PATH，否则 `task ci` 找不到 `golangci-lint`。
- 不要用 PowerShell 的 `>` 重定向 `go run ./cmd/api openapi`：`>` 会按字符串重编出 UTF-16，毁掉 `gen:check` 的字节一致性。用 `task gen` 或 `--output`。
- 钩子里的 shell 语法检查用 `bash -n`。Windows 上需要 Git for Windows 的 `bash` 在 PATH（Git Bash 默认满足）；从 PowerShell 提交若报 `bash: command not found`，改用 Git Bash，或把 Git 的 `usr/bin` 加进 PATH。

## 为什么这样设计

### 版本只留一个真源

Node 由 `.nvmrc` 管，pnpm 由 `packageManager` 管，npm 依赖由 `catalog:` 管，Go 由 `apps/api/go.mod` 的 `go` 指令管，Go lint 工具由 `Taskfile.yml` 的 `GOLANGCI_LINT_VERSION` 管。各管一层，升级时只改一处：

- `.nvmrc` 同时被本地 `fnm` 和 CI 的 `setup-node` 读取；
- `packageManager` 同时被 corepack 和 `pnpm/action-setup` 读取；
- `catalog:` 的版本写在 `pnpm-workspace.yaml`，app 的 `package.json` 只写 `"catalog:"`；
- `apps/api/go.mod` 同时被本地 `go` 和 CI 的 `setup-go` 读取；
- `GOLANGCI_LINT_VERSION` 同时被 `task setup:go` 和 CI 的同一命令消费。

根 `package.json` 的 `engines` 是**声明**，不是强制闸门：pnpm 默认只警告不阻断。真正的 Node 一致性由 `.nvmrc`（本地流程）和 CI 的 `node-version-file`（硬门禁）承担。不要把 `engines` 当成“已经强制”。

### 为什么用 Task，而不是根 npm scripts

`task setup` / `task ci` / `task gen` 是跨语言的入口。t2 加了 `gen` / `gen:check` / `dev:api`，t6 加了 `db:up` / `db:down`；这些命令不属于某一个 npm package，也不该塞进根 `package.json`。CI 调 `task ci:web` / `task ci:api`，本地也调它们，命令清单只有一份。

`task setup` 聚合 Node 与 Go 两个子任务，是 A10 的“一条命令搭环境”入口；`setup:node` 保留给纯 Web 场景，但不会安装 Go 工具，所以不能替代完整 A10 路径。

### 为什么根 `.env` 要经过 Task

Nuxt 在 `apps/web` 下启动，默认只读 `apps/web/.env`；Go 也不会自动读 `.env`。团队约定环境文件在仓库根，Task 在启动子进程前用 `dotenv` 把根 `.env` 注入环境变量：

- `task dev:web` 的 `dotenv: ['.env']` 相对 Taskfile 根；
- `task dev:api` 的任务目录是 `apps/api`，所以写 `../../.env`。

这样不会在 app 目录里复制第二份 `.env`，也不会让密钥散落。

### 为什么 compose 命令写死在 Taskfile 里

`infra/docker-compose.yml` 在子目录里，从仓库根裸跑 `docker compose up` 找不到配置；参数里还有 `--env-file .env` 和 `--project-directory .`，各敲一遍容易漂移。`db:up` / `db:down` 把固定参数封装成唯一入口（A8），`ps` 之类的低频子命令按同参数手敲即可（见第 9 步）。project 名取 `--project-directory` 的目录名，主仓库与各工作树因此天然隔离——这也是不写死 `container_name` 的原因：固定容器名会跨 project 冲突。

### 为什么本地 `pnpm install`，CI 却用 `--frozen-lockfile`

本地 `task setup` 用普通 `pnpm install`，方便加依赖时更新 `pnpm-lock.yaml`；CI 用 `pnpm install --frozen-lockfile`，lockfile 与 `package.json` 不一致就直接失败，保证 runner 上装的就是评审过的那棵树。两者共用检查命令，但安装策略不同是故意的。

### 为什么先 `nuxt prepare`

`nuxt prepare` 生成 `.nuxt/` 里的类型和 `eslint.config.mjs` 的基座；没有它，`lint` 和 `typecheck` 会找不到生成物。它由 `apps/web` 的 `postinstall` 自动触发，所以正常路径是 `task setup` 一次，不需要手动跑。

### 为什么 Go 命令必须在 `apps/api` 内

Go module 根是 `apps/api`，不是仓库根；根目录没有 `go.mod`。`task gen` / `task ci:api` / `task dev:api` 都设了 `dir: apps/api`，所以从根执行 Task 也能落在正确的 module 里。这也是 `apps/web` 与 `apps/api` 工具链互不越界的具体落点。

## 常见误区

- **在干净 clone 上直接 `task ci`**：会因为没有 `node_modules` 失败。顺序是 `task setup` → `task ci`。
- **只跑 `task setup:node` 就以为环境完整**：Go 工具没装，`task ci` 会失败；完整路径用 `task setup`。
- **Go 装了但 `GOPATH/bin` 不在 PATH**：`task setup:go` 成功，`task ci` 却报 `golangci-lint: command not found`。把 `$(go env GOPATH)/bin` 加进 PATH。
- **在仓库根跑 `go run ./cmd/api`**：根目录没有 `go.mod`；用 `task dev:api`，或先 `cd apps/api`。
- **手改 `apps/api/docs/openapi.yaml`**：`gen:check` 会红；改 handler / DTO 后 `task gen`。
- **用 PowerShell `>` 生成契约**：`>` 会重编编码；用 `task gen` 的 `--output`。
- **在仓库根跑 `pnpm dev`**：根 `package.json` 没有 `dev` script；用 `task dev:web`。
- **Node 版本不对但继续开发**：pnpm 可能只警告；CI 会用 `.nvmrc` 的 24.20.0 跑，本地结果不可比。先 `fnm use`。
- **把 `.env` 放在 `apps/web`**：Nuxt 会读它，但 `task dev:web` 的约定是根 `.env`；两处并存会产生“到底哪个生效”的歧义。统一放根。
- **没建 `.env` 就 `task db:up`**：compose 的 `--env-file .env` 找不到文件直接报错（与 `dev:web` / `dev:api` 缺 `.env` 时静默跳过不同）。先 `cp .env.example .env`。
- **手写依赖版本**：`task check:catalog` 会拦；新增依赖用 `pnpm add`（`catalogMode: strict` 会把它写进 catalog）或手动写 `catalog:`。
- **同时引入另一套格式化器**：编辑器保存已配置 Prettier + ESLint；不要再加一个 formatter，避免保存一套、CI 另一套。
- **提交 `.env` / `node_modules` / `.nuxt` / `.output`**：都已在 `.gitignore`；`.env.example` 例外，必须入库。
- **Task 版本太旧**：`task --version` 应是 3.54.x；旧版本可能不认 `Taskfile.yml` 的 schema。

## 延伸

- `AGENTS.md`：工具链边界、Go 分层纪律、契约与生成物、验证命令
- [SPEC-0001](../specs/0001-phase-0-scaffold.md)：t1 / t2 / t6、A1 / A3 / A4 / A8 的验收原文
- [Git 流程讲解](git-workflow.md)：分支、合并、提交消息
- `Taskfile.yml` / `pnpm-workspace.yaml` / `.nvmrc` / `package.json` / `apps/api/go.mod` / `apps/api/.golangci.yml`：本文提到的版本与配置真源
- [Task 官方文档](https://taskfile.dev/)
- [Huma 文档](https://huma.rocks/)
