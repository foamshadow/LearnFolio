---
title: "AGENTS.md 信息分层：What/Why/How 分流与加载机制"
author: foamshadow
date: 2026-11-22
status: draft
tags: [se-arch, docs]
related: [ADR-0007, ADR-0013, docs/proposals/task-lifecycle-gates.md, docs/proposals/agent-confirmation-chain.md]
adopted-as: ""
---

# AGENTS.md 信息分层：What/Why/How 分流与加载机制（proposal）

## 背景

### 实证：规则在上下文里，但没有被触发

2026-11-22，Pi（glm-5.4）在 LearnFolio 执行「登记 model 键 glm-5.4」任务（PR #68）。AGENTS.md 第 152 行写着：

> 任务启动时一次性申请 auto-commit / auto-push 两项独立授权（任务级生效、可随时撤销）

agent 读到了、也理解了这条规则，实际行为却是：一路推进到"要提交了"才回头申请授权。结果等价，流程违规——规则要求**先授权再动手**，实际做成了**动手到门口再要票**。

复盘出三层原因，由浅入深：

1. **归类错误**：该行位于「破坏性操作」小节，夹在两条"commit 须告知 / push 须许可"**约束**之间。agent 按小节主题归类——"破坏性操作"→"临动手才查"。但它的语义是**流程起点**。位置与语义错配。
2. **长会话衰减**：该会话前半段全是与仓库无关的工作（配置 pi 扩展、herdr 集成）。仓库任务从中段开始时，agent 的注意力焦点在"技术细节对不对"（正则、分支名、trailer 格式），启动前置项被挤出工作焦点。
3. **结构性诱因**：AGENTS.md 已达 400 行 / 34KB，两种职责混装——既是规范真源，又是机理教学。规则被埋在教学里。

### 量化：两种职责混装

| 节 | 行 / 字节 | 实际触发时机 |
| --- | --- | --- |
| 提交纪律 | 101 / 5.7KB | 仅 commit / push / PR 时 |
| 分支与版本 | 84 / 4.5KB | 仅建分支 / 合并 / 打 tag 时 |
| 多工作树 | 29 / 1.6KB | 仅开新 worktree 时 |
| 验证命令 | 25 / 1.3KB | 仅自证完成时 |
| 写回清单 | 21 / 825B | 仅 PR 窗口 |
| 其余十节 | 140 / 约 20KB 中约 12KB | 混合 |

两节吃掉 30%；真正"每条消息都要"的内容（仓库身份、工具链边界、Go 分层、契约）只有约 1.5KB。

更关键的事实：`docs/guides/` 里**已有** `git-workflow.md`（306 行）、`review.md`（194 行）、`worktree.md`（140 行）、`merge.md`（223 行）等展开版，而 AGENTS.md 里除文档体系节对 `guides/` **目录**的一句定义外，**没有任何一行指向具体 guide**。两层各写各的。

### 约束：加载机制决定分层上限

对 Pi 1.5.2 源码（`core/resource-loader.js`）核实：

- 上下文文件加载链 = agent 目录 → cwd → **逐级父目录**（`currentDir = dirname(currentDir)`，只向上）
- **不存在** `@file` 引用机制（Claude Code 的私有扩展，Pi 无等价物）
- 子目录 `AGENTS.md` 只在从该目录启动时加载；会话中途 `cd` 不触发重载
- 唯一原生的按需加载机制是 **skill**：启动时只把 name + description 放进系统提示，正文由 agent 在触发点 `read`

推论：**放进 `docs/` 的任何内容都不会自动进上下文**。What 类规则若落 docs/，等于变成"靠 agent 想起来"——正是本次事故的模式。

## 提议

### 1. 判据：按内容性质分流，而非按小节搬家

AGENTS.md 里混装了三种性质的内容，对应三种问题：

