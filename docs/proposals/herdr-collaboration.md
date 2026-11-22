---
title: "herdr 多 agent 协作：评审编排约定"
author: foamshadow
date: 2026-11-22
status: draft
tags: [se-arch, tool-herdr]
related: [docs/proposals/task-lifecycle-gates.md, docs/proposals/agent-confirmation-chain.md]
adopted-as: ""
---

# herdr 多 agent 协作：评审编排约定（proposal）

<!-- docs/proposals/：想法的第一落点，不占编号（毕业时才分配 SPEC-N/ADR-N）。
     未毕业随便改（git 历史即过程记录）；毕业后守正式层纪律。
     状态词表：idea | draft | review | adopted | rejected（跃迁条件见 docs/README.md） -->

## 背景

本机 herdr 已实际承载 LearnFolio 的多 runtime agent（2026-11-22 实测：LearnFolio
workspace 5 个 tab——3 个 idle pi + 2 个 working claude），评审环节是它的最主要场景，
但编排层无约定，已有实践各自为战：

- **评审者无标记**：tab label（pi / pi2 / pi3）只是人的记号，agent 无名字，作者无法
  程序化寻址评审者。曾实践 rename（`dsh` / `cc-pilot`，2026-11-20）但随 pane 关闭消失，
  约定未固化。
- **互传无协议**：评审请求载荷、结论回传通道、等待策略各次实践不一致（PR 评论与会话
  直达混用，何时用哪个无判据）。
- **生命周期无管理**：评审者会话跨任务累积上下文，无释放与轮换机制。

挂点已存在：task-lifecycle-gates（proposals/task-lifecycle-gates.md）任务启动三项配置
已含 **review 单配置（无 / 人工 / 外部 agent）**——review=外部 agent 选中后缺执行层：
怎么找评审者、怎么互传、怎么收尾。本 proposal 补这一层。

设计原则：协议层自持（选择规则 / 互传格式 / 生命周期），**通道细节引用 herdr skill
不重复**；herdr 运行态标记（agent 名字 / tab label）接受机器本地易失，持久账本不另建
——PR 评审评论（`Reviewer:` 角色行 + target sha + body-sha256）与 commit trailer
（`Reviewed-by`）已是真源，两层不打架。

## 提议

### 1. 触发与检测时机

- HERDR_ENV 检测**不是任务启动的无条件动作**：先过 tlg 的 review 选项环节
  （无 / 人工 / 外部 agent），**仅 review=外部 agent 选中后**执行
  `test "${HERDR_ENV:-}" = 1`，再查评审者。不静默检测。
- 检测失败（不在 herdr 中）：报告人类——退回人工评审，或建议移入 herdr 再跑；
  不静默降级、不代选人工。

### 2. 评审者标记（命名即登记）

- **席位命名**：空闲评审者 agent 名 = `rv` + 席位序号（`rv` / `rv2` / `rv3`…）。
  herdr 名字必须唯一（正则 `[a-z][a-z0-9_-]{0,31}`），故带序号。
- **指派态**：rename 为 `rv<N>-<任务简写>`（如 `rv2-2t3` = SPEC-0002-t3 的评审者），
  tab label 同步 `review:<任务简写>`。名字即指派记录，`herdr agent list` 一眼可查
  谁在服务哪个任务。
- **释放态**：任务收尾 rename 回席位名，tab label 回 `review`——指派标记清除，
  rv 标识保留。
- **可指派判据**（`herdr agent list` 三条同时满足）：名字 `rv` 前缀 + 名字无任务
  后缀 + `agent_status: idle`。
- 易失性接受：pane 关闭 / herdr 重启后标记消失是预期行为；跨会话审计走 PR 账本，
  不在 herdr 侧补持久化。

### 3. 选择规则

- **独立性**（AGENTS.md 评审协议的 herdr 侧落实）：排除与作者同 harness 的 pane
  ——协议已规定 reviewer 不得与同一 commit 的 `Assisted-by` 参与者同源；claude
  作者的对手盘默认是 pi 席位。
- **独占**：活跃期一个评审者 pane 只服务一个任务。指派名带任务号，同名即冲突拒绝
  ——「不跨任务复用活跃评审者」从"不建议"升格为硬规则。
- **harness/model 偏好表**（变更走 PR）：

| 场景 | 默认 | opt-in |
| --- | --- | --- |
| commit 级与 PR 级评审 | `Pi:glm-5.3` | `DSH:deepseek-v4.1-flash-1017`（任务启动时手动指定才用——API 按量付费） |
| 作者为 Pi 的任务 | `ClaudeCode:glm-5.3-flash`（同 GLM plan 额度；异 harness，满足互审约束） | 同上 |

- **兜底**：独立性排除后偏好表无合规默认（作者为 ClaudeCode 且 Pi 席位全忙按
  §5 新建即可；作者为未登记 harness 等未来组合）→ **停：升级人类指定**，不静默
  降级、不代选。

### 4. 互传协议

通道细节（`agent prompt` / `agent read` / `--wait` 语义等）引用 herdr skill，此处
只定协议层：

