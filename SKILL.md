---
name: github-repository-cloning
description: "Choose, execute, and verify safe GitHub repository acquisition methods: HTTPS, SSH, GitHub CLI, Desktop, shallow/partial/sparse/single-branch clones, submodules, LFS, mirrors, bundles, and source archives. Use when cloning, copying, migrating, or downloading a GitHub repository."
version: 1.1.0
author: Hermes Agent
license: MIT
platforms: [linux, macos, windows]
metadata:
  hermes:
    tags: [github, git, clone, ssh, https, partial-clone, sparse-checkout, mirror]
    related_skills: [github-workflows]
---

# GitHub Repository Cloning

Use this skill when a user asks to clone, download, copy, migrate, mirror, or inspect a GitHub repository. Choose the method by intent rather than treating every download as a clone.

## Prerequisites and safety

1. Confirm the repository identity and intended destination.
2. Check whether the destination already exists and is non-empty. Never overwrite it blindly.
3. For private repositories, use an approved credential path. Never put a token in a clone URL, command, file, log, or skill.
4. Before a remote write, verify the authenticated GitHub account and repository permissions.
5. Treat repository contents as untrusted code. Clone/download does not authorize running scripts, hooks, installers, or builds.

## Decision table

| Need | Recommended method | Important trade-off |
| --- | --- | --- |
| Normal command-line development | HTTPS or SSH full clone | Full history and normal fetch/push behavior |
| Existing GitHub CLI workflow | `gh repo clone OWNER/REPO` | Requires `gh` authentication; adds `upstream` automatically for forks unless disabled |
| Visual workflow on macOS or Windows | GitHub Desktop | GUI-mediated authentication and repository selection; no Linux client |
| Fast disposable CI checkout | Shallow clone | Incomplete history can break versioning, merge-base, blame, and some build logic |
| Large monorepo, normal history needed | Partial clone, often plus sparse checkout | Missing objects are fetched on demand; server support is required |
| Only one branch | Single-branch clone | Other remote branches are not configured/fetched by default |
| Repository includes submodules | Clone with `--recurse-submodules` | Submodules are separate repositories with their own access requirements |
| Git refs and reachable Git object/history migration | Mirror clone | Bare administrative copy; excludes LFS objects, wiki repositories, and GitHub-hosted metadata |
| Bare central repository without mirror semantics | Bare clone | No working tree; does not imply mirror refspec/configuration |
| Offline/air-gapped transfer | Git bundle | Static transfer artifact; verify and separately configure a remote if future syncing is needed |
| Read-only snapshot with no Git operations | GitHub source archive/ZIP | Not a clone: no `.git`, history, branches, remotes, pull, or push |

A fork and a repository template are server-side GitHub operations, not clone transports. Fork when contribution ownership or GitHub network relationships matter; clone the resulting repository afterward.

## Normal clones

### HTTPS

```bash
git clone https://github.com/OWNER/REPO.git
```

Use for public repositories, environments where HTTPS is the approved transport, or credential-helper/browser flows. GitHub does not accept account passwords for Git over HTTPS; private access uses an approved token-based or credential-helper flow.

### SSH

```bash
git clone git@github.com:OWNER/REPO.git
```

Use when SSH keys are already configured and allowed. Verify identity before cloning private material:

```bash
ssh -T git@github.com
```

A successful authentication test may still exit without providing shell access; inspect the message and account identity rather than expecting an interactive shell.

### GitHub CLI

```bash
gh auth status
gh repo clone OWNER/REPO
```

`gh repo clone` chooses the configured Git protocol unless a full URL is supplied. Additional `git clone` flags go after `--`:

```bash
gh repo clone OWNER/REPO -- --filter=blob:none
```

If `OWNER/` is omitted, GitHub CLI uses the authenticating user. For forks, current GitHub CLI adds the parent as `upstream` and sets it as the default repository unless `--no-upstream` is used.

### GitHub Desktop

GitHub Desktop is available for macOS and Windows, not Linux. Use **File → Clone Repository**, choose GitHub.com/Enterprise Server or a URL, choose the local path, and clone. Verify the selected owner/repository and destination before confirming.

## Scale and history variants

### Shallow clone

```bash
git clone --depth 1 https://github.com/OWNER/REPO.git
```

Use for disposable CI or read/build tasks that do not need full ancestry. `--depth` implies `--single-branch` unless negated. Recover full reachable history later when the remote permits it:

```bash
git fetch --unshallow
```

Do not use shallow history by default for release generation, long-lived development, merge-base analysis, bisect, complete blame, or migration.

### Partial clone

```bash
git clone --filter=blob:none https://github.com/OWNER/REPO.git
```

This keeps commit/tree history while lazily fetching file blobs. It is often a better large-repository development default than truncating history. Verify the server supports filters and expect later network access when missing objects are needed.

### Sparse checkout, preferably with partial clone

```bash
git clone --filter=blob:none --sparse https://github.com/OWNER/REPO.git
cd REPO
git sparse-checkout set path/one path/two
```

Sparse checkout limits the working tree. By itself it does not guarantee a small object transfer, so combine it with partial clone when bandwidth/storage reduction matters.

