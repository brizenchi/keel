# Components

Choose components at `keel init`; change them later with `keel enable`,
`keel disable` or `keel config`. Disabling a component deletes its files
(after a clean-tree check, so the deletion is one reviewable diff); enabling it
generates them again.

| Component | Files | Notes |
| --- | --- | --- |
| `docs` | `docs/standards/*.md` | Git workflow, code review, code style, security, testing, CI, onboarding, index; `GO.md` / `NODE.md` / `PYTHON.md` per language; `AI_ASSISTANTS.md` with `ai`; `API_STANDARD.md`, `DATABASE.md`, `INCIDENT_RESPONSE.md` with `backend`. `PROJECT.md` is project-owned. |
| `backend` | the three documents above; API, database, ownership and money rules in `AGENTS.md`; API/database items in the PR template | On by default. Turn off for libraries, CLIs and other projects without a service. Stored as its own answer (`backend: true/false`) rather than in `components`, so 2.0 installations keep it on update; the CLI treats it like any other component. |
| `ci` | jobs in `.github/workflows/keel.yml` | One job group per module/project listed in the answers. Needs at least one language. |
| `commit-lint` | `commits` job in `keel.yml` | Checks the PR title (the squash commit message). |
| `secrets` | `.gitleaks.toml`, `secrets` job in `keel.yml`, gitleaks step in `lefthook.yml` | Add historical false positives to `.gitleaksignore`. |
| `hooks` | `lefthook.yml` | Pre-commit only: gitleaks (with `secrets`), gofmt (Go), ruff format (Python). Install with `keel hooks`. |
| `github` | `.keel/required-checks.txt` | Read by `keel github`. Append your own check names. |
| `pr-template` | `.github/pull_request_template.md` | Checks listed per language. |
| `codeowners` | `.github/CODEOWNERS` | Project-owned after the first install. |
| `dependabot` | `.github/dependabot.yml` | Weekly grouped minor/patch updates per module; monthly GitHub Actions. |
| `security-policy` | `SECURITY.md` | Project-owned after the first install. |
| `editorconfig` | `.editorconfig` | |
| `gitignore` | `.gitignore` | Only written when the project has none. |
| `ai` | `AGENTS.md`, `CLAUDE.md`, `.claude/settings.json`, `.claude/hooks/*` | `AGENTS.md` has a project-owned *Project-specific rules* section. Claude Code hooks format edited files and block `--no-verify`, force pushes and force-adding `.env`. |

Always generated: `.keel/answers.yml` (answers and installed version — do not
edit by hand; use the CLI) and `.keel/bin/keel`.

## What keel never touches

Your source code, your own workflows, and anything not listed above. The files
marked *project-owned* (`PROJECT.md`, `CODEOWNERS`, `SECURITY.md`, `CLAUDE.md`,
`.gitignore`) are written once and then left alone by `keel update`.
