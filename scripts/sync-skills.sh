#!/usr/bin/env bash
#
# Mirror the canonical skills into each agent's namespaced directory.
#
# Canonical skills live in skills/<name>/. Every directory starting with a dot is
# a GENERATED MIRROR and must never be hand-edited:
#
#   .agents/skills/   Gemini CLI, opencode (and Codex, via the same standard)
#   .claude/skills/   Claude Code
#   .codex/skills/    Codex CLI
#
# Real copies (not symlinks) are used because a symlink checkout fails closed on
# Windows and does not survive a zip download. (Libra itself does track symlinks:
# it stages them as mode 120000 blobs and restores them on Unix.)
#
# Usage:
#   scripts/sync-skills.sh            # mirror skills/ -> the three agent dirs
#   scripts/sync-skills.sh --check    # exit non-zero if any mirror is out of date
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$repo_root"

src="skills"
tools=(agents claude codex)
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