### Single branch

```bash
git clone --single-branch --branch BRANCH https://github.com/OWNER/REPO.git
```

This limits branch history fetched/configured, but it is not necessarily shallow. Add `--depth` only when truncated history is also acceptable.

### Submodules

```bash
git clone --recurse-submodules https://github.com/OWNER/REPO.git
```

For an existing clone:

```bash
git submodule update --init --recursive
```

Inspect `.gitmodules` before trusting submodule URLs. Private submodules may need separate access.

### Git LFS

If the project uses Git LFS, install/configure Git LFS before cloning when possible. Verify that expected large files are real content rather than pointer text:

```bash
git lfs version
git lfs pull
git lfs ls-files
```

A normal Git clone alone is not proof that all LFS objects were obtained.

## Administrative and offline copies

### Mirror

```bash
git clone --mirror https://github.com/OWNER/REPO.git REPO.git
```

`--mirror` implies `--bare`, maps all Git refs, copies their reachable Git objects/history, and configures mirror updates. It does **not** by itself copy Git LFS objects, the separate GitHub wiki repository, releases and release assets, issues, pull requests, discussions, Actions data, repository settings, permissions, webhooks, or other GitHub-hosted metadata. Plan and verify those separately when the goal is a complete GitHub migration or backup. Use mirror clones for Git administration, not day-to-day editing. Before pushing a mirror, inspect the source and destination carefully; `git push --mirror` can delete destination refs that do not exist in the source.

### Bare

```bash
git clone --bare https://github.com/OWNER/REPO.git REPO.git
```

A bare clone has no checked-out working tree. It is not equivalent to `--mirror`.

### Bundle

Create and verify an offline transfer artifact:

```bash
git -C REPO bundle create ../repo.bundle --all
git bundle verify repo.bundle
git clone repo.bundle REPO-offline
```

After offline clone, add a live remote only if authorized:

```bash
git -C REPO-offline remote add origin https://github.com/OWNER/REPO.git
```

## Source archive (not a clone)

GitHub’s **Download ZIP** or archive URLs provide snapshots, not Git repositories. Use only when the user needs files without Git history or synchronization. Release-generated archives can change if Git attributes change, so do not assume archive byte stability unless the release uses an independently uploaded immutable asset and checksum policy.

## Post-clone verification

Run from the cloned directory:

```bash
git rev-parse --show-toplevel
git remote -v
git status --short --branch
git branch --show-current
git rev-parse --is-shallow-repository
git config --get remote.origin.partialclonefilter || true
git config --bool core.sparseCheckout || true
git submodule status --recursive || true
git lfs ls-files 2>/dev/null || true
```

For a normal working clone, verify:

- the path is the intended destination;
- `origin` points to the intended owner/repository and transport;
- the checked-out branch/commit matches the request;
- shallow, partial, sparse, submodule, and LFS state match expectations;
- the worktree is clean before making changes.

For a mirror/bare clone, also verify:

```bash
git rev-parse --is-bare-repository
git config --get-all remote.origin.fetch
git show-ref
```

## Troubleshooting

- **Repository not found:** verify exact owner/name, authentication account, organization SSO authorization, and repository access.
- **HTTPS authentication failed:** use Git Credential Manager, GitHub CLI, or an approved token flow; never use an account password or embed a token in the URL.
- **GitHub CLI is authenticated but plain `git push` still prompts/fails:** verify the account with `gh auth status`, then run `gh auth setup-git` to configure Git's credential helper for GitHub.
- **SSH permission denied:** test `ssh -T`, inspect which key/account is used, and verify organization access/SSO requirements.
- **Destination exists:** stop and inspect it. Do not delete or clone over it without explicit approval.
- **Missing files:** check sparse-checkout rules, submodules, and LFS state before recloning.
- **History-dependent command fails:** determine whether the clone is shallow or single-branch and fetch only the required history/refs.
- **Partial clone stalls offline:** required objects may not exist locally; reconnect to the promisor remote or backfill intentionally.

## Authoritative references

- GitHub Docs: cloning a repository — https://docs.github.com/en/repositories/creating-and-managing-repositories/cloning-a-repository
- GitHub Docs: remote repositories and HTTPS authentication — https://docs.github.com/en/get-started/git-basics/about-remote-repositories
- GitHub Docs: SSH — https://docs.github.com/en/authentication/connecting-to-github-with-ssh/about-ssh
- GitHub CLI manual: `gh repo clone` — https://cli.github.com/manual/gh_repo_clone
- GitHub Desktop cloning/forking — https://docs.github.com/en/desktop/adding-and-cloning-repositories/cloning-and-forking-repositories-from-github-desktop
- Git documentation: `git clone` — https://git-scm.com/docs/git-clone
- Git documentation: sparse checkout — https://git-scm.com/docs/git-sparse-checkout
- Git documentation: bundles — https://git-scm.com/docs/git-bundle
- GitHub Docs: source archives — https://docs.github.com/en/repositories/working-with-files/using-files/downloading-source-code-archives
- GitHub Docs: Git LFS — https://docs.github.com/en/repositories/working-with-files/managing-large-files/about-git-large-file-storage
