#!/usr/bin/env bash
set -euo pipefail

repo=${1:-.}

redact_url() {
  local url=$1
  local prefix remainder query fragment pair key lower
  local -a pairs redacted_pairs

  # Remove all URL userinfo (username, password, or token) before printing.
  # SCP-like SSH syntax (git@host:path) cannot carry a password and is kept.
  if [[ $url =~ ^([A-Za-z][A-Za-z0-9+.-]*://)([^/]*@)(.*)$ ]]; then
    url="${BASH_REMATCH[1]}[REDACTED]@${BASH_REMATCH[3]}"
  fi

  # Redact common credential-bearing query parameters as a second guard.
  if [[ $url == *\?* ]]; then
    prefix=${url%%\?*}
    remainder=${url#*\?}
    fragment=
    if [[ $remainder == *#* ]]; then
      query=${remainder%%#*}
      fragment="#${remainder#*#}"
    else
      query=$remainder
    fi

    IFS='&' read -r -a pairs <<< "$query"
    redacted_pairs=()
    for pair in "${pairs[@]}"; do
      key=${pair%%=*}
      lower=$(printf '%s' "$key" | tr '[:upper:]' '[:lower:]')
      case "$lower" in
        access_token|auth|authorization|credential|key|oauth_token|password|passwd|secret|token|api_key|apikey)
          pair="${key}=[REDACTED]"
          ;;
      esac
      redacted_pairs+=("$pair")
    done
    query=$(IFS='&'; printf '%s' "${redacted_pairs[*]}")
    url="${prefix}?${query}${fragment}"
  fi

  printf '%s' "$url"
}

print_remote_urls() {
  local label=$1
  shift
  local url
  while IFS= read -r url; do
    printf '%s: %s\n' "$label" "$(redact_url "$url")"
  done < <(git -C "$repo" remote get-url --all "$@")
}

if ! git -C "$repo" rev-parse --git-dir >/dev/null 2>&1; then
  printf 'ERROR: not a Git repository: %s\n' "$repo" >&2
  exit 2
fi

printf 'top-level: %s\n' "$(git -C "$repo" rev-parse --show-toplevel 2>/dev/null || printf '(bare repository)')"
printf 'git-dir: %s\n' "$(git -C "$repo" rev-parse --git-dir)"
printf 'bare: %s\n' "$(git -C "$repo" rev-parse --is-bare-repository)"
printf 'shallow: %s\n' "$(git -C "$repo" rev-parse --is-shallow-repository)"
printf 'branch: %s\n' "$(git -C "$repo" branch --show-current 2>/dev/null || true)"
if head=$(git -C "$repo" rev-parse --verify HEAD 2>/dev/null); then
  printf 'head: %s\n' "$head"
else
  printf 'head: (unborn)\n'
fi

if git -C "$repo" remote get-url origin >/dev/null 2>&1; then
  print_remote_urls 'origin-fetch' origin
  print_remote_urls 'origin-push' --push origin
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
