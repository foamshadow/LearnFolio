#!/usr/bin/env bash
# ci-ok 结果矩阵（ADR-0011-D3；C6 部分取代 ADR-0009 D3）：skipped 不是通行证，必须与触发上下文绑定
set -euo pipefail

: "${EVENT:?EVENT 未设置}"
fail=0
err() {
  echo "::error::$*"
  fail=1
}

need_success() {
  local name="$1" result="${2:-}"
  [[ "$result" == "success" ]] || err "${name}: 期望 success，实际 '${result}'"
}

allow_only() {
  local name="$1" result="${2:-}"
  shift 2
  local ok
  for ok in "$@"; do
    [[ "$result" == "$ok" ]] && return 0
  done
  err "${name}: 意外结果 '${result}'（允许：$*）"
}

echo "event=${EVENT} changes=${CHANGES:-} web=${WEB:-} api=${API:-} title=${TITLE:-} pr_meta=${PR_META:-} attribution=${ATTRIBUTION:-}"

if [[ "$EVENT" == "pull_request" ]]; then
  # PR：上下文相关 job 必须是 success；分端 job 只允许"判定无需运行"的 skipped
  need_success changes "${CHANGES:-}"
  need_success title "${TITLE:-}"
  need_success pr-meta "${PR_META:-}"
  need_success attribution "${ATTRIBUTION:-}"

  check_side() {
    local name="$1" result="${2:-}" changed="${3:-}"
    if [[ "$result" == "skipped" ]]; then
      [[ "$changed" == "false" ]] || err "${name} 被跳过，但 changes 判定为 '${changed}'"
    else
      [[ "$result" == "success" ]] || err "${name}: 期望 success，实际 '${result}'"
    fi
  }
  check_side web "${WEB:-}" "${WEB_CHANGED:-}"
  check_side api "${API:-}" "${API_CHANGED:-}"
else
  # push：无 PR 上下文，changes / title / pr-meta 必须被跳过；分端与署名必须真跑
  need_success web "${WEB:-}"
  need_success api "${API:-}"
  need_success attribution "${ATTRIBUTION:-}"
  allow_only changes "${CHANGES:-}" skipped
  allow_only title "${TITLE:-}" skipped
  allow_only pr-meta "${PR_META:-}" skipped
fi

if (( fail != 0 )); then
  echo "::error::ci-ok 判定失败"
  exit 1
fi
echo "ci-ok 判定通过（${EVENT}）"
