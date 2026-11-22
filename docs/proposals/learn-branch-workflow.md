---
title: "learn 学习分支工作流：成员实现线与过程史入库"
author: foamshadow
date: 2026-11-22
status: draft
tags: [se-arch, se-review, tool-git]
related: [ADR-0003, ADR-0007, docs/proposals/task-lifecycle-gates.md]
adopted-as: ""
---

# learn 学习分支工作流（proposal）

## 背景

项目定位含 AI 全栈实践的学习场（多成员），但现行分支七类全部是产品任务流（agent
主导：feat/fix/hotfix/backport/docs），成员学习没有载体——成员想跟随同一 spec 任务
做自己的实现，没有分支类型可归：`feat/*` 是 agent 任务分支，成员个人提交无家可归。

学习场景的诉求与产品任务流不同：

- **同一任务目标，双线并行**：agent 生成标准实现（标答，走正常 feat 流程），
  成员在各自分支上独立实现——宽松管（可随时看标答参考、可 agent 辅助），学习
  价值在过程而非产物。
- **最终只回收学习 journal**：成员的功能实现不进 dev 产品线，学习笔记
  （`docs/learning/<作者键>/`，目录已存在）入库。
- **过程史（commit 链）是记录对象本身**：成员的 wip/推翻重来正是学习过程的
  证据，需要永久可考古——这与"合并后删分支"的现行做法直接冲突，需要挂链机制。

与 docs/proposals/task-lifecycle-gates.md 的关系：learn 流程是**人类任务**的
宽松裁剪实例（agent 流程的三项配置/整理门/break 审查全部不适用），保留的是
确认任务与 journal 回收评审两个停点——两者构成流程谱系的两个物种。

## 提议

### 1. 分支三层结构

| 分支 | 命名（两段式） | 生命周期 |
| --- | --- | --- |
| 标答分支 | `feat/spec-N-tM-<短名>`（现有类型，agent 标准线） | 正常 feat 流程 |
| 聚合分支 | `learn/spec-N-tM`（任务锚 = spec 全锚，防跨 spec 撞名） | 聚合合并后删除 |
| 成员分支 | `learn/spec-N-tM-<作者键>`（如 `learn/spec-0001-t2-foamshadow`） | 任务回收后删除 |
| 中和分支 | `learn-final/spec-N-tM-<作者键>` | **脚本生成，聚合 merge 后即删** |

任务锚固定为 spec 全锚（`spec-N-tM`）；若开放问题 1 未来选择独立学习任务单，
锚 = 任务单 slug——原则：锚必须全局唯一，裸 tM 跨 spec 会撞名。命名**两段式
格式与 D/F 判据不变，但前缀词表需扩展**：AGENTS 现行"前缀取七类之一"不含
`learn/` / `learn-final/`，前缀词表（含单段名禁令清单与 CI 方向矩阵）随
试点前置修订 / 毕业扩展（见 §7）。

### 2. 全流程

```
spec 任务就绪（spec-N-tM）
  ├─ feat 线：agent 标答 → 正常流程 PR → --no-ff 合入 dev（内容基准）
  └─ learn 线：
     learn/spec-N-tM 聚合分支（dev 切，尽早——避免与 feat merge 的时序纠缠）
     learn/spec-N-tM-<作者键> × N（成员从同基点切）
       宽松开发：自由提交（wip 免审、无告知义务——人类任务裁剪）
                可随时看标答、可 agent 辅助（Assisted-by 照常声明）
       （trailer 纪律全量适用：纯人类提交写 `Assisted-by: none`——宽松仅豁免
        审批与告知，不豁免 trailer；漏写会使聚合合并后的 dev push CI 红）
       完工 → learn-finalize 生成中和分支（见 §3）
            → 聚合分支 merge --no-ff 中和分支（本地操作，无需 PR）
       全员齐（或截止时间到）→ 聚合分支开 PR（diff = 全员 journal）
            → 一次评审（journal 记账质量）→ --no-ff 合入 dev
       清理：learn/* 与 learn-final/* 全删
```

dev 最终状态：标答内容 + N 份 journal；`--graph` 全图每任务恒两条 merge 线
（feat 线 + learn 聚合线），成员过程链封装在聚合子图内。

### 3. 中和分支机制（核心手法）

成员分支 tip = 功能代码 + journal——功能不能进 dev 树，过程 commit 要上图，
两者由**中和提交**一次达成：

