---
title: "docs 写回触发与收口清单：事件矩阵与预先性记录"
author: foamshadow
date: 2026-11-22
status: adopted
tags: [se-arch, se-review, tool-git]
related: [ADR-0006, ADR-0011, docs/proposals/task-lifecycle-gates.md]
adopted-as: "ADR-0013（事件边界/二值判定/预先性记录/journal 写回与审查记账）+ AGENTS「文档写回」条款（清单 1/2、learning 例外、时点锚、终态就位）+ journal _template.md 审查记录表 + PR 描述模板自查区"
---

# docs 写回触发与收口清单（proposal）

> **已毕业**（2026-11-22）：决策级落 **ADR-0013**（journal 写回与审查记账：
> 事件边界、二值判定、预先性记录），操作级落 **AGENTS「文档写回」条款**
> （清单 1/2、learning 成员自主例外、时点锚、终态就位）；配套落点 = journal
> `_template.md` 审查记录表 + PR 描述模板自查区 + README 决策线行。
> **真源以 ADR-0013 与 AGENTS 为准**，本文件不再维护。

## 演进记录

- 2026-11-22 起草：Phase 1 spec 暂停期第三个 proposal，起因 = ci-gate C4
  漂移（PR #62 补修）暴露的"文档与事实不对应、文档之间不对应"问题。设计
  要点：事件×文档写回矩阵、合并请求五项清单、预先性记录原则、learning 成员
  自主例外、二值判定（无尾随通道）、journal 规则分组转正（本 proposal 带
  四条，其余留 task-lifecycle-gates 毕业批）。设计决策全程与作者对拍完成
  （二值判定取代尾随通道、learning 判据否决、清单 7→5 精简）。
- 2026-11-22 round 1 评审修正（PR #63，Pi:glm-5.3 BLOCKED 3B+4N）：B1 矩阵
  行轴错位修正——改按 tlg 实际流程编号（③整理门/⑥push/⑦PR 创建/⑧pr-review/
  ⑨合并请求），"②③ 开发/事故"拆行（事故独立成全局行），删"⑨ 合并落地"伪
  行（tlg ⑩ 收尾明文非停点），§1"10 停点"改"10 步流程（停点表不与步骤一一
  对应）"；B2 ⑨ 行边界外写回删除——SPEC 回填与 journal PR 号记账行改窗口内
  落账（AGENTS 窗口条款现行口径），⑨ 为纯核验行；B3 清单 1 时点修正——
  自查区随窗口增量维护至 PASS 前完整，合并请求只核验不写入（PASS 后描述
  冻结），缺口走"补提交 → 重新 PASS → 再授权"回环。非阻塞：N1 ADR-0003
  止血措辞改"deprecated + 锚点分级注记"（毕业指针化保留给 merge-integrity
  先例）；N2 双落点分流水（决策级进 ADR：二值判定/预先性记录/journal 写回；
  操作级进 AGENTS：清单/learning 例外/时点锚）；N3 ⑨ 行格语义歧义随"纯核验
  行"改法消解；N4 learning 例外落 AGENTS 时显式声明澄清现行"事故驱动笔记"
  描述语（§9 已落）。
- 2026-11-22 round 2 PASS（PR #63，Pi:glm-5.3 缩范围复审，target c347f5c）：
  B1–B3 全闭、N1/N2/N4 落实、N3 随 B2 消解。毕业批（同 PR）：正文指针化 +
  ADR-0013 + AGENTS 条款 + journal 模板 + PR 模板自查区 + README 决策线行
  + git-workflow / doc-system 维护触发器同步 + #60 遗留注记。
