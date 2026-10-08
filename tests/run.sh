#!/usr/bin/env bash
# keel self-test.
#
# Snapshots the working tree (including uncommitted changes) into a throwaway
# Git repository, then exercises the CLI and the rendered output:
# components on/off, languages, CI modes, every configuration command, update
# merges, GitHub dry runs and commit-message linting.
#
# Requires: uv, git, python3, actionlint, shellcheck.
# The CLI runs under $KEEL_TEST_BASH (default /bin/bash, i.e. bash 3.2 on
# macOS) to keep it compatible with the oldest shell users are likely to have.
set -euo pipefail

repo=$(cd "$(dirname "$0")/.." && pwd)
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
test_bash=${KEEL_TEST_BASH:-/bin/bash}
fail=0
pass() { printf '  \033[32m✓\033[0m %s\n' "$1"; }
bad() { printf '  \033[31m✗ %s\033[0m\n' "$1"; fail=1; }
check() { if eval "$2"; then pass "$1"; else bad "$1"; fi; }
gitc() { git -c user.name=test -c user.email=test@example.test "$@"; }

export NO_COLOR=1
export KEEL_SOURCE="$work/tpl"
keel() { "$test_bash" "$repo/template/.keel/bin/keel" "$@"; }

snapshot() { # copy tracked + untracked (non-ignored) files into a tagged repo
  local dir=$1 tag=$2 f
  rm -rf "$dir"; mkdir -p "$dir"
  (cd "$repo" && git ls-files -co --exclude-standard) | while IFS= read -r f; do
    [ -e "$repo/$f" ] || continue
    mkdir -p "$dir/$(dirname "$f")"; cp -p "$repo/$f" "$dir/$f"
  done
  (cd "$dir" && git init -q -b main && git add -A && gitc commit -qm snapshot && git tag "$tag")
}

new_repo() { # new_repo <name> -> path of an empty repo with one commit
  local d="$work/out/$1"
  mkdir -p "$d"
  (cd "$d" && git init -q -b main && gitc commit -q --allow-empty -m "chore: init" \
    && git remote add origin "git@github.com:acme/$1.git")
  echo "$d"
}

commit_all() { (cd "$1" && git add -A && gitc commit -qm "chore: keel change" >/dev/null); }

