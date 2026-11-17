---
title: "本地环境上手：从 clone 到 task ci"
author: foamshadow
date: 2026-11-17
status: draft
tags: [tool-node, tool-git, se-arch]
related: [SPEC-0001, ADR-0007]
---

# 本地环境上手：从 clone 到 task ci

## 讲给谁 / 前置知识

给第一次 clone 仓库、要把 `apps/web` 跑起来的成员（人类或 agent）。前置只需要会三件事：`git clone`、`git commit`、`git push`，以及使用终端。不需要先懂 Nuxt、pnpm workspace 或 Task——本文会把每个工具第一次出现时的作用讲清楚。

这是 t1 的首段，只覆盖 **Node 侧**（`apps/web` 与 workspace 根）；Go（t2）与 Docker（t6）的段落后续补入。规则真源仍是 `AGENTS.md` 与 `SPEC-0001`，本文只解释怎么把环境搭起来，不新增规则。

## 核心图景

本地环境由四层组成，每层只认一个版本真源：

| 层 | 真源 | 谁消费 |
| --- | --- | --- |
| Node | `.nvmrc`（`24.20.0`） | 本机 `fnm`；CI 的 `setup-node` |
| pnpm | 根 `package.json` 的 `packageManager`（`pnpm@12.19.0`） | 本机 corepack；CI 的 `pnpm/action-setup` |
| 依赖版本 | `pnpm-workspace.yaml` 的 `catalog:` | `pnpm install` |
| 命令 | 根 `Taskfile.yml` | 本地 `task`；CI 的 `task` |

搭好之后，日常只记四条命令：

```text
fnm use --install-if-missing     # 切到 .nvmrc 指定的 Node
task setup                       # pnpm install + nuxt prepare
task dev:web                     # 起 Nuxt（默认 http://localhost:3000）
task ci                          # 提交前的本地 CI 等价物
```

第一次的完整链路是：

```text
fnm（读 .nvmrc）
  └─ Node 24.20.0
       └─ corepack（读 packageManager）
            └─ pnpm 12.19.0
                 └─ task setup
                      ├─ pnpm install（按 catalog 解析版本）
                      └─ apps/web postinstall: nuxt prepare（生成 .nuxt 类型）
                           └─ task dev:web / task ci
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

Task（go-task）是跨语言任务运行器。仓库根只有一份 `Taskfile.yml`，Node、未来的 Go 与 Docker 命令都从它进入。

```bash
# macOS
brew install go-task

# Arch Linux
sudo pacman -S go-task

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

当前只有 `NUXT_PUBLIC_API_BASE`（默认 `http://localhost:8080`）。没有 `.env` 也能启动，Nuxt 会走 `nuxt.config.ts` 里的硬编码缺省；需要指向别的 API 时再建。

`.env` 已 gitignore，不要提交；`.env.example` 才是入库模板。

### 5. 安装依赖

```bash
task setup
```

它执行 `pnpm install`，由 workspace 根安装 `apps/*` 与 `packages/*` 的依赖；`apps/web` 的 `postinstall` 会跑 `nuxt prepare`，生成 `.nuxt/` 下的类型与 ESLint 配置。第一次会下载依赖，之后通常很快。

如果这一步报 Node 或 pnpm 版本不对，先回到第 1、2 步；不要用“先把依赖装上再说”绕过。

### 6. 起开发服务器

```bash
task dev:web
```

浏览器打开 <http://localhost:3000>，应看到 LearnFolio 页面和当前 API base。`Ctrl+C` 停止。

`task dev:web` 会用 Task 的 `dotenv` 读根 `.env`，再启动 Nuxt；Nuxt 自己只读 `apps/web/.env`，所以根 `.env` 必须由 Task 注入。没有 `.env` 时 Task 静默跳过，页面显示默认的 `http://localhost:8080`。

### 7. 提交前跑 CI 等价物

```bash
task ci
```

它按顺序执行：

1. `task check:catalog`：检查 `apps/*`、`packages/*` 的直接依赖是否都写成 `catalog:` 或 `workspace:`；
2. `pnpm --filter @learnfolio/web lint`；
3. `pnpm --filter @learnfolio/web format:check`（Prettier）；
4. `pnpm --filter @learnfolio/web typecheck`（`nuxt typecheck` + `vue-tsc`）；
5. `pnpm --filter @learnfolio/web build`。

全绿再 push。CI 的 web job 调的是同一组 Task 命令：`task check:catalog` + `task ci:web`，不是另一套手写清单。

commit / push 的授权模型见 `AGENTS.md`「破坏性操作」与 [ADR-0007](../adr/0007-collaboration-authorization.md)；能跑通不等于能直接推。

需要手动格式化时：

```bash
task format
```

它只对 `apps/web` 跑 Prettier；编辑器保存时也会先走 Prettier，再由 ESLint 修可自动修复的规则。

### 常用命令速查

