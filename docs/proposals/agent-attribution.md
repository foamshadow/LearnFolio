---
title: "agent 署名：提交级来源标签（opt-out）"
author: foamshadow
date: 2026-11-14
status: draft
tags: [se-arch, tool-git]
related: [ADR-0003]
adopted-as: ""
---

# agent 署名（proposal）

## 背景

本仓库把 agent 当作主要实现者（README 与 AGENTS 的定位），但提交里只记录人类 author，
**没有任何来源标签**。后果有三层：

- **产品层**：历史即内容。Meta 阶段的时间线页要靠 frontmatter 索引 journal / learning /
  guides / specs，提交层却只有自由文本消息，无法回答"哪个 agent 做了什么"。
- **审计层**：与 `proposals/agent-confirmation-chain` 同源——确认要留痕，产出也要留痕。
  出问题时"这是 agent 干的还是人写的"是排查第一问，现在只能靠回忆。
- **流程层**：规则缺失时错误不会被发现，只会被继承。建仓首次提交即因此
  缺署名而需撤回重做——这正是本条提案的触发事故。

## 提议

### 1. 语义：opt-out，而非 opt-in

**每一条提交都必须带 `Assisted-by` trailer**：agent 参与的写 `<harness>:<model>`，
纯人类提交写 `none`。

选择 opt-out 的理由：opt-in（"没有就表示没人参与"）下，CI 只能校验格式、不能校验存在性，
漏写永远检查不出来——而首提交漏写正是这个洞。opt-out 让"缺失"成为可判定的错误，
把纪律变成机制。

重写与多参与方的语义（trailer **跟内容走，不跟操作走**）：

- 无冲突 rebase / fixup / squash：智力来源不变，git 重写默认保留 message——trailer
  原样随行，零额外规则；
- 冲突解决：解决者向提交注入了新内容，成为该提交的共同参与者——追加一行自己的
  trailer（多行、行序 = 参与顺序）；
- rebase / 整理的**执行者**：操作不产生内容，不记；
- merge commit（--no-ff）：opt-out 不留例外——带执行者 harness 或 `none`（逐提交
  正则校验，任何"某类提交豁免"都会让校验分支化）。

```
Assisted-by: DSH:deepseek-flash
```

```
Assisted-by: none
```

### 2. 位置与格式

- 只允许出现在 commit message **末尾的 trailer 块**（正文出现不算数，`git interpret-trailers`
  的可解析位置）；
- 键名固定 `Assisted-by`（大小写敏感）；
- 值 `<harness>:<model>`，ASCII 无空格；多参与方各一行（trailer 键可重复），
  行序 = 参与顺序，**不表达权重**；
- 校验正则：`^Assisted-by: (none|[A-Za-z][A-Za-z0-9]*:[a-z0-9][a-z0-9.-]*)$`
- 查询：`git log --grep='^Assisted-by:'` 给出全部提交；`--invert-grep` 配 `none` 得纯人类历史。

### 3. 身份约束

`author` 与 `committer` 恒为人类（审定者与执行者）；agent **不署** author / committer。
责任在人，来源在标签——与 journal 的"作者键 = 审定者"一致。

### 4. harness / model 键闭合登记（新值 = AGENTS 加一行 + PR；毕业迁 AGENTS 提交纪律节）

harness 键：

| 键 | 全称 |
| --- | --- |
| `DSH` | DeepSeek Harness |
| `ClaudeCode` | Claude Code |
| `ZCode` | ZCode（GLM） |

model 键（= 官方 API id 的 kebab-case 小写，含官方快照后缀——照抄官方 id，
不自行附加日期）：

| 键 | 官方全称 |
| --- | --- |
| `deepseek-v4.1-flash-1017` | DeepSeek-V4.1-Flash-1017 |
| `glm-5.3-flash` | GLM-5.3-Flash（ZCode 当前默认） |

### 5. 身份的来源：agent 自述 + 配置查证

环境变量注入方案被否（见被否方案表）：成员人人多 harness × 多 model，shell 全局变量
跨工具链共享、无法跟踪当前会话身份，必错配，配置负担随模型数线性涨。agent 是唯一
在"现场"的实体——**自述为源，但自述 ≠ 凭感觉，自述 = 查证**。确定键的信源优先级：

1. **harness 的 model 配置**（settings / 供应商切换器的当前 model 字段）——精确到
   配置粒度，最可信；
2. **系统提示的 model id**（如 `account:…/GLM-5.3-Flash`——可能带路由前缀，
   取尾段映射键）；
3. **harness 自省命令 / status 输出**（如有）。

取最精确者映射登记表键；信源冲突、或精确不到版本粒度（只知"deepseek"不知快照）
→ **询问人**，不猜。harness 键同理：系统提示自述 + 配置形态交叉确认。

### 6. 声明的性质

自述（即使经过配置查证）仍是**声明（claim）**，不是**证明（proof）**：可信度来自
查证纪律与评审抽查，不可用于归责或能力认定。模型键用登记表键，不自行附加日期
版本——commit date 已在提交里。

### 7. 强制：钩子为主，CI 为辅

- **t3（lefthook）**：`commit-msg` 钩子校验 trailer 存在性与格式。缺失时**中止提交**
  （fail-closed，静默补 `none` 会把 agent 提交误标成人类提交，比缺省更坏）；
  中止后由 agent 按信源清单（§5：harness 配置 → 系统提示 → 问人）查证补写——
  钩子不代填、不依赖环境变量。
  `--no-verify` 可绕过——钩子防手滑，不防有意逃避。
