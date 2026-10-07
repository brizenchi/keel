# Migrating from dev-standards 1.x to keel 2.x

keel 2.0 is the renamed and extended dev-standards. The layout of generated
files changed, so `copier update` cannot move a 1.x project to 2.x by itself.
Re-install instead; it takes a few minutes and is one reviewable diff.

## What changed

| 1.x (dev-standards) | 2.x (keel) |
| --- | --- |
| `.copier-answers.yml` | `.keel/answers.yml` |
| `.github/workflows/standards.yml` | `.github/workflows/keel.yml` |
| `uses: brizenchi/dev-standards/...@v1` | `uses: brizenchi/keel/...@v2` |
| `.github/required-checks.txt` | `.keel/required-checks.txt` |
| `.standards/bin/setup-github` | `keel github` |
| `.standards/bin/check-commit-msg.sh` | `keel lint-commit` |
| `ai_rules: true/false` | the `ai` component |
| ruleset `dev-standards` | ruleset `keel` |

## Steps

1. Note your 1.x answers (`cat .copier-answers.yml`) and anything you added to
   `.github/required-checks.txt`.
2. Remove the 1.x machinery, keeping your project-owned files:

   ```bash
   git rm -q -r .copier-answers.yml .github/workflows/standards.yml \
     .github/required-checks.txt .standards
   git commit -m "chore: remove dev-standards 1.x"
   ```

3. Install keel with the same answers:

   ```bash
   keel init --defaults -- \
     --data project_name=… --data github_repo=owner/name \
     --data 'languages=["go","node"]' \
     --data 'go_modules=[{"dir": "."}]' \
     --data 'node_projects=[{"dir": "web"}]' \
     --data ci_mode=reusable --data ci_caller_job=keel
   ```

   Copier asks before overwriting files that already exist (standards
   documents, `AGENTS.md`, …). Accept to take the 2.x version, then re-apply
   your edits from the diff, or decline to keep yours.

4. Update references in your own workflows: `uses: ./.github/workflows/standards.yml`
   → `uses: ./.github/workflows/keel.yml`, and job ids used in `needs:`.
5. Append your own checks to `.keel/required-checks.txt`.
6. If you applied the 1.x ruleset, delete the `dev-standards` ruleset in
   *Settings → Rules* and run `keel github`.
7. Commit: `chore: migrate to keel 2`.

The 1.x reusable workflows stay available at `@v1` (the repository redirect
covers the old name), so nothing breaks while you migrate.
