#!/usr/bin/env bash
# PR 描述元数据校验（C6）：末行必须是合法 Assisted-by trailer；正文不得含评审记录段。
# 只由 pr-meta job 在 pull_request 事件调用；不校验 docs 单提交（ADR-0005 单提交拟撤销）。
set -euo pipefail

: "${GITHUB_EVENT_PATH:?GITHUB_EVENT_PATH 未设置}"

body=$(jq -r '.pull_request.body // ""' "$GITHUB_EVENT_PATH")
last=$(printf '%s\n' "$body" | awk 'NF{last=$0} END{print last}')
regex='^Assisted-by: (none|[A-Za-z][A-Za-z0-9]*:[a-z0-9][a-z0-9.-]*)$'

if ! [[ "$last" =~ $regex ]]; then
  echo "::error::PR 描述最后一行不是合法 Assisted-by trailer（实际：${last:-<空>}）"
  exit 1
fi

if grep -qE '^##[[:space:]]*评审' <<< "$body"; then
  echo "::error::PR 描述包含评审记录段（## 评审…）；描述只保留最终变更"
  exit 1
fi

echo "pr-meta 通过：末行 trailer 合法，无评审记录段"
