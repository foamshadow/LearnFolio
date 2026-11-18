#!/usr/bin/env bash
# Merge a PASSed PR using the frozen title/body snapshot.
#
# Why this exists (merge-integrity §1, P0):
#   GitHub's squash merge reads the *live* PR description, which can change
#   after PASS without changing the head SHA.  This script re-checks the PASS
#   snapshot immediately before merging, then verifies the landed commit.
#
# Safety:
#   - human confirmation is required (interactive prompt unless --yes);
#   - PASS target must equal the current PR head;
#   - PASS body-sha256 must match sha256(title + "\n" + body);
#   - PR body must end with a valid Assisted-by trailer and contain no review
#     state lines (mirrors C6 pr-meta, intentionally redundant);
#   - docs PRs (head ref docs/*) use squash + snapshot body; other PRs use
#     --no-ff and the repository's default title path (no --subject/--body);
#   - the landed subject/body (and parents for code PRs) are verified after
#     the merge.  A verification failure is reported, not auto-reverted.
#
# Usage:
#   scripts/merge.sh <PR> [--dry-run] [--yes] [--mode docs|code]
#
#   --dry-run       validate and print the command, make no changes
#   --yes           skip the interactive confirmation
#   --mode ...      override branch-derived mode (docs/* => docs, else code)
#
# Examples:
#   task merge -- 47 --dry-run
#   task merge -- 47 --yes              # docs/* => squash + snapshot body
#   scripts/merge.sh 48 --yes           # dev/main => --no-ff
#
# The script does NOT authorize a merge: ADR-0007 still requires human
# authorization before running it with --yes.

set -Eeuo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(git rev-parse --show-toplevel)
# shellcheck source=lib/attribution.sh
source "$SCRIPT_DIR/lib/attribution.sh"

die() {
  printf '[merge] ERROR: %s\n' "$*" >&2
  exit 1
}

log() {
  printf '[merge] %s\n' "$*" >&2
}

usage() {
  cat <<'EOF'
Usage: scripts/merge.sh <PR> [options]

Options:
  --dry-run       validate and print the merge command, make no changes
  --yes           skip the interactive confirmation
  --mode docs     force docs path (squash + snapshot body)
  --mode code     force code path (--no-ff; no subject/body)
  -h, --help      show this help

Mode defaults to docs for head refs starting with docs/, code otherwise.
EOF
}

need_cmd() {
  local cmd
  for cmd in "$@"; do
    command -v "$cmd" >/dev/null 2>&1 || die "missing command: $cmd"
  done
}

sha256_hex() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum | awk '{print $1}'
  elif command -v shasum >/dev/null 2>&1; then
    shasum -a 256 | awk '{print $1}'
  else
    die "need sha256sum or shasum"
  fi
}

reviewer_regex='^Reviewer: (none|[A-Za-z][A-Za-z0-9]*:[a-z0-9][a-z0-9.-]*)$'

pr=""
dry_run=0
assume_yes=0
mode=""

while (($#)); do
  case "$1" in
    --dry-run)
      dry_run=1
      shift
      ;;
    --yes)
      assume_yes=1
      shift
      ;;
    --mode)
      [[ $# -ge 2 && -n "${2:-}" ]] || die "--mode requires a value"
      mode=$2
      shift 2
      ;;
    -h | --help)
      usage
      exit 0
      ;;
    --*)
      usage >&2
      die "unknown argument: $1"
      ;;
    *)
      [[ -z "$pr" ]] || {
        usage >&2
        die "only one PR number is accepted"
      }
      pr=$1
      shift
      ;;
  esac
done

[[ -n "$pr" ]] || {
  usage >&2
  die "PR number is required"
}
[[ "$pr" =~ ^[0-9]+$ ]] || die "PR must be numeric: $pr"
[[ -z "$mode" || "$mode" == "docs" || "$mode" == "code" ]] ||
  die "--mode must be docs or code"

need_cmd gh jq git
cd "$REPO_ROOT"

tmp=$(mktemp -d)
cleanup() {
  rm -rf "$tmp"
}
trap cleanup EXIT

# 1. Read the live PR metadata exactly once.  jq -j preserves body bytes,
# including the trailing newline; shell command substitution does not.
gh pr view "$pr" \
  --json number,title,body,headRefOid,baseRefName,headRefName,state,isDraft,mergeable,mergeStateStatus,url \
  >"$tmp/pr.json" || die "cannot fetch PR #$pr (gh auth?)"

