#!/usr/bin/env bash
# setup-symlinks.sh
#
# Creates the symlinks required for the opencode plugin to resolve bundled
# skills from the repo-root skills/ directory.
#
# Run after cloning, or after any operation that may have stripped symlinks
# (e.g. certain zip/tarball extractions, Windows checkouts, etc.).
#
# Usage:
#   ./scripts/setup-symlinks.sh

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

create_symlink() {
  local target="$1"   # path where the symlink should be created
  local source="$2"   # value the symlink should point to (relative)
  local label="$3"    # human-readable description for output

  if [ -L "$target" ]; then
    local current
    current="$(readlink "$target")"
    if [ "$current" = "$source" ]; then
      echo "  [ok]      $label ($target -> $source)"
      return
    else
      echo "  [fix]     $label (was -> $current, updating to -> $source)"
      ln -sfn "$source" "$target"
    fi
  elif [ -e "$target" ]; then
    echo "  [error]   $target exists but is not a symlink — remove it manually and re-run"
    exit 1
  else
    ln -s "$source" "$target"
    echo "  [created] $label ($target -> $source)"
  fi
}

echo "Setting up symlinks..."
create_symlink \
  "$REPO_ROOT/plugins/opencode/skills" \
  "../../skills" \
  "plugins/opencode/skills -> repo-root skills/"

echo "Done."
