---
title: "PR 评审协议：结构化评论、两轮收敛与交流步数优化"
author: foamshadow
date: 2026-11-15
status: adopted
tags: [se-arch, tool-git]
related: [ADR-0004, ADR-0005, ADR-0007, ADR-0009, SPEC-0001]
adopted-as: "AGENTS 提交纪律/评审协议子节 + docs/guides/review.md + PR 模板自检"
---

# PR 评审协议（proposal）

> 已毕业（2026-11-17）：规则真源 = `AGENTS.md`「评审协议」子节；教学 = `docs/guides/review.md`；PR 模板自检 = `.github/PULL_REQUEST_TEMPLATE.md`。本文正文已替换为指针，防双真源；演进过程保留在下。

## 演进记录

- 2026-11-15 起草。起因：PR #13 三轮评审——第一轮 3 阻塞 + 3 非阻塞，第二轮修正引入 A9 伪先例与时区错误，第三轮才发现 PR 标题/描述未同步。结论：问题不在单条意见，而在评审缺少状态机与完整清单；先以 proposal 孵化，试点后再迁 AGENTS。
- 2026-11-15 修正记录落点：初版误把 PR 描述当评审账本，导致 #13 / #15 的 squash 正文携带评审修正记录。改为「评论承载状态、commit 只写最终态、journal 承载过程」，撤掉 PR 模板的评审结论节；已合入历史不重写，记 journal 执行差异。
- 2026-11-16 试点失败样本：#22 PASS 后 PR 描述被追加评审清单，squash 正文 trailer 失位，dev push attribution 红；补 PASS 冻结、`body-sha256`、`Reviewer` 行；按 B 记录失败样本，不延长试点。
- 2026-11-17 毕业：规则落 AGENTS「评审协议」子节；新增 `docs/guides/review.md`；PR 模板增加自检节；本文正文改指针。
