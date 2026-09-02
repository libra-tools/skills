#!/usr/bin/env bash
#
# Install this repository's Libra hooks into .libra/hooks/.
#
# .libra/ is the storage directory and is never tracked, so the canonical hook
# lives at hooks/pre-commit.sh and is copied into place by this script. Run it
# once after cloning, and again after pulling a hook change.
#
# Usage:
#   scripts/install-hooks.sh            # install, refusing to clobber a custom hook
#   scripts/install-hooks.sh --force    # overwrite whatever is there
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$repo_root"

force=false
[ "${1:-}" = "--force" ] && force=true

[ -d .libra ] || { echo "error: no .libra directory — is this a Libra repository?" >&2; exit 1; }
mkdir -p .libra/hooks

for src in hooks/*.sh; do
  [ -f "$src" ] || continue
  name="$(basename "$src")"
  dest=".libra/hooks/$name"

  if [ -f "$dest" ] && ! $force; then
    if cmp -s "$src" "$dest"; then
      echo "up to date  $dest"
      continue
    fi
    # `libra init` ships an inert example hook; replacing that is safe.
    if grep -q "Pre-commit hook example" "$dest" 2>/dev/null; then
      echo "replacing the inert libra-init example at $dest"
    else
      echo "refusing to overwrite customized $dest (re-run with --force)" >&2
      exit 1
    fi
  fi

  cp "$src" "$dest"
  chmod +x "$dest"
  echo "installed   $dest"
done

echo
echo "Done. Commits now run scripts/validate-skills.sh and scripts/sync-skills.sh --check."
