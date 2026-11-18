#!/usr/bin/env bash
# shellcheck shell=bash
#
# Ruleset helpers for scripts/retract.sh.
#
# Scope:
#   - resolve the production rulesets by name (no hardcoded numeric IDs);
#   - verify the mutable ruleset state against scripts/rulesets.expected.json;
#   - toggle only RS-1 enforcement (PR gate) around a retract;
#   - snapshot the before/after JSON for the journal.
#
# Non-goals:
#   - creating or migrating rulesets (one-time infra step, separate);
#   - touching classic branch protection;
#   - touching Git refs.
#
# The production model is intentionally asymmetric:
#   RS-1 dev-main-pr-gate    : require PR + required ci-ok, NO bypass actor;
#   RS-2 dev-main-history    : block force-push, owner/admin bypass (retract only);
#   RS-3 dev-main-undeletable: block deletion, NO bypass actor.
#
# A retract therefore cannot force-push while RS-1 is active (require-PR blocks
# direct pushes, including force). retract.sh disables RS-1 for the shortest
# possible window, force-pushes through RS-2's bypass, then re-enables RS-1.
# RS-2 and RS-3 stay active for the whole operation; RS-3 is never touched by
# retract, so deletion never gains a bypass.

set -euo pipefail

REPO_ROOT=${REPO_ROOT:-$(git rev-parse --show-toplevel)}
RULESET_EXPECTED_FILE=${RULESET_EXPECTED_FILE:-"$REPO_ROOT/scripts/rulesets.expected.json"}
PR_GATE_NAME=${PR_GATE_NAME:-dev-main-pr-gate}
HISTORY_NAME=${HISTORY_NAME:-dev-main-history}
UNDELETABLE_NAME=${UNDELETABLE_NAME:-dev-main-undeletable}
RULESET_WAIT_ATTEMPTS=${RULESET_WAIT_ATTEMPTS:-6}
RULESET_WAIT_SECONDS=${RULESET_WAIT_SECONDS:-10}
SNAPSHOT_DIR=${SNAPSHOT_DIR:-""}
REPO_SLUG=${REPO:-""}
PR_GATE_ID=${PR_GATE_ID:-""}
HISTORY_ID=${HISTORY_ID:-""}
UNDELETABLE_ID=${UNDELETABLE_ID:-""}

log() {
  printf '[rulesets] %s\n' "$*" >&2
}

die() {
  printf '[rulesets] ERROR: %s\n' "$*" >&2
  exit 1
}

need_cmd() {
  local cmd
  for cmd in "$@"; do
    command -v "$cmd" >/dev/null 2>&1 || die "missing command: $cmd"
  done
}

rulesets_repo() {
  if [[ -n "$REPO_SLUG" ]]; then
    printf '%s\n' "$REPO_SLUG"
    return 0
  fi
  REPO_SLUG=$(gh repo view --json nameWithOwner -q .nameWithOwner) ||
    die "cannot resolve repository (gh auth?)"
  printf '%s\n' "$REPO_SLUG"
}

ruleset_get() {
  local id=$1 repo
  repo=$(rulesets_repo)
  gh api "repos/$repo/rulesets/$id"
}

