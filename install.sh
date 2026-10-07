#!/usr/bin/env sh
# Install dev-standards into the current Git repository (or the given directory).
#
#   sh -c "$(curl -fsSL https://raw.githubusercontent.com/brizenchi/dev-standards/main/install.sh)"
#   sh -c "$(curl -fsSL …/install.sh)" -- path/to/repo --vcs-ref v1.2.0
#
# Extra arguments after the directory are passed to `copier copy`
# (e.g. --vcs-ref, --data key=value, --defaults).
#
# Env:
#   DEV_STANDARDS_SRC  template source (default gh:brizenchi/dev-standards)
set -eu

src=${DEV_STANDARDS_SRC:-gh:brizenchi/dev-standards}
dst=${1:-.}
[ $# -gt 0 ] && shift

if ! git -C "$dst" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "error: $dst is not a Git repository (run 'git init' first)" >&2
  exit 1
fi
if [ -n "$(git -C "$dst" status --porcelain)" ]; then
  echo "error: $dst has uncommitted changes; commit or stash them so the install can be reviewed as one diff" >&2
  exit 1
fi

if command -v uvx >/dev/null 2>&1; then
  run() { uvx copier "$@"; }
elif command -v pipx >/dev/null 2>&1; then
  run() { pipx run copier "$@"; }
elif command -v copier >/dev/null 2>&1; then
  run() { copier "$@"; }
else
  echo "error: needs uv (recommended), pipx or copier." >&2
  echo "  install uv: https://docs.astral.sh/uv/getting-started/installation/" >&2
  exit 1
fi

# Copier asks questions interactively; keep a TTY even when piped from curl.
if [ -t 0 ] || [ ! -r /dev/tty ]; then
  run copy "$src" "$dst" "$@"
else
  run copy "$src" "$dst" "$@" </dev/tty
fi
