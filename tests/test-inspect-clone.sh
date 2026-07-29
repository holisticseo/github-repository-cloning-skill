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

# Normal repository with credential-bearing fetch/push URLs.
printf 'fixture\n' > "$tmp/unborn/fixture.txt"
git -C "$tmp/unborn" add fixture.txt
git -C "$tmp/unborn" -c user.name='Inspector Test' -c user.email='inspector@example.invalid' commit -q -m fixture
git -C "$tmp/unborn" remote add origin 'https://fetch-user:fetch-password@example.invalid/org/repo.git?token=fetch-query-secret&mode=read'
git -C "$tmp/unborn" remote set-url --push origin 'https://push-token@example.invalid/org/repo.git?access_token=push-query-secret#fragment'
git -C "$tmp/unborn" remote set-url --add --push origin 'ssh://deploy-secret@example.invalid/org/repo.git?password=ssh-query-secret'
normal_output=$("$inspector" "$tmp/unborn")
assert_contains "$normal_output" 'bare: false'
assert_contains "$normal_output" 'head: '
assert_not_contains "$normal_output" 'head: (unborn)'
assert_contains "$normal_output" 'origin-fetch: https://[REDACTED]@example.invalid/org/repo.git?token=[REDACTED]&mode=read'
assert_contains "$normal_output" 'origin-push: https://[REDACTED]@example.invalid/org/repo.git?access_token=[REDACTED]#fragment'
assert_contains "$normal_output" 'origin-push: ssh://[REDACTED]@example.invalid/org/repo.git?password=[REDACTED]'
for secret in fetch-user fetch-password fetch-query-secret push-token push-query-secret deploy-secret ssh-query-secret; do
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
