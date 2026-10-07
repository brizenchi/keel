# dev-standards

Engineering standards for any Git repository — Go, Node / TypeScript and Python —
installed with one command and kept up to date without losing local edits.

What a project gets:

| Area | Files |
| --- | --- |
| Standards (Chinese) | `docs/standards/`: Git workflow, code review, code style and error handling, Go / Node / Python rules, API, database, security, testing, CI, incident response, onboarding, AI assistants, and a project-owned `PROJECT.md` |
| Git integration | Conventional Commits PR-title check, PR template, CODEOWNERS, Dependabot, `.standards/bin/setup-github` (squash-only merges, branch ruleset with required checks, secret scanning + push protection, Dependabot alerts, private vulnerability reporting) |
| CI | `.github/workflows/standards.yml` calling versioned reusable workflows from this repository: `pr-title`, `secrets` (gitleaks), `go`, `node`, `python` |
| Local hooks | `lefthook.yml`: secret scan + formatter only; everything else is CI's job |
| AI assistants | `AGENTS.md` (Codex, Cursor, …), `CLAUDE.md`, Claude Code hooks that format edits and block `--no-verify` / force pushes |

Deployment is intentionally out of scope: projects keep their own deploy workflows.

## Install

In the root of a Git repository with a clean working tree:

```bash
sh -c "$(curl -fsSL https://raw.githubusercontent.com/brizenchi/dev-standards/main/install.sh)"
```

or directly with [Copier](https://copier.readthedocs.io/) (via [uv](https://docs.astral.sh/uv/)):

```bash
uvx copier copy gh:brizenchi/dev-standards .
```

Copier asks a few questions (languages, directories, CI mode, …) and records the
answers in `.copier-answers.yml`. Then:

```bash
git diff                                   # review
brew install lefthook gitleaks && lefthook install
gh auth login && .standards/bin/setup-github --dry-run   # then without --dry-run
git add -A && git commit -m "chore: install dev-standards"
```

Non-interactive example:

```bash
uvx copier copy --defaults gh:brizenchi/dev-standards . \
  --data 'languages=["go","node"]' \
  --data 'go_modules=[{"dir": "."}]' \
  --data 'node_projects=[{"dir": "web", "scripts": "lint test build"}]'
```

## Update

```bash
uvx copier update             # re-ask questions, merge the new version
uvx copier update --defaults  # keep previous answers
```

Copier performs a three-way merge between the version you installed, the new
version and your working tree: your edits are kept, and real conflicts are marked
inline like a Git merge. Resolve them, run your checks and commit
(`chore: update dev-standards`).

## Customising per project

| Want to… | Do |
| --- | --- |
| Change languages, directories, scripts, CI mode | `uvx copier update` and answer differently |
| Add project conventions (architecture, deploy, commands) | Edit `docs/standards/PROJECT.md` and the "Project-specific rules" section of `AGENTS.md` |
| Tweak any generated file | Edit it; updates merge around your changes |
| Own a file completely | `CODEOWNERS`, `SECURITY.md`, `CLAUDE.md`, `.gitignore` and `PROJECT.md` are never overwritten after the first install |
| Add your own CI checks | Put them in another workflow file; append their names to `.github/required-checks.txt` and rerun `setup-github` |
| Gate a deploy on the standards | Choose `ci_mode=reusable`; call `./.github/workflows/standards.yml` from your pipeline and add `needs:` to the deploy job |

### Answers

| Question | Meaning |
| --- | --- |
| `languages` | Any of `go`, `node`, `python` |
| `go_modules` | `[{dir, packages?, lint?, lint_version?}]` — `packages` defaults to `./...` |
| `node_projects` | `[{dir, scripts?, node_version?, package_manager?}]` — scripts default to `lint test build`; package manager from the lockfile unless set |
| `python_projects` | `[{dir, python_version?, test_command?}]` |
| `commit_scopes` | Suggested scopes shown in the Git workflow document |
| `ci_mode` | `standalone` (runs on PRs and pushes) or `reusable` (called by your workflow) |
| `ai_rules` | Install `AGENTS.md`, `CLAUDE.md` and Claude Code hooks |

## Reusable workflows

Usable directly, without Copier:

```yaml
jobs:
  go:
    uses: brizenchi/dev-standards/.github/workflows/go.yml@v1
    with:
      working-directory: backend
```

| Workflow | Jobs | Inputs |
| --- | --- | --- |
| `pr-title.yml` | `pr-title` | `types` |
| `secrets.yml` | `gitleaks` | `gitleaks-version` |
| `go.yml` | `check`, `lint`, `vuln` | `working-directory`, `packages`, `go-version-file`, `lint`, `lint-version` (v1.x or v2.x), `vuln-blocking` |
| `node.yml` | `check`, `audit` | `working-directory`, `node-version`, `scripts`, `package-manager`, `audit-blocking` |
| `python.yml` | `check`, `audit` | `working-directory`, `python-version`, `test-command`, `audit-blocking` |

## Versioning

Releases are tagged `vX.Y.Z`. Generated workflows reference the reusable
workflows as `@v1`, which is a **branch** fast-forwarded to the latest `1.x`
release (a branch, not a tag: Copier versions projects by tags, and a moving
`v1` tag would hide the installed version from `copier update`).
`copier update` moves projects to the newest `vX.Y.Z` tag. Breaking changes
(renamed inputs, removed jobs, new required checks) bump the major version and
start a `v2` branch. See [CHANGELOG.md](CHANGELOG.md).

Release:

```bash
git tag v1.2.0 && git branch -f v1 v1.2.0
git push origin main v1 v1.2.0
```

## Developing this repository

```bash
tests/run.sh      # renders the template in several configurations and lints the result
```

Requires `uv`, `actionlint` and `shellcheck`.

Vulnerability jobs (`vuln`, `audit`) are non-blocking by default: they report
findings without failing the calling workflow, so a deploy that `needs:` the
standards is not blocked by a newly published CVE. Set `vuln-blocking` /
`audit-blocking` to `true` to make them gate.
