---
title: "阶段路线图（演进中）"
author: foamshadow
date: 2026-11-13
status: draft
tags: [se-arch]
related: [SPEC-0001]
adopted-as: ""
---

# 阶段路线图（演进中）

## 背景

选型原则：不为做网站而选功能，为学知识点而选功能。本图是策划期对 Phase 划分的**草案**——各段落在开工时毕业为正式 spec（Phase 0 已毕业为 SPEC-0001），随认知演进自由改写。

## 提议（当前草案）

| Phase | 主题 | 功能 | 学习目标 |
| --- | --- | --- | --- |
| 0 | 骨架 | monorepo 脚手架、CI/CD、Docker、docs 体系、配置项基线 | 工程化地基（已毕业：SPEC-0001） |
| 1 | 内容核心 | markdown 内容管线、主题/暗色/SEO、首个业务 handler + 契约消费、首次部署 | SSG、Vue 组件树、composables、Go 模块结构与 error wrap |
| 2 | 交互层 | 评论（CRUD 全链路）、浏览量点赞、全站搜索、表单限流、RSS/sitemap | ent、事务边界、防注入、Redis、中间件链、后台任务、migrations |
| 3 | 用户与后台 | 认证（JWT + HttpOnly + RBAC）、admin 后台、图片上传、结构化日志 + metrics | 认证协议、授权中间件、文件流/MIME、slog/Prometheus |
| 4 | 语言特性深水区 | 开发统计聚合器、可选 RAG 问答 | goroutine pool、channel pipeline、sync、generics、SSE 流式 |
| Meta | 项目展示自身 | 开发时间线页、架构自展示页、学习路线图页 | 构建期按 frontmatter 提取索引（管线 Phase 1 定） |

## 毕业条件

某 Phase 开工前，其段落改写为正式 SPEC-N（走 ready 评审）；本图相应段落标注毕业去向（adopted-as 语义按段落适用）。Phase 顺序与内容均可随需求工程（网站内容构思）调整。

> 毕业制例外声明：proposals 毕业制默认**整篇**跃迁，本文件例外——按 Phase 段落毕业（去向在表内标注）；整篇状态长期保持 draft，仅当全部 Phase 毕业后作为归档进入 adopted，或整体方案被推翻时进入 rejected。

## 演进记录

- 2026-11-13 由策划期路线图（ED1 §7）蒸馏入库为 draft；同日自 t4 提前至 first commit（README 指路）
