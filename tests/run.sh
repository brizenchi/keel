#!/usr/bin/env bash
# Self-test: render the template in several configurations and verify the output.
# Requires: uv (uvx), git, python3, actionlint, shellcheck, gh (for setup-github --dry-run).
set -euo pipefail

repo=$(cd "$(dirname "$0")/.." && pwd)
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
fail=0
pass() { printf '  ✓ %s\n' "$1"; }
bad() { printf '  ✗ %s\n' "$1"; fail=1; }

# Copier renders from Git: snapshot the working tree (including uncommitted
# changes) into a throwaway repository with a version tag.
snapshot() {
  local dir=$1 tag=$2
  rm -rf "$dir" && mkdir -p "$dir"
  (cd "$repo" && git ls-files -co --exclude-standard -z | xargs -0 -I{} cp --parents {} "$dir/" 2>/dev/null) \
    || (cd "$repo" && git ls-files -co --exclude-standard | while read -r f; do mkdir -p "$dir/$(dirname "$f")"; cp "$f" "$dir/$f"; done)
  (cd "$dir" && git init -q -b main && git add -A && git -c user.name=t -c user.email=t@t commit -qm snapshot && git tag "$tag")
}

render() { # name, extra copier args...
  local name=$1; shift
  local dst="$work/out/$name"
  mkdir -p "$dst"
  (cd "$dst" && git init -q -b main)
  uvx --quiet copier copy --quiet --defaults --vcs-ref v1.0.0 "$@" "$work/tpl" "$dst" >/dev/null
  (cd "$dst" && git add -A && git -c user.name=t -c user.email=t@t commit -qm "chore: install dev-standards")
  echo "$dst"
}