1. 从成员分支 tip 切中和分支 `learn-final/spec-N-tM-<作者>`；
2. **树设置为聚合基 + journal**："聚合基" = finalize 时刻的聚合分支 tip
   （序贯 finalize 下前批成员的 journal 已在 tip 上，中和树含他人 journal
   不影响三方合并干净）；`git restore --source=<聚合分支> --staged
   --worktree -- .` 恢复全部既有文件到 index 与工作区、`git rm` 成员新增的
   功能文件、保留 `docs/learning/<作者键>/`；
3. 提交中和 commit（`docs: learn 中和——仅保留 journal`）；
4. 聚合分支 `git merge --no-ff learn-final/...`——三方合并的 diff **仅 journal
   文件**（其余内容与聚合基逐字节一致），DAG 挂上成员完整 commit 链。

效果：dev 树零功能代码污染；`git log --graph` 上成员的每一条 wip、每一次
推翻重来永久可达（分支删除后仍可考古）。

**脚本接口**：`scripts/learn-finalize.sh <成员分支名>` 自动完成上述步骤
（含边界处理：新增文件删除、共有文件恢复、docs/learning 保留）。

### 4. 硬约束与规则适配

- **聚合合 dev 走 `--no-ff` 禁 squash，且禁用 `--mode docs` 覆盖**：现行
  merge.sh 的路径判定按 head ref 前缀（`docs/*` → docs/squash，其余 →
  code/`--no-ff`），**不看 diff 内容**——`learn/*` 聚合分支天然落入 code 路径
  （`--no-ff`），路径判定本身无需新增 learn 规则；约束仅一条：操作者不得用
  `--mode docs` 覆盖（squash 会生成单提交、丢掉第二父，成员 commit 链从 dev
  不可达——过程史全丢）。merge.sh 可加一句 learn 分支的 mode 覆盖拦截（防御性）。
- **merge message 第六类格式**：`合并 learn spec-N-tM：一句话`——CI 标题
  正则同步加 alternation（SPEC-0001-A5 的取代链或变更记录承载）。
- **dev 第一父链读法扩展**：任务史 = `M-feat` + `M-learn` 两节点/任务，按
  message 前缀区分（现行机制，加 learn 前缀类即可自洽）。
- **merge commit 不带 trailer**（平台生成，ADR-0004 既有语义）——成员的参与
  记录在成员 commit 自身的 `Assisted-by`（agent 辅助则声明）与 journal 文件内。

### 5. 评审裁剪（人类宽松流程）

- **开发期零门禁**：无三项配置（agent 申请机制）、无整理门/break 审查、无
  逐条审批——成员是人类，task-lifecycle-gates 的 agent 停点全部不适用。
  trailer 纪律是例外（见 §2，全量适用含 none）。
- **唯一新增评审停点：聚合 PR 评审**——焦点是 journal 记账质量（事实、结构、
  可读性），不是代码质量门（代码不进树）；按评审协议执行（BLOCKED →
  REVIEW-FIX → PASS，快照合并）。每任务一次集中评审，N 份 journal 一批。
- 成员任务停点全景：**确认任务 → 自由开发 → 聚合 PR 评审 → 合并授权**——
  三停点与 agent 流程（确认任务 + 评审 + 合并授权）同构，其中评审承载学习
  维度；合并授权同 agent 流程口径（现阶段人类授权，agent 只执行脚本）。

### 6. 开放问题

1. **学习任务来源**：复用产品 spec 的 tM（有真源、双线对照自然）还是独立
   学习任务单（无 spec）？——倾向首学期复用 spec tM，独立任务单待需求出现。
2. **聚合 PR 的评审者**：按标准 docs 评审协议（DSH 核事实与账本）起步，还是
   人类核心成员做"导师视角"评审（学习反馈维度）？——首期按标准协议起步，
   教学反馈维度待实践后议。
3. **成员 journal 内容约定**（记什么：过程叙事 / 关键决策 / 踩坑 / 与标答
   对照的心得）——在 journal 模板的 learning 变体里定，随首个任务实践补。

### 7. 毕业条件

- **演练前置最小修订 PR**（授权通道，先行）：现行 CI 方向矩阵不认
  `dev|learn/*`（会直接判红，ci-ok 与 merge.sh 均拒），AGENTS 前缀词表也不含
  `learn/`——演练前先落一个最小修订 PR：AGENTS 分支节加 learn 试点条款 +
  `.github/scripts/check-title.sh` 方向矩阵加 `dev|learn/*` 变体 +
  SPEC-0001-A5 变更记录。**不落此 PR 演练无通道**（试点条款标注"试点期，
  随毕业收编或回滚"）。
