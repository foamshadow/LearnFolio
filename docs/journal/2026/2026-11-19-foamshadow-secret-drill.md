---
title: "敏感数据桌面演练：retract 首次生产实弹与四条发现"
date: 2026-11-19
author: foamshadow
tags: [se-arch, tool-git, tool-ci, incident]
related: [ADR-0010, docs/proposals/merge-integrity.md, docs/guides/merge.md, "docs/journal/2026/2026-11-18-foamshadow-ruleset-migration.md"]
---

# 敏感数据桌面演练：retract 首次生产实弹与四条发现

> agent 执行、人全程在场授权（四项预授权：auto-commit / auto-push / drill PR 手动合并 /
> retract `--yes`）。本篇记录 2026-11-19 的敏感数据桌面演练——merge-integrity proposal
> 毕业条件的最后一项 agent 可执行项，也是 `scripts/retract.sh` 的**首次生产实弹**
> （此前仅 production dry-run，见 ruleset 迁移 journal）。

## 时间线（UTC）

| 时刻 | 事件 |
| --- | --- |
| 05:50 | 切 `fix/infra-secret-drill`，写演练载荷 `infra/drill-fake-credential.txt`（自述假密钥 `sk-drill-0000…`） |
| 05:54 | 提交 `6b731e9`（签名）+ push + PR #53 |
| 05:55 | CI title job **拦下**：标题冒号半角（发现 2） |
| 05:57 | rerun 仍败——同一半角字节再次生成（发现 2 实锤） |
| 05:59 | python 显式 `：` 构造经 API 改标题；`edited` 事件触发新 run → success |
| 06:01:06 | **T0：合并 #53（`gh pr merge --merge`）**，bad = `80a691f` 落 dev head |
| 06:02:12 | `retract.sh --bad 80a691f --yes`：备份 → 快照 → 禁 RS-1 → reset + lease force-push → 恢复 RS-1 |
| 06:03:06 | retract 完成（全程 54s，退出码 0） |
| 06:04+ | 五项独立验证全绿；备份分支删除（真实事件口径：备份 ref 属清理对象） |

## retract.sh 生产实弹读数

- preflight 三条件实测：bad 在 dev 头部 ✓、age 64s ≤ 24h ✓、除 dev/backup 外无分支含 bad ✓
- RS-2 在 force-push 时显示 `Bypassed rule violations … Cannot force-push`——owner bypass
  按设计生效，非保护失效
- RS-1（id 27526062）禁用 → 恢复后 `enforcement: active` 复核 ✓；trap 未触发（无异常路径）
- force-with-lease 锚定 bad SHA；clone reset 指引：`git fetch origin && git reset --hard origin/dev`
- re-land（P2b 后半）**有意跳过**：载荷 100% 为密钥，无可重落内容——P2b 文本的
  「同一内容」预设的是内容错误，敏感场景无此半步（已对齐 proposal「敏感数据」行：
  轮换 + rewrite + 平台清理，revert 不在流程）

## 发现项（按严重度）

1. **签名链依赖桌面 agent**：commit signing 走 1Password SSH agent，解锁前**任何提交
   都无法生成**（含应急期间的响应记录）。真实事件的 runbook 应含「确认签名链可用」前置项。
2. **agent 生成半角冒号两次**：合并 message 的全角冒号要求在收口 journal 强调过，实际
   执行仍连续两次生成 `:`（半角）——不是打字问题，是文本生成的字节级缺陷；「重打一遍」
   不可靠，**程序化构造（`：`）+ API 原子提交**才可靠。CI title job 是真正的兜底层，
   两层防线（生成自觉 + CI 拦截）按设计工作，但生成侧自觉不可依赖。
3. **备份 ref 持有「密钥」**：retract 的备份分支（`backup/dev-80a691f-…`）含假钥。真实
   事件中备份 ref 必须纳入平台清理阶段一并清除，否则「不可留在任何历史」不成立。
   本演练结束即删（local + origin）。
4. **平台侧提交仍可达**：force-push 后 `80a691f` 仍可经 SHA 直达（API 实测）。真实事件
   需走 GitHub support / 官方 remove-sensitive-data 流程——proposal「平台清理」列无
   仓库内工具可替代，runbook 应直接链接 GitHub 官方指引。PR #53 页面将长期显示 MERGED
   且指向已不可达的合并提交，真实事件应在 PR 评论标注「已撤回」（前例 #34→#36 口径）。

## revert 不在流程（确认项）

proposal 修复阶梯「敏感数据」行原文：**不可留在任何历史 → 独立事件响应：轮换 + rewrite +
平台清理；revert 不够**。本演练确认其机理：revert 产生新提交但旧提交仍在历史，且 revert
diff 本身会再次完整暴露密钥明文。桌面轮换记录：若为真实凭据，T0 后第一动作是在服务商
控制台作废/轮换（本次假钥无服务商侧，动作以本行代替）。

## 对毕业账面与 clone 通知的影响

- 敏感数据桌面演练：**完成**（proposal 毕业条件逐项对齐：轮换 ✓ rewrite ✓ 验证 ✓
  revert 不在流程 ✓）
- clone 通知闭项物料：retract 输出的 reset 指引可直接作为团队渠道模板；闭项仍待渠道
  发生（团队首次真实交互时顺手完成）
- 毕业仅余：clone 通知闭项 → 毕业 PR（3/3 + 0 违例 + 撤回演练 + 本演练）顺路结账

## 附：演练产物清单

| 产物 | 状态 |
| --- | --- |
| PR #53（载荷） | MERGED，其合并提交已撤出 dev 第一父链 |
| bad `80a691f` / 载荷 `6b731e9` | dev 不可达；平台侧 SHA 仍可达（发现 4） |
| 备份 `backup/dev-80a691f-20261119140212` | 演练后已删（local + origin） |
| 快照 `.tools/retract/20261119T140231` | 本地留存 |
| dev 拓扑 | 还原至 `5b6185b`，push CI 绿（run 44469325670） |
