# CLI reference

`keel` is a single bash script. It is installed globally by
[`install.sh`](../install.sh) and copied into every project as `.keel/bin/keel`.
It drives [Copier](https://copier.readthedocs.io/) (through `uvx` or `pipx`) and
the GitHub CLI.

Requirements: `git`, `uv` or `pipx`, and `python3` with PyYAML or `uv`.
Optional: `lefthook`, `gitleaks`, `gh`.

Commands that change files (`init`, `config`, `enable`, `disable`, `set`, `add`,
`remove`, `update`) refuse to run on a dirty working tree and print the changed
files when they finish, so every change is one reviewable diff.

## Install and inspect

### `keel init [--version REF] [--defaults] [-- COPIER_ARGS]`

Installs keel into the current repository. Detects the GitHub repository from
the `origin` remote and the languages present in the repository root, then asks
the questions described in [configuration.md](configuration.md).

| Option | Meaning |
| --- | --- |
| `--version REF` | Install a specific release (default: latest tag) |
| `--defaults` | Do not ask; use defaults plus any `--data` passed after `--` |
| `-- ARGS` | Extra Copier arguments, e.g. `--data 'languages=["go"]'` |

### `keel status`

Installed template version and source, repository, languages, CI mode,
enabled components, available updates, whether the git hooks are installed,
and — with an authenticated `gh` — whether the `keel` ruleset is active.

### `keel doctor`

Checks required tools (`git`, `uv`/`pipx`) and optional ones (`lefthook`,
`gitleaks`, `gh`). Exits non-zero when a required tool is missing.

## Configure

These commands keep the installed version (`--vcs-ref=:current:`); use
`keel update` to change versions.

| Command | Example | Effect |
| --- | --- | --- |
| `keel config` | | Re-ask every question with current answers as defaults |
| `keel components` | | List components and whether they are enabled |
| `keel enable <c>...` | `keel enable ai hooks` | Add components; their files are generated |
| `keel disable <c>...` | `keel disable dependabot` | Remove components; their files are deleted |
| `keel set <k>=<v>...` | `keel set ci_mode=reusable ci_caller_job=checks` | Change answers |
| `keel add <list> ...` | `keel add go_modules dir=services/api lint=false` | Append an entry (replaces one with the same `dir`) |
| | `keel add commit_scopes api web` | Append scopes |
| `keel remove <list> <dir\|value>` | `keel remove node_projects web` | Remove an entry |

`keel add go_modules|node_projects|python_projects` also adds the language to
`languages` when missing.

## Upgrade

### `keel update [REF]`

Moves to the latest release (or `REF`) with a three-way merge between the
installed version, the new version and your working tree. Prints the version
change and any files with conflict markers to resolve.

## Git and GitHub

### `keel hooks`

Runs `lefthook install` for the generated `lefthook.yml` and warns when
`gitleaks` is missing.

### `keel github [--dry-run] [--solo] [--approvals N] [--no-admin-bypass] [--repo owner/name]`

Applies, idempotently:

- merge settings: squash only, PR title as commit title, delete branch on merge;
- secret scanning and push protection (availability depends on the plan for private repositories);
- Dependabot alerts and security updates, private vulnerability reporting;
- a branch ruleset named `keel` on the default branch: no deletion or force
  push, linear history, pull request with `N` approvals (default 1, `--solo` = 0),
  resolved review threads, squash-only merges, and the status checks listed in
  `.keel/required-checks.txt`.

Repository admins may bypass the ruleset unless `--no-admin-bypass` is given.
Features unavailable for the repository are reported as *skipped*.

### `keel lint-commit [FILE | -m MSG]`

Validates a commit subject against Conventional Commits:
`type(scope)!: subject`, types `feat fix perf refactor docs test build ci chore revert`,
subject ≤ 72 characters. Without arguments it checks `$COMMIT_TITLE` or the
last commit.

## Environment

| Variable | Default | Purpose |
| --- | --- | --- |
| `KEEL_SOURCE` | `gh:brizenchi/keel` | Template source; a local path or fork works |
| `KEEL_COPIER_SPEC` | `copier>=9.4,<10` | Copier version used |
| `NO_COLOR` | | Disable coloured output |
| `KEEL_REF`, `KEEL_INSTALL_DIR` | `v2`, `~/.local/bin` | Used by `install.sh` |
