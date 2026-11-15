---
title: "t5 施工日：配色从未真正渲染过的发现，与一次 .gitattributes 覆盖事故"
date: 2026-11-15
author: foamshadow
tags: [se-arch, tool-ide, se-review]
related: [SPEC-0001]
---

# t5 施工：scheme 覆盖发现与 .gitattributes 覆盖事故

> agent 起草、人审定（作者键 = 审定者）。t5（.vscode 基线）按 2026-11-15 提前执行决议施工，
> PR #20。本文记施工中的两个事件与三个决策。

## 事件

### 1. AGENTS 的标记配色从未真正渲染过

`.vscode/settings.json` 基线写入后实机验收发现：NOE 渲染成橙、Tips 渲染成红，与 AGENTS
「TODO 注释规范」表（蓝/灰蓝）不符。排查链条：色值无误 → 扩展无错位 → 读
better-todo-tree 的 package.json 才定位根因——扩展的 `useColourScheme` 默认 `true`，
按 tags 列表**顺序轮转**分配红橙黄绿蓝靛紫，优先级高于 `customHighlight`；合并后 tags
序列里 NOE 排第 2 位（→orange）、Tips 排第 8 位轮转回 red，与截图逐一吻合。

**值得记账的是**：这不是基线引入的 bug——用户个人全局配置同样没关该开关，意味着
AGENTS 表定下的配色在所有项目里从未按设定值渲染过，只是没人盯着验收。"写了配置"
和"配置按预期生效"之间隔着一层默认值，不实测就发现不了。

**处置**：workspace 层随 PR #20 写入 `useColourScheme: false`；user 层在本机同批修正
（不入库）。实测恢复 AGENTS 表配色。教训沉淀：配置基线的验收必须是**渲染结果比对**，
不是文件写入确认。

### 2. .gitattributes 覆盖事故（未遂）

构造 t5 交付物时，按"跨平台行尾统一"写了一份 `.gitattributes` 直接 Write——**没有先查
仓库根的既有文件**。原文件 first commit 即存在（LF 强制 + 更全的二进制清单 + SVG 文本化
+ 契约生成物 linguist-generated 标记），被覆盖后靠未提交态的 `git diff` 行数异常（M 而非
新增）当场发现，`git checkout origin/dev` 完整恢复，无损失。

连带发现 `.editorconfig` 同样 first commit 即存在（UTF-8 / LF / Go tab / web 2 空格分段），
t5 的"缩进规则推迟 t1/t2"讨论随之作废——文件已在，缺的只是 VSCode 侧消费
（editorconfig 扩展推荐 + files.eol 兜底），变更记录同步修正。

**教训**：给已有仓库写"新文件"前先 `git ls-tree` 扫根目录——first commit 的地基件
（.gitattributes / .editorconfig / .github 模板）不在 docs/ 与 .github/ 的常规检索路径里，
只看文档体系会漏。

## 决策

- **WARN 纳入团队基线**：原个人层 `WAR` 重命名为团队标记 `WARN`（警告/风险，琥珀黄 `#FFC107`，warning 图标 + 加粗）；AGENTS 表、项目 `.vscode/settings.json`、全局规则与 user settings 同步——警告不再与 BUG / FIXME 的红色冲突，个人层不再保留 WAR。
- **推荐插件从克制转向开箱即用**：判定由"有仓库证据才推荐"放宽为"不预设成员有自我
  配置"（foamshadow 决策），加入 alabaster / color-highlight / vscode-icons / errorlens
  等通用体验件；errorlens 为顺原则补入（新人不必先学 PROBLEMS 面板）。
- **`.vscode/settings.json` 禁写平台专属键**：该文件走 git 分发而非 Settings Sync，
  写 terminal/path 类键 = 把全局环境刚修掉的 Win→Linux 污染模式重新引进仓库。

## 落点

- 代码：PR #20（feat/spec-0001-t5-vscode-baseline → dev，两个提交：基线 + 文档写回）
- SPEC-0001 变更记录：t5 落地对齐行（同 PR 追加）
- AGENTS「TODO 注释规范」注：预告转落地事实（同 PR）
