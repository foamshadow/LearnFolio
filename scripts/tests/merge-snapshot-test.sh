#!/usr/bin/env bash
# Fixture tests for scripts/merge.sh.  No network, no real merge: every case
# stops at --dry-run, with a fake gh that serves PR/comments JSON.
set -Eeuo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
MERGE_SH="$SCRIPT_DIR/../merge.sh"
[[ -x "$MERGE_SH" ]] || {
  printf 'missing executable: %s\n' "$MERGE_SH" >&2
  exit 1
}

tmp=$(mktemp -d)
cleanup() {
  rm -rf "$tmp"
}
trap cleanup EXIT

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

sha256_hex() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum | awk '{print $1}'
  else
    shasum -a 256 | awk '{print $1}'
  fi
}

git init -q "$tmp/repo"
git -C "$tmp/repo" config user.email test@example.invalid
git -C "$tmp/repo" config user.name test
printf 'fixture\n' >"$tmp/repo/file"
git -C "$tmp/repo" add file
git -C "$tmp/repo" commit -qm 'fixture base'
head1=$(git -C "$tmp/repo" rev-parse HEAD)
printf 'second\n' >>"$tmp/repo/file"
git -C "$tmp/repo" commit -qam 'fixture second'
head2=$(git -C "$tmp/repo" rev-parse HEAD)

mkdir -p "$tmp/bin"
cat >"$tmp/bin/gh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
case "${1:-}" in
  repo) printf 'owner/repo\n' ;;
  pr)
    case "${2:-}" in
      view) cat "${FAKE_PR_JSON:?}" ;;
      merge) printf '%s\n' "$*" >>"${FAKE_MERGE_LOG:?}" ;;
      *) printf 'fake gh: unsupported pr %s\n' "${2:-}" >&2; exit 1 ;;
    esac
    ;;
  api) cat "${FAKE_COMMENTS_JSON:?}" ;;
  *) printf 'fake gh: unsupported %s\n' "$*" >&2; exit 1 ;;
esac
EOF
chmod +x "$tmp/bin/gh"
export PATH="$tmp/bin:$PATH"
export FAKE_MERGE_LOG="$tmp/merge.log"

body_docs=$'## 变更\n\nfixture docs change\n\nAssisted-by: ClaudeCode:glm-5.3-flash\n'
body_code=$'## 变更\n\nfixture code change\n\nAssisted-by: ClaudeCode:glm-5.3-flash\n'

make_pr() {
  local body=$1 head=$2 ref=$3 out=$4
  jq -n \
    --arg body "$body" \
    --arg head "$head" \
    --arg ref "$ref" \
    '{
      number: 42,
      title: "docs: fixture merge snapshot",
      body: $body,
      headRefOid: $head,
      headRefName: $ref,
      baseRefName: "dev",
      state: "OPEN",
      isDraft: false,
      mergeable: "MERGEABLE",
      mergeStateStatus: "CLEAN",
      url: "https://example.invalid/pull/42"
    }' >"$out"
}

make_comments() {
  local body=$1 hash=$2 out=$3
  jq -n --arg body "$body" --arg hash "$hash" \
    '[{id: 1, html_url: "https://example.invalid/pull/42#issuecomment-1", body: $body}]' \
    >"$out"
}

pass_body() {
  local target=$1 hash=$2
  printf 'REVIEW: PASS\ntarget %s\nbody-sha256: %s\n\nReviewer: DSH:deepseek-v4.1-flash-1017\n' \
    "$target" "$hash"
}

body_hash() {
  local title=$1 body=$2
  { printf '%s\n' "$title"; printf '%s' "$body"; } | sha256_hex
}

run_merge() {
  (cd "$tmp/repo" && bash "$MERGE_SH" "$@" 2>&1)
}

expect_ok() {
  local name=$1
  shift
  local out
  if ! out=$(run_merge "$@"); then
    printf '%s\n' "$out" >&2
    fail "$name: expected success"
  fi
  printf 'PASS %s\n' "$name"
  printf '%s\n' "$out" >"$tmp/last.out"
}

