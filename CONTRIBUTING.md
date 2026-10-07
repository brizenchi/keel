# Contributing to keel

Thanks for helping! keel is small on purpose: a Copier template, a bash CLI and
a handful of reusable GitHub workflows. Changes should keep it that way.

## Ground rules

- **Generated output is public API.** Renaming a file, a job or an answer
  breaks projects on `keel update`. Prefer additive changes; breaking ones need
  a major version and a migration note.
- **Deterministic.** No network calls or randomness while rendering; the same
  answers must always produce the same files.
- **Every component stays optional.** A file must render correctly whether or
  not other components are enabled. Cross-references between components are
  wrapped in `[% if 'x' in components %]`.
- **Local hooks stay minimal.** Only checks that must run before code leaves
  the machine (secrets) or are instant (formatters). Everything else belongs in CI.

## Repository layout

```text
copier.yml               questions, components, template settings
template/                files rendered into projects ([[ ]] / [% %] Jinja delimiters)
template/.keel/bin/keel  the CLI (also what install.sh downloads)
.github/workflows/       reusable workflows (pr-title, secrets, go, node, python) + this repo's CI
docs/                    user documentation
tests/run.sh             self-test
```

Templates use `[[ … ]]` and `[% … %]` instead of Jinja's `{{ }}` / `{% %}` so
GitHub Actions expressions (`${{ }}`) need no escaping. Files without the
`.jinja` suffix are copied verbatim.

## Development

Requirements: `uv`, `git`, `python3`, [`actionlint`](https://github.com/rhysd/actionlint),
[`shellcheck`](https://www.shellcheck.net/).

```bash
tests/run.sh
```

The self-test snapshots your working tree into a throwaway Git repository,
renders the template in several configurations, lints the output
(YAML, actionlint, shellcheck, links, leftover template syntax), exercises
the CLI (`init`, `enable`, `disable`, `set`, `add`, `remove`, `update`,
`github --dry-run`, `lint-commit`) and verifies that `update` keeps local edits.

Try the CLI against your working copy:

```bash
KEEL_SOURCE=/path/to/keel /path/to/keel/template/.keel/bin/keel init
```

(Copier renders from Git, so commit your changes in the keel checkout first,
or use `tests/run.sh`, which snapshots uncommitted changes.)

## Pull requests

- Title in Conventional Commits form, e.g. `feat(cli): add keel remove`.
- Add or update tests in `tests/run.sh` for behaviour changes.
- Update `CHANGELOG.md` under *Unreleased* and the docs in `docs/`.
- Keep the English and Chinese READMEs in sync for user-facing changes.

## Releasing (maintainers)

1. Move *Unreleased* entries in `CHANGELOG.md` under a new version heading.
2. Bump `KEEL_CLI_VERSION` in `template/.keel/bin/keel`.
3. Commit, then tag and push: `git tag vX.Y.Z && git push origin main vX.Y.Z`.

The release workflow runs the self-test, publishes a GitHub release with the
changelog section, and fast-forwards the major branch (`v2`) to the new tag.
