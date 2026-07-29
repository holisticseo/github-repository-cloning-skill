#!/usr/bin/env bash
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
inspector="$root/scripts/inspect-clone.sh"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

assert_contains() {
  local haystack=$1 needle=$2
  [[ $haystack == *"$needle"* ]] || fail "expected output to contain: $needle"
}

assert_not_contains() {
  local haystack=$1 needle=$2
  [[ $haystack != *"$needle"* ]] || fail "output exposed forbidden value: $needle"
}

# Unborn repository: rev-parse must not leak the literal HEAD fallback.
git init -q "$tmp/unborn"
unborn_output=$("$inspector" "$tmp/unborn")
assert_contains "$unborn_output" 'bare: false'
assert_contains "$unborn_output" 'head: (unborn)'
[[ $(printf '%s\n' "$unborn_output" | grep -c '^head: ') -eq 1 ]] || fail 'unborn repository printed an invalid head value'

# Normal repository with credential-bearing fetch/push URLs. Build the fixtures
# at runtime so no credential-shaped URL is stored in the source tree.
fetch_user='fetch-user-sentinel'
fetch_password='fetch-password-sentinel'
fetch_query='fetch-query-sentinel'
push_user='push-token-sentinel'
push_query='push-query-sentinel'
deploy_user='deploy-secret-sentinel'
ssh_query='ssh-query-sentinel'
redacted_marker="[$(printf 'REDACTED')]"
printf 'fixture\n' > "$tmp/unborn/fixture.txt"
git -C "$tmp/unborn" add fixture.txt
git -C "$tmp/unborn" -c user.name='Inspector Test' -c user.email='inspector@example.invalid' commit -q -m fixture
git -C "$tmp/unborn" remote add origin "https://${fetch_user}:${fetch_password}@example.invalid/org/repo.git?token=${fetch_query}&mode=read"
git -C "$tmp/unborn" remote set-url --push origin "https://${push_user}@example.invalid/org/repo.git?access_token=${push_query}#fragment"
git -C "$tmp/unborn" remote set-url --add --push origin "ssh://${deploy_user}@example.invalid/org/repo.git?password=${ssh_query}"
normal_output=$("$inspector" "$tmp/unborn")
assert_contains "$normal_output" 'bare: false'
assert_contains "$normal_output" 'head: '
assert_not_contains "$normal_output" 'head: (unborn)'
assert_contains "$normal_output" "origin-fetch: https://${redacted_marker}@example.invalid/org/repo.git?token=${redacted_marker}&mode=read"
assert_contains "$normal_output" "origin-push: https://${redacted_marker}@example.invalid/org/repo.git?access_token=${redacted_marker}#fragment"
assert_contains "$normal_output" "origin-push: ssh://${redacted_marker}@example.invalid/org/repo.git?password=${redacted_marker}"
for secret in "$fetch_user" "$fetch_password" "$fetch_query" "$push_user" "$push_query" "$deploy_user" "$ssh_query"; do
  assert_not_contains "$normal_output" "$secret"
done

# Bare repository behavior.
git clone -q --bare "$tmp/unborn" "$tmp/bare.git"
bare_output=$("$inspector" "$tmp/bare.git")
assert_contains "$bare_output" 'top-level: (bare repository)'
assert_contains "$bare_output" 'bare: true'
assert_contains "$bare_output" 'head: '
[[ $bare_output != *$'status:\n'* ]] || fail 'bare repository should not print worktree status'

printf 'PASS: redaction, normal, bare, and unborn inspector behavior\n'