expect_fail() {
  local name=$1
  shift
  local out rc
  set +e
  out=$(run_merge "$@")
  rc=$?
  set -e
  ((rc != 0)) || {
    printf '%s\n' "$out" >&2
    fail "$name: expected non-zero exit"
  }
  printf 'PASS %s (failed as expected)\n' "$name"
}

# --- docs path: squash + snapshot body
make_pr "$body_docs" "$head1" "docs/fixture" "$tmp/pr-docs.json"
make_comments "$(pass_body "$head1" "$(body_hash 'docs: fixture merge snapshot' "$body_docs")")" \
  "$(body_hash 'docs: fixture merge snapshot' "$body_docs")" "$tmp/comments-docs.json"
FAKE_PR_JSON="$tmp/pr-docs.json" FAKE_COMMENTS_JSON="$tmp/comments-docs.json" \
  expect_ok "docs dry-run" 42 --dry-run
grep -q -- '--squash' "$tmp/last.out" || fail "docs dry-run did not select squash"
grep -q -- '--body-file' "$tmp/last.out" || fail "docs dry-run did not pass snapshot body"
grep -q -- '--merge' "$tmp/last.out" && fail "docs dry-run unexpectedly selected merge"

# --- code path: --no-ff, no subject/body
make_pr "$body_code" "$head1" "feat/spec-0001-t9-fixture" "$tmp/pr-code.json"
make_comments "$(pass_body "$head1" "$(body_hash 'docs: fixture merge snapshot' "$body_code")")" \
  "$(body_hash 'docs: fixture merge snapshot' "$body_code")" "$tmp/comments-code.json"
FAKE_PR_JSON="$tmp/pr-code.json" FAKE_COMMENTS_JSON="$tmp/comments-code.json" \
  expect_ok "code dry-run" 42 --dry-run
grep -q -- '--merge' "$tmp/last.out" || fail "code dry-run did not select merge"
grep -q -- '--squash' "$tmp/last.out" && fail "code dry-run unexpectedly selected squash"
grep -q -- '--subject' "$tmp/last.out" && fail "code dry-run must not pass a subject"

# --- body edited after PASS: hash mismatch
body_edited=$'## 变更\n\nfixture docs change (edited)\n\nAssisted-by: ClaudeCode:glm-5.3-flash\n'
make_pr "$body_edited" "$head1" "docs/fixture" "$tmp/pr-edited.json"
FAKE_PR_JSON="$tmp/pr-edited.json" FAKE_COMMENTS_JSON="$tmp/comments-docs.json" \
  expect_fail "body hash mismatch" 42 --dry-run

# --- head moved after PASS: target mismatch
make_pr "$body_docs" "$head2" "docs/fixture" "$tmp/pr-head2.json"
FAKE_PR_JSON="$tmp/pr-head2.json" FAKE_COMMENTS_JSON="$tmp/comments-docs.json" \
  expect_fail "target mismatch" 42 --dry-run

# --- PASS without Reviewer line
hash_docs=$(body_hash 'docs: fixture merge snapshot' "$body_docs")
make_comments $'REVIEW: PASS\ntarget '"$head1"$'\nbody-sha256: '"$hash_docs"$'\n' \
  "$hash_docs" "$tmp/comments-no-reviewer.json"
FAKE_PR_JSON="$tmp/pr-docs.json" FAKE_COMMENTS_JSON="$tmp/comments-no-reviewer.json" \
  expect_fail "missing Reviewer" 42 --dry-run

# --- review state line in PR body
body_review=$'## 变更\n\nReviewer: DSH:deepseek-v4.1-flash-1017\n\nAssisted-by: ClaudeCode:glm-5.3-flash\n'
make_pr "$body_review" "$head1" "docs/fixture" "$tmp/pr-review.json"
FAKE_PR_JSON="$tmp/pr-review.json" FAKE_COMMENTS_JSON="$tmp/comments-docs.json" \
  expect_fail "review state line" 42 --dry-run

printf 'all merge-snapshot fixture tests passed\n'
