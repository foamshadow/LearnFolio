#!/usr/bin/env bash
# PR 标题 + 合并方向校验（ADR-0009 D5 / SPEC-0001-A5）
# 六条变体：feat / fix / hotfix 发布 / hotfix backport / Phase 收口 / docs
set -euo pipefail
export LC_ALL=C.UTF-8

: "${PR_TITLE:?PR_TITLE 未设置}"
: "${BASE_REF:?BASE_REF 未设置}"
: "${HEAD_REF:?HEAD_REF 未设置}"

feat_re='^合并 spec-[0-9]{4}-t[0-9]+ [a-z0-9-]+：.+$'
fix_re='^合并 fix [a-z0-9-]+：.+$'
hotfix_release_re='^合并 hotfix [a-z0-9-]+：.+（发布 v[0-9]+\.[0-9]+\.[0-9]+）$'
hotfix_backport_re='^合并 hotfix [a-z0-9-]+：backport 自 v[0-9]+\.[0-9]+\.[0-9]+$'
phase_re='^合并 Phase [0-9]+ 收口：v[0-9]+\.[0-9]+\.[0-9]+$'
docs_re='^docs: .+$'

expect() {
  local pattern="$1" label="$2"
  if [[ ! "$PR_TITLE" =~ $pattern ]]; then
    echo "::error::PR 标题不符合「${label}」变体：${PR_TITLE}"
    echo "期望形如：$(case "$label" in
      feat) echo '合并 spec-0001-t1 短名：一句话' ;;
      fix) echo '合并 fix 短名：一句话' ;;
      backport) echo '合并 hotfix 短名：backport 自 vX.Y.Z' ;;
      docs) echo 'docs: 一句话' ;;
      hotfix) echo '合并 hotfix 短名：一句话（发布 vX.Y.Z）' ;;
      phase) echo '合并 Phase N 收口：vX.Y.Z' ;;
    esac)"
    exit 1
  fi
}

# 方向矩阵：标题变体与 base×head 必须同时成立
case "${BASE_REF}|${HEAD_REF}" in
  "dev|feat/"*) expect "$feat_re" feat ;;
  "dev|fix/"*) expect "$fix_re" fix ;;
  "dev|backport/"*) expect "$hotfix_backport_re" backport ;;
  "dev|docs/"*) expect "$docs_re" docs ;;
  "main|hotfix/"*) expect "$hotfix_release_re" hotfix ;;
  "main|dev") expect "$phase_re" phase ;;
  *)
    echo "::error::不允许的合并方向：${BASE_REF} ← ${HEAD_REF}"
    echo "允许：dev←feat/*、dev←fix/*、dev←backport/*、dev←docs/*、main←hotfix/*、main←dev"
    exit 1
    ;;
esac

echo "PR 标题与方向校验通过：${BASE_REF} ← ${HEAD_REF}｜${PR_TITLE}"