title=$(jq -r '.title // ""' "$tmp/pr.json")
head_sha=$(jq -r '.headRefOid // ""' "$tmp/pr.json")
head_ref=$(jq -r '.headRefName // ""' "$tmp/pr.json")
base_ref=$(jq -r '.baseRefName // ""' "$tmp/pr.json")
state=$(jq -r '.state // ""' "$tmp/pr.json")
is_draft=$(jq -r '.isDraft // false' "$tmp/pr.json")
mergeable=$(jq -r '.mergeable // ""' "$tmp/pr.json")
merge_state=$(jq -r '.mergeStateStatus // ""' "$tmp/pr.json")
pr_url=$(jq -r '.url // ""' "$tmp/pr.json")
jq -j '.body // ""' "$tmp/pr.json" >"$tmp/body"
body_file="$tmp/body"

[[ -n "$title" ]] || die "PR #$pr has an empty title"
[[ -n "$head_sha" ]] || die "PR #$pr has no head SHA"
[[ -n "$head_ref" ]] || die "PR #$pr has no head ref"
[[ -n "$base_ref" ]] || die "PR #$pr has no base ref"
[[ "$base_ref" == "dev" || "$base_ref" == "main" ]] ||
  die "PR #$pr targets $base_ref; only dev/main are merge targets"
[[ "$state" == "OPEN" ]] || die "PR #$pr is not open (state: $state)"
[[ "$is_draft" == "false" ]] || die "PR #$pr is a draft"
[[ "$mergeable" == "MERGEABLE" ]] || die "PR #$pr is not mergeable ($mergeable)"
[[ "$merge_state" == "CLEAN" ]] ||
  die "PR #$pr mergeStateStatus is $merge_state (expected CLEAN; wait for CI/mergeability)"

# 2. Validate the live PR body with the same shape C6 enforces.
last=$(awk 'NF{last=$0} END{print last}' "$body_file")
[[ -n "$last" ]] || die "PR body is empty (missing Assisted-by trailer)"
[[ "$last" =~ $assisted_regex ]] ||
  die "PR body last line is not a valid Assisted-by trailer: $last"
if grep -qE '^#+[[:space:]]*评审' "$body_file"; then
  die "PR body contains a review heading (评审); description must contain final changes only"
fi
if grep -qE '^(REVIEW(-FIX)?([[:space:]:：]|$)|Reviewer[[:space:]]*[:：]|Author[[:space:]]*[:：]|Reviewed-by[[:space:]]*[:：])' "$body_file"; then
  die "PR body contains a review state line (REVIEW / Reviewer / Author / Reviewed-by)"
fi

current_hash=$({ printf '%s\n' "$title"; cat "$body_file"; } | sha256_hex)
[[ "$current_hash" =~ ^[0-9a-f]{64}$ ]] || die "cannot compute sha256 for PR snapshot"

# 3. Find the PASS comment whose target/hash match this exact head/body.
repo=$(gh repo view --json nameWithOwner -q .nameWithOwner) ||
  die "cannot resolve repository (gh auth?)"
gh api --paginate "repos/$repo/issues/$pr/comments" >"$tmp/comments.raw" ||
  die "cannot fetch PR comments"
jq -s 'add // []' "$tmp/comments.raw" >"$tmp/comments.json" ||
  die "cannot parse PR comments"

