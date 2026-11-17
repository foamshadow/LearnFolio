<!--
标题速查（提交前删掉本段注释；五类合并变体 + docs squash 变体；短名段用空格，不是分支名里的连字符）：
- 合并 spec-0001-t1 短名：一句话              （feat/* → dev）
- 合并 fix 短名：一句话                        （fix/* → dev）
- 合并 hotfix 短名：一句话（发布 vX.Y.Z）        （hotfix/* → main）
- 合并 hotfix 短名：backport 自 vX.Y.Z         （backport/* → dev）
- 合并 Phase N 收口：vX.Y.Z                    （dev → main）
- docs: 一句话                                 （docs/* → dev，squash）
-->

<!--
自检（提交前删掉本段注释）：
- 标题 = 落地主题；docs 单意图（提交数不限，ADR-0010）；描述只含最终变更，无评审记录/试错
- 状态评论带角色行（BLOCKED/PASS: Reviewer；REVIEW-FIX: Author）；提交前互审的 commit 写 Reviewed-by；描述不写评审状态行（含 Reviewed-by）
- 描述末行是 Assisted-by trailer，其后无内容；PASS 评论含 target / body-sha256 / Reviewer
- docs 用 PASS 快照合并；code 走 --no-ff；不要手改 merge message
-->

## 变更

<!-- 做了什么、为什么；关联 SPEC 任务号 / ADR 编号 -->

## 验证

<!-- 跑了哪些命令、结果如何；纯文档改动写"编号 / 链接 / 词表自洽即可" -->

## 新增依赖

<!-- 新增 Go module / npm 包必须列许可证；无则写"无"（ADR-0002） -->

## 检查单

- [ ] 每个提交都带 `Assisted-by` trailer（agent 参与时；纯人类提交写 `none`）
- [ ] 合入内容使用 conventional commits（scope：web / api / infra / ci / docs / deps）
- [ ] 改动与 SPEC / ADR 对齐，验收条目如实勾选

<!-- 将下一行占位替换为实际值，并保留在正文末尾（squash 后进入提交正文）；纯人类 PR 写 none -->
Assisted-by: <harness>:<model>