| 性质 | 回答的问题 | 例（取自「提交纪律」） | 载体 |
| --- | --- | --- | --- |
| **What** | 现行规则是什么 | 「一个提交 = 一个完整逻辑单元」 | 见 §2 分流 |
| **Why** | 为什么；被否的方案 | 「整理不是 squash，禁止整体压成一个提交」（ADR-0007） | `docs/adr/` |
| **How** | 机理与操作步骤 | 「rebase 前先 `git branch backup/<branch>-<时间戳>`」 | skill（与 What 同住） |

「提交纪律」101 行是三者的纠缠体——这才是"读起来信息太多"的根因，不只是体积。

### 2. What 的分流判据：这条规则在什么时候必须在场

| What 的类型 | 在场要求 | 违反的后果 | 落点 | 体量预估 |
| --- | --- | --- | --- | --- |
| 不可让渡 | 每条消息 | 产物错误 | AGENTS.md | 约 6–7KB |
| 阶段性 | 该流程阶段 | 流程错误 | skill（What + How） | 4 个 |
| 区域性 | 该目录 | 局部错误 | 嵌套 AGENTS.md | 推迟，见 §5 |

**不可让渡**（留 AGENTS.md）：仓库身份、工具链边界、Go 分层、契约与生成物、验证命令表、分支命名表、合入策略、trailer 正则、写回清单 1 的五个标题、流程骨架。

**阶段性**（进 skill）：

| skill | 触发（写进 description） | 内容来源（原样搬运） |
| --- | --- | --- |
| `commit-push` | 即将 commit / push / 开 PR | 提交纪律的粒度、整理门、approved 后冻结、授权语义 |
| `branch-sync` | 切分支 / rebase / 合并 / 打 tag / 回滚 | 三层历史读法、远端重写对齐、tag 打点规则 |
| `review-protocol` | 评审或被评审 | 状态机、PASS 快照格式、herdr 编排 |
| `docs-writeback` | PR 创建后至合并前 | 清单 1 细则、清单 2、停点语义 |

**Why**（进 ADR）：「继承条款」「规范变更」两节本质是决策记录，迁为 ADR，AGENTS.md 留一行指向。

### 3. 目标结构

```
AGENTS.md          What-常驻 + 流程骨架 + 触发指引        ≤ 8KB（现 34KB）
skill ×4           What + How（阶段规程，无教学）
AGENTS.md（嵌套）  What-区域                               推迟
docs/adr           Why                                     新增：本决策；迁入继承条款、规范变更
docs/guides        How-教学 + What-复述（人类读）           保持现状
docs/specs         What-验收                               不动
```

流程骨架里的触发指引写成**硬触发**，不是"参见 X"：

```markdown
## 流程骨架（每步细则按触发读 skill）

0. 启动：申请三项配置（见 proposals/task-lifecycle-gates）→ 读 skill agent-collaboration
1. 切分支 / 同步 / 合并 / 打 tag → 读 skill branch-sync；多任务并行 → 读 skill worktree
2. 写代码（受下方硬约束）
3. 自证：跑「验证命令」表
4. commit / push / PR → 读 skill commit-push
5. 评审 → 读 skill review-protocol；合并 → 读 skill merge
6. 写回 → 清单 1（细则读 skill docs-writeback）
```

### 4. 可靠性：约束靠机制，不靠记忆

skill 加载"靠 agent 自觉触发"是已知弱点（Pi 文档原话：*"A model might fail to load a relevant skill"*）。三层缓解：

1. **位置**：触发指引写进 AGENTS.md 流程骨架，读第一屏即撞见
2. **机制兜底**：能被钩子拦的违规靠钩子——`commit-msg` 已 fail-closed 校验 trailer，skill 忘读也不会产出违规提交
3. **显式入口**：`/skill:<name>` 可由人或编排脚本强制加载

**诚实的局限**：「启动时申请授权」没有机制可兜底——它是会话行为，不是 git 行为。只能靠位置 + 触发。真正的强制需来自 harness（例如 Pi 扩展在 `session_start` 后检查首条任务消息前是否已申请），超出本提案范围，记入 §7。

### 5. 推迟项与边界

