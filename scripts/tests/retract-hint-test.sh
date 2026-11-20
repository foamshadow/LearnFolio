#!/usr/bin/env bash
# Fixture tests for the retract.sh hint-commit component (ADR-0012 ②).
# Extracts the LIVE validation + hint blocks out of scripts/retract.sh and
# runs them against throwaway repos: no network, no ruleset mutation.
# Scenarios: success / commit-tree failure / update-ref CAS failure /
# push failure / invalid RETRACT_ASSISTED_BY (die).
set -Eeuo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
RETRACT_SH="$SCRIPT_DIR/../retract.sh"
[[ -f "$RETRACT_SH" ]] || {
  printf 'missing: %s\n' "$RETRACT_SH" >&2
  exit 1
}

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

# --- extract the live blocks -------------------------------------------------
# Trailer validation: comment marker through its closing `esac`.
VALIDATION=$(awk '/^# ADR-0012 component 2 trailer declaration/{f=1} f{print} f&&/^esac$/{exit}' "$RETRACT_SH")
# Hint publish: `hint_msg=$(cat <<HINT` through the outermost (column-0) `fi`.
HINT_BLOCK=$(awk '/^hint_msg=\$\(cat <<HINT$/{f=1} f{print} f&&/^fi$/{exit}' "$RETRACT_SH")
[[ -n "$VALIDATION" ]] || fail "validation block not found in retract.sh"
[[ -n "$HINT_BLOCK" ]] || fail "hint block not found in retract.sh"
[[ "$VALIDATION" == *esac ]] || fail "validation extraction truncated"
[[ "$HINT_BLOCK" == *fi ]] || fail "hint extraction truncated"

tmp=$(mktemp -d)
cleanup() {
  rm -rf "$tmp"
}
trap cleanup EXIT

# Run the extracted blocks inside a fixture repo. Scenarios may pre-tweak the
# repo before the blocks execute (broken remote, moved backup ref, ...).
# $1 = scenario name, $2 = RETRACT_ASSISTED_BY value
run_scenario() {
  local scenario="$1" assisted_value="$2"
  local dir="$tmp/$scenario"
  mkdir -p "$dir"
  git -C "$dir" init -q
  git -C "$dir" config user.name t
  git -C "$dir" config user.email t@t.local
  echo a >"$dir/a.txt"
  git -C "$dir" add .
  git -C "$dir" commit -qm "bad"
  git -C "$dir" branch backup/dev-test
  git -C "$dir" remote add origin "$dir/origin.git"

  (
    cd "$dir"
    log() {
      printf '[log] %s\n' "$*"
    }
    die() {
      printf '[die] %s\n' "$*"
      exit 78
    }
    export RETRACT_ASSISTED_BY="$assisted_value"
    eval "$VALIDATION"
    # Per-scenario pre-tweaks AFTER validation, BEFORE the hint publish.
    case "$scenario" in
      commit-tree-fail) git branch -D backup/dev-test ;;       # tree-ish gone
      update-ref-cas-fail) x=$(git commit-tree 'HEAD^{tree}' -m x) && git branch -f backup/dev-test "$x" ;;  # backup != bad_sha
      push-fail) git remote set-url origin "$dir/broken-origin" ;;  # nonexistent path
    esac
    bad_sha=$(git rev-parse HEAD)   # pre-tweaks in D move only `backup`
    backup=backup/dev-test
    eval "$HINT_BLOCK"
  )
}

# --- A: success (bare remote, FF push, trailer declared) ----------------------
git init -q --bare "$tmp/success/origin.git" 2>/dev/null || {
  mkdir -p "$tmp/success"
  git init -q --bare "$tmp/success/origin.git"
}
# note: run_scenario recreates the dir; seed the bare remote after init.
run_scenario success none
rc=$?
[[ $rc -eq 0 ]] || fail "success scenario exited $rc"
ref=$(git -C "$tmp/success/origin.git" rev-parse refs/heads/backup/dev-test)
parent=$(git -C "$tmp/success" rev-parse refs/heads/backup/dev-test^)
bad=$(git -C "$tmp/success" rev-parse HEAD)
[[ "$parent" == "$bad" ]] || fail "hint parent is not bad tip"
tree_hint=$(git -C "$tmp/success" rev-parse "refs/heads/backup/dev-test^{tree}")
tree_bad=$(git -C "$tmp/success" rev-parse "HEAD^{tree}")
[[ "$tree_hint" == "$tree_bad" ]] || fail "hint tree differs from bad tip"
trailer=$(git -C "$tmp/success" log -1 --format=%B refs/heads/backup/dev-test | grep '^Assisted-by:')
[[ "$trailer" == "Assisted-by: none" ]] || fail "trailer mismatch: $trailer"
printf 'ok: success\n'

# --- B: commit-tree failure (backup ref deleted pre-flight) -------------------
out=$(run_scenario commit-tree-fail none 2>&1); rc=$?
[[ $rc -eq 0 ]] || fail "commit-tree-fail exited $rc (must be non-fatal)"
[[ "$out" == *"hint commit failed"* ]] || fail "missing hint-commit WARNING"
[[ "$out" == *"components 1/3 still notify"* ]] || fail "missing fallback note"
printf 'ok: commit-tree-fail\n'

# --- C: update-ref CAS failure ------------------------------------------------
out=$(run_scenario update-ref-cas-fail none 2>&1); rc=$?
[[ $rc -eq 0 ]] || fail "update-ref-cas-fail exited $rc (must be non-fatal)"
[[ "$out" == *"hint ref update failed"* ]] || fail "missing ref-update WARNING"
printf 'ok: update-ref-cas-fail\n'

# --- D: push failure (broken remote; local hint remains) ----------------------
out=$(run_scenario push-fail none 2>&1); rc=$?
[[ $rc -eq 0 ]] || fail "push-fail exited $rc (must be non-fatal)"
[[ "$out" == *"hint push failed"* ]] || fail "missing push WARNING"
[[ "$out" == *"local hint remains"* ]] || fail "missing local-remains note"
local_ref=$(git -C "$tmp/push-fail" rev-parse refs/heads/backup/dev-test)
[[ -n "$local_ref" ]] || fail "local backup ref missing after failed push"
printf 'ok: push-fail\n'

# --- E: invalid RETRACT_ASSISTED_BY (die before any mutation) -----------------
rc=0
out=$(run_scenario trailer-invalid "not valid!" 2>&1) || rc=$?
[[ $rc -eq 78 ]] || fail "invalid trailer should die(78), got $rc"
[[ "$out" == *"invalid RETRACT_ASSISTED_BY"* ]] || fail "missing invalid-value message"
printf 'ok: trailer-invalid\n'

printf 'ALL SCENARIOS PASSED\n'
