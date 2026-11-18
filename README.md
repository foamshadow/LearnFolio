# LearnFolio

一个由 5 人小队与 AI agent 协作建造、以自身开发与学习历程为内容的学习型全栈网站。

LearnFolio 是一个学习驱动的全栈工程实践项目：前端承载内容与展示，后端提供 API，
两端以 code-first 的 OpenAPI 契约连接。项目最核心的设计是一条自指的内容飞轮——
开发中学到的知识写成学习笔记，笔记经显式蒸馏后成为网站的发布内容；开发过程记录
与选型决策经构建期索引汇成展示页，项目用它自己的开发史完成首次内容填充。
交付一个网站，同时锻造一支掌握全栈工程方法的团队。

## 技术栈

- 前端：Nuxt 4（Vue 3 + TypeScript）
- 后端：Go（huma v2 + ent）
- 仓库：pnpm workspace + Go module 混合 monorepo
- 基建：Docker Compose + Nginx，单 ECS 部署

## 状态

Phase 0 收口：v0.1.0（覆盖 SPEC-0001，验收 A1–A10 已勾；A5 实测④与真实第二成员 onboarding 验收的待回填说明见 SPEC 变更记录。收口走 `dev` --no-ff 合回 `main` 与 annotated tag，收口后 `dev` 不追平 `main`）。施工图见
[SPEC-0001](docs/specs/0001-phase-0-scaffold.md)，文档地图见 [docs/README.md](docs/README.md)。

## 开发环境

Node 24.20.0 / pnpm 12.19.0 / Task 3.54.0 / Go 1.27.4；从 clone 到 `task ci` 的步骤见
[docs/guides/onboarding.md](docs/guides/onboarding.md)。

## 开发模型

迭代增量 + 每增量内微瀑布（spec → 实现 → 验收 → 复盘）+ SCM 变更控制（分支模型与 tag 基线）；
每 Phase 收口复盘，产出 journal 与学习笔记。阶段路线见
[docs/proposals/roadmap.md](docs/proposals/roadmap.md)（演进中的草稿，各 Phase 开工时逐段毕业为 spec）。

## License

[AGPL-3.0](LICENSE) · Copyright (C) 2026 FoamShadow