check_project() { # dir, expected-present..., !expected-absent...
  local dst=$1; shift
  local f
  for f in "$@"; do
    case "$f" in
      !*) [ ! -e "$dst/${f#!}" ] && pass "absent: ${f#!}" || bad "should not exist: ${f#!}" ;;
      *)  [ -e "$dst/$f" ] && pass "present: $f" || bad "missing: $f" ;;
    esac
  done
  # No unrendered template syntax (TOML [[tables]] in .gitleaks.toml are legitimate).
  if grep -rlE '\[\[ |\[% |%\]' "$dst" --exclude-dir=.git --exclude=.gitleaks.toml >/dev/null 2>&1; then
    bad "unrendered template syntax in: $(grep -rlE '\[\[ |\[% |%\]' "$dst" --exclude-dir=.git --exclude=.gitleaks.toml | tr '\n' ' ')"
  else pass "no unrendered template syntax"; fi
  # YAML validity
  if (cd "$dst" && python3 - <<'PY'
import pathlib, sys, yaml
bad = []
for p in pathlib.Path('.').rglob('*.y*ml'):
    if '.git' in p.parts: continue
    try: yaml.safe_load(p.read_text())
    except Exception as e: bad.append(f"{p}: {e}")
print("\n".join(bad)); sys.exit(1 if bad else 0)
PY
  ); then pass "YAML valid"; else bad "invalid YAML"; fi
  # Workflows
  if (cd "$dst" && actionlint .github/workflows/*.yml); then pass "actionlint"; else bad "actionlint"; fi
  # Shell scripts
  local scripts=("$dst/.standards/bin/setup-github" "$dst/.standards/bin/check-commit-msg.sh")
  [ -d "$dst/.claude/hooks" ] && scripts+=("$dst"/.claude/hooks/*.sh)
  if shellcheck -x "${scripts[@]}"; then pass "shellcheck"; else bad "shellcheck"; fi
  # Links
  if python3 "$repo/tests/linkcheck.py" "$dst" docs AGENTS.md SECURITY.md .github >/dev/null; then pass "markdown links"
  else bad "broken links: $(python3 "$repo/tests/linkcheck.py" "$dst" docs AGENTS.md SECURITY.md .github | head -3)"; fi
  # setup-github dry run produces valid JSON payloads
  if (cd "$dst" && .standards/bin/setup-github --dry-run --repo acme/demo | python3 -c '
import json, re, sys
text = sys.stdin.read()
blocks = re.findall(r"^\{.*?^\}", text, re.S | re.M)
assert len(blocks) == 2, f"expected 2 JSON payloads, got {len(blocks)}"
ruleset = json.loads(blocks[1]); json.loads(blocks[0])
checks = [c["context"] for r in ruleset["rules"] if r["type"] == "required_status_checks" for c in r["parameters"]["required_status_checks"]]
assert checks, "no required checks"
print(len(checks))'); then pass "setup-github --dry-run JSON"; else bad "setup-github --dry-run"; fi
}

echo "== reusable workflows"
if (cd "$repo" && actionlint .github/workflows/*.yml); then pass "actionlint"; else bad "actionlint"; fi
if shellcheck "$repo/install.sh"; then pass "shellcheck install.sh"; else bad "shellcheck install.sh"; fi

echo "== commit message checker"
cm="$repo/template/.standards/bin/check-commit-msg.sh"
for ok in "feat(api): add pagination" "fix: correct typo" "feat(auth)!: require PKCE" "docs(standards): 补充规范" "Merge branch 'main'"; do
  printf '%s\n' "$ok" > "$work/msg"; "$cm" "$work/msg" 2>/dev/null && pass "accepts: $ok" || bad "rejects valid: $ok"
done
for no in "update stuff" "feat" "Feat(api): x" "feat(api):nospace"; do
  printf '%s\n' "$no" > "$work/msg"; "$cm" "$work/msg" 2>/dev/null && bad "accepts invalid: $no" || pass "rejects: $no"
done

snapshot "$work/tpl" v1.0.0

echo "== go only (standalone)"
d=$(render go-only --data project_name=goapp --data github_repo=acme/goapp --data 'languages=["go"]')
check_project "$d" AGENTS.md CLAUDE.md .claude/settings.json docs/standards/GO.md '!docs/standards/NODE.md' '!docs/standards/PYTHON.md' lefthook.yml .github/workflows/standards.yml
grep -q 'branches: \[main\]' "$d/.github/workflows/standards.yml" && pass "standalone triggers on push to main" || bad "standalone push trigger"

echo "== node only, no AI rules"
d=$(render node-noai --data project_name=web --data 'languages=["node"]' --data ai_rules=false --data 'node_projects=[{"dir":"web","scripts":"verify","node_version":"20","package_manager":"npm"}]')
check_project "$d" docs/standards/NODE.md '!AGENTS.md' '!CLAUDE.md' '!.claude' '!docs/standards/AI_ASSISTANTS.md' '!docs/standards/GO.md'
grep -q 'scripts: "verify"' "$d/.github/workflows/standards.yml" && pass "custom node scripts" || bad "custom node scripts"
grep -q 'package-manager: "npm"' "$d/.github/workflows/standards.yml" && pass "explicit package manager" || bad "explicit package manager"

echo "== python only"
d=$(render py --data project_name=svc --data 'languages=["python"]')
check_project "$d" docs/standards/PYTHON.md '!docs/standards/GO.md'
grep -q 'ruff-format' "$d/lefthook.yml" && pass "ruff hook" || bad "ruff hook"

echo "== all languages, reusable, nested dirs"
d=$(render mono --data project_name=mono --data github_repo=acme/mono --data 'languages=["go","node","python"]' \
  --data 'go_modules=[{"dir":"."},{"dir":"services/api","lint":false,"packages":"./internal/..."}]' \
  --data 'node_projects=[{"dir":"apps/web"}]' --data 'python_projects=[{"dir":"tools/etl","test_command":"pytest -q"}]' \
  --data ci_mode=reusable --data ci_caller_job=ci --data 'commit_scopes=["api","web"]')
check_project "$d" docs/standards/GO.md docs/standards/NODE.md docs/standards/PYTHON.md
grep -q '^  workflow_call:' "$d/.github/workflows/standards.yml" && pass "reusable trigger" || bad "reusable trigger"
grep -qx 'ci / go-services-api / check' "$d/.github/required-checks.txt" && pass "prefixed check names" || bad "prefixed check names"
grep -q 'ci / go-services-api / lint' "$d/.github/required-checks.txt" && bad "lint check listed although lint=false" || pass "lint=false omits lint check"
grep -q '`api`' "$d/docs/standards/GIT_WORKFLOW.md" && pass "commit scopes documented" || bad "commit scopes"

echo "== no languages"
d=$(render none --data project_name=docsonly)
check_project "$d" '!docs/standards/GO.md' '!docs/standards/NODE.md' '!docs/standards/PYTHON.md'

echo "== update keeps local edits"
d=$(render upd --data project_name=upd --data 'languages=["go"]')
printf '\n- Local rule: services talk through the gateway only.\n' >> "$d/AGENTS.md"
printf '\nProject owned text.\n' >> "$d/docs/standards/PROJECT.md"
sed -i.bak 's/控制在 400 行以内/控制在 300 行以内/' "$d/docs/standards/GIT_WORKFLOW.md" && rm "$d/docs/standards/GIT_WORKFLOW.md.bak"
(cd "$d" && git add -A && git -c user.name=t -c user.email=t@t commit -qm "docs: local edits")
# New template version changes another line of the same document.
sed -i.bak 's/禁止对 `\[\[ default_branch \]\]` 或任何已推送/严禁对 `[[ default_branch ]]` 或任何已推送/' "$work/tpl/template/docs/standards/GIT_WORKFLOW.md.jinja" && rm "$work/tpl/template/docs/standards/GIT_WORKFLOW.md.jinja.bak"
printf '\nNew upstream paragraph.\n' >> "$work/tpl/template/docs/standards/PROJECT.md.jinja"
(cd "$work/tpl" && git add -A && git -c user.name=t -c user.email=t@t commit -qm v1.1 && git tag v1.1.0)
(cd "$d" && uvx --quiet copier update --quiet --defaults --vcs-ref v1.1.0 >/dev/null)
grep -q 'Local rule: services talk through the gateway only.' "$d/AGENTS.md" && pass "AGENTS.md project rule kept" || bad "AGENTS.md project rule lost"
grep -q '控制在 300 行以内' "$d/docs/standards/GIT_WORKFLOW.md" && pass "local doc edit kept" || bad "local doc edit lost"
grep -q '严禁对 `main`' "$d/docs/standards/GIT_WORKFLOW.md" && pass "upstream doc change applied" || bad "upstream doc change missing"
grep -q 'Project owned text.' "$d/docs/standards/PROJECT.md" && ! grep -q 'New upstream paragraph.' "$d/docs/standards/PROJECT.md" \
  && pass "PROJECT.md untouched by update" || bad "PROJECT.md was modified by update"
grep -q '_commit: v1.1.0' "$d/.copier-answers.yml" && pass "answers file records v1.1.0" || bad "answers file version"

echo
if [ "$fail" -eq 0 ]; then echo "ALL CHECKS PASSED"; else echo "SOME CHECKS FAILED"; exit 1; fi
