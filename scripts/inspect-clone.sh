#!/usr/bin/env bash
set -euo pipefail

repo=${1:-.}

if ! git -C "$repo" rev-parse --git-dir >/dev/null 2>&1; then
  printf 'ERROR: not a Git repository: %s\n' "$repo" >&2
  exit 2
fi

printf 'top-level: %s\n' "$(git -C "$repo" rev-parse --show-toplevel 2>/dev/null || printf '(bare repository)')"
printf 'git-dir: %s\n' "$(git -C "$repo" rev-parse --git-dir)"
printf 'bare: %s\n' "$(git -C "$repo" rev-parse --is-bare-repository)"
printf 'shallow: %s\n' "$(git -C "$repo" rev-parse --is-shallow-repository)"
printf 'branch: %s\n' "$(git -C "$repo" branch --show-current 2>/dev/null || true)"
printf 'head: %s\n' "$(git -C "$repo" rev-parse HEAD 2>/dev/null || printf '(unborn or unavailable)')"

if git -C "$repo" remote get-url origin >/dev/null 2>&1; then
  printf 'origin-fetch: %s\n' "$(git -C "$repo" remote get-url origin)"
  printf 'origin-push: %s\n' "$(git -C "$repo" remote get-url --push origin)"
else
  printf 'origin: (none)\n'
fi

printf 'partial-filter: %s\n' "$(git -C "$repo" config --get remote.origin.partialclonefilter || printf '(none)')"
printf 'sparse-checkout: %s\n' "$(git -C "$repo" config --bool core.sparseCheckout || printf 'false')"
printf 'mirror: %s\n' "$(git -C "$repo" config --bool remote.origin.mirror || printf 'false')"
printf 'origin-fetch-refspecs:\n'
git -C "$repo" config --get-all remote.origin.fetch 2>/dev/null || printf '  (none)\n'

printf 'submodules:\n'
git -C "$repo" submodule status --recursive 2>/dev/null || printf '  (none or unavailable)\n'

if command -v git-lfs >/dev/null 2>&1 || git lfs version >/dev/null 2>&1; then
  printf 'lfs-files:\n'
  git -C "$repo" lfs ls-files 2>/dev/null || printf '  (none or unavailable)\n'
else
  printf 'lfs: git-lfs not installed\n'
fi

if [ "$(git -C "$repo" rev-parse --is-bare-repository)" = false ]; then
  printf 'status:\n'
  git -C "$repo" status --short --branch
fi
