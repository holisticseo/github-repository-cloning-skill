# GitHub Repository Cloning Skill

A verification-first skill for choosing and safely executing GitHub repository acquisition methods.

It covers:

- HTTPS, SSH, GitHub CLI, and GitHub Desktop
- full, shallow, partial, sparse, and single-branch clones
- submodules and Git LFS
- bare clones, mirrors, and Git bundles
- GitHub source archives and why they are not clones
- post-clone verification and common failures

## Install in Hermes Agent

Copy this repository into a skill directory so `SKILL.md` is at the skill root, or use the runtime's supported skill installation workflow. The skill name is `github-repository-cloning`.

## Use

Load the skill whenever a request involves cloning, downloading, mirroring, migrating, or making an offline copy of a GitHub repository.

For local verification:

```bash
./scripts/inspect-clone.sh /path/to/repository
```

The script is read-only. It reports repository type, origin, branch, shallow/partial/sparse state, submodules, and Git LFS tracking.

## Research basis

The initial idea came from a shared Grok conversation, but operational claims were checked against current GitHub, GitHub CLI, and Git documentation. See [research notes](references/research.md).

## License

MIT — see [LICENSE](LICENSE).
