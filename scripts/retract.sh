#!/usr/bin/env bash
# Retract the current dev head through the P2b fast path.
#
# Model (ADR-0010 / merge-integrity):
#   P2b = force-reset dev to the bad commit's first parent, then re-land the
#   same content through a new PR. This script only performs the reset/push
#   half; re-land is a normal PR and is never automated here.
#
# Ruleset window:
#   RS-1 dev-main-pr-gate  (require PR + ci-ok, no bypass) is disabled for the
#   shortest possible window; RS-2 dev-main-history (force block, owner bypass)
#   and RS-3 dev-main-undeletable (deletion block, no bypass) stay active.
#   The require-PR rule blocks direct pushes, including force pushes, so RS-1
#   must be disabled for the push to pass.
#
# Safety:
#   - human confirmation is required (interactive prompt unless --yes);
#   - the three-condition retract window (Q1, decided 2026-11-18) is enforced:
#     bad at dev head, no other branch based on bad, age within --window-hours;
#   - backup branch is created locally and on origin before any rewrite;
#   - force push uses --force-with-lease + --force-if-includes;
#   - EXIT/INT/TERM trap re-enables RS-1; restore failure exits 99 and prints
#     the manual recovery command + snapshot path.
#
# Usage:
#   scripts/retract.sh --bad <sha> [--base <sha>] [--window-hours N]
#                      [--dry-run] [--yes]
#
# Environment overrides (mainly for drills):
#   REPO, PR_GATE_NAME, HISTORY_NAME, RULESET_EXPECTED_FILE,
#   RULESET_WAIT_ATTEMPTS, RULESET_WAIT_SECONDS

set -Eeuo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(git rev-parse --show-toplevel)
# shellcheck source=lib/rulesets.sh
source "$SCRIPT_DIR/lib/rulesets.sh"

usage() {
  cat <<'EOF'
Usage: scripts/retract.sh --bad <sha> [options]

Options:
  --bad <sha>          head commit to retract (must equal origin/dev)
  --base <sha>         reset target (default: <bad>^)
  --window-hours N     retract window in hours (default: 24)
  --dry-run            print the plan, make no changes
  --yes                skip the interactive confirmation
  -h, --help           show this help
EOF
}

bad=""
base=""
window_hours=24
dry_run=0
assume_yes=0