| 场景 | 命令 |
| --- | --- |
| 第一次、依赖变更后 | `task setup` |
| 日常开发 | `task dev:web` |
| 提交前 | `task ci` |
| 格式化 | `task format` |
| 只查依赖是否走 catalog | `task check:catalog` |

### Windows 备注

- 用 PowerShell 时，复制文件是 `Copy-Item .env.example .env`，不是 `cp`。
- `corepack enable` 可能需要管理员权限；`winget install Task.Task` 不需要。
- 仓库的 `.gitattributes` 已把文本行尾锁为 LF；不要把编辑器全局的 CRLF 设置带进来。
- `fnm` 的 shell hook 写进 PowerShell `$PROFILE`，否则新终端不会自动切 Node。

## 为什么这样设计

### 版本只留一个真源

Node 由 `.nvmrc` 管，pnpm 由 `packageManager` 管，npm 依赖由 `catalog:` 管。三处各管一层，升级时只改一处：

- `.nvmrc` 同时被本地 `fnm` 和 CI 的 `setup-node` 读取；
- `packageManager` 同时被 corepack 和 `pnpm/action-setup` 读取；
- `catalog:` 的版本写在 `pnpm-workspace.yaml`，app 的 `package.json` 只写 `"catalog:"`。

根 `package.json` 的 `engines` 是**声明**，不是强制闸门：pnpm 默认只警告不阻断。真正的 Node 一致性由 `.nvmrc`（本地流程）和 CI 的 `node-version-file`（硬门禁）承担。不要把 `engines` 当成“已经强制”。

### 为什么用 Task，而不是根 npm scripts

`task setup` / `task ci` 是跨语言的入口。t2 会加 `task gen` / `task gen:check`，t6 会加 `task db:up`；这些命令不属于某一个 npm package，也不该塞进根 `package.json`。CI 调 `task ci:web`，本地也调它，命令清单只有一份。

### 为什么根 `.env` 要经过 Task

Nuxt 在 `apps/web` 下启动，默认只读 `apps/web/.env`。团队约定环境文件在仓库根，Task 在启动子进程前用 `dotenv` 把根 `.env` 注入环境变量，Nuxt 的 `runtimeConfig.public.apiBase` 就能通过 `NUXT_PUBLIC_API_BASE` 覆盖缺省值。这样不会在 app 目录里复制第二份 `.env`，也不会让密钥散落。

### 为什么本地 `pnpm install`，CI 却用 `--frozen-lockfile`

本地 `task setup` 用普通 `pnpm install`，方便加依赖时更新 `pnpm-lock.yaml`；CI 用 `pnpm install --frozen-lockfile`，lockfile 与 `package.json` 不一致就直接失败，保证 runner 上装的就是评审过的那棵树。两者共用检查命令，但安装策略不同是故意的。

### 为什么先 `nuxt prepare`

`nuxt prepare` 生成 `.nuxt/` 里的类型和 `eslint.config.mjs` 的基座；没有它，`lint` 和 `typecheck` 会找不到生成物。它由 `apps/web` 的 `postinstall` 自动触发，所以正常路径是 `task setup` 一次，不需要手动跑。

## 常见误区

- **在干净 clone 上直接 `task ci`**：会因为没有 `node_modules` 失败。顺序是 `task setup` → `task ci`。
- **在仓库根跑 `pnpm dev`**：根 `package.json` 没有 `dev` script；用 `task dev:web`。
- **Node 版本不对但继续开发**：pnpm 可能只警告；CI 会用 `.nvmrc` 的 24.20.0 跑，本地结果不可比。先 `fnm use`。
- **把 `.env` 放在 `apps/web`**：Nuxt 会读它，但 `task dev:web` 的约定是根 `.env`；两处并存会产生“到底哪个生效”的歧义。统一放根。
- **手写依赖版本**：`task check:catalog` 会拦；新增依赖用 `pnpm add`（`catalogMode: strict` 会把它写进 catalog）或手动写 `catalog:`。
- **同时引入另一套格式化器**：编辑器保存已配置 Prettier + ESLint；不要再加一个 formatter，避免保存一套、CI 另一套。
- **提交 `.env` / `node_modules` / `.nuxt` / `.output`**：都已在 `.gitignore`；`.env.example` 例外，必须入库。
- **Task 版本太旧**：`task --version` 应是 3.54.x；旧版本可能不认 `Taskfile.yml` 的 schema。

## 延伸

- `AGENTS.md`：工具链边界、验证命令、提交纪律
- [SPEC-0001](../specs/0001-phase-0-scaffold.md)：t1 / A1 / A2 / A4 的验收原文
- [Git 流程讲解](git-workflow.md)：分支、合并、提交消息
- `Taskfile.yml` / `pnpm-workspace.yaml` / `.nvmrc` / `package.json`：本文提到的四个真源
- [Task 官方文档](https://taskfile.dev/)