lint_output() { # lint_output <dir>
  local dst=$1
  if grep -rlE '\[\[ |\[% |%\]' "$dst" --exclude-dir=.git --exclude=.gitleaks.toml --exclude=keel >/dev/null 2>&1; then
    bad "unrendered template syntax: $(grep -rlE '\[\[ |\[% |%\]' "$dst" --exclude-dir=.git --exclude=.gitleaks.toml --exclude=keel | tr '\n' ' ')"
  else pass "no unrendered template syntax"; fi
  if (cd "$dst" && python3 - <<'PY'
import pathlib, re, sys
cjk = re.compile(r"[\u4e00-\u9fff]")
bad = [str(p) for p in pathlib.Path('.').rglob('*') if p.is_file() and '.git' not in p.parts
       and cjk.search(p.read_text(errors='ignore'))]
print("\n".join(bad)); sys.exit(1 if bad else 0)
PY
  ); then pass "output is English only"; else bad "non-English text in output"; fi
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
  if compgen -G "$dst/.github/workflows/*.yml" >/dev/null; then
    if (cd "$dst" && actionlint .github/workflows/*.yml); then pass "actionlint"; else bad "actionlint"; fi
  fi
  local scripts=("$dst/.keel/bin/keel")
  [ -d "$dst/.claude/hooks" ] && scripts+=("$dst"/.claude/hooks/*.sh)
  if shellcheck -x "${scripts[@]}"; then pass "shellcheck"; else bad "shellcheck"; fi
  if [ -d "$dst/docs" ] || [ -f "$dst/AGENTS.md" ]; then
    local targets=()
    for t in docs AGENTS.md SECURITY.md .github; do [ -e "$dst/$t" ] && targets+=("$t"); done
    if python3 "$repo/tests/linkcheck.py" "$dst" "${targets[@]}" >/dev/null; then pass "markdown links"
    else bad "broken links: $(python3 "$repo/tests/linkcheck.py" "$dst" "${targets[@]}" | head -3)"; fi
  fi
}

github_dry_run_checks() { # prints the number of required status checks in the dry run
  (cd "$1" && keel github --dry-run --repo acme/demo) | python3 -c '
import json, re, sys
text = sys.stdin.read()
blocks = re.findall(r"^\{.*?^\}", text, re.S | re.M)
assert len(blocks) == 2, f"expected 2 JSON payloads, got {len(blocks)}"
json.loads(blocks[0]); ruleset = json.loads(blocks[1])
assert ruleset["name"] == "keel"
print(sum(len(r["parameters"]["required_status_checks"]) for r in ruleset["rules"] if r["type"] == "required_status_checks"))'
}

# ---------------------------------------------------------------- static

echo "== static checks"
check "reusable workflows pass actionlint" "(cd '$repo' && actionlint .github/workflows/*.yml)"
check "shellcheck: CLI, install.sh, hooks" "shellcheck -x '$repo/template/.keel/bin/keel' '$repo/install.sh' '$repo'/template/*/hooks/*.sh"
check "CLI parses with $test_bash" "'$test_bash' -n '$repo/template/.keel/bin/keel'"
check "CHANGELOG has a section for the CLI version" \
  "grep -q \"^## \\[\$(sed -n 's/^KEEL_CLI_VERSION=\"\\(.*\\)\"\$/\\1/p' '$repo/template/.keel/bin/keel')\\]\" '$repo/CHANGELOG.md'"

echo "== lint-commit"
for ok in "feat(api): add pagination" "fix: correct typo" "feat(auth)!: require PKCE" "docs(standards): 补充规范" "Merge branch 'main'"; do
  check "accepts: $ok" "keel lint-commit -m \"$ok\" >/dev/null"
done
for no in "update stuff" "feat" "Feat(api): x" "feat(api):nospace" "feat: $(printf 'x%.0s' $(seq 1 80))"; do
  check "rejects: ${no:0:40}" "! keel lint-commit -m \"$no\" >/dev/null 2>&1"
done

snapshot "$work/tpl" v2.0.0

# ---------------------------------------------------------------- init

echo "== init: all components, Go + Node (standalone)"
d=$(new_repo full)
(cd "$d" && keel init --defaults -- --data 'languages=["go","node"]' \
  --data 'node_projects=[{"dir":"web","scripts":"verify","package_manager":"npm"}]' >/dev/null)
for f in .keel/answers.yml .keel/bin/keel .keel/required-checks.txt .github/workflows/keel.yml lefthook.yml \
         .gitleaks.toml .github/pull_request_template.md .github/CODEOWNERS .github/dependabot.yml SECURITY.md \
         .editorconfig .gitignore AGENTS.md CLAUDE.md .claude/settings.json docs/standards/GO.md docs/standards/NODE.md \
         docs/standards/AI_ASSISTANTS.md docs/standards/PROJECT.md docs/standards/API_STANDARD.md \
         docs/standards/DATABASE.md docs/standards/INCIDENT_RESPONSE.md; do
  check "generated $f" "[ -e '$d/$f' ]"
done
check "no PYTHON.md without python" "[ ! -e '$d/docs/standards/PYTHON.md' ]"
check "github_repo detected from origin" "grep -q 'github_repo: acme/full' '$d/.keel/answers.yml'"
check "installed version recorded" "grep -q '_commit: v2.0.0' '$d/.keel/answers.yml'"
check "workflows use @v2" "grep -q 'brizenchi/keel/.github/workflows/go.yml@v2' '$d/.github/workflows/keel.yml'"
check "explicit package manager" "grep -q 'package-manager: \"npm\"' '$d/.github/workflows/keel.yml'"
check "standalone runs on push to main" "grep -q 'branches: \[main\]' '$d/.github/workflows/keel.yml'"
lint_output "$d"
check "github dry run lists 5 required checks" "[ \"\$(github_dry_run_checks '$d')\" = 5 ]"
commit_all "$d"
check "status runs" "(cd '$d' && keel status >/dev/null)"
out=$(cd "$d" && keel status); check "status reports up to date" "grep -q 'up to date (v2.0.0)' <<<\"\$out\""
check "refuses to init twice" "! (cd '$d' && keel init --defaults >/dev/null 2>&1)"

echo "== init: minimal (docs only, no languages)"
d=$(new_repo minimal)
(cd "$d" && keel init --defaults -- --data 'components=["docs"]' >/dev/null)
for f in .github/workflows/keel.yml lefthook.yml .gitleaks.toml AGENTS.md .claude .keel/required-checks.txt SECURITY.md .github/CODEOWNERS; do
  check "not generated: $f" "[ ! -e '$d/$f' ]"
done
check "docs generated" "[ -f '$d/docs/standards/README.md' ]"
check "no SECURITY.md link without security-policy" "! grep -q '(../../SECURITY.md)' '$d/docs/standards/SECURITY_STANDARD.md'"
lint_output "$d"

echo "== init: library without backend rules"
d=$(new_repo lib)
(cd "$d" && keel init --defaults -- --data 'languages=["python"]' --data backend=false >/dev/null)
for f in API_STANDARD.md DATABASE.md INCIDENT_RESPONSE.md; do
  check "not generated: docs/standards/$f" "[ ! -e '$d/docs/standards/$f' ]"
done
check "AGENTS.md has no HTTP API rules" "! grep -q 'HTTP APIs' '$d/AGENTS.md'"
check "AGENTS.md has no money rule" "! grep -q 'float types for money' '$d/AGENTS.md'"
check "PR template has no API/database items" "! grep -q 'Database changed' '$d/.github/pull_request_template.md'"
lint_output "$d"
commit_all "$d"
out=$(cd "$d" && keel components); check "components lists backend as off" "grep -q 'off backend' <<<\"\$out\""

echo "== init: ci component without languages produces no workflow"
d=$(new_repo cionly)
(cd "$d" && keel init --defaults -- --data 'components=["ci","hooks"]' >/dev/null)
check "no empty keel.yml" "[ ! -e '$d/.github/workflows/keel.yml' ]"
check "hooks file valid without commands" "python3 -c 'import yaml,sys; yaml.safe_load(open(sys.argv[1]))' '$d/lefthook.yml'"

echo "== init: Python + Go monorepo, reusable mode"
d=$(new_repo mono)
(cd "$d" && keel init --defaults -- --data 'languages=["go","python"]' \
  --data 'go_modules=[{"dir":"."},{"dir":"services/api","lint":false,"packages":"./internal/..."}]' \
  --data 'python_projects=[{"dir":"tools/etl","test_command":"pytest -q"}]' \
  --data ci_mode=reusable --data ci_caller_job=checks --data 'commit_scopes=["api","etl"]' >/dev/null)
check "reusable trigger" "grep -q '^  workflow_call:' '$d/.github/workflows/keel.yml'"
check "prefixed required check" "grep -qx 'checks / go-services-api / check' '$d/.keel/required-checks.txt'"
check "lint=false omits lint check" "! grep -q 'go-services-api / lint' '$d/.keel/required-checks.txt'"
check "ruff hook for python" "grep -q 'ruff-format' '$d/lefthook.yml'"
check "commit scopes documented" "grep -q '\`api\`' '$d/docs/standards/GIT_WORKFLOW.md'"
lint_output "$d"

# ---------------------------------------------------------------- configure

echo "== configure: enable / disable / set / add / remove"
d=$(new_repo cfg)
(cd "$d" && keel init --defaults -- --data 'languages=["go"]' >/dev/null); commit_all "$d"

(cd "$d" && keel disable ai dependabot >/dev/null)
check "disable ai removes AGENTS.md and .claude" "[ ! -e '$d/AGENTS.md' ] && [ ! -e '$d/.claude' ]"
check "disable dependabot removes dependabot.yml" "[ ! -e '$d/.github/dependabot.yml' ]"
check "disable keeps the installed version" "grep -q '_commit: v2.0.0' '$d/.keel/answers.yml'"
commit_all "$d"

(cd "$d" && keel enable ai >/dev/null)
check "enable ai restores AGENTS.md" "[ -f '$d/AGENTS.md' ] && [ -f '$d/.claude/settings.json' ]"
commit_all "$d"

(cd "$d" && keel disable backend >/dev/null)
check "disable backend removes API_STANDARD.md" "[ ! -e '$d/docs/standards/API_STANDARD.md' ] && grep -q 'backend: false' '$d/.keel/answers.yml'"
commit_all "$d"
(cd "$d" && keel enable backend >/dev/null)
check "enable backend restores API_STANDARD.md" "[ -f '$d/docs/standards/API_STANDARD.md' ] && grep -q 'HTTP APIs' '$d/AGENTS.md'"
commit_all "$d"

check "rejects unknown component" "! (cd '$d' && keel enable nope >/dev/null 2>&1)"

echo "dirty" > "$d/dirty.txt"
check "refuses to change a dirty tree" "! (cd '$d' && keel disable ai >/dev/null 2>&1)"
out=$(cd "$d" && keel disable ai 2>&1 || true); check "dirty tree message mentions commit" "grep -q 'Commit or stash' <<<\"\$out\""
rm "$d/dirty.txt"

(cd "$d" && keel set default_branch=develop >/dev/null)
check "set default_branch updates the workflow" "grep -q 'branches: \[develop\]' '$d/.github/workflows/keel.yml'"
commit_all "$d"

(cd "$d" && keel add go_modules dir=services/api lint=false >/dev/null)
check "add go module adds a job" "grep -q 'go-services-api:' '$d/.github/workflows/keel.yml'"
check "add go module keeps lint=false" "! grep -q 'go-services-api / lint' '$d/.keel/required-checks.txt'"
commit_all "$d"

(cd "$d" && keel add node_projects dir=web >/dev/null)
check "add node project enables the node language" "grep -q 'node-web:' '$d/.github/workflows/keel.yml' && [ -f '$d/docs/standards/NODE.md' ]"
commit_all "$d"

(cd "$d" && keel add commit_scopes api web >/dev/null)
check "add commit scopes" "grep -q '\`web\`' '$d/docs/standards/GIT_WORKFLOW.md'"
commit_all "$d"

(cd "$d" && keel remove go_modules services/api >/dev/null)
check "remove go module removes its job" "! grep -q 'go-services-api' '$d/.github/workflows/keel.yml'"
check "remove unknown entry fails" "! (cd '$d' && git add -A && gitc commit -qm x >/dev/null; keel remove go_modules nope >/dev/null 2>&1)"
lint_output "$d"

# ---------------------------------------------------------------- update

echo "== update: keeps local edits, applies upstream changes"
d=$(new_repo upd)
(cd "$d" && keel init --defaults -- --data 'languages=["go"]' >/dev/null); commit_all "$d"
printf '\n- Local rule: services talk through the gateway only.\n' >> "$d/AGENTS.md"
printf '\nProject owned text.\n' >> "$d/docs/standards/PROJECT.md"
sed -i.bak 's/aim for under 400 changed lines/aim for under 300 changed lines/' "$d/docs/standards/GIT_WORKFLOW.md" && rm "$d/docs/standards/GIT_WORKFLOW.md.bak"
# answers written before the backend question existed
sed -i.bak '/^backend: /d' "$d/.keel/answers.yml" && rm "$d/.keel/answers.yml.bak"
commit_all "$d"
gw="$work/tpl/template/[% if 'docs' in components %]docs[% endif %]/standards/GIT_WORKFLOW.md.jinja"
sed -i.bak 's/\*\*Never force-push `\[\[ default_branch \]\]`/**Do not ever force-push `[[ default_branch ]]`/' "$gw" && rm "$gw.bak"
printf '\nNew upstream paragraph.\n' >> "$work/tpl/template/[% if 'docs' in components %]docs[% endif %]/standards/PROJECT.md.jinja"
# the new release also changes the CLI, which then replaces itself mid-run
cli="$work/tpl/template/.keel/bin/keel"
{ head -1 "$cli"; printf '# %s\n' "padding that shifts every byte offset in the file" "$(printf 'x%.0s' $(seq 1 200))"; tail -n +2 "$cli"; } > "$cli.new"
mv "$cli.new" "$cli"; chmod +x "$cli"
(cd "$work/tpl" && git add -A && gitc commit -qm v2.1 && git tag v2.1.0)
out=$(cd "$d" && keel status); check "status sees the new release" "grep -q 'v2.1.0 available' <<<\"\$out\""
check "update with the project's own CLI exits cleanly" "(cd '$d' && '$test_bash' .keel/bin/keel update >/dev/null 2>&1)"
check "AGENTS.md project rule kept" "grep -q 'Local rule: services talk through the gateway only.' '$d/AGENTS.md'"
check "local doc edit kept" "grep -q 'aim for under 300 changed lines' '$d/docs/standards/GIT_WORKFLOW.md'"
check "upstream doc change applied" "grep -q 'Do not ever force-push \`main\`' '$d/docs/standards/GIT_WORKFLOW.md'"
check "answers without backend keep backend docs" "[ -f '$d/docs/standards/API_STANDARD.md' ] && grep -q 'backend: true' '$d/.keel/answers.yml'"
check "PROJECT.md untouched" "grep -q 'Project owned text.' '$d/docs/standards/PROJECT.md' && ! grep -q 'New upstream paragraph.' '$d/docs/standards/PROJECT.md'"
check "answers record v2.1.0" "grep -q '_commit: v2.1.0' '$d/.keel/answers.yml'"
check "the project's CLI was updated" "grep -q 'padding that shifts' '$d/.keel/bin/keel'"

# ---------------------------------------------------------------- install

echo "== install.sh: checksum-verified download"
rel="$work/release"; mkdir -p "$rel"
cp "$repo/template/.keel/bin/keel" "$rel/keel"
(cd "$rel" && if command -v sha256sum >/dev/null; then sha256sum keel; else shasum -a 256 keel; fi > SHA256SUMS)
check "installs a verified release" \
  "KEEL_DOWNLOAD_URL='file://$rel' KEEL_INSTALL_DIR='$work/bin' sh '$repo/install.sh' >/dev/null && '$test_bash' '$work/bin/keel' version | grep -q '^keel '"
printf '# tampered\n' >> "$rel/keel"
out=$(KEEL_DOWNLOAD_URL="file://$rel" KEEL_INSTALL_DIR="$work/bin2" sh "$repo/install.sh" 2>&1 || true)
check "rejects a tampered download" "grep -q 'checksum mismatch' <<<\"\$out\" && [ ! -e '$work/bin2/keel' ]"

echo
if [ "$fail" -eq 0 ]; then echo "ALL CHECKS PASSED"; else echo "SOME CHECKS FAILED"; exit 1; fi
