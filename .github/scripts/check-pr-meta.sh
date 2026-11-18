#!/usr/bin/env bash
# PR 描述元数据校验（C6）：末行必须是合法 Assisted-by trailer；正文不得含评审状态行
# （REVIEW / REVIEW-FIX / Reviewer / Author / Reviewed-by 开头，或「评审」标题段）。
# 只由 pr-meta job 在 pull_request 事件调用；不校验评论层 Reviewer（payload 不含评论）。
# 不校验 docs 单提交（ADR-0005 单提交已撤销，ADR-0010）。
set -euo pipefail

: "${GITHUB_EVENT_PATH:?GITHUB_EVENT_PATH 未设置}"

# 正则单一源：scripts/lib/attribution.sh（与 commit-msg / check-attribution 共用）
script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../../scripts/lib/attribution.sh
source "$script_dir/../../scripts/lib/attribution.sh"

body=$(jq -r '.pull_request.body // ""' "$GITHUB_EVENT_PATH")
last=$(printf '%s\n' "$body" | awk 'NF{last=$0} END{print last}')

if ! [[ "$last" =~ $assisted_regex ]]; then
  echo "::error::PR 描述最后一行不是合法 Assisted-by trailer（实际：${last:-<空>}）"
  exit 1
fi

if grep -qE '^#+[[:space:]]*评审' <<< "$body"; then
  echo "::error::PR 描述包含评审记录段（评审标题）；描述只保留最终变更"
  exit 1
fi

if grep -qE '^(REVIEW(-FIX)?([[:space:]:：]|$)|Reviewer[[:space:]]*[:：]|Author[[:space:]]*[:：]|Reviewed-by[[:space:]]*[:：])' <<< "$body"; then
  echo "::error::PR 描述包含评审状态行（REVIEW / Reviewer / Author / Reviewed-by）；评审只进评论或 commit trailer"
  exit 1
fi

echo "pr-meta 通过：末行 trailer 合法，无评审状态行"
