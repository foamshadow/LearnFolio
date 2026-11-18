#!/usr/bin/env bash
# 署名 trailer 正则的单一源：commit-msg 钩子与 CI 的 check-attribution.sh /
# check-pr-meta.sh 共用。只定义变量，不设置 shell 选项；由 source 方决定 set -euo pipefail。
#
# 解析规则（ADR-0004 / AGENTS「agent 署名」）：
#   harness 首字母大写、model 全小写 kebab-case；快照后缀照抄，不附加日期。
#   键名大小写敏感；值 ASCII 无空格；多参与方各一行。

assisted_regex='^Assisted-by: (none|[A-Za-z][A-Za-z0-9]*:[a-z0-9][a-z0-9.-]*)$'
reviewed_regex='^Reviewed-by: (none|[A-Za-z][A-Za-z0-9]*:[a-z0-9][a-z0-9.-]*)$'