- **t0（ci.yml）**：PR 内逐提交做正则校验，违规列出 SHA 并失败；并入 `ci-ok` 聚合。
  CI 是唯一能挡住 `--no-verify` 的一层。
- **PR 描述**：同列该串（分支删除后仍可查，与 trailer 互补）。

## 不做：文档层署名

journal / learning / guides 不在 frontmatter 记录起草 agent。理由：文档质量难以自动核验，
"谁写的"对这类产物的溯源价值低于提交层；强行记录只增加维护面。时间线页若需要按 agent
切分，以提交层 trailer 关联文档路径即可，不必在文档里重复一份。

## 不做：开发 / 审核 agent 的角色区分

角色区分现阶段不做：当前没有消费方需要区分一个提交里 agent 是开发还是审核
（时间线页尚未存在——不预支判据）；"审核 agent"的审核同样是自报声明，区分的
可信度增量有限；git 生态的正确扩展形态是**另起 trailer 键**（kernel 惯例
`Reviewed-by:`）而非在 `Assisted-by` 值里编码角色——值保持 `<harness>:<model>`
纯净，正则与未来的闭合校验都不用动。翻转条件：时间线 / 统计真需要按角色切分时，
加 `Reviewed-by: <harness>:<model>` 键，零破坏演进。

## 被否方案

| 方案 | 否决理由 |
| --- | --- |
| opt-in（缺席 = 无 agent） | CI 无法校验存在性，漏写不可检测；首提交事故的直接成因 |
| `Co-authored-by:` | GitHub 会尝试关联账号，agent 无账号；语义上把 agent 抬成共同作者，与"agent 起草、人审定"不符 |
| author = agent、committer = human | blame / PR 归属指向无账号身份；与 journal "作者键 = 审定者"规则冲突 |
| 只在 PR 描述标注 | 不进 git 历史；分支删除、仓库迁移即丢失 |
| 自由文本（"本提交由 AI 辅助"） | 不可机械聚合，时间线页无法按 agent 维度切分 |
| 引入 DCO / `Signed-off-by` | 与本提案正交；AGPL 已承载版权声明，再加只增仪式成本 |
| 环境变量注入（`LF_HARNESS` / `LF_MODEL`） | 成员人人多 harness × 多 model，shell 全局变量跨工具链共享、无法跟踪当前会话身份，必错配；配置负担随模型数线性增长——被多运行时现实直接否决（2026-11-14 讨论） |

## 毕业与推行路径

规则不进编号文档层，直接落 AGENTS"提交纪律"节；决策理由由一份新 ADR 沉淀
（ADR-0003 正文不可变，不能扩写）。不设演练门槛、不要求跨 harness 样本数——
本提案的验收就是它自己落地：钩子装上、CI 跑绿、首提交带署名。

1. **首提交（bootstrap）**：本文与 20 件原稿一并入库，首提交本身带 `Assisted-by`——
   规则与其首个消费者同时到达，不引用尚不存在的文档；
2. **规则 PR**：AGENTS 增 3 – 4 条 bullet + harness / model 登记表自本节迁入
   （本文正文替换为指针后，登记表不得随之丢失）+ 立 ADR 记录取舍；PR 模板提示行
   待模板随 t0 落地时由该任务顺带补入（规则 PR 先于 t0 时模板尚不存在）；
   本文 status → `adopted`，`adopted-as` 指向 AGENTS 提交纪律节与新 ADR
   （编号于其起草时按协议分配）——本文按"落点毕业"（整篇规则一次落 AGENTS，
   不同于 roadmap 的按段落毕业）；正文替换为指向 AGENTS / ADR 的指针；
3. **t0**：ci.yml 增 trailer 校验 job；
4. **t3**：lefthook `commit-msg` 钩子。

## 开放问题

- 多 agent 的行序是否表达主导关系？当前：不表达。
- 模型版本是否入 trailer？当前：不入，commit date 承担时间维度。

## 演进记录

- 2026-11-14 起草。起因：建仓首次提交缺 agent 署名，触发"撤回重做"（旧提交由根重置替换，不留旧史）。
- 2026-11-14 评审定稿方向：改 opt-out；加钩子审查层；文档层不做；首提交以根重置并入本文，
  不设演练式毕业条件。
- 2026-11-14 同日讨论落地：重写 / 多参与方四情形语义写入（trailer 跟内容不跟操作）；
  开发 / 审核 agent 角色区分不做（翻转条件 = 另起 `Reviewed-by` 键）；键表升两列——
  model 键 = 官方 API id 的 kebab-case（含官方快照后缀，照抄不自行附加日期）；
  **身份来源定环境注入**（§5）：agent 无法可靠自知 harness 与精确 model 版本，
  `LF_HARNESS` / `LF_MODEL` 由 harness 启动配置注入、agent 只透传，缺失时询问人而非自猜。
- 2026-11-14 二次转向：**环境变量注入被否**——多 harness × 多 model 现实下 shell
  全局变量跨工具链共享、无法跟踪当前会话，必错配且配置负担不可扩展；身份来源改
  **agent 自述 + 配置查证**（信源优先级：harness model 配置 > 系统提示 id > 自省命令；
  精确不到快照粒度即问人）；钩子只 fail-closed 校验、不代填；model 键粒度目标 =
  详细版本（快照 id 照抄，如 DeepSeek-V4.1-Flash-1017）。
