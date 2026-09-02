#!/usr/bin/env bash
#
# Install every skill in this repo globally, for all supported agents.
#
# Skill directories each agent scans for user-global skills:
#
#   ~/.claude/skills/            Claude Code, opencode
#   ~/.agents/skills/            Codex CLI, Gemini CLI, opencode
#   ~/.codex/skills/             Codex CLI
#   ~/.gemini/skills/            Gemini CLI
#   ~/.config/opencode/skills/   opencode
#
# Each skill is symlinked by default so `libra pull` + re-run keeps everything
# fresh; use --copy where symlinks are awkward (Windows, or a repo that lives on
# removable media). Re-running is safe and idempotent.
#
# Usage:
#   ./install.sh [--copy] [--dry-run]
#   ./install.sh --uninstall [--dry-run]
set -euo pipefail

repo_root="$(cd "$(dirname "$0")" && pwd)"
src="$repo_root/skills"

mode=symlink
action=install
dry_run=false
for arg in "$@"; do
  case "$arg" in
    --copy)      mode=copy ;;
    --uninstall) action=uninstall ;;
    --dry-run)   dry_run=true ;;
    -h|--help)   sed -n '2,20p' "$0"; exit 0 ;;
    *) echo "error: unknown option '$arg'" >&2; exit 2 ;;
  esac
done

[ -d "$src" ] || { echo "error: no skills found in $src" >&2; exit 1; }

targets=(
  "$HOME/.claude/skills"           # Claude Code, opencode
  "$HOME/.agents/skills"           # Codex CLI, Gemini CLI, opencode
  "$HOME/.codex/skills"            # Codex CLI
  "$HOME/.gemini/skills"           # Gemini CLI
  "$HOME/.config/opencode/skills"  # opencode
)

run() { if $dry_run; then echo "  would: $*"; else "$@"; fi; }

# A symlink into a removable mount breaks the moment the volume is unmounted.
if [ "$action" = install ] && [ "$mode" = symlink ]; then
  case "$repo_root" in
    /run/media/*|/media/*|/mnt/*|/Volumes/*)
      echo "warning: $repo_root looks like a removable mount." >&2
      echo "         Global symlinks will dangle when it is unmounted — consider --copy." >&2
      echo ;;
  esac
fi

for base in "${targets[@]}"; do
  $dry_run || mkdir -p "$base"
  for skill in "$src"/*/; do
    [ -d "$skill" ] || continue
    name="$(basename "$skill")"
    link="$base/$name"

    if [ "$action" = uninstall ]; then
      if [ -e "$link" ] || [ -L "$link" ]; then
        run rm -rf "$link"
        echo "removed   $link"
      fi
      continue
    fi

    run rm -rf "$link"
    if [ "$mode" = copy ]; then
      run cp -R "$src/$name" "$link"
      echo "copied    $link"
    else
      run ln -s "$src/$name" "$link"
      echo "installed $link -> $src/$name"
    fi
  done
done

echo
if [ "$action" = uninstall ]; then
  echo "Uninstalled. Project-local copies under .claude/, .codex/ and .agents/ are untouched."
else
  echo "Done. Skills are now available to Claude Code, Codex CLI, Gemini CLI, and opencode."
  echo "Re-run this after 'libra pull' to pick up updates."
fi