while (($#)); do
  case "$1" in
    --bad)
      [[ $# -ge 2 && -n "$2" ]] || die "--bad requires a value"
      bad=$2
      shift 2
      ;;
    --base)
      [[ $# -ge 2 && -n "$2" ]] || die "--base requires a value"
      base=$2
      shift 2
      ;;
    --window-hours)
      [[ $# -ge 2 && -n "$2" ]] || die "--window-hours requires a value"
      window_hours=$2
      shift 2
      ;;
    --dry-run)
      dry_run=1
      shift
      ;;
    --yes)
      assume_yes=1
      shift
      ;;
    -h | --help)
      usage
      exit 0
      ;;
    *)
      usage >&2
      die "unknown argument: $1"
      ;;
  esac
done

[[ -n "$bad" ]] || {
  usage >&2
  die "--bad is required"
}
[[ "$window_hours" =~ ^[0-9]+$ ]] || die "--window-hours must be a non-negative integer"

need_cmd gh jq git
cd "$REPO_ROOT"

branch=$(git branch --show-current)
[[ "$branch" == "dev" ]] || die "retract must run on dev (current: ${branch:-detached})"
[[ -z "$(git status --porcelain)" ]] || die "worktree is not clean"

git fetch origin --prune

bad_sha=$(git rev-parse --verify "${bad}^{commit}") || die "bad commit not found: $bad"
origin_dev=$(git rev-parse --verify origin/dev) || die "origin/dev not found"
head_sha=$(git rev-parse --verify HEAD)

[[ "$origin_dev" == "$bad_sha" ]] ||
  die "origin/dev ($origin_dev) is not the bad commit ($bad_sha)"
[[ "$head_sha" == "$bad_sha" ]] ||
  die "local dev HEAD ($head_sha) is not the bad commit ($bad_sha)"

if [[ -z "$base" ]]; then
  base="${bad_sha}^"
fi
base_sha=$(git rev-parse --verify "${base}^{commit}") || die "base commit not found: $base"
[[ "$base_sha" != "$bad_sha" ]] || die "base must differ from bad"

if ! git merge-base --is-ancestor "$base_sha" "$bad_sha"; then
  die "base $base_sha is not an ancestor of bad $bad_sha"
fi

bad_ts=$(git show -s --format=%ct "$bad_sha")
now=$(date +%s)
age=$((now - bad_ts))
((age >= 0)) || age=0
max_age=$((window_hours * 3600))
((age <= max_age)) ||
  die "bad commit is ${age}s old, outside the ${window_hours}h retract window"

# Q1 condition 2 of the three-condition window: no branch may have bad as an
# ancestor. Any branch already based on bad would be orphaned by the reset
# (visible exposure); allowed referrers are dev itself, origin/dev, and
# backup/* -- local branches and their pushed remote-tracking refs (earlier
# runs' backups must survive a retry). Remote HEAD symrefs are aliases of
# refs checked separately. Anything else -- including main -- closes the
# window: use revert or the ADR-0010 D1 ritual instead.
refs_out=$(git for-each-ref --contains="$bad_sha" --format='%(refname)' \
  refs/heads refs/remotes) ||
  die "cannot enumerate refs containing $bad_sha"
guard_refs=$(grep -Ev \
  '^refs/(heads/dev|remotes/origin/dev)$|^refs/heads/backup/|^refs/remotes/[^/]+/backup/|^refs/remotes/[^/]+/HEAD$' \
  <<<"$refs_out" || true)
if [[ -n "$guard_refs" ]]; then
  die "retract window closed: other refs already contain bad:
$guard_refs
rebase the listed branches onto ${base_sha} and retry, or use revert / ADR-0010 D1"
fi

stamp=$(date +%Y%m%d%H%M%S)
backup="backup/dev-${bad_sha:0:7}-${stamp}"
bad_subject=$(git show -s --format=%s "$bad_sha")

log "retract plan:"
log "  bad:    $bad_sha  ($bad_subject)"
log "  base:   $base_sha"
log "  backup: $backup"
log "  window: ${window_hours}h (age ${age}s)"
log "  guard:  no other branch contains bad (verified)"
log "  RS-1:   $PR_GATE_NAME (will be disabled, then re-enabled)"
log "  RS-2:   $HISTORY_NAME (stays active; owner bypass for force)"
log "  RS-3:   $UNDELETABLE_NAME (stays active; no bypass)"

resolve_rulesets
verify_all

if ((dry_run)); then
  log "dry-run: no backup, no ruleset change, no push"
  exit 0
fi

if ((!assume_yes)); then
  printf '\nType '"'"'retract'"'"' to continue: ' >&2
  read -r answer || die "confirmation aborted"
  [[ "$answer" == "retract" ]] || die "aborted by operator"
fi

# ADR-0012 component 2 trailer declaration, validated BEFORE any mutation
# (backup creation/push included): the retract caller declares authorship of
# the tool-generated hint commit. Default `none` is accurate only for a human
# operator; agent sessions must export RETRACT_ASSISTED_BY=<harness>:<model>
# (same regex as AGENTS).
case "${RETRACT_ASSISTED_BY:-none}" in
  none|[A-Za-z][A-Za-z0-9]*:[a-z0-9][a-z0-9.-]*) assisted_by="${RETRACT_ASSISTED_BY:-none}" ;;
  *) die "invalid RETRACT_ASSISTED_BY '${RETRACT_ASSISTED_BY}' (expected: none or Harness:model)" ;;
