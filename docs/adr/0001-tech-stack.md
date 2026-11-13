---
id: ADR-0001
title: "技术栈选型：Nuxt 4 + Go + huma v2 + ent，混合 monorepo"
status: accepted
date: 2026-11-12
author: foamshadow
tags: [se-arch, lang-go, lang-vue]
related: [SPEC-0001]
---

# ADR-0001：技术栈选型

> 补记说明：实际决策与权衡发生在建仓前策划期（2026-11-10 ~ 11-12），本篇为沉淀归档；此后的 ADR 在决策当时撰写。

## 背景（Context）

5 人学习型团队（3 核心）的长期项目：开发中学习全栈、文档驱动（spec 先行，AI agent 按 spec 实现，人做验收复盘）、开发与学习经历即网站内容。约束：团队已有 Vue/Nuxt 资产与 pnpm monorepo 基建经验（foampray）；后端选定 Go 作为学习目标；API 非对外公共产品；agent 是主要实现者，规范须可被机器执行。

## 决策（Decision）

| 决策项 | 结论 | 关键理由 |
| --- | --- | --- |
| 前端 | Nuxt 4（Vue 3 + TS，`app/` 布局） | 复用 Vue 资产；@nuxt/content 内容管线现成；Nitro 自托管友好 |
| 后端 | Go | 学习目标（语言特性 + 全栈原理）；编译期类型检查契合 agent 开发 |
| 仓库组织 | 混合 monorepo（`apps/*` 双工具链分界） | 协作团队跨端原子提交；基建经验迁移 |
| 契约路线 | code-first | API 非对外公共产品；spec 由代码保证一致，构思期不被预设 API 面拖累 |
| 契约工具 | huma v2 | 反射生成 OpenAPI 3.1，适配 chi/echo/net-http |
| 数据访问 | ent（ORM） | schema → codegen → 强类型查询，与 Prisma 心智同构 |
| 内容管理 | git-based markdown，无 CMS | 内容随仓库走；内容源与工程笔记分离（learning 不直通网站，发布走蒸馏）；admin 后台留作 Phase 3 学习目标 |
| 部署 | Docker Compose + Nginx，单 ECS | 沿用既有基建经验 |

## 被否方案（Alternatives）

| 方案 | 否决理由 | 翻转条件 |
| --- | --- | --- |
| Next.js | React 生态宽度收益不足以抵消 Vue 资产迁移成本 | 明确想学 React/RSC |
| sqlc | 学习 SQL 本身不是目标，ORM 优先 | 学习目标改为掌握 SQL / 手写数据访问 |
| 前后端分仓 | 此团队规模下契约同步成本不成立 | 团队显著扩大、契约需独立版本化 |
| design-first 契约 | 构思期不应预设 API 面 | API 成为对外公共产品（届时从代码导出 spec 再补） |
| swag 注解生成 | 产出以 Swagger 2.0 为主、默认不解析 internal/、OpenAPI 3.1 支持不成熟 | —（整体退回 Swagger 2.0 生态时再议） |
| 顶层 `web/ + server/` 命名 | Nuxt 4 每个前端 app 自带 Nitro `server/`，与 Go 目录撞名，agent 走错门高发 | — |
| 课程表式 SE 学习 | 预排知识清单违反实践驱动，改 just-in-time | —（方法论决策，附记于此） |

## 后果（Consequences）

- 契约生成链成为关键路径：huma → openapi.yaml → schema.ts；`task gen` 必须串行（`migrate:diff` 独立）；生成物禁手改，CI gen:check 防漂移；换行确定性由 .gitattributes 保证（git 不读 .editorconfig）
- **ent 生成代码入库**：apps/api/ent/ 提交进 git，仅 ent/schema/ 手写——clone 即 build、agent 可读生成的强类型 API、CI 免装 codegen；diff 噪音以 linguist-generated 折叠压制（schema/ 反选不折叠）
- 双工具链 monorepo 引入边界纪律（Node/Go 命令互不越界、命名空间 @learnfolio/*）与 Docker context 不对称（Node 侧指仓库根且保留整个 docs/——Meta 三页构建期按 frontmatter 索引四类全要；Go 侧指 apps/api——Phase 1+ 首次部署时落地）
- module path 全小写一经 tag 并被 GOPROXY 缓存即不可逆
- ent 在 Phase 2 首次落地，此前仅有与 Prisma 的心智同构预期，需按实际 API 校准
