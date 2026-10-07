#!/usr/bin/env sh
# Install the keel CLI.
#
#   curl -fsSL https://raw.githubusercontent.com/brizenchi/keel/main/install.sh | sh
#
# Env:
#   KEEL_REF          git ref to install from (default: v2, the latest 2.x release)
#   KEEL_INSTALL_DIR  target directory (default: ~/.local/bin)
#
# The CLI is a single bash script; installing it only downloads that file.
# Running `keel init` inside a repository then installs the standards there.
set -eu

ref=${KEEL_REF:-v2}
dir=${KEEL_INSTALL_DIR:-"$HOME/.local/bin"}
url="https://raw.githubusercontent.com/brizenchi/keel/${ref}/template/.keel/bin/keel"

command -v curl >/dev/null 2>&1 || { echo "error: curl is required" >&2; exit 1; }
mkdir -p "$dir"
tmp=$(mktemp)
trap 'rm -f "$tmp"' EXIT
curl -fsSL "$url" -o "$tmp"
head -1 "$tmp" | grep -q '^#!/usr/bin/env bash' || { echo "error: unexpected download from $url" >&2; exit 1; }
chmod +x "$tmp"
mv "$tmp" "$dir/keel"
trap - EXIT

echo "keel installed to $dir/keel ($("$dir/keel" version))"
case ":$PATH:" in
  *":$dir:"*) ;;
  *) echo "note: $dir is not on your PATH; add it, e.g.  export PATH=\"$dir:\$PATH\"" ;;
esac
if ! command -v uvx >/dev/null 2>&1 && ! command -v pipx >/dev/null 2>&1; then
  echo "note: keel needs uv (https://docs.astral.sh/uv/getting-started/installation/) or pipx"
fi
echo
echo "Next, inside a Git repository:  keel init"