- **载荷**：评审请求只含锚点（任务号、评审层级、对象描述）+ **回传地址**（作者
  pane 的 agent 名——评审者结论与提醒的投递目标；作者 pane 按既有习惯命名即可，
  唯一性由 herdr 保证）+ 输出协议要求（评审协议
  状态机文本格式；**快照行顶格要求随载荷显式传递**——协议只约束内容，机器解析
  约束（merge.sh `startswith` 逐行提取，行首不得带列表标记）必须在载荷里写明，
  不依赖评审者排版习惯）；**评审对象不走会话传**，评审者自取——commit 级读共享工作树
  `git diff --staged`（作者 stage 后发起），PR 级 `gh pr diff N` + PR 描述。
- **commit 级 = 会话直达**：评审结论以协议文本 `agent prompt <作者名>` 直发作者会话；
  持久账本 = commit trailer `Reviewed-by`（评审协议已有），直达内容不做第二真源。
- **PR 级 = 先评论后会话提醒**：评审者先发 PR 评论（`REVIEW: BLOCKED/PASS` +
  target sha + body-sha256），再直发作者一条短提醒（如
  `PR #N 收到评审：REVIEW: BLOCKED（4B+2N），请查收`）；作者 `gh pr view --comments`
  拉全文。持久账本 = PR 评论。
- **超长内容兜底**：落临时文件、报路径（herdr skill 既有 fallback）。
- **等待策略**：发出用 `agent prompt --wait`；长任务不等轮次间隙的瞬态 idle
  （`--until idle` 会被骗过，2026-11-20 实测）——可靠完成信号 = 评审者主动回传。
- **DSH 降级通道**：dsh-tui 无集成签名，`agent prompt` 不可用——走
  `pane send-text` + `send-keys enter`（两步分开发），标记命名照常（rename 可用）。

### 5. 生命周期（池化轮换）

```
空闲池 rv / rv2 / rv3 …（idle）
   │ 被指派：rename rv2-2t3 + tab label review:2t3
   ▼
服务任务期间不 compact（评审者上下文连续性服务于同一任务的多次往返）
   │ 例外：上下文过大拖慢评审（≈190KB 响应变慢教训）可提前 compact
   │ 任务收尾：prompt "/compact" + rename 回席位名 + label 回 review
   ▼
回到空闲池；compact 后会话默认给下一任务复用（省 pi 冷启动——每次冷启动读整个项目）
质量敏感场景 opt-in：不复用，直接新会话/新 pane（作者判断或人类指定）
```

- **无空闲评审者 → 新建**：新建的 kind/model 取偏好表中该任务适用的行（独立性
  排除后"新建什么"由此回答——如作者为 Pi → 新建 claude 席位；默认场景 → pi）。
  流程：`tab create`（label `review`）+ `agent start rv<N> --kind <kind> -- <model
  参数>`（启动参数待实测）→ rename → 首 prompt 自含任务
  背景（评审请求本就自含上下文，评审者不怕新会话）。
- 手动指定 DSH 且无在场 DSH pane：`tab create` + pane 内起 dsh-tui（无 agent 集成，
  不走 `agent start`），互传按降级通道。

### 6. AGENTS.md 提醒行（随本 PR 落）

评审协议子节追加一条：review=外部 agent 选中后才检测 herdr；在 herdr 中按
proposals/herdr-collaboration.md 编排（席位寻址、互传分级、池化生命周期）；
不在则退回人工评审。毕业时展开为完整条款、本 proposal 正文替换为指针。

## 毕业条件

- 实弹演练覆盖三类路径各 ≥1 次：① commit 级直达往返；② PR 级评论 + 提醒往返；
  ③ 无空闲新建 pane。
- ①③ 可与 task-lifecycle-gates 演练矩阵的 review=agent 项共用演练，不另起炉灶。
- 复盘（journal）后毕业：AGENTS.md 评审协议子节扩展为完整编排条款 + 偏好表登记；
  本 proposal 正文替换为指针。
- 衔接预留：agent-confirmation-chain 的 L1「上层 agent 确认」可复用本协议的席位
  寻址与互传分级；其毕业时在本演进记录追加衔接方式，不预支设计。

## 演进记录

- 2026-11-22 起草（idea → draft 同日于对话成形）：初版即含五项定稿——检测时机
  后置至 review 选项之后、席位命名即登记、互传分级（commit 直达 / PR 评论+提醒）、
  池化生命周期（收尾 compact 回池 + 复用为默认）、偏好表（Pi:glm-5.3 全层级默认、
  DSH 手动指定 opt-in）。
- 2026-11-22 round 1 评审吸收（PR #65，Pi:glm-5.3 经本编排首演，0B+4N+1Q，
  处置①修后 round 2 重审）：N1 related 补 `docs/` 前缀；N3 兜底落 §3/§5（偏好表
  补"作者为 Pi"行、新建 kind 按偏好表适用行、无合规候选升级人类指定）；N2/N4/Q1
  落本任务 journal（版本列、复述面判定、审查记录口径）。
