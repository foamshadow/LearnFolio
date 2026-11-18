---
id: ADR-0006
title: "文档体系与规则生长：六类文档、取代链、随消费者到达"
status: accepted
date: 2026-11-14
author: foamshadow
tags: [se-arch]
related: [ADR-0001, ADR-0003, ADR-0004, ADR-0005, SPEC-0001]
supersedes: ""
superseded-by: ""
---

# ADR-0006：文档体系与规则生长

> 补记说明：本篇把建仓前策划期的文档体系设计（过程未随仓库保存）与建仓后一天的运行修正合并为一条决策记录；
> 操作细则见 `docs/README.md`，规则条款见 `AGENTS.md` 文档体系节。

## 背景（Context）

项目以"文档驱动 + 自指飞轮"为定位：spec 是 agent 的施工图，journal / learning 是内容素材，开发史本身是展示内容。
约束：5 人 + 多 agent；写作主体既有人也有 agent；文档要能被机器检索（frontmatter / 编号）；变更语义必须可判定
（哪些能随便改、哪些改了就失义）；仓库要自足（clone 后不依赖仓库外记录即可施工）。

## 决策（Decision）

### 1. 六类文档，四种变更语义

| 类型 | 语义 | 状态机 |
| --- | --- | --- |
| `specs/` | 受控 | draft → ready → done / superseded / abandoned |
| `adr/` | 不可变（正文四节） | proposed → accepted → deprecated / superseded |
| `journal/` | 可变 | 无状态机（一篇 = 一个事件） |
| `learning/<作者键>/` | 可变 | draft / verified |
| `guides/` | 可变 | draft / verified |
| `proposals/` | 可变偏受控（孵化区） | idea → draft → review → adopted / rejected |

### 2. 编号与取代链

- `SPEC-NNNN` / `ADR-NNNN`，4 位零填充，递增不复用；起草前 fetch 取 max+1；
- ready / accepted 即冻结编号与文件名；**draft 状态的编号文档不得被引用**（提及用标题）——改号成本因此为零；
- 方向变更 = 新编号 + 双向链（`supersedes` / `superseded-by`，只指直接取代者）；
  部分推翻 → 旧文档 `deprecated`（不挂链）、新文档写明取代范围；
- 验收条目 A-N append-only（废弃划掉留槽）；语义变更走尾部"变更记录"追加，历史不删。

### 3. 孵化区与毕业

- proposals 不占编号，slug 一经创建即冻结；毕业后**正文替换为指针**（防双真源），frontmatter 记 `adopted-as`；
- 例外：roadmap 按 Phase 段落毕业，在文内显式声明。

### 4. 规则随第一个消费者到达

AGENTS 不一次写满：每个规则节恰好先于或伴随它的第一个消费者出现（t0 验证命令、t2 Go 纪律、t3 钩子、t4 继承条款）。
没有消费者的规则无法验证，只会成为没人遵守的教条；规则与实现同 PR 评审，语境才不会丢。

### 5. 真源层级

AGENTS = 规则真源（做什么）；ADR = 决策真源（为什么，含被否方案）；guides = 教学衍生物（怎么理解，**不得新增规则**）。
冲突以 AGENTS 为准，冲突本身视为 guides 的 bug。仓库内文档不引用仓库外记录；建仓前的过程写明"未随仓库保存"。

### 6. 流程冻结线

Phase 0 收口（v0.1.0）前允许规则快速迭代；此后规则进入基线，只走 ADR 取代链 + PR，不重写已发布历史。

## 被否方案（Alternatives）

| 方案 | 否决理由 | 翻转条件 |
| --- | --- | --- |
| 文档统一放 wiki / CMS | 版本、评审、引用与代码脱节，无法进 PR 门禁 | 内容团队与工程团队分离 |
| 单一 `docs/` 平铺 | 变更语义混杂，受控层与可变层无法区分 | 文档类型收敛到两类 |
| 只保留 journal（流水账） | 没有决策沉淀与施工图，agent 无法按 spec 开工 | — |
| 规则一次写全（big design up front） | 无消费者的规则无法验证，且会滞后于实现 | 需求完全稳定 |
| 文档层记 agent 署名 | 质量难核验，溯源价值低于提交层（ADR-0004） | 时间线页需要按文档维度切分 |
| 仓库外文档作为施工输入 | 破坏仓库自足，clone 后无法施工 | 外部文档纳入同一版本控制 |

## 后果（Consequences）

- 六类文档、四套状态机、一条取代链：新成员需要一次导读（`docs/README.md`），入口是"决策线"表。
- 规则渐进增长：AGENTS 初版只有 day-0 八节，后续随任务到达——好处是每条规则都有消费者与评审语境，
  代价是早期规则看起来"不完整"。
- 取代链只指直接取代者，登记 O(1)；找现行沿链跳，考古沿链回溯。
- proposals 毕业后正文变指针，历史留在 git 与演进记录里。
- 冻结线让前期可快速迭代、后期必须走变更控制，分界点是 v0.1.0。