ruleset_id_by_name() {
  local name=$1 repo raw ids=()
  repo=$(rulesets_repo)
  raw=$(gh api --paginate "repos/$repo/rulesets") ||
    die "cannot list rulesets for $repo"
  mapfile -t ids < <(
    jq -r --arg name "$name" '.[] | select(.name == $name) | .id' <<<"$raw"
  )
  if ((${#ids[@]} == 0)); then
    die "ruleset not found: $name (run the one-time migration first)"
  fi
  if ((${#ids[@]} > 1)); then
    die "multiple rulesets named $name: ${ids[*]}"
  fi
  printf '%s\n' "${ids[0]}"
}

validate_config() {
  [[ "$RULESET_WAIT_ATTEMPTS" =~ ^[0-9]+$ ]] ||
    die "RULESET_WAIT_ATTEMPTS must be a non-negative integer"
  [[ "$RULESET_WAIT_SECONDS" =~ ^[0-9]+$ ]] ||
    die "RULESET_WAIT_SECONDS must be a non-negative integer"
  [[ -f "$RULESET_EXPECTED_FILE" ]] ||
    die "expected ruleset file missing: $RULESET_EXPECTED_FILE"
}

resolve_rulesets() {
  validate_config
  PR_GATE_ID=$(ruleset_id_by_name "$PR_GATE_NAME")
  HISTORY_ID=$(ruleset_id_by_name "$HISTORY_NAME")
  UNDELETABLE_ID=$(ruleset_id_by_name "$UNDELETABLE_NAME")
  log "RS-1 $PR_GATE_NAME = $PR_GATE_ID"
  log "RS-2 $HISTORY_NAME = $HISTORY_ID"
  log "RS-3 $UNDELETABLE_NAME = $UNDELETABLE_ID"
}

normalize_ruleset() {
  jq -S '{
    name,
    target,
    enforcement,
    bypass_actors: (.bypass_actors // []),
    conditions,
    rules
  }'
}

expected_ruleset() {
  local key=$1 want_enforcement=${2:-active}
  [[ -f "$RULESET_EXPECTED_FILE" ]] ||
    die "expected ruleset file missing: $RULESET_EXPECTED_FILE"
  jq -S --arg key "$key" --arg enforcement "$want_enforcement" \
    '.[$key] | .enforcement = $enforcement' "$RULESET_EXPECTED_FILE"
}

verify_ruleset() {
  local key=$1 id=$2 want_enforcement=${3:-active}
  local expected actual

  expected=$(expected_ruleset "$key" "$want_enforcement")
  actual=$(ruleset_get "$id" | normalize_ruleset)

  if [[ "$expected" != "$actual" ]]; then
    printf '[rulesets] expected %s (%s):\n%s\n' "$key" "$want_enforcement" "$expected" >&2
    printf '[rulesets] actual %s (%s):\n%s\n' "$key" "$id" "$actual" >&2
    die "ruleset state mismatch: $key"
  fi
}

verify_all() {
  verify_ruleset pr_gate "$PR_GATE_ID" active
  verify_ruleset history "$HISTORY_ID" active
  verify_ruleset undeletable "$UNDELETABLE_ID" active
}

# Minimal-body PUT is merge semantics on GitHub's ruleset API (tested 2026-11-18):
# omitted fields survive, so the toggle cannot clobber rules/conditions/bypass.
ruleset_put_enforcement() {
  local id=$1 enforcement=$2 repo body
  repo=$(rulesets_repo)
  body=$(jq -nc --arg enforcement "$enforcement" '{enforcement: $enforcement}')
  gh api -X PUT "repos/$repo/rulesets/$id" --input - <<<"$body" >/dev/null
}

wait_for_enforcement() {
  local id=$1 want=$2 attempt current
  for ((attempt = 1; attempt <= RULESET_WAIT_ATTEMPTS; attempt++)); do
    current=$(ruleset_get "$id" | jq -r '.enforcement')
    if [[ "$current" == "$want" ]]; then
      return 0
    fi
    log "waiting for ruleset $id enforcement=$want" \
      "(attempt $attempt/$RULESET_WAIT_ATTEMPTS, now=$current)"
    sleep "$RULESET_WAIT_SECONDS"
  done
  return 1
}

snapshot_rulesets() {
  local stamp
  if [[ -z "$SNAPSHOT_DIR" ]]; then
    stamp=$(date +%Y%m%dT%H%M%S)
    SNAPSHOT_DIR="$REPO_ROOT/.tools/retract/$stamp"
  fi
  mkdir -p "$SNAPSHOT_DIR"
  ruleset_get "$PR_GATE_ID" | jq -S . >"$SNAPSHOT_DIR/pr-gate.json"
  ruleset_get "$HISTORY_ID" | jq -S . >"$SNAPSHOT_DIR/history.json"
  ruleset_get "$UNDELETABLE_ID" | jq -S . >"$SNAPSHOT_DIR/undeletable.json"
  cp "$RULESET_EXPECTED_FILE" "$SNAPSHOT_DIR/expected.json"
  {
    printf 'timestamp=%s\n' "$(date -Iseconds)"
    printf 'repo=%s\n' "$(rulesets_repo)"
    printf 'pr_gate=%s id=%s\n' "$PR_GATE_NAME" "$PR_GATE_ID"
    printf 'history=%s id=%s\n' "$HISTORY_NAME" "$HISTORY_ID"
    printf 'undeletable=%s id=%s\n' "$UNDELETABLE_NAME" "$UNDELETABLE_ID"
  } >"$SNAPSHOT_DIR/metadata.txt"
  log "snapshot: $SNAPSHOT_DIR"
}

disable_pr_gate() {
  log "disabling RS-1 (PR gate) for the retract window"
  ruleset_put_enforcement "$PR_GATE_ID" disabled
  wait_for_enforcement "$PR_GATE_ID" disabled ||
    die "RS-1 did not reach enforcement=disabled"
  verify_ruleset pr_gate "$PR_GATE_ID" disabled
}

enable_pr_gate() {
  log "enabling RS-1 (PR gate)"
  ruleset_put_enforcement "$PR_GATE_ID" active
  wait_for_enforcement "$PR_GATE_ID" active ||
    die "RS-1 did not reach enforcement=active"
  verify_ruleset pr_gate "$PR_GATE_ID" active
}

print_manual_restore() {
  printf 'manual restore:\n' >&2
  printf '  gh api -X PUT repos/%s/rulesets/%s --input - <<< %q\n' \
    "$(rulesets_repo)" "$PR_GATE_ID" '{"enforcement":"active"}' >&2
  printf '  snapshot: %s\n' "$SNAPSHOT_DIR" >&2
}

rulesets_status() {
  resolve_rulesets
  printf 'RS-1 %s (%s): %s\n' "$PR_GATE_NAME" "$PR_GATE_ID" \
    "$(ruleset_get "$PR_GATE_ID" | jq -r .enforcement)"
  printf 'RS-2 %s (%s): %s\n' "$HISTORY_NAME" "$HISTORY_ID" \
    "$(ruleset_get "$HISTORY_ID" | jq -r .enforcement)"
  printf 'RS-3 %s (%s): %s\n' "$UNDELETABLE_NAME" "$UNDELETABLE_ID" \
    "$(ruleset_get "$UNDELETABLE_ID" | jq -r .enforcement)"
}
