# Reusable workflows

The generated `.github/workflows/keel.yml` calls these workflows, and you can
call them directly from any repository without installing the template:

```yaml
jobs:
  go:
    uses: brizenchi/keel/.github/workflows/go.yml@v2
    with:
      working-directory: backend
```

`@v2` is a branch that always points at the latest 2.x release. Pin a tag
(`@v2.0.0`) or a commit SHA for fully reproducible builds.

## `pr-title.yml`

| Job | Runs on | Inputs |
| --- | --- | --- |
| `pr-title` | pull requests only | `types` — allowed types as a regex alternation (default `feat\|fix\|perf\|refactor\|docs\|test\|build\|ci\|chore\|revert`) |

Fails unless the title matches `type(scope)!: subject` with a subject of at
most 72 characters. The title is passed through the environment, never
interpolated into the script.

## `secrets.yml`

| Job | Inputs |
| --- | --- |
| `gitleaks` | `gitleaks-version` (default `8.30.1`) |

Scans the full history. Uses the caller's `.gitleaks.toml` and
`.gitleaksignore` when present.

## `go.yml`

| Job | What it does |
| --- | --- |
| `check` | `gofmt -s -l`, `go vet`, `go test -race -cover` |
| `lint` | golangci-lint (v1 or v2 action chosen from `lint-version`), using the module's or repository's `.golangci.yml` |
| `vuln` | govulncheck — non-blocking unless `vuln-blocking: true` |

Inputs: `working-directory` (`.`), `packages` (`./...`), `go-version-file`
(`<dir>/go.mod`), `lint` (`true`), `lint-version` (`v2.5.0`), `vuln-blocking` (`false`).

## `node.yml`

| Job | What it does |
| --- | --- |
| `check` | Install with the package manager, then run each script in `scripts` that exists |
| `audit` | Production dependency audit, high severity — non-blocking unless `audit-blocking: true` |

Inputs: `working-directory` (`.`), `node-version` (`22`), `scripts`
(`lint test build`), `package-manager` (`auto`), `audit-blocking` (`false`).

## `python.yml`

| Job | What it does |
| --- | --- |
| `check` | `ruff check`, `ruff format --check`, install (uv), tests |
| `audit` | pip-audit of `uv.lock` or `requirements.txt` — non-blocking unless `audit-blocking: true` |

Inputs: `working-directory` (`.`), `python-version` (`3.12`), `test-command`
(auto: pytest when tests exist), `audit-blocking` (`false`).

## Why audits do not block by default

When `keel.yml` is called from a pipeline (`ci_mode: reusable`), a failed job
fails the whole call and blocks everything that `needs:` it. A vulnerability
published today in a dependency should not stop an unrelated hotfix from
shipping, so audit jobs report without failing unless you opt in.