esac

log "creating backup branch $backup"
git branch "$backup" "$bad_sha"
git push origin "$backup"
backup_remote=$(git ls-remote --heads origin "refs/heads/$backup" | cut -f1)
[[ "$backup_remote" == "$bad_sha" ]] ||
  die "backup branch verification failed: $backup"

snapshot_rulesets

restore_needed=0
restore_done=0
on_exit() {
  local rc=$?
  trap - EXIT INT TERM
  if ((restore_needed == 1 && restore_done == 0)); then
    log "restoring RS-1 after exit $rc"
    if (enable_pr_gate); then
      restore_done=1
    else
      printf '[retract] FATAL: RS-1 restore failed; PR gate may still be disabled\n' >&2
      print_manual_restore
      exit 99
    fi
    if [[ "$(git rev-parse HEAD)" != "$(git rev-parse origin/dev)" ]]; then
      log "restoring local dev to origin/dev after failed retract"
      git reset --hard origin/dev ||
        log "WARN: local dev restore failed; inspect manually"
    fi
  fi
  exit "$rc"
}
trap on_exit EXIT
trap 'exit 130' INT TERM

restore_needed=1
disable_pr_gate

log "resetting local dev to $base_sha"
git reset --hard "$base_sha"
[[ "$(git rev-parse HEAD)" == "$base_sha" ]] || die "local reset verification failed"

log "force-pushing dev with lease on $bad_sha"
git push \
  --force-with-lease="refs/heads/dev:$bad_sha" \
  --force-if-includes \
  origin "$base_sha:dev"

git fetch origin
[[ "$(git rev-parse origin/dev)" == "$base_sha" ]] ||
  die "remote dev verification failed after force push"

enable_pr_gate
verify_all
restore_needed=0
restore_done=1
trap - EXIT INT TERM

# Hint commit on the backup tip (ADR-0012 component 2), published only after
# the rewrite fully succeeded (review B1): an empty commit (tree unchanged) on
# top of the preserved bad tip, carrying the rewrite fact + alignment command.
# backup/* rides the default fetch refspec (clones using --single-branch or a
# custom refspec will not receive it). Every failure here is non-fatal:
# components 1 (operator output) and 3 (AGENTS rule) still notify.
hint_msg=$(cat <<HINT
clone 对齐通知:dev 已重写(bad ${bad_sha:0:7} 已撤回)

对齐操作:git fetch origin && git reset --hard origin/dev
前置自检:git log origin/dev..HEAD 为空且工作树干净,经人类确认后执行
(AGENTS「远端重写对齐」/ ADR-0012);本分支保留重写前历史至事件闭项。

Assisted-by: ${assisted_by}
HINT
)
hint_sha=$(git commit-tree "${backup}^{tree}" -p "$backup" -m "$hint_msg") || hint_sha=""
if [[ -z "$hint_sha" ]]; then
  log "WARNING: hint commit failed (non-fatal); remote backup stays at ${bad_sha:0:7}; components 1/3 still notify"
else
  if git update-ref "refs/heads/$backup" "$hint_sha" "$bad_sha"; then
    if git push origin "refs/heads/$backup:refs/heads/$backup"; then
      log "hint commit on $backup: ${hint_sha:0:7}"
    else
      log "WARNING: hint push failed (non-fatal); remote backup stays at ${bad_sha:0:7}, local hint remains; components 1/3 still notify"
    fi
  else
    log "WARNING: hint ref update failed (non-fatal); remote backup stays at ${bad_sha:0:7}; components 1/3 still notify"
  fi
fi

log "retract complete"
printf 'retracted dev: %s -> %s\n' "$bad_sha" "$base_sha" >&2
printf 'backup branch: %s\n' "$backup" >&2
printf 'clone reset:   git fetch origin && git reset --hard origin/dev\n' >&2
printf 're-land:       open a new PR with the same content (P2b)\n' >&2
