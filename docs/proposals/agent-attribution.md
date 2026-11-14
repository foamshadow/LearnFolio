---
title: "agent 署名：提交级来源标签（opt-out）"
author: foamshadow
date: 2026-11-14
status: adopted
tags: [se-arch, tool-git]
related: [ADR-0003, ADR-0004]
adopted-as: "ADR-0004 / AGENTS 提交纪律节"
---

# agent 署名（proposal）

> **已毕业（2026-11-14）**：规则真源 = `AGENTS.md`"提交纪律 / agent 署名"节；决策理由与被否方案 =
> `ADR-0004`。本文正文已替换为指针，防止双真源；演进过程保留在下。

## 演进记录

- 2026-11-14 起草。起因：建仓首次提交缺 agent 署名，触发"撤回重做"（旧提交由重建仓库根替换，不留旧史）。
- 2026-11-14 评审定稿方向：改 opt-out；加钩子审查层；文档层不做；首提交以重建根并入本文，不设演练式毕业条件。
- 2026-11-14 同日讨论落地：重写 / 多参与方四情形语义写入（trailer 跟内容不跟操作）；开发 / 审核 agent 角色区分不做（翻转条件 = 另起 `Reviewed-by` 键）；键表升两列——model 键 = 官方 API id 的 kebab-case（含官方快照后缀，照抄不自行附加日期）；身份来源先定环境注入。
- 2026-11-14 二次转向：**环境变量注入被否**——多 harness × 多 model 现实下 shell 全局变量跨工具链共享、无法跟踪当前会话，必错配且配置负担不可扩展；身份来源改 **agent 自述 + 配置查证**（信源优先级：harness model 配置 > 系统提示 id > 自省命令；精确不到快照粒度即问人）；钩子只 fail-closed 校验、不代填；model 键粒度目标 = 详细版本（快照 id 照抄，如 DeepSeek-V4.1-Flash-1017）。
- 2026-11-14 毕业：规则落 AGENTS 提交纪律节（含 harness / model 键表），决策立 ADR-0004；本文 status → adopted，正文改为指针。