jq -r '
  .[]
  | select(.body | startswith("REVIEW: PASS"))
  | . as $c
  | ($c.body | split("\n") | map(select(gsub("\\s"; "") != ""))) as $lines
  | {
      id: $c.id,
      url: $c.html_url,
      target: (($c.body | split("\n") | map(select(startswith("target "))) | first // "") | ltrimstr("target ")),
      hash: (($c.body | split("\n") | map(select(startswith("body-sha256: "))) | first // "") | ltrimstr("body-sha256: ")),
      reviewer: ($lines[-1] // "")
    }
  | [.id, .url, .target, .hash, .reviewer] | @tsv
' "$tmp/comments.json" >"$tmp/pass.tsv" || die "cannot parse PASS comments"

pass_id=""
pass_url=""
pass_target=""
pass_reviewer=""
while IFS=$'\t' read -r id url target hash reviewer; do
  [[ -n "$id" ]] || continue
  [[ "$target" =~ ^[0-9a-f]{7,40}$ ]] || continue
  [[ "$hash" =~ ^[0-9a-f]{64}$ ]] || continue
  [[ "$reviewer" =~ $reviewer_regex ]] || continue
  [[ "$head_sha" == "$target"* ]] || continue
  [[ "$hash" == "$current_hash" ]] || continue
  pass_id=$id
  pass_url=$url
  pass_target=$target
  pass_reviewer=$reviewer
done <"$tmp/pass.tsv"

if [[ -z "$pass_id" ]]; then
  printf '[merge] PASS candidates (id  target  hash  reviewer):\n' >&2
  sed 's/^/  /' "$tmp/pass.tsv" >&2 || true
  die "no PASS comment matches head $head_sha and current body-sha256 $current_hash"
fi

# 4. Branch-derived path: docs/* is squash + snapshot body; everything else is
# --no-ff with the platform's default title path.
if [[ -z "$mode" ]]; then
  if [[ "$head_ref" == docs/* ]]; then
    mode=docs
  else
    mode=code
  fi
fi
[[ "$mode" == "docs" || "$mode" == "code" ]] || die "invalid mode: $mode"

subject="$title (#$pr)"
merge_cmd=(gh pr merge "$pr" --match-head-commit "$head_sha")
if [[ "$mode" == "docs" ]]; then
  merge_cmd+=(--squash --subject "$subject" --body-file "$body_file")
else
  merge_cmd+=(--merge)
fi

log "PR #$pr: $title"
log "head: $head_sha ($head_ref) -> base: $base_ref"
log "mode: $mode"
log "PASS: $pass_url (target $pass_target, reviewer ${pass_reviewer#Reviewer: })"
log "body-sha256: $current_hash"

if ((dry_run)); then
  printf '[merge] dry-run: ' >&2
  printf '%q ' "${merge_cmd[@]}" >&2
  printf '\n' >&2
  exit 0
fi

if ((!assume_yes)); then
  printf '\nType '"'"'merge'"'"' to merge PR #%s (%s): ' "$pr" "$mode" >&2
  read -r answer || die "confirmation aborted"
  [[ "$answer" == "merge" ]] || die "aborted by operator"
fi

log "merging PR #$pr"
"${merge_cmd[@]}" || die "gh pr merge failed"

# 5. Verify the landed commit, not just GitHub's success response.
merged=$(gh pr view "$pr" \
  --json state,mergeCommit,baseRefName,headRefOid,url) ||
  die "cannot re-read PR #$pr after merge"
merged_state=$(jq -r '.state // ""' <<<"$merged")
merge_commit=$(jq -r '.mergeCommit.oid // ""' <<<"$merged")
[[ "$merged_state" == "MERGED" ]] || die "PR #$pr is not MERGED (state: $merged_state)"
[[ -n "$merge_commit" ]] || die "PR #$pr has no merge commit"

git fetch origin --prune || die "git fetch origin failed after merge"
landed_sha=$(git rev-parse "origin/$base_ref") ||
  die "cannot resolve origin/$base_ref"
[[ "$landed_sha" == "$merge_commit" ]] ||
  die "origin/$base_ref ($landed_sha) is not the merge commit ($merge_commit)"

landed_subject=$(git show -s --format=%s "$merge_commit")
[[ "$landed_subject" == "$subject" ]] ||
  die "landed subject mismatch: expected '$subject', got '$landed_subject'"

landed_body=$(git show -s --format=%b "$merge_commit")
snapshot_body=$(cat "$body_file")
if [[ "$mode" == "docs" ]]; then
  [[ "$landed_body" == "$snapshot_body" ]] ||
    die "landed body mismatch: squash body is not the PASS snapshot (rstrip-normalized)"
else
  [[ -z "$landed_body" ]] ||
    die "landed merge commit body is not empty for code PR"
  parents=$(git show -s --format=%P "$merge_commit")
  read -r _p1 p2 _rest <<<"$parents"
  [[ -n "${p2:-}" && "$p2" == "$head_sha" ]] ||
    die "merge commit second parent ($p2) is not the PASS target ($head_sha)"
fi

log "merged PR #$pr -> $merge_commit"
log "verified: subject '$landed_subject'; $mode landed body/parents match"
