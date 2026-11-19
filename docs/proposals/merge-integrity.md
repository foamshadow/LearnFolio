---
title: "合并完整性与历史修复：快照合并、撤回窗口与 PR 编号守恒"
author: foamshadow
date: 2026-11-16
status: adopted
tags: [se-arch, tool-git, tool-ci]
related: [ADR-0004, ADR-0005, ADR-0007, ADR-0009, ADR-0010, ADR-0011, ADR-0012, SPEC-0001]
adopted-as: "AGENTS「分支与版本」合并与同步子节（含「远端重写对齐」，ADR-0012）+ docs/guides/merge.md + scripts/merge.sh、scripts/retract.sh（task merge / task retract）+ rulesets RS-1/2/3"
---

# 合并完整性与历史修复

> 已毕业（2026-11-19）：规则真源 = `AGENTS.md`「分支与版本」合并与同步子节（含「远端重写对齐」，ADR-0012）；教学与操作 = `docs/guides/merge.md`；实现 = `scripts/merge.sh`、`scripts/retract.sh`（`task merge` / `task retract`）；平台强制 = rulesets RS-1/2/3（迁移记录见 journal `2026-11-18-foamshadow-ruleset-migration.md`）。本文正文已替换为指针，防双真源；演进过程与被否方案保留在下。

## 演进记录

- 2026-11-16 由 #22 事故讨论起草：5 个 PR 号、revert/redo、force reset + re-land；确立“先分类、元数据不 revert、快照合并、撤回窗口”四个结论。
- 2026-11-16 第一轮决策：PASS 模板归 review-protocol；软约束（不引入 review-gate/merge bot）；人类授权后 agent 执行合并；docs/code 分路径；收口后仍允许 rewrite（当时需同步 AGENTS 冻结线，11-17 已完成）；PASS 模板加 `body-sha256`；`required_approving_review_count` 保持 0；评论靠共识管理，不镜像。
- 2026-11-16 第二轮决策：ADR-0010 方向（dev/main/tag message-only；内容不允许；journal 留痕）；docs 单提交拟撤销；review-protocol 计划先毕业。后续 11-17 已落地（review #28、ADR #29）。
- 2026-11-17 事实对齐：review-protocol #28 毕业（PASS 规则迁 AGENTS/guide）；C6 #27 落地；ADR-0010 #29 accepted（ADR-0005 `deprecated`、docs 单提交撤销）；scripts 未实现、`(#N)` 未实测。
- 2026-11-17 开放问题 3 实测结案（#33）：`docs/guides/merge.md` 首版落地，按快照合并手动六步合并——PASS `target` / `body-sha256` 校验通过；落地 subject 的手写 `(#33)` **逐字落地、无重复追加**；落地 body 与快照逐字节一致；dev push CI 一次全绿（0 补救提交、0 额外号）。顺带证伪 proposal §1 的 code 命令：显式 `--subject "<标题>"` 因平台不追加会丢 `(#N)`，merge.sh 定稿时按 guide 的默认标题路径反向统一；同批修正两处过时记账（ADR-0009 部分取代已由 ADR-0011 闭合、`(#N)` 移出未实测清单）。
- 2026-11-17 P2b 首次实弹（#34 → #36）：#34 按旧 §1 命令显式 `--subject` 合并，subject 缺 ` (#34)`；备份 `b42eee2`、dev reset 至 `94580a8`、旧 PR 标 superseded、#36 以默认标题路径重落 `d071f24`；保护开关与 dev push CI 均核验。§1 的 code 命令已在本条后同步修正。
- 2026-11-17 t1 收尾对齐：同文“待建”改已落地（#33）；未实现行 / 开放问题 2 / 撤回演练补 P2b 事实；开放问题 5 增实战口径。
- 2026-11-18 ruleset 迁移与 `retract.sh` 落地（#42）：classic protection 删除；RS-1/2/3 三规则集不对称模型；`scripts/retract.sh` + `task retract` 落地；Q2/Q4/Q5 结案，Q1 保留开放。PUT 最小体 merge 语义、恢复 payload 形状坑、dry-run 局限、B1 删除保护拆分见 journal `2026-11-18-foamshadow-ruleset-migration.md`。
- 2026-11-18 快照合并脚本落地（PR #50）：`scripts/merge.sh` + `task merge`（PASS target/hash、docs squash 快照 body、code `--no-ff`、合并后落地核验；`task test:merge` fixture）；pilot 自此可开始。
- 2026-11-18 merge.sh 首次实弹（PR #50，pilot code 1/3）：`task merge` 自合并；PASS target/body hash 复核、合并后 subject/body/第二父核验通过，N1 路径实测。
- 2026-11-18 Q1 定稿（三条件撤回窗口，`fix/infra-retract-window-guard`）：bad 在 dev 头部 + 无分支以 bad 为祖先 + age ≤ 24h；retract preflight 补 `for-each-ref --contains` 守卫（`dev` / `origin/dev` / `backup/*` 白名单，其余含 bad 的 ref 即拦，含 main；同机可见暴露全覆盖，异机 clone 由时间兜底）；同批补 ADR-0007 D5 理由（ADR-0010 撤销其机制前提，规则不变、理由改为真源传播成本）。
- 2026-11-19 pilot 2/3（docs: PR #51）：`task merge` docs 路径首次实弹，squash 落 dev `dce0ab0`；PASS 快照 body-sha256（`a5eb7c37`）与落地正文密码学比对一致，“0 次 PASS 后描述变更导致落地正文不一致”违例保持 0；N1 docs 路径实测闭合。
- 2026-11-19 pilot 3/3（docs: PR #52）：翻牌 PR 以 `task merge` docs 路径自合并（合并动作即第三票），squash 落 dev `5b6185b`；PASS 快照 body-sha256（`8f4ddb9d`）预检通过，落地正文与描述内容一致（尾换行归一化）。
- 2026-11-19 **毕业**（本 PR）：pilot 3/3（#50 code / #51 #52 docs，全程 `task merge`，0 次「PASS 后描述变更」，`(#N)` 四度实证：#33/#50/#51/#52）；撤回演练闭项（retract 生产首弹 54s + clone 通知机制产品化，ADR-0012 三件套：retract 输出 / backup 提示 commit（实现随 fix 任务）/ AGENTS「远端重写对齐」条款；未发一次性 issue 为所有者裁定，公开仓库未知 clone 不可枚举属通知义务客观上限，残余风险由所有者接受）；敏感数据桌面演练完成（retract 生产首弹、四条发现，journal `2026-11-19-foamshadow-secret-drill.md`）；status → adopted，正文替换为指针。手动流程保留为脚本不可用时的兜底。

## 被否方案（毕业时随文保留）

- **revert 修元数据**：+1 提交、+1 号，坏 message 还在；#22 的 5 个号就是这样来的。
- **删分支 / 删 dev 重建**：不省号；删 dev 要关保护、可能影响 open PR；与 force update 等价但副作用更多。
- **auto-merge / merge queue 单独用**：仍用实时描述；queue 只验树，不验提交正文。
