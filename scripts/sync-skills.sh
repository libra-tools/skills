#!/usr/bin/env bash
#
# Mirror the canonical skills into each agent's namespaced directory.
#
# Canonical skills live in .agents/skills/<name>/ (read directly by Gemini CLI and
# opencode). Claude Code reads .claude/skills/ and Codex CLI reads .codex/skills/,
# so we keep real copies there. Real copies (not symlinks) are used because Libra
# does not track symlinks and because copies survive Windows clones and zip downloads.
#
# Usage:
#   scripts/sync-skills.sh            # mirror canonical -> .claude/skills + .codex/skills
#   scripts/sync-skills.sh --check    # exit non-zero if any mirror is out of date (for CI)
#
# Run this after editing anything under .agents/skills/, before committing.
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$repo_root"

src=".agents/skills"
tools=(claude codex)
check_only=false
[ "${1:-}" = "--check" ] && check_only=true

[ -d "$src" ] || { echo "error: no $src directory found" >&2; exit 1; }

drift=0

for tool in "${tools[@]}"; do
  dest=".${tool}/skills"
  mkdir -p "$dest"

  # Remove mirrored skills whose canonical source is gone.
  for d in "$dest"/*/; do
    [ -d "$d" ] || continue
    name="$(basename "$d")"
    if [ ! -d "$src/$name" ]; then
      if $check_only; then echo "drift: $dest/$name has no canonical source"; drift=1
      else rm -rf "$dest/$name"; echo "removed stale $dest/$name"; fi
    fi
  done

  # Mirror each canonical skill.
  for skill in "$src"/*/; do
    [ -d "$skill" ] || continue
    name="$(basename "$skill")"
    if $check_only; then
      if ! diff -rq "$skill" "$dest/$name" >/dev/null 2>&1; then
        echo "drift: $dest/$name differs from $src/$name"; drift=1
      fi
    else
      rm -rf "$dest/$name"
      cp -R "$skill" "$dest/$name"
      echo "synced $dest/$name"
    fi
  done
done

if $check_only && [ "$drift" -ne 0 ]; then
  echo "skills are out of sync — run scripts/sync-skills.sh" >&2
  exit 1
fi

$check_only && echo "all agent skill mirrors are up to date"
exit 0
