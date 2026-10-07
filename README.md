<div align="center">

# keel

**Engineering standards for any Git repository — installed in one command, tuned per project, upgraded without losing your edits.**

[![CI](https://github.com/brizenchi/keel/actions/workflows/ci.yml/badge.svg)](https://github.com/brizenchi/keel/actions/workflows/ci.yml)
[![Release](https://img.shields.io/github/v/release/brizenchi/keel?sort=semver)](https://github.com/brizenchi/keel/releases)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

English · [简体中文](README.zh-CN.md)

</div>

keel gives a repository the boring-but-essential parts of a well-run codebase:
written standards, CI quality gates, secret scanning, Conventional Commits,
GitHub branch rules, Dependabot, and rules for AI coding assistants. You pick
the pieces you want; every generated file stays a plain, editable file in your
repository.

```console
$ keel init
? Components to install
  ◉ docs            standards documents (docs/standards/)
  ◉ ci              language checks in CI (.github/workflows/keel.yml)
  ◉ commit-lint     PR titles must follow Conventional Commits (CI)
  ◉ secrets         secret scanning: gitleaks config + CI job
  ◉ hooks           local git hooks: secret scan + formatters (lefthook.yml)
  ◯ ai              AI assistant rules: AGENTS.md, CLAUDE.md, Claude Code hooks
  …
? Languages used in this repository  ◉ Go  ◉ Node / TypeScript  ◯ Python
```

## Why keel

- **Choose, don't inherit.** Thirteen independent components. Untick one and
  its files are never written; disable it later and they are removed.
- **Yours to edit.** Generated files are ordinary files. `keel update` performs
  a three-way merge, so local edits survive upgrades and real conflicts are
  shown like a Git merge. Files such as `PROJECT.md` and `CODEOWNERS` are never
  touched after the first install.
- **CI is the gate, not your laptop.** Checks run in GitHub Actions through
  versioned [reusable workflows](docs/workflows.md). Local hooks only do what
  must happen before code leaves your machine: secret scanning and formatting.
- **Git-native.** `keel github` applies a branch ruleset (required checks,
  squash-only merges, linear history), secret scanning with push protection,
  Dependabot alerts and private vulnerability reporting — idempotently.
- **Deterministic.** Installation is template rendering with
  [Copier](https://copier.readthedocs.io/). No AI is involved; the same answers
  produce the same files.
- **Go, Node / TypeScript, Python**, including monorepos with several modules.

## Install

keel needs `git` and [uv](https://docs.astral.sh/uv/) (or pipx).

```bash
curl -fsSL https://raw.githubusercontent.com/brizenchi/keel/main/install.sh | sh
```

This places a single script at `~/.local/bin/keel`. Every project also gets its
own copy at `.keel/bin/keel`, so teammates can run it without a global install.

## Quick start

```bash
cd your-repo            # a Git repository with a clean working tree
keel init               # choose components and answer a few questions
git diff                # review what was generated
keel hooks              # install local git hooks (needs lefthook, gitleaks)
keel github --dry-run   # preview GitHub settings, then run without --dry-run
git add -A && git commit -m "chore: install keel"
```

Non-interactive, e.g. in a bootstrap script:

```bash
keel init --defaults -- \
  --data 'languages=["go","node"]' \
  --data 'go_modules=[{"dir": "."}]' \
  --data 'node_projects=[{"dir": "web"}]'
```

## Day-to-day

| Task | Command |
| --- | --- |
| See what is installed, outdated or missing | `keel status` |
| Check local tooling | `keel doctor` |
| Turn components on or off | `keel enable ai` · `keel disable dependabot` |
| Change an answer | `keel set default_branch=develop` |
| Add a module to check | `keel add go_modules dir=services/api` |
| Re-answer everything interactively | `keel config` |
| Upgrade to the latest release | `keel update` |
| Validate a commit message | `keel lint-commit -m "feat(api): add search"` |

Every command that changes files requires a clean working tree and ends by
listing the changed files, so each change is one reviewable diff.

## What you get

| Component | Files | Enforced by |
| --- | --- | --- |
| `docs` | `docs/standards/` — Git workflow, code review, code style and error handling, Go / Node / Python, API, database, security, testing, CI, incident response, onboarding, and a project-owned `PROJECT.md` | review |
| `ci` | `.github/workflows/keel.yml` — gofmt/vet/race tests/golangci-lint, package scripts, ruff/pytest, vulnerability audits | GitHub Actions |
| `commit-lint` | Conventional Commits check of PR titles | GitHub Actions |
| `secrets` | `.gitleaks.toml` + full-history scan | GitHub Actions, local hook |
| `hooks` | `lefthook.yml` — secret scan and formatters on commit | git |
| `github` | `.keel/required-checks.txt` for `keel github` | GitHub ruleset |
| `pr-template`, `codeowners`, `dependabot`, `security-policy`, `editorconfig`, `gitignore` | the usual repository files | GitHub |
| `ai` | `AGENTS.md`, `CLAUDE.md`, Claude Code hooks (format edits, block `--no-verify` and force pushes) | the assistant / Claude Code |

Details: [docs/components.md](docs/components.md). The standards documents are
currently written in Simplified Chinese; an English edition is on the roadmap.

## Customising

| You want to… | Do this |
| --- | --- |
| Adjust any generated file | Edit it. `keel update` merges around your changes. |
| Record project conventions | `docs/standards/PROJECT.md` and the *Project-specific rules* section of `AGENTS.md` |
| Add your own CI checks | Another workflow file; append the check names to `.keel/required-checks.txt`, then `keel github` |
| Gate a deploy on keel's checks | `keel set ci_mode=reusable`, call `./.github/workflows/keel.yml` from your pipeline and add `needs:` |
| Change a rule for every project | Fork or contribute to keel, release, then `keel update` in each project |

All answers are documented in [docs/configuration.md](docs/configuration.md).

## Documentation

- [CLI reference](docs/cli.md)
- [Components](docs/components.md)
- [Configuration (answers)](docs/configuration.md)
- [Reusable workflows](docs/workflows.md)
- [Migrating from dev-standards 1.x](docs/migration.md)

## Versioning

Releases are tagged `vX.Y.Z` and follow [Semantic Versioning](https://semver.org/).
Generated workflows reference `@v2`, a branch that tracks the latest 2.x
release; projects record the exact installed tag in `.keel/answers.yml`.
See [CHANGELOG.md](CHANGELOG.md).

## Contributing

Issues and pull requests are welcome — see [CONTRIBUTING.md](CONTRIBUTING.md).
Please report security issues privately as described in [SECURITY.md](SECURITY.md).

## License

[MIT](LICENSE) © brizenchi
