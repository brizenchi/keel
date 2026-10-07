# Configuration

Answers are stored in `.keel/answers.yml`. Change them with `keel set`,
`keel add`, `keel remove`, `keel enable`, `keel disable` or `keel config` —
not by editing the file, which also records the installed version.

| Answer | Type | Default | Meaning |
| --- | --- | --- | --- |
| `project_name` | string | directory name | Used in documents |
| `github_repo` | `owner/name` | from `origin` | Used by `keel github`, `SECURITY.md`, docs |
| `default_branch` | string | `main` | CI triggers and branch rules |
| `components` | list | all | See [components.md](components.md) |
| `languages` | list of `go`, `node`, `python` | `[]` | Selects per-language docs, CI jobs and hooks |
| `go_modules` | list | `[{dir: "."}]` | `{dir, packages?, lint?, lint_version?}` |
| `node_projects` | list | `[{dir: "."}]` | `{dir, scripts?, node_version?, package_manager?}` |
| `python_projects` | list | `[{dir: "."}]` | `{dir, python_version?, test_command?}` |
| `codeowners` | string | `@<owner>` | Default owners in `CODEOWNERS` |
| `commit_scopes` | list | `[]` | Suggested scopes shown in the Git workflow document |
| `ci_mode` | `standalone` \| `reusable` | `standalone` | See below |
| `ci_caller_job` | string | `keel` | Job id that calls `keel.yml` in reusable mode |

## Per-module options

### Go (`go_modules`)

| Key | Default | |
| --- | --- | --- |
| `dir` | — | Module directory (where `go.mod` lives) |
| `packages` | `./...` | Space-separated patterns for vet, test, lint, govulncheck |
| `lint` | `true` | Run golangci-lint |
| `lint_version` | `v2.5.0` | `v1.x` or `v2.x`, matching your `.golangci.yml` format |

### Node (`node_projects`)

| Key | Default | |
| --- | --- | --- |
| `dir` | — | Directory with `package.json` |
| `scripts` | `lint test build` | Package scripts to run in order; missing ones are skipped |
| `node_version` | `22` | |
| `package_manager` | auto | `npm`, `pnpm` or `yarn`; auto prefers the lockfile, npm first |

### Python (`python_projects`)

| Key | Default | |
| --- | --- | --- |
| `dir` | — | Project directory |
| `python_version` | `3.12` | |
| `test_command` | auto | Default runs `pytest` when tests exist |

## CI modes

**standalone** — `.github/workflows/keel.yml` runs on pull requests and pushes
to the default branch. Required check names look like `go-root / check`.

**reusable** — `keel.yml` only runs when your own workflow calls it, so other
jobs (a deploy, for example) can depend on it:

```yaml
jobs:
  keel:
    uses: ./.github/workflows/keel.yml
  deploy:
    needs: [keel]
    # …
```

Required check names are then prefixed with the caller job id, e.g.
`keel / go-root / check`.
