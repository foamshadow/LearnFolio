#!/usr/bin/env bash
# commit-msg 钩子：fail-closed 校验署名 trailer（缺失即中止，不代填）。
# 用法：commit-msg.sh <git 传入的提交消息文件路径>
# 绕过：git commit --no-verify；由 CI 的 attribution job 兜底（唯一绕不过的一层）。
set -euo pipefail

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../lib/attribution.sh
source "$script_dir/../lib/attribution.sh"

# merge commit 不记 trailer（AGENTS「agent 署名」）：本地 git merge 同样跳过。
# 平台生成的 merge commit 不经过本地钩子，此分支只服务本地合并（如 backport）。
if git rev-parse -q --verify MERGE_HEAD >/dev/null; then
  exit 0
fi

msg_file="${1:-}"
if [[ -z "$msg_file" || ! -f "$msg_file" ]]; then
  echo "commit-msg: 未收到可读的提交消息文件，拒绝提交" >&2
  exit 1
fi

# 与 CI 同口径：先按 git 的 cleanup 规则去掉注释行，再解析末尾 trailer 块。
# 正文里出现的 Assisted-by 不算 trailer（AGENTS 明确要求位置在末尾 trailer 块）。
if ! trailers=$(git stripspace --strip-comments < "$msg_file" | git interpret-trailers --parse); then
  echo "commit-msg: 无法解析提交消息中的 trailer，拒绝提交" >&2
  exit 1
fi

if ! grep -Eqx "$assisted_regex" <<< "$trailers"; then
  echo "commit-msg: 缺少或格式错误的 Assisted-by trailer，提交已中止。" >&2
  echo "  期望：Assisted-by: <harness>:<model>（纯人类提交写 Assisted-by: none）" >&2
  echo "  位置：消息末尾的 trailer 块；正文里出现不算。键表见 AGENTS.md「agent 署名」。" >&2
  exit 1
fi

# Reviewed-by 是 opt-in：不要求存在；出现时只校验格式，与 CI 保持一致。
reviewed=$(grep -iE '^reviewed-by:' <<< "$trailers" || true)
if [[ -n "$reviewed" ]] && grep -Evx "$reviewed_regex" <<< "$reviewed" >/dev/null; then
  echo "commit-msg: Reviewed-by trailer 格式错误，提交已中止。" >&2
  echo "  期望：Reviewed-by: <harness>:<model>（人类写 none；opt-in，不要求存在）" >&2
  exit 1
fi
