# LearnFolio 工程文档

本目录是工程文档真源。文档预置三种变更语义——"多变"只发生在它该发生的地方：

| 目录 | 用途 | 变更语义 |
| --- | --- | --- |
| `specs/` | 功能规格书，agent 的施工图 | 受控：draft → ready → done / superseded / abandoned；语义变更走文件尾"变更记录"追加，方向变更开新编号取代 |
| `adr/` | 选型决策记录 | 不可变 = 正文四节；status 单向流转 accepted → deprecated / superseded |
| `journal/` | 开发过程日志（年份分组，一篇 = 一个事件） | 可变：自由追加改写 |
| `learning/<作者键>/` | 学习笔记（事故驱动："X 撞了我"），网站内容素材（发布走蒸馏） | 可变：自由追加改写 |
| `guides/` | 教学与剖析文档（主动建构："我要学会 X"）；写作标准见 `_template.md`——默认读者 = 学习者（未掌握全部前置知识），详尽优先于简洁，讲相关技术本身 | 可变：自由追加改写 |
| `proposals/` | **孵化区**：想法的第一落点；不占编号，毕业才进正式层 | 可变偏受控（见"proposals 与毕业制"） |

## 标识与命名

### 编号（仅 specs / adr）

- 格式：SPEC-NNNN / ADR-NNNN，4 位零填充，全局递增，永不复用
- 分配：起草前 git fetch，取目录内最大编号 + 1
- 冻结：status → ready / accepted 的瞬间，编号与文件名短名永久冻结（title 可改，文件不重命名——文件名承载 ID）
- draft 期可改号且零副作用，前提：**draft 状态的编号文档不得被任何文档引用**（提及用标题）；
  无编号文档路径即标识、可被引用——proposals 的 slug 一经创建即冻结（内容随便改，文件名不改）
- 废弃不删文件只改 status → 目录本身即编号登记簿
- journal / learning / guides / proposals 不编号，**路径即标识**（编号的分配协调成本只在受控/不可变层支付；proposals 以 slug 冻结补位）
- 引用格式：SPEC-0007、SPEC-0007-A3（条目级）；正则 `SPEC-\d{4}(-A\d+)?` 无歧义

### 文件名

- 一律 ASCII kebab-case：`^[a-z0-9]+(-[a-z0-9]+)*\.md$`（例外：`README.md`（目录索引）与 `_template.md`——地图自身即 README，规则不得否认自己的文件名）
- 禁止 CJK / 空格 / 大写 / 下划线——理由：grep 可搜性、跨平台文件名规范化（NFD/NFC）、agent 工具链兼容；若 Phase 1 选用 Nuxt Content 索引 docs/，本规则同时成为 URL 稳定性的前提；中文标题写 frontmatter title
- specs/adr：`NNNN-短名.md`；journal：`YYYY/YYYY-MM-DD-<作者键>-<slug>.md`；
  learning：`<作者键>/<slug>.md`；guides / proposals：`<slug>.md`

### 取代链（specs 与 adr 共用，双向**链**式）

- 方向变更 = 开新编号；旧文档正文一字不改
- 旧：`status: superseded` + `superseded-by: 新编号`；新：`supersedes: 旧编号`
- **只指直接取代者**（不指链尾最新）：每次取代只改一个节点的 frontmatter，登记 O(1)；
  找现行 = 沿 superseded-by 跳到无该字段的节点；考古 = 沿 supersedes 回溯
- **部分推翻**：旧文档标 `deprecated`（不挂链，它还部分活着）；新文档 `supersedes` 指向旧 +
  正文写明取代范围——读者用 `git grep supersedes.*NNNN` 反查部分继任者
- supersedes/superseded-by 数组化（多篇合并/分拆）**暂不设计**——首次分拆场景出现时再扩展词表（不预支）

### 验收条目

- A1、A2… **只追加、不重排、不复用**；废弃划掉保留槽位：`~~A4~~（已废弃 YYYY-MM-DD，见变更记录）`
- 逻辑上属中间位置的新条目仍追加到末尾，逻辑顺序靠正文表达
- 位置编号一旦重排，git 历史与 PR 中的条目级引用会**静默**指向错误条目——这是本规则存在的理由

### proposals 与毕业制

- 状态词表：`idea | draft | review | adopted | rejected`
- 跃迁：idea → draft（成形为可读提案：背景+提议+毕业条件）；draft → review（作者认为成熟，
  征求核心意见）；review → adopted（毕业评审通过 → 分配编号进正式层，frontmatter 记
  `adopted-as`）；review → rejected（否决**保留并记录理由**——否决也是知识）
