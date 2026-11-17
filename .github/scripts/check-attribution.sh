#!/usr/bin/env bash
# 逐提交署名校验：Assisted-by 存在性与格式；Reviewed-by 格式（若出现，opt-in）
# PR 取 base..head；push 取 before..after，before 不可用时 fail-closed 回退全史
set -euo pipefail

: "${EVENT:?EVENT 未设置}"
assisted_regex='^Assisted-by: (none|[A-Za-z][A-Za-z0-9]*:[a-z0-9][a-z0-9.-]*)$'
reviewed_regex='^Reviewed-by: (none|[A-Za-z][A-Za-z0-9]*:[a-z0-9][a-z0-9.-]*)$'

if [[ "$EVENT" == "pull_request" ]]; then
  : "${BASE_SHA:?BASE_SHA 未设置}"
  : "${HEAD_SHA:?HEAD_SHA 未设置}"
  range=("${BASE_SHA}..${HEAD_SHA}")
  label="PR ${BASE_SHA:0:7}..${HEAD_SHA:0:7}"
else
  : "${AFTER:?AFTER 未设置}"
  before="${BEFORE:-}"
  if [[ -z "$before" || "$before" =~ ^0+$ ]] || ! git cat-file -e "${before}^{commit}" 2>/dev/null; then
    echo "before 不可用（首推 / 强推 / 未取到对象），回退为 after 全史校验"
    range=("$AFTER")
    label="push 全史 @ ${AFTER:0:7}"
  else
    range=("${before}..${AFTER}")
    label="push ${before:0:7}..${AFTER:0:7}"
  fi
fi

if ! raw=$(git rev-list --no-merges "${range[@]}"); then
  echo "::error::无法计算提交范围（${label}）"
  exit 1
fi

if [[ -z "$raw" ]]; then
  echo "范围内没有非 merge 提交（${label}）"
  exit 0
fi

mapfile -t commits <<< "$raw"
bad=0
for sha in "${commits[@]}"; do
  subject=$(git show -s --format=%s "$sha")
  trailers=$(git show -s --format=%B "$sha" | git interpret-trailers --parse)
  commit_ok=1

  if ! grep -Eqx "$assisted_regex" <<< "$trailers"; then
    commit_ok=0
    bad=1
    echo "::error::${sha} 缺少或格式错误的 Assisted-by trailer：${subject}"
    echo "     期望：Assisted-by: <harness>:<model>（纯人类提交写 none）"
  fi

  # 收集时忽略大小写；校验正则保持大小写敏感，小写/大写漂移在此判红
  reviewed=$(grep -iE '^reviewed-by:' <<< "$trailers" || true)
  if [[ -n "$reviewed" ]] && grep -Evx "$reviewed_regex" <<< "$reviewed" >/dev/null; then
    commit_ok=0
    bad=1
    echo "::error::${sha} 存在格式错误的 Reviewed-by trailer：${subject}"
    echo "     期望：Reviewed-by: <harness>:<model>（人类写 none；opt-in，不要求存在）"
  fi

  if (( commit_ok )); then
    echo "ok  ${sha:0:7} ${subject}"
  fi
done

if (( bad != 0 )); then
  echo "::error::署名校验失败（${label}）"
  exit 1
fi
echo "署名校验通过：${#commits[@]} 个非 merge 提交（${label}；Reviewed-by 仅格式校验）"
