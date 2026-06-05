#!/usr/bin/env bash
#
# Install every skill in this repo globally, for all supported agents.
#
#   Claude Code            reads  ~/.claude/skills/
#   Codex CLI / Gemini CLI / opencode   read  ~/.agents/skills/
#
# Each skill is symlinked (not copied) so `libra pull` + re-run keeps everything fresh.
# Re-running is safe and idempotent.
set -euo pipefail

repo_root="$(cd "$(dirname "$0")" && pwd)"
src="$repo_root/.agents/skills"
[ -d "$src" ] || { echo "error: no skills found in $src" >&2; exit 1; }

targets=(
  "$HOME/.agents/skills"   # Codex CLI, Gemini CLI, opencode (global)
  "$HOME/.claude/skills"   # Claude Code (global)
)

for base in "${targets[@]}"; do
  mkdir -p "$base"
  for skill in "$src"/*/; do
    [ -d "$skill" ] || continue
    name="$(basename "$skill")"
    link="$base/$name"
    rm -rf "$link"
    ln -s "$src/$name" "$link"
    echo "installed $link -> $src/$name"
  done
done

echo
echo "Done. Skills are now available to Claude Code, Codex CLI, Gemini CLI, and opencode."
echo "Re-run this after 'libra pull' to pick up updates."