- **首个学习任务全流程演练**：6 分支齐开 → 至少 2 个成员完成 learn 分支 →
  中和 / 聚合 / 评审 / 合并全链走通 → dev DAG 挂链验证（merge 后、删分支前
  `git branch --contains <成员功能 commit>`；或删后
  `git merge-base --is-ancestor <成员 commit> origin/dev`）→ 分支清理后
  过程史仍可考古。
- **learn-finalize 脚本实测**：覆盖三类边界（成员新增文件、共有文件修改、
  docs/learning 路径保留）。
- **复盘无致命缺陷** → 毕业：
  - **proposal 去向**：毕业为 ADR（新编号），frontmatter `adopted-as` 记录；
    ADR 内声明与现行文档的关系——ADR-0003 已 deprecated（分支类型现行真源
    在 AGENTS 分支节），本 ADR 声明 learn 类型的加入与 AGENTS 分支节的形成
    取代关系，正文指针化。
  - **正式层收尾**：AGENTS 分支节从试点条款转正（七类 → 九类：learn 聚合/
    成员，learn-final 为脚本临时分支不入表或注明）、merge message 第六类与
    CI 正则走 SPEC-0001-A5 取代链、merge.sh 加 learn 分支的 mode 覆盖拦截
    （防御性，非路径判定）、`docs/guides/git-workflow.md` 补 learn 节、
    journal 模板 learning 变体登记（开放问题 3 一并定）。
- 本 proposal 与 task-lifecycle-gates 的毕业互不依赖：learn 演练可先于
  Phase 1 spec 进行（学习任务可复用已有 spec 的任务，无需新 spec）。

### 8. 被否的替代设计

- **成员自己摘 journal 走 docs PR**：零新机制，但人工摘取步骤 + 过程史无法
  挂 dev DAG（分支删除即丢失）——学习记录的核心诉求落空。
- **archive/learn 归档分支 + `merge -s ours`**：commit 可达但 dev 主图不见
  过程线（`-s ours` 树不含内容、历史在旁路归档链上），journal 与过程史分离，
  且多一个永久引用——被本方案的真 merge 挂链取代。
- **直接 merge 成员分支进 dev（无中和）**：功能代码污染 dev 产品线——违背
  "只回收 journal"的根本诉求。
- **GitHub PR 直接 merge 成员分支**：PR 按钮 = 真合并，功能全进；`-s ours`
  手法则需本地操作 + 绕 RS-1 门禁（retract 式窗口）——复杂化被否，中和分支
  让 GitHub 原生 merge 直接可用。
- **成员分支不删（保留过程史）**：分支列表膨胀——DAG 挂链后无保留必要。
- **成员各自直接 PR 进 dev（无聚合层）**：dev 第一父链每任务 1 + N 个 merge，
  任务史读法稀释；聚合层让它收敛为恒定 2 节点，且聚合分支天然充当聚合 PR
  载体（N 份 journal 一次评审）。

## 演进记录

- 2026-11-22 起草：Phase 1 spec 暂停期的第二个 proposal。设计要点：分支三层
  （成员/聚合/中和）、中和分支机制（树=聚合基+journal、挂链靠 merge 第二父）、
  聚合合并 --no-ff 硬约束（防 squash 丢链）、人类宽松流程裁剪（单停点）。
  开放问题三项（任务来源/评审者/journal 内容约定）待首个学习任务实践。
- 2026-11-22 round 1 评审修正（PR #61，Pi:glm-5.3 BLOCKED 3B+4N+1Q）：B1
  merge.sh 判定事实修正——现行按 head ref 前缀判定、`learn/*` 天然落 code
  路径 --no-ff，"纯文档判成 docs/squash"为错述，删去；约束收敛为"禁用
  --mode docs 覆盖"+ 防御性拦截（核对了 scripts/merge.sh:233-239 实际实现）。
  B2 毕业条件时序死结——CI 方向矩阵不认 dev|learn/*、演练无通道，补"演练
  前置最小修订 PR"授权路径（AGENTS 试点条款 + check-title.sh 矩阵变体 +
  SPEC-0001-A5 变更记录）。B3 前缀词表矛盾修正（AGENTS"前缀取七类之一"，
  learn/learn-final 需词表扩展）+ 毕业产物补 proposal 去向（ADR-N +
  adopted-as + 与 ADR-0003/AGENTS 关系声明）。非阻塞：N1 trailer 纪律全量
  适用（含 none）显式化；N2 停点计数改"唯一新增评审停点"三停点同构；N3
  learn-finalize 实现注记（restore --staged --worktree、聚合基 = finalize
  时刻聚合 tip）；N4 挂链验证命令改 merge-base --is-ancestor；Q1 任务锚
  固定 spec 全锚防跨 spec 撞名。
