#!/usr/bin/env sh
# Install the keel CLI.
#
#   curl -fsSL https://raw.githubusercontent.com/brizenchi/keel/main/install.sh | sh
#
# Env:
#   KEEL_VERSION      release to install, e.g. v2.1.0 (default: the latest release)
#   KEEL_INSTALL_DIR  target directory (default: ~/.local/bin)
#   KEEL_REF          install from a branch or commit instead of a release
#                     (development only: no checksum is available)
#
# Release downloads are verified against the release's SHA256SUMS file.
# The CLI is a single bash script; installing it only downloads that file.
# Running `keel init` inside a repository then installs the standards there.
set -eu

repo=https://github.com/brizenchi/keel
dir=${KEEL_INSTALL_DIR:-"$HOME/.local/bin"}
version=${KEEL_VERSION:-latest}
ref=${KEEL_REF:-}
if [ -n "${KEEL_DOWNLOAD_URL:-}" ]; then base=$KEEL_DOWNLOAD_URL   # tests and mirrors
elif [ "$version" = latest ]; then base="$repo/releases/latest/download"
else base="$repo/releases/download/$version"; fi

die() { echo "error: $*" >&2; exit 1; }
command -v curl >/dev/null 2>&1 || die "curl is required"

sha256() {
  if command -v sha256sum >/dev/null 2>&1; then sha256sum "$1" | cut -d' ' -f1
  elif command -v shasum >/dev/null 2>&1; then shasum -a 256 "$1" | cut -d' ' -f1
  else die "sha256sum or shasum is required to verify the download"; fi
}

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

if [ -n "$ref" ]; then
  url="https://raw.githubusercontent.com/brizenchi/keel/$ref/template/.keel/bin/keel"
  curl -fsSL "$url" -o "$tmp/keel" || die "download failed: $url"
  echo "note: installed from $ref without checksum verification"
else
  curl -fsSL "$base/keel" -o "$tmp/keel" || die "download failed: $base/keel"
  curl -fsSL "$base/SHA256SUMS" -o "$tmp/SHA256SUMS" || die "download failed: $base/SHA256SUMS"
  expected=$(awk '$2 == "keel" || $2 == "*keel" { print $1 }' "$tmp/SHA256SUMS")
  [ -n "$expected" ] || die "SHA256SUMS has no entry for keel"
  actual=$(sha256 "$tmp/keel")
  [ "$expected" = "$actual" ] || die "checksum mismatch for keel (expected $expected, got $actual)"
fi
head -1 "$tmp/keel" | grep -q '^#!/usr/bin/env bash' || die "the download is not the keel CLI"

mkdir -p "$dir"
chmod +x "$tmp/keel"
mv "$tmp/keel" "$dir/keel"

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
