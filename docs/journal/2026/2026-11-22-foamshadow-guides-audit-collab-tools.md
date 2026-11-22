---
title: "guides 全量对账首跑：8 处漂移的类型学与协作工具安装缺口"
date: 2026-11-22
author: foamshadow
tags: [se-review, tool-git, tool-herdr]
related: [ADR-0010, ADR-0012, ADR-0013, docs/proposals/merge-integrity.md, docs/proposals/herdr-collaboration.md]
---

# guides 全量对账首跑：漂移类型与安装缺口

## 事件

用户点名两件事：检查 guides 的完整程度与同步程度；补 herdr 安装部分。8 篇 guide
（8 篇本体 1831 行；含 _template.md 共 9 文件 1869 行）逐篇对照实现真源（AGENTS / ADR / ci.yml / scripts / PR 模板 / 配置
文件），同批补 onboarding 协作工具安装节。这是 ADR-0013 落地后清单 1 第 2 项
（复述面）的首次**全量**执行——此前各 PR 只做增量 grep（"本 PR 改变的事实"），
本次是"存量 guides vs 真源"的整体对账。

## 漂移清单与类型学

8 处漂移全部是同一根因的变体：**下游文档复述了"某个东西的状态"，上游毕业 /
演进后没人回头改复述句**——#62 的 C4 滞后不是孤例，是模式在 guides 全文的分布。
按上游事件分三类：

1. **proposal 毕业滞后**（merge.md / review.md，4 处）：merge-integrity 已
   adopted（ADR-0012 落地，2026-11-19），但 merge.md 开篇仍称 "status: review"
   + "已决/未决"框架——同一篇的毕业清单段落自己都逐条划完了，唯独开篇没跟上；
   review.md 延伸节同样称"评审中"；两篇 frontmatter `related` 均缺 ADR-0012，
   merge.md 现状速览与延伸决策链也缺。教训：**proposal 毕业时，指针化正文之外
   还要全仓库 grep 对它状态的复述句**——毕业批（#56）当时的清单 1 只核了"新增
   的复述"，没核"存量复述"。
2. **规则演进滞后**（git-workflow / doc-system / ci-gate，3 处）：git-workflow
   称 PR 模板"四节"（#64 已加写回自查子节）；doc-system 称"九篇 ADR"（现 13
   篇）且延伸行仍写 docs "单提交"（ADR-0010 已撤销——同仓库 git-workflow 自己
   都是新口径）；ci-gate 称"四个脚本"（check-catalog.mjs 是第五件，同文 C4 段
   自己引用了它）。
3. **登记滞后**（agent-collaboration，1 处软漂移）：键表举例缺 `Pi` / `glm-5.3`
   （ADR-0011 登记后未回填举例；有"以表为准"兜底，未误导，但举例过时）。

**无一处在真源层**——AGENTS / ADR / 模板 / 配置全部自洽，漂移全部集中在
guides 教学层。真源层级（AGENTS > ADR > guides）再次自证：过期只发生在离真源
最远的一层，这也再次支持"机器对账以 guides 为主要扫描对象"的演进口判断。

## 版本事实核对（全对）

onboarding 七层真源表逐项对实现：`.nvmrc 24.20.0` / `pnpm@12.19.0` /
`go 1.27.4` / `golangci v2.15.0` / `postgres:17.12` 全部吻合；task 3.54（CI
固定）一致。git-workflow 历史美观总纲（#62）、ci-gate C4 段（#62）、doc-system
设计七（#64）、review.md 快照顶格（#66）均已在位——近期写回窗口的同步动作有效。

## 补齐：onboarding 协作工具节

- **gh 安装节**：主线上手链原本止于 `task ci`，而 `task merge` / `task retract`
  / 评审评论全依赖 gh——新人断链点。补第 11 步（必装：平台矩阵 + `gh auth
  login` + 验证）。
- **herdr 安装节**（用户点名）：安装渠道从二进制 strings 反推核实（不猜 URL）
  ——Home = herdr.dev；四渠道 brew / nix / mise / 官网直装；仅直装支持
  `herdr update` 自更新与 `stable|preview` 双通道（渠道安装时自更新拒绝执行并
  提示对应升级命令；本机即直装形态，0.9.5）。写入 guide 的只有安装骨架 + 失防
  条款（"用法以 `herdr --help` / `herdr --skill` 为准"）——herdr 迭代快，
  guide 不复述命令全集，避免制造下一批 C4 型漂移。

## 审查记录

| 轮 | 版本 | 审查者 | 层级 | 结果 |
| --- | --- | --- | --- | --- |
| 1 | add7c67 | Pi:glm-5.3 | PR 级 | PASS（0B+2N：N1 ci-gate 消费面表述不精确、N2 journal 行数口径——均属本轮 diff，同批修正后复审） |
