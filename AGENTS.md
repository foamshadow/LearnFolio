# AGENTS.md

本文件是 LearnFolio 仓库的规范唯一真源，对所有成员（人类与 AI agent）生效，无豁免权。
修改本文件必须走 PR（见"规范变更"）。

> 渐进补入：本初版只含建仓即生效的规则。t2 已补"Go 分层纪律 / 契约与生成物 / 工具版本"；
> t3 已补提交纪律的 lefthook 配置行（钩子实现见 `lefthook.yml` 与 `scripts/hooks/commit-msg.sh`）。

## 仓库身份

- 仓库：github.com/foamshadow/LearnFolio
- Go module：github.com/foamshadow/learnfolio（小写不可逆：tag + GOPROXY 缓存后固定）
- Node 命名空间：@learnfolio/*（与 module path 对齐）
- 结构规则一句话：apps/* 是会被部署的东西，packages/* 是会被 import 的东西，
  apps/api 是唯一碰数据库的地方，契约生成物唯一来源是 task gen；
  docs/ 是工程文档真源，apps/api/docs/ 是契约生成物落点
- 仓库若为 private：设 GOPRIVATE=github.com/foamshadow/*

## 工具链边界

- Node 侧（apps/web、packages/*）：pnpm 命令，在对应目录内执行
- Go 侧（apps/api）：go 命令，在 apps/api 内执行
- 双侧命令不得越界执行

## 文档体系（docs/）

- 六类：specs/（受控：draft → ready → done / superseded / abandoned）、adr/（正文不可变；
  status 单向流转 accepted → deprecated / superseded）、journal/（年份分组，一篇 = 一个事件；
  记录完整开发经历——事件、事故、决策讨论、复盘、执行差异；可变层，谁经历谁写；
  写回边界 = 最后一次 push，PASS 与合并属边界外走下一事件；粒度 = 提炼教训 + 评论层索引，
  不逐轮复述；版本级审查历史走「审查记录」表（格式见 journal 模板）——ADR-0013）、
  learning/<作者键>/（可变：事故驱动笔记）、guides/（可变：教学与剖析文档——
  "我要学会 X"对 learning 的"X 撞了我"）、proposals/（孵化区：想法的第一落点，
  不占编号，毕业才进正式层）
- 跨文档引用一律用编号或路径，可到条目级（SPEC-0001-A3）；仓库内文档不引用仓库外记录
- 编号分配：起草前 fetch 取 max+1；specs ready / ADR accepted 即冻结编号与文件名；draft 状态的**编号文档**
  （specs / adr）不得被引用（提及用标题）——改号成本因此为零；无编号文档路径即标识、
  可被引用，但 proposals 的 slug 一经创建即冻结（内容随便改，文件名不改）；
  废弃不删文件只改 status（目录即登记簿）
- 方向变更 = 新编号取代链（supersedes / superseded-by，仅指直接取代者）；**部分取代只挂正向链**（旧文档标 deprecated、不填 superseded-by；反查用新文档的 supersedes）；
  语义变更走尾部"变更记录"追加（历史不删）；验收条目 append-only（废弃划掉留槽）
- spec 的 ready 须至少一名非作者核心成员批准（bootstrap 例外仅 SPEC-0001，已记录于该 spec）
- 作者键在本文档登记、永不更改、与 GitHub 用户名解耦；状态与标签词表见 docs/README.md（闭合）
- learning 与网站内容解耦：发布 = 显式蒸馏进独立内容源（Phase 1 定），本目录不直通网站
- **任务 PR 的文档写回窗口 = PR 创建后、评审通过前**：变更记录、验收勾选、实测结果随任务 PR 追加提交
  （代码任务多提交合法；docs 分支可追加提交，force push 需人类确认；ADR-0010 已撤销单提交约束）；需要 PR 号或 CI 实测的
  记账行只能落在这个窗口。合并后才发现遗漏 = 执行差异，记 journal 并在后续文档 PR 补，不改写已合入的账本行
  （approved 后追加会因 Dismiss stale approvals 作废审批）
- 新文档类型：加目录 + _template.md + 在 docs/README.md 地图登记一行

## 文档写回与收口清单（ADR-0013）

写回边界 = 合并请求停点（tlg 流程 ⑨ = 停点表 #9「合并授权」）；边界外发现 =
执行差异唯一通道——**无尾随通道**（二值判定：窗口内更新，或记录"无需更新"
一句话理由）。预先性记录：状态与完成描述字段随窗口增量维护，合并只落终态标记。

- **清单 1（合并请求停点五项核验）**——自查区随写回窗口增量维护、PASS 前完整，
  停点上人工只核验不写入（PASS 后描述冻结）：
  1. SPEC 窗口闭合：变更记录 / 验收勾选 / 实测结果齐
  2. 复述面：本 PR 改变的事实/规则 → grep AGENTS + guides（复述句带来源锚
     `随 #NN 落地` / 真源文件名，使 grep 可执行）→ 窗口内更新或记录"无需更新"
  3. 登记面：新 ADR → README 决策线行；新词表值 → 词表行；触及 proposal 陈述 → 演进记录
  4. journal 封账：边界 = 最后一次 push；无 journal → 说明理由
  5. 终态就位：触及的状态字段（SPEC/proposal status、README 状态行）差一步终态
- **清单 2（Phase 收口扩展）**：清单 1 + guides 全量 vs 实现逐篇对齐 + 收口
  journal 事故清单如实完整 + README 词表复核 + PR 模板与条款对齐抽查
- **learning 例外（成员自主）**：learning/<作者键>/ 澄清现行"事故驱动笔记"
  描述语——项目不设写回触发器，写不写、何时写由成员决定；项目侧唯一动作 =
  被动可见性（收口 journal 事故清单如实完整）
- **guides 维护触发器扩展**：实现/配置变更（ci.yml、merge.sh、钩子、脚本）与
  AGENTS/ADR 变更同样触发清单 1 第 2 项复述面检查

## 分支与版本

分支七类。命名约束（D/F 冲突防护：git ref 存储为文件路径，分支 `feat` 与目录 `feat/` 不能共存）：**main 与 dev 是仅有的两条长存分支**；任何新建分支不得取 main / dev / feat / fix / hotfix / backport / docs 的**单段名**，也**不得以 `main/` 或 `dev/` 为前缀**（与长存分支 D/F 冲突）；`feat/` `fix/` `hotfix/` `backport/` `docs/` 前缀合法（前缀本身不是分支，是目录）：

- main：产品库。只接受 --no-ff 合入；只接受收口 PR 与 hotfix PR
- dev：受控库，单条集成分支（Phase 串行无需多线）
- feat/spec-N-tM-短名：任务分支，从 dev 切出，PR 回 dev（tM = spec 任务分解节任务号）
- fix/spec-N-tM-短名 | fix/spec-N-短名 | fix/<scope>-短名：dev 上的修复，
  与 feat 同层同流程（锚点三级：在飞任务 / 已合入 spec / 无 spec 归属取 scope 白名单）
- hotfix/<scope>-短名：从 main 切出，修已发布基线（必然无 spec 锚）
- backport/<短名>：hotfix 回流 dev 的载体（dev 必 PR 且禁 bypass，"在 dev 上直接
  git merge"不可执行）——从 dev 切出，`git merge <hotfix tag>`（tag 永久自解释，
  优于已删分支的裸 SHA），PR 回 dev
- docs/<短名>：纯文档改动（`docs/**` 与根文档），从 dev 切出，PR 回 dev，**squash 合入**——
  单意图，落地为一条普通提交（无 merge 节点，见 ADR-0005；提交数不限，ADR-0010）

分支名固定两段 `前缀/短名`，名称内不得再含 `/`；短名段为 ASCII kebab-case：`^[a-z0-9]+(-[a-z0-9]+)*$`（如 `feat/spec-0001-t2-api-healthz` 的短名段 = `spec-0001-t2-api-healthz`）；前缀取上述七类之一

合并与同步（完整机理与决策链见 ADR-0003）：

- 合入策略分两类（ADR-0005）：**代码任务一律 --no-ff**（settings 保留 merge commit 并物理强制）；
  **纯文档 PR 走 squash**——`docs/*` 分支、单意图，落地为一条普通提交、无 merge 节点；提交数不限（ADR-0005 / ADR-0010）；
  **不得开启** Require linear history（与 --no-ff 互斥），rebase merge 保持关闭
- merge message = PR 标题 + 平台附加的 ` (#N)`（settings 设 Default to PR title、正文留空；2026-11-14 实测），五种格式：
  `合并 spec-N-tM 短名：一句话`（feat→dev）/ `合并 fix 短名：一句话`（fix→dev）/
  `合并 hotfix 短名：一句话（发布 vX.Y.Z）`（hotfix→main——缺此变体则首个 hotfix PR
  会被自己的 CI 拦死）/ `合并 hotfix 短名：backport 自 vX.Y.Z`（backport→dev）/
  `合并 Phase N 收口：vX.Y.Z`（dev→main）；PR 标题由 CI 正则校验
  （六条完整 alternation + 分支方向矩阵，正则见 SPEC-0001-A5）；
  **合并界面不得手改 message 字段**（Default to PR title 已预填，手改 = 账本行失守）
- 文档 PR 无 merge 提交：PR 标题即落地提交主题，GitHub 同样追加 ` (#N)`（实测：`docs: … (#3)`），
  账本行 = 该提交；squash 的标题 / 正文取自 PR 标题与描述，描述末尾同列 `Assisted-by` trailer（见 ADR-0005）
- feat 同步 dev：仅在冲突或 ci-ok 红疑基线时 `git rebase dev`；同步即作废 approved 需重审；
  分支保护不开 "Require up to date"（与整理门过约束死锁，补偿 = push 触发 CI，见 ADR-0003）
- hotfix 合回 main 并 tag 后，经 **backport/ 分支回流 dev（禁 cherry-pick，机理见
  ADR-0003）**：从 dev 切 backport/<短名>，`git merge <hotfix tag>`，PR 回 dev
- dev 的 push CI 红 = 语义冲突落地：开 fix/ 修复，或 `git revert -m 1` 回滚
  （被 revert 的任务重合入不带回内容，须 revert 那个 revert）
- **远端重写对齐**（撤回 / retract 之后，ADR-0012）：`git pull --ff-only` 失败、status 报
  diverged、push 被非 fast-forward 拒绝，且已知 dev 被重写时——先查 `backup/*` 的对齐提示，
  经**人类确认**后执行 `git fetch origin && git reset --hard origin/dev`；前置自检：
  `git log origin/dev..HEAD` 为空（无未推提交）且工作树干净；工作树脏时**不得直接
  reset**——未提交改动以 `git stash push -u -m <唯一标签>` 或 `wip:` 提交留存，
  无法留存即中止并提示人类；agent 会话遇此状况主动提示人类并对齐（clone 通知机制的
  agent 侧组件，2026-11-19 演练闭项决策）

版本号与 tag：

- vX.Y.Z 只在 main；**X = 主版本：0.x 为开发期，首次公开上线置 1.0.0（首次公开
  稳定，非不兼容变更），其后 X+1 仅当出现不兼容变更，X+1 时 Y / Z 归零**；Z = 仅 hotfix 自增；
  **Y = 收口时显式指定并记录于收口 journal**。约定：Phase 0 → v0.1.0；
  Phase 1（首次上线）→ v1.0.0；其后每收口 Y+1
- tag 一律 **annotated**，message 首行两种格式：收口 `vX.Y.Z — Phase N 收口：一句话`、
  hotfix `vX.Y.Z — hotfix <短名>：一句话`；正文收口列覆盖 SPEC、hotfix 列变更摘要与
  backport PR 号；推送显式 `git push origin vX.Y.Z`（`--follow-tags` 依附常规 push、
  会连带推当前分支——合并发生在远端时本地 main 落后，行为不可预期；显式 refspec 只推 tag）
- **release tag 打在发布内容的代表 commit**（`git fetch origin` 后取 `origin/` 引用，
  不依赖本地新鲜度——本地 dev/main 落后时打本地 ref 会打错 commit 且不报错）：
  **收口 tag 打 merge commit = `origin/main`**（在 main 第一父链上，"main 第一父链 +
  tag = 版本史"读法与 describe 才成立——**仅 main 侧**：收口 merge commit 不在 dev
  祖先，dev 侧 `git describe` 解析不到收口 tag；Phase 1 部署若用 describe 生成镜像
  tag / 版本号，dev 构建会拿到旧 tag 或失败——版本号一律以 main 侧为准或显式注入）；
  **hotfix tag 打 hotfix tip = `origin/main^2`**（merge 第二父：被删分支的改动靠 tag
  留存，且 backport 的 `git merge <tag>` 依赖它指向 hotfix 线本身——指向 merge commit
  会把整条 main 线并进 dev）
- 收口后 **dev 不追平 main**（ff 追平会覆盖任务史读法）——分叉是常态

三层历史读法：

- main 第一父链 + tag = 版本史（Phase 级；hotfix patch tag 打在 hotfix tip = merge
  第二父，不装饰此链——查 patch 版本用 `git tag -l` / `git tag --contains`）
- dev 第一父链 = 任务史 + backport 事件 + 文档单提交（merge 节点按 message 前缀区分；文档提交以 `docs:` 前缀识别）
- feat 全量提交 = 过程史（逻辑步骤级）；合并后自动删除分支不丢过程史

破坏性操作（Phase 0 由人类执行或确认；agent 确认链孵化中，见
proposals/agent-confirmation-chain，毕业后取代本条）：

- 操作分级（ADR-0007）：读 / 改自主；commit 须**提交前告知**（获 auto-commit 时）或逐条审批（`wip:` 免审）；
  `docs/*` 提交须确认；**push 须许可**（获 auto-push 时任务内免逐次审批，每次 push 后报告）
- 任务启动时一次性申请 auto-commit / auto-push 两项独立授权（任务级生效、可随时撤销）
- 人类执行/确认：rebase -i 整理门、任何 force push（一律
  `--force-with-lease --force-if-includes`）、打 tag、dev→main 合并、git revert -m
- rebase 前先 `git branch backup/<branch>-<时间戳>`
- feat 分支寿命 > 3 天或提交数 > 30 = 任务粒度过大信号，拆 tM 而非加子分支垫层

## 多工作树（worktree）

同一仓库允许多工作树并行（多个 agent / 多任务的物理隔离）。**一条分支只能在一个工作树里 checkout**；
工作树只影响本地检出的分支，不改变远端、PR、CI 与分支保护的任何规则。

- 位置与命名：任务工作树一律在仓库根的 `.worktrees/<短名段>`（已 gitignore，不入库）；短名冲突时用
  `<前缀>-<短名>`。主工作树**优先**常驻 `dev`（或 `main`）；并行任务必须进工作树，单人串行时可临时在主树
  切分支，但不得与任何工作树占用同一分支
- 创建：`git worktree add --no-track -b <分支> .worktrees/<短名> dev`——**加 `--no-track`**：从
  `origin/dev` 起手（或 `branch.autoSetupMerge=always`）会自动把新分支的 upstream 设成 `origin/dev`，
  导致 `git status` 误报 ahead/behind、`git pull` 把 dev 合进任务分支；`push.default=upstream` 时裸
  `git push` 还会尝试推 dev（默认 `simple` 会因分支名不匹配而拒绝，但不应依赖这层）。漏加则
  `git branch --unset-upstream` 补救
- upstream：任务分支只允许跟踪同名远端分支（首次 `git push -u origin <分支>`）；发现指向 `dev` / `main` 立即改正
- 基线：从最新 `dev` 切；落后时在**该工作树内** `git rebase dev` 后再开 PR（approved 后改写会作废审批，同提交纪律）
- 锁：长时 agent 会话用 `git worktree lock --reason "<harness>/<任务>" .worktrees/<短名>`，结束或合入后
  `unlock`。锁不是互斥锁——只在 `.git/worktrees/<id>/` 写 locked 标记，阻止 `prune` / `remove` / `move`
  动这棵树，不阻止任何进程读写文件或跑 git；并发安全仍靠下面的纪律
- 清理：分支合并并删除后 `git worktree remove .worktrees/<短名>`；**禁止**对他人活跃工作树执行
  `remove --force` / `prune`；`git worktree prune` 只清已删目录的元数据，执行前先 `git worktree list`
- 并发纪律：工作树共享同一个 `.git`（对象库、hooks、仓库 config）——禁止进入他人工作树执行
  commit / rebase / checkout / 删除分支；`git gc --prune=now`、修改 hooks 或仓库级 config 前先确认无其他
  活跃工作树；fetch 与只读命令可并行
- 运行态隔离：不同工作树可同时起 dev server / 数据库，端口与 `.env` 本地错开（`.env` 不入库）；
  共享的只有 git 对象与 hooks（lefthook 已落地：钩子装在共享 `.git/hooks`，job 的 `root:`
  按当前工作树解析；`task setup:hooks` 从任一工作树执行都会更新同一套钩子）
- 授权：auto-commit / auto-push 按工作树各自申请、不跨工作树继承（ADR-0007）；一个工作树的 agent
  不得代另一个提交或推送
- 分支七类命名与方向规则不变；工作树不改变 `feat/*` 等分支的创建与 PR 方向

## 提交纪律（feat 内草稿文化 + 合入严格格式）

- **历史美观总纲**：git 历史美观是首要目标，作用域 = **入账层**（dev/main 第一父链
  + PR 整理后的提交序列）——commit 量精简（整理门 fixup 纯噪音、不攒"补一行"碎片）、
  分支结构明确（三层历史读法、任务恒定 merge 形态）、commit 内容合规完善（单一意图、
  可编译，见提交粒度）、无意义分支及时清理（合并后删本地分支，squash 落地用 `-D`；
  远端由 delete_branch_on_merge 自动删）。feat 内 WIP 过程提交不受此限（草稿文化，
  过程史保留正是 --no-ff 的目的）
- feat 内：WIP 高频提交（`wip:` 前缀，message 可草）；**WIP 不要求可编译**，锚点（一个可验证步骤）
  应编译过 / 测试绿——过程保留是 --no-ff 的目的，WIP 不丢人
- 提交前告知：改了什么、为什么、几个（auto-commit 省等待，不省告知）；禁止静默连续提交
- 提交粒度（ADR-0007）：整理后一个提交 = 一个完整逻辑单元——单一意图、纯格式化 / 重命名独立、
  不攒"补一行"碎片；PR 整理后保留的每个提交必须可编译（bisect 可用）；合入必须绿（CI）
- push 前自查：diff 完整、无半成品、无调试代码、注释到位（继承 harmony §提交纪律）
- 消息写"做了什么 / 为什么"，不写"修复上次的…"（同源）
- PR 开启前：rebase -i 整理为逻辑级提交序列——fixup 掉纯噪音（typo 类），保留逻辑步骤；
  整理不是 squash，禁止把整个任务压成一个提交
- 纯文档 PR 例外：`docs/*` 分支单意图、由 GitHub squash 合入（ADR-0005 / ADR-0010）；
  多提交合法，不必先在本地压成一个提交——"禁止整体 squash"只约束代码任务
- 整理时机只允许 PR 前或评审期间增量；**approved 后不再改写**，要改退回重审
  （settings 开 Dismiss stale pull request approvals：新 push 自动作废 approval——
  纪律机制化；副作用 = 评审期间追加 commit 也作废 approval 需重审，与规则一致）
- conventional commits 适用面：合入 dev/main 的内容；feat 内 WIP 豁免；
  scope 白名单：web / api / infra / ci / docs / deps
- push 下限 = 任务级即推（每任务至少一推，防 agent 长任务丢失现场）
- 协作闭环（不依赖 Issues）：SPEC 评审通过（人类核心成员）→ 切任务分支
  feat/spec-N-tM-短名 → PR → 人类核心审查（非实现者）→ --no-ff 合入 dev
- GitHub Issues / Projects 为可选执行追踪层：任务真源是 spec 的任务分解节
- 任务状态面板（Obsidian，仓库外）：**不属于项目内文件**——不入库、不占仓库路径、
  非规则/账本真源（任务真源 = spec 任务分解节）；agent 可按用户指定的位置即时重新
  生成（内容 = 当前 repo 状态快照），刷新时机由约定触发（现约定：每次合并 PR 后）
- 合并权限：3 名核心成员拥有 spec 评审权与收口合并权；非核心成员提 PR 由核心审
- 新增依赖（Go module 与 npm 包）：PR 描述声明其许可证——MIT/Apache/BSD 可入，
  GPL 系评估传染，无许可证禁入
- 本地钩子（t3 起，lefthook）：`task setup` 安装并启用 `.gitmessage`；`commit-msg` fail-closed
  校验 trailer（不代填；`--no-verify` 可绕过，由 CI 补位）；`pre-commit` 按后缀分流
  （Go `gofmt`、web `prettier`、shell `bash -n`）
- lefthook 配置纪律：修复类 job 必须 `stage_fixed: true`（否则格式化结果留在工作区、不进本次
  提交）；需要子目录 CWD 的 job 写 `root:`（如 `root: apps/api`），pre-commit **不得**写
  `root: "."`（会清空文件集、job 直接 skip，v2.2.2 实测）；`commit-msg` 的 `root: "."`
  只改 CWD，安全

### agent 署名（`Assisted-by`，opt-out）

- **每条提交都必须带 trailer**：agent 参与的写 `Assisted-by: <harness>:<model>`，纯人类提交写
  `Assisted-by: none`；缺席即判定违规——opt-in 下 CI 只能校验格式、不能校验存在性，漏写不可检测
  （2026-11-14 首提交事故的直接成因）
- 位置 = commit message **末尾的 trailer 块**（`git interpret-trailers` 可解析处；正文出现不算）；
  键名大小写敏感；值 ASCII 无空格；多参与方各一行（键可重复），行序 = 参与顺序、**不表达权重**
- 示例：`Assisted-by: DSH:deepseek-v4.1-flash-1017`（model 用登记表键，快照后缀照抄）；纯人类提交
  `Assisted-by: none`
- 重写语义（trailer **跟内容走，不跟操作走**）：无冲突 rebase / fixup / squash 原样随行；冲突解决者
  追加自己一行；整理执行者不记；**merge commit 不记**——平台生成的合并提交不注入内容，与整理执行者同理，
  审计与 CI 校验均以 `git log --no-merges` 为准（2026-11-14 实测：GitHub 生成的 merge commit 无法携带 trailer）
- `author` / `committer` 恒为人类；来源是**声明（claim）非证明（proof）**，不得用于归责或能力认定
- 身份来源：agent 自述 + 配置查证（harness model 配置 > 系统提示 model id > 自省命令）；信源冲突或
  精确不到版本粒度时**问人，不猜**
- 强制两层：`commit-msg` 钩子（t3 落地）fail-closed（缺 trailer 即中止，**不代填**——静默补 `none` 会把 agent
  提交误标为人类提交）；t0 CI 逐提交正则校验（唯一能挡 `--no-verify` 的一层）；PR 描述同列该串（与 trailer 互补）
- 校验正则：`^Assisted-by: (none|[A-Za-z][A-Za-z0-9]*:[a-z0-9][a-z0-9.-]*)$`；决策理由见 ADR-0004

harness 键（闭合登记；新值 = 本表加一行 + PR）：

| 键 | 全称 |
| --- | --- |
| `DSH` | DeepSeek Harness |
| `ClaudeCode` | Claude Code |
| `ZCode` | ZCode（GLM） |
| `Pi` | Pi |

model 键（= 官方 API id 的 kebab-case 小写；快照后缀照抄，不自行附加日期——commit date 已在提交里）：

| 键 | 官方全称 |
| --- | --- |
| `deepseek-v4.1-flash-1017` | DeepSeek-V4.1-Flash-1017 |
| `glm-5.3` | GLM-5.3 |
| `glm-5.3-flash` | GLM-5.3-Flash |

### commit 级评审署名（`Reviewed-by`，opt-in）

- **时点**：重要 commit 在**提交前**由另一评审者（agent 或人类）审完整个待提交内容，commit 生成时在 trailer 块写 `Reviewed-by: <harness>:<model>`；提交后才发生的审查不回头改旧 commit，交给下一个 commit 或 PR。
- **范围**：`Reviewed-by` 表示整个 commit 的待提交内容都被该 reviewer 审过；只审部分文件不写，未覆盖部分留到下一个 commit / PR。
- **opt-in**：不强制要求存在；缺失不判违规，也不代表未评审。CI 只校验格式（若出现），不校验存在性。
- **互审**：reviewer 必须与同一 commit 的所有 `Assisted-by` 参与者不同（互审不是自审）；人类评审的 `none` 是角色标记，不参与身份比较；多个 reviewer 不重复。
- **重写**：内容变更（amend 改树 / 冲突 rebase / fixup）使 `Reviewed-by` 失效，须重审；tree 不变（message-only / 无冲突 rebase）可保留。
- **位置**：trailer 块，建议 `Assisted-by` 在前、`Reviewed-by` 在后；一个 reviewer 一行，行序 = 评审顺序，不表达权重；merge commit 不写。
- **正则**：`^Reviewed-by: (none|[A-Za-z][A-Za-z0-9]*:[a-z0-9][a-z0-9.-]*)$`；人类评审写 `none`，多人时具体人名以 PR 评论 / journal 为准。

### 评审协议（review）

- 状态机：`REVIEW: BLOCKED`（评审者）→ `REVIEW-FIX`（作者）→ `REVIEW: PASS`（评审者）；一条评论承载一个状态，不在评论区聊天；ID 用 `B` / `N` / `Q`，阻塞项必须带证据；两轮上限，第二轮仍 BLOCKED 则拆 PR、缩范围或升级给人决策。
- `REVIEW: PASS` 是评审结论，不是 GitHub approval；同账号自审路径 = `COMMENTED` 评审 + `REVIEW: PASS` 评论 + 人类明确合并授权；`required_approving_review_count=0`（单人多 agent 阶段）。
- PASS 必须带 `target <sha>`、`body-sha256: <sha256(title + "\n" + body)>`；所有状态评论都带角色行：`REVIEW: BLOCKED` / `REVIEW: PASS` 末行 `Reviewer: <harness>:<model>`，`REVIEW-FIX` 末行 `Author: <harness>:<model>`（键表同 `Assisted-by`，人类写 `none`）。这是协议软要求：CI 不校验评论，缺失不阻断合并，但留下状态无主的缺口。
- PASS 后 PR 标题/描述冻结：任何编辑作废 PASS，必须重新 PASS 并重新快照；PR 描述只放最终变更，末行 `Assisted-by` trailer 之后不得有内容。
- docs：squash，合并用 PASS 快照生成正文；code：`--no-ff`，merge commit 正文为空，分支提交 trailer 由 attribution 校验。
- 人类授权后 agent 可执行合并（跑脚本）；未授权不得 merge。评审状态只在评论，PR 描述不写评审过程。
- PR 级评审只在评论层；commit 级提交前互审走 `Reviewed-by`（见「commit 级评审署名」）；两者记录不同事件，不互相替代。不把评审状态写进 PR 描述（`pr-meta` 拒绝 `REVIEW` / `Reviewer` / `Author` / `Reviewed-by` 行）。键表闭合——未登记 runtime 先走登记 PR；`glm-5.3` 与 `glm-5.3-flash` 是两个键。
- 历史 PASS 缺口（#27 / #28 / #29 缺席或署名与事实不符）与历史 commit 级评审均不回填；journal 记录，规则向前生效（ADR-0011）。
- docs 单意图、提交数不限（ADR-0010）。

## 验证命令（agent 自证完成的唯一方式；未跑通不得声称完成）

**生效时点**：工具链随 t1（根 Taskfile）与 t2（Go）落地——此前仓库仅含文档与 CI 骨架，纯文档改动（*.md）无需执行下表任何命令，确认编号 / 链接 / 词表自洽即可（ci:docs 立项前的轻量路径）；**t0 至 t1 之间的空档**（ci.yml 已入库、task 尚不存在）：本地无可跑命令，验证 = PR 上的 GitHub Actions 结果 + YAML 语法人工核对。

| 改动范围 | 必跑 |
| --- | --- |
| apps/api/**/*.go | `cd apps/api && go build ./... && go test ./... && golangci-lint run ./...` |
| apps/api 的 handler / DTO / ent schema | 追加 `task gen && task gen:check` |
| apps/web/**/*.{ts,vue} | `pnpm --filter @learnfolio/web lint && pnpm --filter @learnfolio/web typecheck` |
| lefthook.yml / scripts/hooks/** / scripts/lib/attribution.sh / .github/scripts/check-{attribution,pr-meta}.sh | `pnpm exec lefthook validate`；好 / 坏 trailer 双路径；`--no-verify` 后跑 CI 脚本验证补位 |
| 任何改动 | 提交前 `task ci`（CI 管线本地等价物，全绿才推） |

- 生成物报错时禁止改生成物：回源头（Go struct / ent schema）改，再 task gen
- 禁止跨 app import：apps/web 不引用 apps/api 的任何文件，唯一通道是生成的 schema.ts
- 新增 Node 依赖一律走 pnpm-workspace.yaml 的 catalog:，不在 app 的 package.json 写死版本
- 钩子改动必须实测：带合法 trailer 的提交成功；缺 trailer 的提交被 `commit-msg` 中止；
  `--no-verify` 绕过后的补位用 `EVENT=push BEFORE=<parent> AFTER=<head> bash .github/scripts/check-attribution.sh`
  本地复跑验证（与 CI 同脚本、同正则源）
- `check-pr-meta.sh` 改动用合成 `GITHUB_EVENT_PATH` 跑 good / missing 两路径（末行 trailer
  合法 / 缺失）；它只校验 PR 描述，不能用 push 区间测试替代

## Go 分层纪律

- 依赖单向：handler → service → repository；repository 是唯一碰 DB 的层
- internal/handler 放 HTTP 层与 request/response DTO（可带 huma 注解）
- internal/model 放领域/持久化实体：零 huma 注解，永不出现在 OpenAPI spec
- ent 生成代码入库（Phase 2 起）：apps/api/ent/ 提交，仅 ent/schema/ 是手写源（clone 即 build；查询必须对照生成的强类型 API 写）
- 预定目录 config/ store/ httpx/ telemetry/ 随首个代码出现，禁止提前建空目录
- 第二个 cmd/* 二进制出现当天，wire() 组装从 main.go 提入 internal/app/

## 契约与生成物

- 生成物不手改：apps/web/shared/api/schema.ts、ent 生成代码、apps/api/docs/openapi.yaml 一律改源头后重新生成
- 契约产物显式导入：schema.ts 位于 shared/api/（不进 shared/types、shared/utils 自动导入目录），引用一律 #shared/api/schema
- task gen 必须串行（Taskfile 用 cmds: 链式，不用并行执行的 deps:）；migrate:diff 独立任务（需 Docker），不进 gen:check
- openapi 子命令自带写盘（--output，内部临时文件成功后原子替换），禁止 stdout 重定向：shell 管道参与编码，Windows PowerShell 的 `>` 按字符串重编出 UTF-16，gen:check 字节一致性即毁
- 换行纪律：.gitattributes 锁 eol=lf——git 不读 .editorconfig，换行漂移会让 gen:check 永久红；生成物已标 linguist-generated
- SQL 安全（Phase 2 生效）：绕过 ORM 的 raw 查询必须占位符参数绑定；禁止 fmt.Sprintf / 拼接 / f-string 组装 SQL
- 错误响应统一 huma 内建 RFC 9457 problem+json（huma.Error*），不手搓错误信封

## 工具版本

- 生成器 CLI（ent codegen / atlas）用 go.mod 的 tool 指令锁定（Go 1.24+，Phase 2 首个工具落地时启用）；禁止 CI 中 go install ...@latest
- golangci-lint 版本单一源：Taskfile var；CI 与 task setup 共同消费同一数字（t2 的 CI 直接调 task setup:go；不进 go tool，避免污染 module graph；.golangci.yml 顶层 version 键兜底防 v1/v2 跨界）
- Node / pnpm 版本由 packageManager 字段与 .nvmrc 锁定
- lefthook / Prettier 版本由 `pnpm-workspace.yaml` 的 catalog 锁定；根 `package.json` 只写
  `catalog:`，`task check:catalog` 同时校验根与 apps / packages

## TODO 注释规范

| 标记 | 颜色 | 含义 |
| --- | --- | --- |
| NOE | 蓝 | 高级注释，标识一个块或重要注释（可在 TODO 中查看） |
| TEST | 紫 | 测试用块 |
| MARK | 橙 | 标记某一行（如设定的参数） |
| TODO | 黄 | 标准待办提示 |
| WARN | 琥珀黄 | 警告/风险，需注意但未必是缺陷 |
| BUG | 红 | 代码级 bug |
| FIXME | 红 | 功能级缺陷，需修复 |
| update | 绿 | 提示可能需要更新 |
| Tips | 灰蓝 | 小提示 |

注：颜色由 IDE 的 TODO 高亮插件（如 TODO Tree）渲染，配置随 .vscode 基线分发（已随 t5 入库，PR #20）；
语义为主、颜色为辅。进 main 的 BUG / FIXME 须关联 SPEC 编号或 issue 号。

## 作者键登记

| 作者键 | 成员（GitHub 用户名，仅备注，非绑定） | 登记日期 |
| --- | --- | --- |
| foamshadow | foamshadow | 2026-11-12 |
| DevLMax28 | DevLMax28 | 2026-11-14 |
| pray-cheems | pray-cheems | 2026-11-14 |
| codeever | codeever | 2026-11-14 |
| cn-baiqiang | cn-baiqiang | 2026-11-14 |

作者键用于 docs/learning/ 一级目录与 journal 文件名（见 docs/README.md）。

## 继承条款（来源：harmony-wechat / foampray，2026-11-14 裁剪）

判据（ADR-0008）：工具无关 + 对 5 人团队成立 + 有消费者；每条注来源，与既有条款冲突时以既有条款为准。

- 事故→制度闭环：事故当天或最近一次 PR 内，journal 记事故 + 落一条带判据的条款 + 关联 PR（H §提交纪律 / 复盘）
- 第一父链 = 任务账本：dev 第一父链只允许任务 merge 与 docs 单提交（H §分支纪律）
- 收口冻结 + 文档对齐核对：文档不得落后于代码，先改文档再合并（H §里程碑收口）
- 变更链同 PR 同步：改 spec 同批改下游文档与验收（H §文档驱动）
- 注释写"为什么"；TODO 落码，不留在聊天记录（H §注释要求）
- 验收如实记账：受限 / 跳过 / 缺失都入账，不粉饰（H 复盘）
- 任务收尾：日志 / 进度 / 代码一起提交（F §任务收尾检查）

改写继承（按 PR 门禁）：

- 提交前确认 → 双授权 + WIP 免审（ADR-0007）
- push 凭指令 → 任务级 auto-push + 每次报告
- 未完成不提交 → WIP 豁免、保留提交必须绿
- docs 直推 dev → `docs/*` + squash（ADR-0005）
- 里程碑表 + 收口 → roadmap + SPEC + 收口检查单（收口流程后续再优化）
- 计划=事实 → 验收条目按实际勾选；执行差异记录进 journal；规格语义变化走 spec 变更记录

不取：superpowers 插件链、ArkTS / DevEco 命令与单模块结构、课程语境概述、PERT 图、双 README 分工。

## 规范变更

- 本文件的改动走 PR + review；事故驱动变更在 journal 记事故并关联 PR
- **沉淀三问**（试错 → 文档的落位判据）：① 是过程还是结论？过程（事故 / 讨论 / 复盘 / 执行差异）→
  journal（事故须关联 PR）；结论（选型 / 规则 / 策略）→ ADR；同一事件可两者都落、用 `related` 互链。
  ② 决策还是细节？决策 → ADR（含被否方案）；细节 → 本条或 guides。③ 第一个消费者是谁？
  无 → `proposals/` 孵化；有 → 随其 PR 一起到达
- **流程冻结线**：Phase 0 收口（v0.1.0）前允许规则快速迭代；此后规则进入基线，只走 ADR 取代链 + PR；
  历史默认不重写，message-only rewrite 按 ADR-0010 受控例外，内容仍不重写。
- 重决策推翻走 ADR 取代链（新 ADR 声明取代，不改旧文件）
- 本文件不自带版本号，版本语义由 tag 基线承担