- **未毕业随便改**（git 历史即过程记录，这是它与 ADR 的本质区别；slug 一经创建即冻结）；
  毕业后守正式层纪律，且**正文替换为指针**（保留 frontmatter 与演进记录，正文仅留
  "已毕业为 X，真源以 X 为准"——防双真源）；毕业后再推翻走 ADR/SPEC 取代链
- 毕业时分配的编号遵守编号分配协议（fetch 取 max+1）

### 状态词表（闭合；新增值 = 改本文件 + PR）

- specs：`draft | ready | done | superseded | abandoned`
- adr：`proposed | accepted | deprecated | superseded`——deprecated = **部分或全部**
  条款失效、仍存参考价值（读者以 `git grep "supersedes.*ADR-NNNN"` 反查继任条款）；
  superseded = 整体被取代，正文不再生效。按 status=accepted 检索现行决策会漏掉
  deprecated 中仍生效的多数条款，须反查确认
- learning / guides：`draft | verified`（文档自身成熟度；learning 永不直接发布，无 published 态）
- proposals：`idea | draft | review | adopted | rejected`

### 标签词表（闭合前缀命名空间；新 tag = 本文件登记一行，同 PR 内完成）

`lang-*` | `se-*` | `infra` | `content` | `tool-*`

### 作者键

docs/learning/ 一级目录名与 journal 文件名中的作者标识；在 AGENTS.md 登记一次，一经使用永不更改，与 GitHub 用户名解耦（用户名可被改名且旧名不保留）。

## 真源层级（同一规则出现在多处时）

- AGENTS.md = 规则真源（做什么）；adr/ = 决策真源（为什么，含被否方案）；
  guides/ = 教学衍生物（怎么理解）——**不得新增规则，只解释既有规则**
- 冲突时以 AGENTS.md 为准；冲突本身视为 guides 的 bug，同一 PR 内修正
- AGENTS / ADR 的 PR 触及 guides 已覆盖的主题时，须同 PR 更新 guides
  （维护触发器——否则 guides 静默过期）

## 决策线（ADR 阅读顺序）

ADR 按决策时间排列，单看是碎片，按阶段读是一条线。建仓前的策划过程未随仓库保存（见各 ADR 的补记说明与 SPEC-0001 的 `source` 字段），决策已回填为 0001 / 0002 / 0003。

| 阶段 | ADR | 状态 | 回答什么 |
| --- | --- | --- | --- |
| 选型（建仓前） | ADR-0001 技术栈、ADR-0002 许可证 | accepted | 用什么、怎么授权 |
| 流程设计（建仓） | ADR-0003 分支与合并 | deprecated（部分条款） | 怎么协作、账本怎么读 |
| 运行修正（建仓次日） | ADR-0004 agent 署名 | accepted | 来源怎么记 |
| 运行修正（建仓次日） | ADR-0005 双合并策略 | deprecated（部分条款） | 文档怎么落 |
| 元决策 | ADR-0006 文档体系与规则生长 | accepted | 为什么是六类、规则怎么长 |
| 协作与继承（建仓次日） | ADR-0007 授权模型、ADR-0008 遗产继承 | accepted | 谁能做什么、从旧项目取什么 |
| 交付（Phase 0） | ADR-0009 CI 门禁策略 | deprecated（ADR-0011 部分取代） | 门禁为什么这样搭；C6 相关看 ADR-0011 |
| 历史修复（Phase 0） | ADR-0010 历史修复与 docs 分支 | accepted | message-only rewrite、docs 单提交撤销 |
| 评审署名（Phase 0） | ADR-0011 评审署名双轨与 pr-meta 边界 | accepted | 状态评论角色行、commit 级 Reviewed-by、Pi/glm-5.3 登记、C6 部分取代 |
| 远端重写对齐（Phase 0 后） | ADR-0012 撤回后 clone 通知与对齐 | accepted | 三件套机制（retract 输出 / backup 提示 commit / AGENTS 条款）、trailer 声明制、备份保留窗口 |

读法：先看阶段，再看单篇。`deprecated` 表示部分条款已被取代，沿 `supersedes` 找继任者（ADR-0005 只取代 ADR-0003 的合并方式条款；ADR-0010 只取代 ADR-0005 的 docs 单提交条款；ADR-0011 只取代 ADR-0009 的 C6 job 清单、push 跳过集合与结果矩阵条款，ADR-0009 按部分取代约定不挂 superseded-by）。**新增 ADR 时在本表追加一行**——这张表就是决策线的入口。

## frontmatter

status / title / author / tags / source / related / date / supersedes / superseded-by / adopted-as（仅 proposals，按文档类型取用，见各 _template.md）。下游：agent 按 status=ready 检索可开工的 spec；未来站点索引按 frontmatter 构建时间线与知识图谱页。

## 扩展规则

新文档类型 = 加目录 + `_template.md` + 在本地图登记一行；状态/标签词表新增同机制（本文件 + PR）。
