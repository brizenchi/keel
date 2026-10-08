# Changelog

All notable changes to keel are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the project uses
[Semantic Versioning](https://semver.org/): template output, CLI behaviour and
reusable-workflow inputs are the public API.

## [Unreleased]

## [2.1.1] — 2026-10-08

### Fixed

- `keel update` (and `config`, `enable`, …) could end with
  `syntax error near unexpected token` when the update replaced
  `.keel/bin/keel` while it was running. The update itself had completed.
  Updating from 2.1.0 or earlier still shows the message once, because the old
  CLI is the one running.

## [2.1.0] — 2026-10-08

### Changed

- All generated standards documents, the PR template and generated comments are
  now in English (previously Simplified Chinese). `keel update` merges the new
  text like any upstream change; local edits are kept, but heavily edited
  documents may need conflicts resolved by hand.

### Added

- `backend` component (on by default): API design, database and incident
  response documents, plus the API, database, ownership and money rules in
  `AGENTS.md` and the PR template. Turn it off for libraries, CLIs and other
  projects without a service: `keel disable backend`. It is stored as its own
  answer, so installations from 2.0 keep these documents on update.
- Release assets: every release attaches the CLI and a `SHA256SUMS` file, and
  `install.sh` installs the latest release and verifies its checksum
  (`KEEL_VERSION` pins a release; `KEEL_REF` installs from a branch without
  verification).

### Fixed

- `ONBOARDING.md` pointed Node users to `.copier-answers.yml` instead of
  `.keel/answers.yml`.

## [2.0.0] — 2026-10-07

The project is renamed from **dev-standards** to **keel**. See
[docs/migration.md](docs/migration.md) for upgrading a 1.x installation.

### Added

- `keel` CLI (single bash script, also shipped as `.keel/bin/keel` in every
  project): `init`, `status`, `doctor`, `config`, `components`, `enable`,
  `disable`, `set`, `add`, `remove`, `update`, `hooks`, `github`,
  `lint-commit`.
- Selectable components at install time — `docs`, `ci`, `commit-lint`,
  `secrets`, `hooks`, `github`, `pr-template`, `codeowners`, `dependabot`,
  `security-policy`, `editorconfig`, `gitignore`, `ai`. Disabling a component
  removes its files; enabling it brings them back.
- `install.sh` installs the CLI to `~/.local/bin`.
- Reusable workflows: `vuln-blocking` / `audit-blocking` inputs (audits are
  non-blocking by default); `go.yml` supports golangci-lint v1 and v2;
  `node.yml` accepts an explicit `package-manager`.
- Open-source project files: contributing guide, code of conduct, security
  policy, issue and pull request templates, release workflow.

### Changed

- Generated files live under `.keel/`: answers in `.keel/answers.yml`,
  required checks in `.keel/required-checks.txt`, CLI in `.keel/bin/keel`.
- The generated workflow is `.github/workflows/keel.yml` and references the
  reusable workflows as `brizenchi/keel/.github/workflows/*.yml@v2`.
- The GitHub ruleset created by `keel github` is named `keel`.

### Removed

- `.standards/bin/setup-github` (now `keel github`) and
  `.standards/bin/check-commit-msg.sh` (now `keel lint-commit`).
- The `ai_rules` question (now the `ai` component).

## [1.0.0] — 2026-10-07

Released as **dev-standards**.

### Added

- Copier template: standards documents, AGENTS.md / CLAUDE.md, Claude Code
  hooks, lefthook (gitleaks + formatters), PR template, CODEOWNERS, Dependabot,
  SECURITY.md, `.standards/bin/setup-github`, `.standards/bin/check-commit-msg.sh`.
- Reusable workflows: `pr-title`, `secrets`, `go`, `node`, `python`.
- `install.sh` one-command installer.

[Unreleased]: https://github.com/brizenchi/keel/compare/v2.0.0...HEAD
[2.0.0]: https://github.com/brizenchi/keel/compare/v1.0.0...v2.0.0
[1.0.0]: https://github.com/brizenchi/keel/releases/tag/v1.0.0