- **嵌套 AGENTS.md**：业界主流做法（agents.md 官方建议；OpenAI 主仓 88 个），但 AGENTS.md 里 api / web 的区域规则目前不足 1KB，拆出收益 < 维护成本。**推迟条件**：某目录局部规则超过约 30 行。注意 Pi 语义——嵌套文件只在从该目录启动时生效，与 worktree 模型兼容（worktree 是完整 checkout）。
- **guides 不作 agent 载体**：guides 是"我要学会 X"的教学层，含基础知识，对 agent 是冗余。本提案**不**把规程放进 guides；guides 保持人类读者定位，与 skill 的重叠按既有「复述面」规则对账（清单 1 第 2 项）。
- **不与 task-lifecycle-gates 重叠**：该提案定义**流程里有哪些停点**（三项配置、停点表 #1–#10）；本提案只定义**规则文本如何被可靠读到**。启动协议的归属是它，本提案依赖它、不另立。

### 6. 真源顺序与防漂移

AGENTS.md、skill、guides 三者会包含同一规则的不同详略版本。约定：

- **真源顺序**：AGENTS.md > skill > guides。冲突时以上游为准，下游改写
- skill 正文**原样搬运**自 AGENTS.md 现文，不在搬运 PR 内重写——一个 PR 里既搬又改，评审无法判断语义是否漂移。精简留给后续独立 PR
- guides 的复述句继续带来源锚（现行规则），清单 1 第 2 项的 grep 对账范围**扩展到 skill**

## 毕业条件

- 四个 skill 落地且各被至少一个真实任务触发过（journal 可查）
- AGENTS.md 降到 ≤ 8KB，清单 1 第 2 项对账范围含 skill，无漂移
- 至少一次"agent 在触发点正确加载 skill"的实证，以及一次"skill 未加载但被钩子拦住"的实证（验证 §4 第 2 层）
- 毕业为 ADR（新编号）：记录三层分流判据、skill 清单、嵌套 AGENTS.md 推迟条件、真源顺序；「继承条款」「规范变更」的迁入在同批或后续 PR 完成

## 被否的替代设计

| 方案 | 否决理由 |
| --- | --- |
| 阶段规程放进 `docs/guides/`，AGENTS.md 留指向 | guides 是人类教学层，含基础知识，对 agent 纯冗余；且 docs/ 下内容不自动进上下文，What 落此处 = 靠 agent 想起来 |
| 在 AGENTS.md 里用 `@path` 引用其他文件 | Pi 1.5.2 无此机制（源码核实）；Claude Code 私有扩展 |
| 把 What 全部放进 `docs/`，AGENTS.md 只留索引 | 同上——What 失去常驻性；不可让渡的约束必须每条消息在场 |
| 只加强措辞（加粗、感叹号、"必须"） | 本次事故中 agent 并非没读懂，是没在该想起时想起。措辞强度不解决注意力调度 |
| 按小节整体搬进 skill | 「提交纪律」是 What/Why/How 纠缠体；整体搬会把 Why 一起带进 skill，与 ADR 形成双真源 |
| 现在就做嵌套 AGENTS.md | 区域规则不足 1KB，收益 < 成本；记推迟条件 |

## 演进记录

- **2026-11-22 draft**：首版。起于 PR #68 的授权流程事故；量化 AGENTS.md 职责混装（34KB，两节占 30%，guides 已有展开版但零指向）；核实 Pi 加载语义（只向上、无 `@file`、skill 是唯一按需机制）；定 What/Why/How 分流判据与四 skill 清单。

## 待决问题

- **harness 级强制**：「启动时申请授权」无机制兜底。是否做 Pi 扩展在会话首轮提醒？归属 harness 个性化层（不入库）还是项目 `.pi/extensions/`（入库、随仓库分发）？后者意味着仓库开始携带可执行代码，需单独决策
- **skill 存放位置**：`.pi/skills/`（Pi 专属）还是 `.agents/skills/`（跨工具通用，Pi 与 Claude Code 均识别）？团队是多 harness 的，倾向后者
- **多 harness 一致性**：Claude Code / dsh 是否等价支持 skill 的按需加载？若否，阶段性规程对它们仍是常驻或不可见，需逐工具核实后再定论
