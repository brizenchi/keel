# Security Policy

## Supported versions

| Version | Supported |
| --- | --- |
| 2.x | ✅ |
| 1.x (dev-standards) | ❌ — please migrate, see [docs/migration.md](docs/migration.md) |

## Reporting a vulnerability

Please **do not** open a public issue. Report privately via
[GitHub private vulnerability reporting](https://github.com/brizenchi/keel/security/advisories/new).

Relevant areas include the `keel` CLI (it runs shell commands and calls the
GitHub API with your credentials), the reusable workflows (they run in other
projects' CI), and the generated hooks.

We aim to acknowledge reports within 3 working days and to release a fix for
confirmed high-severity issues within 14 days.
